USE ecommerce_churn_analysis;

-- 1. Customer Churn Rate Based on Inactivity

WITH customers_last_order_dates AS (
    SELECT 
        customer_id,
        MAX(order_date) AS last_order_date
    FROM ecommerce_churn_analysis.orders
    GROUP BY customer_id
),

dataset_end AS (
    SELECT MAX(order_date) AS dataset_end_date
    FROM ecommerce_churn_analysis.orders
)

SELECT
    (SELECT COUNT(*) FROM ecommerce_churn_analysis.customers) AS total_customers,
    COUNT(*) AS churn_customers,
    COUNT(*) * 100.0 / (SELECT COUNT(*) FROM ecommerce_churn_analysis.customers) AS churn_rate,
    100.0 - (COUNT(*) * 100.0 / (SELECT COUNT(*) FROM ecommerce_churn_analysis.customers)) AS retention_rate
FROM customers_last_order_dates c
CROSS JOIN dataset_end d
WHERE DATEDIFF(d.dataset_end_date, c.last_order_date) > 90;

-- 2. Customer Retention Rate Over Time

-- Customers with 0 orders

SELECT COUNT(c.customer_id)
FROM ecommerce_churn_analysis.customers c LEFT JOIN ecommerce_churn_analysis.orders o
ON c.customer_id = o.customer_id
WHERE o.order_id IS NULL;


-- Customers with 1 order and multiple orders

WITH Customers_with_number_of_orders AS 
(
SELECT c.customer_id, COUNT(o.order_id) AS Number_Of_Orders
FROM ecommerce_churn_analysis.customers c JOIN ecommerce_churn_analysis.orders o
ON c.customer_id = o.customer_id
GROUP BY c.customer_id)

SELECT 
COUNT(CASE WHEN Number_Of_Orders = 1 THEN 1 END)  AS Customers_with_1_order,
COUNT(CASE WHEN Number_Of_Orders > 1 THEN 1 END)  AS Customers_with_multiple_orders,
COUNT(CASE WHEN Number_Of_Orders > 1 THEN 1 END)*100.0/
(COUNT(CASE WHEN Number_Of_Orders > 1 THEN 1 END)+ COUNT(CASE WHEN Number_Of_Orders = 1 THEN 1 END)) AS retention_percentage
FROM Customers_with_number_of_orders;

-- 3. Purchase Interval Analysis

-- CTE for detection of Previous order date by customers

WITH order_sequence AS
(
SELECT
    customer_id,
    order_id,
    order_date,
    LAG(order_date) OVER (
        PARTITION BY customer_id
        ORDER BY order_date
    ) AS previous_order_date
FROM ecommerce_churn_analysis.orders
),

-- CTE for Time Between Customer Purchases

purchase_intervals AS
(
SELECT
    customer_id,
    order_id,
    order_date,
    previous_order_date,
    DATEDIFF(order_date, previous_order_date) AS days_between_orders
FROM order_sequence
WHERE previous_order_date IS NOT NULL
),

-- CTE for Average Time Between Customer Purchases

customer_purchase_frequency AS
(
SELECT
    customer_id,
    AVG(days_between_orders) AS avg_days_between_orders
FROM purchase_intervals
GROUP BY customer_id
)

-- Classification of customers based on purchase frequency

SELECT
CASE
    WHEN avg_days_between_orders < 30 THEN 'Frequent Buyers'
    WHEN avg_days_between_orders BETWEEN 30 AND 90 THEN 'Moderate Buyers'
    ELSE 'Rare Buyers'
END AS purchase_frequency,
COUNT(*) AS number_of_customers
FROM customer_purchase_frequency
GROUP BY purchase_frequency;

-- 4. Relationship Between Purchase Frequency and Churn

WITH Customers_with_number_of_orders AS 
(
SELECT customer_id, COUNT(order_id) AS number_of_orders, MAX(order_date) AS last_order_date
FROM ecommerce_churn_analysis.orders o
GROUP BY customer_id),

Customers_with_order_segments AS (

SELECT customer_id,number_of_orders,last_order_date,
CASE 
	WHEN number_of_orders = 1                THEN  '1 order'
    WHEN number_of_orders BETWEEN 2 AND 5    THEN  '2 to 5 orders'
    WHEN number_of_orders BETWEEN 6 AND 10   THEN  '6 to 10 orders'
    WHEN number_of_orders > 10               THEN  '>10 orders'
END AS customer_order_segment
FROM Customers_with_number_of_orders),

dataset_end AS (
    SELECT MAX(order_date) AS dataset_end_date
    FROM ecommerce_churn_analysis.orders
)

