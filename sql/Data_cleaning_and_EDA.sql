
-- 1.Database Selection
USE ecommerce_churn_analysis;

-- 2. Creating Tables customers, orders,products and order_items

CREATE TABLE customers (
    customer_id INT PRIMARY KEY,
    country VARCHAR(100)
);

CREATE TABLE products (
    product_id VARCHAR(20) PRIMARY KEY,
    product_name VARCHAR(255)
);

CREATE TABLE orders (
    order_id VARCHAR(20) PRIMARY KEY,
    customer_id INT,
    order_date DATETIME,
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);

CREATE TABLE order_items (
    order_item_id INT AUTO_INCREMENT PRIMARY KEY,
    order_id VARCHAR(20),
    product_id VARCHAR(20),
    quantity INT,
    price DECIMAL(10,2),
    FOREIGN KEY (order_id) REFERENCES orders(order_id),
    FOREIGN KEY (product_id) REFERENCES products(product_id)
);

-- 3. Data Cleaning in MySQL

SELECT *
FROM sql_project
WHERE customer_id IS NULL;


SELECT customer_id, COUNT(DISTINCT country) AS country_count
FROM sql_project
GROUP BY customer_id
HAVING country_count > 1;

-- Add a column row_id for detecting duplicates
ALTER TABLE sql_project
ADD COLUMN row_id INT AUTO_INCREMENT PRIMARY KEY;

-- Create a Table with row_ids having duplicate data
CREATE TABLE duplicates AS
SELECT *
FROM (
    SELECT *,
           ROW_NUMBER() OVER (
               PARTITION BY invoice, stock_code, quantity, price
               ORDER BY row_id
           ) AS rn
    FROM sql_project
) t
WHERE rn > 1;

-- Verify the number of duplicates
SELECT COUNT(*) FROM duplicates;

-- Delete the duplicate rows from main table
DELETE FROM sql_project
WHERE row_id IN (
    SELECT row_id FROM duplicates
);

SELECT invoice,
       stock_code,
       quantity,
       price,
       COUNT(*)
FROM sql_project
GROUP BY invoice, stock_code, quantity, price
HAVING COUNT(*) > 1;

DELETE FROM sql_project
WHERE invoice LIKE 'C%'; 

delete FROM sql_project
WHERE price <= 0;

-- 4.Populating the schema tables from the source table

INSERT INTO customers (customer_id, country)
SELECT customer_id, MIN(country)
FROM sql_project
GROUP BY customer_id;

INSERT INTO products (product_id, product_name)
SELECT stock_code, MIN(description) as description
FROM sql_project
group by stock_code;

INSERT INTO orders (order_id, customer_id, order_date)
SELECT 
    invoice,
    customer_id,
    MIN(invoice_date) AS order_date
FROM sql_project
GROUP BY invoice, customer_id;


SELECT order_id, COUNT(*)
FROM orders
GROUP BY order_id
HAVING COUNT(*) > 1;


INSERT INTO order_items(order_id,product_id,quantity,price)
SELECT 
      invoice,
      stock_code,
      quantity,
      price
FROM sql_project;

ALTER TABLE order_items
MODIFY price DECIMAL(10,3);

UPDATE order_items oi
JOIN sql_project rt
ON oi.order_id = rt.invoice
AND oi.product_id = rt.stock_code
SET oi.price = rt.price
WHERE oi.price = 0;

-- 5. SQL Based Exploratory Data Analysis

-- Total number of customers

SELECT COUNT(*) AS total_customers FROM customers;

-- Total number of orders

SELECT COUNT(*) AS total_orders FROM orders;

-- Total Number of Products

SELECT COUNT(*) AS total_products FROM products;

-- Total number of order items

SELECT COUNT(*) AS total_order_items FROM order_items;

-- Total Revenue Generated

SELECT ROUND(SUM(price*quantity),2) AS total_revenue FROM order_items;

-- Orders per month and Revenue per month

SELECT DATE_FORMAT(o.order_date,'%m-%Y') AS order_month, 
       COUNT(DISTINCT o.order_id) AS total_orders,
       SUM(oi.quantity*oi.price) AS total_revenue
FROM order_items oi JOIN orders o
ON oi.order_id = o.order_id
GROUP BY order_month
ORDER BY MIN(o.order_date);

-- Number of orders per customers and Customer Purchase Freqeuncy 

WITH Customers_with_number_of_orders AS 
(
SELECT c.customer_id, COUNT(o.order_id) AS Number_Of_Orders
FROM ecommerce_churn_analysis.customers c JOIN ecommerce_churn_analysis.orders o
ON c.customer_id = o.customer_id
GROUP BY c.customer_id)

SELECT 
COUNT(CASE WHEN Number_Of_Orders = 1 THEN 1 END)  AS Customers_with_1_order,
COUNT(CASE WHEN Number_Of_Orders BETWEEN 2 AND 5 THEN 1 END)  AS Customers_with_2_to_5_orders,
COUNT(CASE WHEN Number_Of_Orders BETWEEN 6 AND 10 THEN 1 END)  AS Customers_with_6_to_10_orders,
COUNT(CASE WHEN Number_Of_Orders > 10 THEN 1 END) AS Customers_with_more_than_10_orders
FROM Customers_with_number_of_orders;

-- Customer Lifetime Value

WITH order_revenue AS
(
SELECT 
    o.order_id,
    o.customer_id,
    SUM(oi.price * oi.quantity) AS order_value
FROM ecommerce_churn_analysis.orders o JOIN ecommerce_churn_analysis.order_items oi
ON o.order_id = oi.order_id
GROUP BY o.order_id, o.customer_id
)

SELECT 
    customer_id,
    COUNT(order_id) AS total_orders,
    SUM(order_value) AS total_customer_revenue,
    AVG(order_value) AS avg_order_value
FROM order_revenue
GROUP BY customer_id
ORDER BY total_customer_revenue DESC
LIMIT 25;

-- Product Sales Distribution by total revenue 

SELECT p.product_id,
       p.product_name, 
       SUM(oi.quantity) AS quantity_sold,
       SUM(oi.quantity*oi.price) AS total_revenue_generated
FROM ecommerce_churn_analysis.products p JOIN ecommerce_churn_analysis.order_items oi 
ON p.product_id = oi.product_id 
GROUP BY p.product_id, p.product_name
ORDER BY total_revenue_generated ASC
LIMIT 25;

--  Product Sales Distribution by quantity sold

SELECT p.product_id,
       p.product_name, 
       SUM(oi.quantity) AS quantity_sold,
       SUM(oi.quantity*oi.price) AS total_revenue_generated
FROM ecommerce_churn_analysis.products p JOIN ecommerce_churn_analysis.order_items oi 
ON p.product_id = oi.product_id 
GROUP BY p.product_id, p.product_name
ORDER BY quantity_sold DESC
LIMIT 25;

-- Order Value Analysis (Avg/Max/Min)

WITH order_revenue AS
(
SELECT 
    o.order_id,
    SUM(oi.price * oi.quantity) AS order_value
FROM ecommerce_churn_analysis.orders o JOIN ecommerce_churn_analysis.order_items oi
ON o.order_id = oi.order_id
GROUP BY o.order_id
)

SELECT MIN(order_value) AS lowest_order_value,
       AVG(order_value) AS average_order_value,
       MAX(order_value) AS highest_order_value
 FROM order_revenue;

-- Order Value Distribution By High Value, Low Value, Medium Value Orders

WITH order_revenue AS
(
SELECT 
    order_id,
    SUM(price * quantity) AS order_value
FROM ecommerce_churn_analysis.order_items
GROUP BY order_id
)

SELECT
    CASE
        WHEN order_value < 50 THEN 'Low Value'
        WHEN order_value BETWEEN 50 AND 150 THEN 'Medium Value'
        ELSE 'High Value'
    END AS order_value_segment,
    COUNT(*) AS number_of_orders
FROM order_revenue
GROUP BY order_value_segment;

-- Order Value Histogram

WITH order_revenue AS
(
SELECT 
    order_id,
    SUM(price * quantity) AS order_value
FROM ecommerce_churn_analysis.order_items
GROUP BY order_id
)

SELECT * FROM order_revenue;

-- Customer Geographic Distribution

WITH country_customer_stats AS (

SELECT c.country,
       COUNT(DISTINCT c.customer_id) AS number_of_customers,
       SUM(oi.price*oi.quantity) AS country_revenue,
       COUNT(DISTINCT oi.order_id) AS country_orders
FROM ecommerce_churn_analysis.customers c JOIN ecommerce_churn_analysis.orders o
ON c.customer_id = o.customer_id
JOIN ecommerce_churn_analysis.order_items oi 
ON o.order_id =oi.order_id
GROUP BY c.country)


SELECT country,number_of_customers,country_revenue,country_orders, country_revenue*100.0/total_revenue AS revenue_percentage
FROM 
    (
    SELECT country,number_of_customers,country_revenue,country_orders, SUM(country_revenue) OVER() AS total_revenue
    FROM country_customer_stats
    ) t
ORDER BY revenue_percentage DESC;


-- Basket Size Analysis

-- Average Basket Size

WITH basket_size AS
(
SELECT order_id,
       SUM(quantity) AS items_in_order
FROM ecommerce_churn_analysis.order_items
GROUP BY order_id
)

SELECT AVG(items_in_order) AS avg_items_per_order
FROM basket_size;

-- Basket Size Distribution Small, Medium, Large, Baskets

WITH basket_size AS
(
SELECT order_id,
       SUM(quantity) AS items_in_order
FROM ecommerce_churn_analysis.order_items
GROUP BY order_id
)

SELECT
COUNT(CASE WHEN items_in_order BETWEEN 1 AND 5 THEN 1 END) AS small_orders,
COUNT(CASE WHEN items_in_order BETWEEN 6 AND 15 THEN 1 END) AS medium_orders,
COUNT(CASE WHEN items_in_order > 15 THEN 1 END) AS large_orders
FROM basket_size;

-- Orders with Large Quantities

SELECT order_id,
       SUM(quantity) AS items_in_order
FROM ecommerce_churn_analysis.order_items
GROUP BY order_id
HAVING SUM(quantity) > 50
ORDER BY items_in_order DESC
LIMIT 5;





       