SELECT
    customer_order_segment,
    COUNT(*) AS total_customers,
    COUNT(CASE WHEN DATEDIFF(d.dataset_end_date, c.last_order_date) > 90 THEN 1 END) AS churn_customers,
    COUNT(CASE WHEN DATEDIFF(d.dataset_end_date, c.last_order_date) > 90 THEN 1 END)*100.0/COUNT(*) AS churn_rate,
    100.0 - (COUNT(CASE WHEN DATEDIFF(d.dataset_end_date, c.last_order_date) > 90 THEN 1 END)*100.0/COUNT(*)) AS retention_rate
FROM Customers_with_order_segments c
CROSS JOIN dataset_end d 
GROUP BY customer_order_segment;

-- 5. Relationship between Customer Lifetime value and Churn behavior

-- CTE for computing customer liftime value
WITH customer_lifetime_value AS (

SELECT o.customer_id, SUM(oi.price*oi.quantity) AS customer_revenue, MAX(o.order_date) AS last_order_date
FROM ecommerce_churn_analysis.order_items oi JOIN ecommerce_churn_analysis.orders o
ON oi.order_id = o.order_id
GROUP BY o.customer_id),
-- CTE for segmenting customers into revenue tertiles
customers_revenue_tertiles AS (

SELECT customer_id, customer_revenue,last_order_date,
       NTILE(3) OVER (ORDER BY customer_revenue) AS revenue_tertile
FROM customer_lifetime_value),

-- Assigning names to segments based on revenue
customer_value_segments AS (

SELECT customer_id, customer_revenue,last_order_date,

CASE 
	WHEN revenue_tertile = 1                     THEN    'Low Value'
    WHEN revenue_tertile = 2                     THEN    'Medium Value'
    WHEN revenue_tertile = 3                     THEN    'High Value'
END AS customer_value_segment
FROM customers_revenue_tertiles),

-- Calculating the dataset end date to check for churn
dataset_end AS (
    SELECT MAX(order_date) AS dataset_end_date
    FROM ecommerce_churn_analysis.orders
)

-- Calculting total churn customers in each segment and the churn rate
SELECT
    customer_value_segment,
    COUNT(*) AS total_customers,
    COUNT(CASE WHEN DATEDIFF(d.dataset_end_date, c.last_order_date) > 90 THEN 1 END) AS churn_customers,
    COUNT(CASE WHEN DATEDIFF(d.dataset_end_date, c.last_order_date) > 90 THEN 1 END)*100.0/COUNT(*) AS churn_rate,
    100.0 - (COUNT(CASE WHEN DATEDIFF(d.dataset_end_date, c.last_order_date) > 90 THEN 1 END)*100.0/COUNT(*)) AS retention_rate
FROM customer_value_segments c
CROSS JOIN dataset_end d 
GROUP BY customer_value_segment;

-- 6. Customer Lifetime Value Before Churn (Statistics and Distribution)

WITH customer_lifetime_value AS (

SELECT o.customer_id, SUM(oi.price*oi.quantity) AS customer_revenue, MAX(o.order_date) AS last_order_date
FROM ecommerce_churn_analysis.order_items oi JOIN ecommerce_churn_analysis.orders o
ON oi.order_id = o.order_id
GROUP BY o.customer_id),

dataset_end AS (
    SELECT MAX(order_date) AS dataset_end_date
    FROM ecommerce_churn_analysis.orders
),

customer_churn_flag AS (

SELECT c.*, 
      CASE
      	  WHEN  DATEDIFF(d.dataset_end_date, c.last_order_date) > 90  THEN 1
      	  ELSE 0
      END AS churn_flag
FROM customer_lifetime_value c CROSS JOIN dataset_end d),

churn_revenue_segment AS (
SELECT 
     customer_id, customer_revenue,

   CASE
        WHEN customer_revenue < 100 THEN 'Low Revenue'
        WHEN customer_revenue BETWEEN 100 AND 500 THEN 'Medium Revenue'
        WHEN customer_revenue BETWEEN 500 AND 1000 THEN 'High Revenue'
        ELSE 'Very High Revenue'
  END AS revenue_segment 
FROM customer_churn_flag
WHERE churn_flag =1)


SELECT revenue_segment, COUNT(*) AS number_of_customers
FROM churn_revenue_segment
GROUP BY revenue_segment;

-- 7. RFM Segmentation of Customers

WITH dataset_end AS (
    SELECT MAX(order_date) AS dataset_end_date
    FROM ecommerce_churn_analysis.orders
),

customer_rfm_base AS (

SELECT 
    o.customer_id,
    DATEDIFF(MAX(d.dataset_end_date), MAX(o.order_date)) AS recency,
    COUNT(DISTINCT o.order_id) AS frequency,
    SUM(oi.price * oi.quantity) AS monetary

FROM ecommerce_churn_analysis.orders o JOIN ecommerce_churn_analysis.order_items oi
 
ON o.order_id = oi.order_id

CROSS JOIN dataset_end d
GROUP BY o.customer_id
),

rfm_scores AS (

SELECT *,
       NTILE(5) OVER (ORDER BY recency ASC) AS recency_score,
       NTILE(5) OVER (ORDER BY frequency) AS frequency_score,
       NTILE(5) OVER (ORDER BY monetary) AS monetary_score
FROM customer_rfm_base
),

rfm_segmentation AS (

SELECT *,
    
 CASE
    WHEN recency_score >= 4 AND frequency_score >= 4 AND monetary_score >= 4
        THEN 'Champions'

    WHEN frequency_score >= 4 AND monetary_score >= 3
        THEN 'Loyal Customers'

    WHEN recency_score <= 2 AND frequency_score >= 3
        THEN 'At Risk'

    WHEN recency_score >= 4 AND frequency_score <= 2
        THEN 'New Customers'

    ELSE 'Others'
END AS rfm_segment
FROM rfm_scores)

SELECT *, SUM(total_revenue) OVER() AS overall_revenue, total_revenue*100.0/SUM(total_revenue) OVER() AS revenue_percentage
FROM 
(
  SELECT
  rfm_segment, COUNT(*) AS number_of_customers,SUM(monetary) AS total_revenue
  FROM rfm_segmentation
  GROUP BY rfm_segment) t;

-- 8. Cohort Analysis Based on First Purchase Month 

WITH first_purchase AS (
SELECT
    customer_id,
    MIN(order_date) AS first_order_date
FROM ecommerce_churn_analysis.orders
GROUP BY customer_id
),

cohort_assignments AS (

SELECT
    customer_id,
    DATE_FORMAT(first_order_date,'%Y-%m') AS cohort_month,
    first_order_date
FROM first_purchase
),

customer_activity AS (

SELECT
    c.customer_id,
    c.cohort_month,
    o.order_date,
    TIMESTAMPDIFF(MONTH,c.first_order_date,o.order_date) AS month_number

FROM cohort_assignments c
JOIN ecommerce_churn_analysis.orders o
ON c.customer_id = o.customer_id
),

cohort_retention AS (

SELECT
    cohort_month,
    month_number,
    COUNT(DISTINCT customer_id) AS active_customers
FROM customer_activity
GROUP BY cohort_month, month_number
)

SELECT
    r.cohort_month,
    r.month_number,
    r.active_customers,
    r.active_customers * 100.0 /
        FIRST_VALUE(r.active_customers) OVER
        (PARTITION BY r.cohort_month ORDER BY r.month_number)
        AS retention_rate

FROM cohort_retention r
ORDER BY cohort_month, month_number;

-- 9. Product Behavior of Churned Customers

WITH customer_last_orderdate AS (

    SELECT 
        o.customer_id,
        MAX(o.order_date) AS last_order_date
    FROM ecommerce_churn_analysis.orders o
    GROUP BY o.customer_id
),

dataset_end AS (

    SELECT 
        MAX(order_date) AS dataset_end_date
    FROM ecommerce_churn_analysis.orders
),

customer_churn_status AS (

    SELECT 
        c.customer_id,
        c.last_order_date,
        CASE 
            WHEN DATEDIFF(d.dataset_end_date, c.last_order_date) > 90 
            THEN 'Churned'
            ELSE 'Active'
        END AS churn_status
    FROM customer_last_orderdate c
    CROSS JOIN dataset_end d
),

product_customers_by_churn_status AS (

    SELECT 
        oi.product_id,
        c.churn_status,
        COUNT(DISTINCT o.customer_id) AS number_of_customers
    FROM ecommerce_churn_analysis.order_items oi
    JOIN ecommerce_churn_analysis.orders o
        ON oi.order_id = o.order_id
    JOIN customer_churn_status c
        ON o.customer_id = c.customer_id
    GROUP BY 
        oi.product_id,
        c.churn_status
)

SELECT 
    p.product_id,
    p.product_name,

    COALESCE(SUM(CASE 
        WHEN churn_status = 'Churned' 
        THEN number_of_customers END),0) AS churned_customers,

    COALESCE(SUM(CASE 
        WHEN churn_status = 'Active' 
        THEN number_of_customers END),0) AS active_customers,

    ROUND(
        COALESCE(SUM(CASE 
            WHEN churn_status = 'Churned' 
            THEN number_of_customers END),0) * 100.0
        /
        NULLIF(
            COALESCE(SUM(CASE 
                WHEN churn_status = 'Churned' 
                THEN number_of_customers END),0) +
            COALESCE(SUM(CASE 
                WHEN churn_status = 'Active' 
                THEN number_of_customers END),0),
        0),
    2) AS churn_customer_percentage

FROM product_customers_by_churn_status pcs
JOIN ecommerce_churn_analysis.products p
    ON pcs.product_id = p.product_id

GROUP BY 
    p.product_id,
    p.product_name

HAVING 
    SUM(number_of_customers) >= 20

ORDER BY 
    churn_customer_percentage DESC;









 




