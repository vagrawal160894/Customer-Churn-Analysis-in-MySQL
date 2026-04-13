# Customer Churn & Retention Analysis — E-commerce SQL Case Study

**Author:** Vishal Agrawal &nbsp;|&nbsp; **Tools:** MySQL · Python · DBeaver &nbsp;|&nbsp; **Dataset:** Online Retail II (~525K transactions)

---

## Project Objective

Customer churn is one of the most costly problems in e-commerce — acquiring a new customer is significantly more expensive than retaining an existing one. This project analyzes one year of historical transaction data from an online retail platform to:

- Identify behavioral patterns and lifecycle stages associated with customer churn
- Quantify the financial impact of churn across different customer value segments
- Deliver data-driven, actionable retention recommendations grounded in SQL-based analysis

---

## Dataset Description

| Attribute | Detail |
|---|---|
| Source | Online Retail II Dataset (UCI Machine Learning Repository) |
| Original File | `Online_retail_II.xlsx` |
| Raw Volume | ~525,000 transactions |
| Columns | 8 (invoice, stock code, description, quantity, date, price, customer ID, country) |
| Time Period | Approximately 1 year of online retail activity |

**Preprocessing (Python/Pandas):** Rows with missing customer IDs (guest purchases) were removed since churn analysis requires identifiable customers. Column names were standardized, and a random sample of 100,000 transactions was created for query performance during development. The cleaned dataset was imported into MySQL as the primary source table.

---

## Data Cleaning (MySQL)

Real-world data required several validation steps before analysis:

- **Missing values:** Verified zero missing customer IDs post-Python preprocessing
- **Duplicate transactions:** 381 duplicate records identified via `ROW_NUMBER()` window function and removed
- **Cancelled orders:** ~2,250 rows with invoice numbers beginning with "C" and negative quantities removed
- **Invalid prices:** 11 records with a unit price of 0 removed as incomplete transactions
- **Country inconsistencies:** Customers associated with multiple countries resolved by selecting a single country per customer ID

---

## Database Schema Design

The cleaned transactional data was normalized into a structured relational schema to improve query efficiency and analytical scalability:

```
customers     →  customer_id (PK), country
products      →  product_id (PK), product_name
orders        →  order_id (PK), customer_id (FK), order_date
order_items   →  order_item_id (PK), order_id (FK), product_id (FK), quantity, price
```

Each table was created with primary keys and linked via foreign keys to maintain referential integrity. During population, an edge case was discovered — the `price` column needed adjustment from `DECIMAL(10,2)` to `DECIMAL(10,3)` to preserve sub-cent pricing accuracy.

---

## Selected High-Impact Analyses

### 1. Customer Churn Rate Analysis
**Definition:** A customer is classified as churned if they have not placed an order in the final 90 days of the dataset.

| Metric | Value |
|---|---|
| Total Customers | 4,147 |
| Churned Customers | 1,368 |
| Churn Rate | 32.99% |
| Retention Rate | 67.01% |

Nearly one in three customers became inactive — identifying churn reduction as a critical lever for long-term revenue stability.

---

### 2. Purchase Frequency vs. Churn
One of the most impactful findings in the project: churn rate drops dramatically as customers place more orders.

| Customer Segment | Churn Rate | Retention Rate |
|---|---|---|
| 1 order | 54.55% | 45.45% |
| 2–5 orders | 28.21% | 71.79% |
| 6–10 orders | 7.50% | 92.50% |
| >10 orders | 3.89% | 96.11% |

The 26-percentage-point drop between the first and second order represents the **single largest retention opportunity** in the entire dataset.

---

### 3. RFM Customer Segmentation
Customers were scored and segmented on Recency, Frequency, and Monetary value using SQL window functions:

| Segment | Customers | Revenue Share |
|---|---|---|
| Loyal Customers | 1,323 | 72.76% |
| New Customers | 889 | — |
| Others | 1,379 | — |
| At Risk | 273 | — |
| Champions | 244 | 8.5% |

A small group of highly engaged customers drives the overwhelming majority of revenue — making their retention the highest financial priority.

---

### 4. Cohort Retention Analysis
Customers were grouped by acquisition month and tracked across subsequent months. Key finding: across nearly all cohorts, **63–82% of customers are lost within the first month** after their initial purchase. Retention then stabilizes at 20–35% for months 3–10, suggesting a loyal core emerges after early attrition.

---

### 5. Churn by Customer Lifetime Value Segment
Customers were divided into Low, Medium, and High CLV tertiles. Churn rates showed a sharp gradient:

| Segment | Churn Rate |
|---|---|
| Low Value | 52.70% |
| Medium Value | 32.07% |
| High Value | 15.12% |

High-value customers demonstrate strong loyalty (85% retention), while low-value customers represent the largest volume of churned users.

---

## Key Insights

1. **The first purchase is the highest-risk point in the customer lifecycle.** Over half of single-order customers churn and never return.
2. **Revenue is highly concentrated.** Loyal Customers (1,323 of 4,147) account for 72.76% of total revenue; the top 5 customers generated between £34,000 and £92,000 each.
3. **Churn is unevenly distributed.** Low-value customers churn at 3.5× the rate of high-value customers, confirming that value and loyalty are deeply linked.
4. **Seasonality is a major revenue driver.** November recorded 2,234 orders and £278,200 in revenue — nearly double the monthly average — driven by holiday demand.
5. **273 at-risk RFM customers are the most recoverable segment.** They have demonstrated prior loyalty and have not yet fully disengaged, making them more responsive than cold win-back targets.
6. **Product type predicts churn risk.** Novelty and low-commitment items (stickers, seasonal gifts, decorative accessories) show 35–50% churn rates, making first-purchase product category a useful early churn signal.

---

## Business Recommendations

1. **Launch a second-purchase conversion campaign** triggered within 7 days of a first order — even a small improvement in first-to-second order conversion materially reduces overall churn.
2. **Implement a pre-churn early warning system** using the 74-day average purchase interval: flag customers inactive for 60–75 days and trigger re-engagement before the 90-day churn threshold is crossed.
3. **Protect high-value customers with a dedicated VIP retention program** — priority service, exclusive early access, and volume-based loyalty rewards. Retaining one Champions-tier customer far outweighs the cost of acquiring a replacement.
4. **Target the 273 at-risk RFM customers** with personalized win-back offers referencing their purchase history and time-limited incentives before they fully churn.
5. **Integrate product-level churn signals into post-purchase workflows.** When a first purchase falls in a high-churn category, enroll the customer in an extended onboarding sequence with cross-sell recommendations toward higher-engagement categories.
6. **Front-load Q3 inventory and marketing spend** to capitalize on the September–November demand peak, and deploy post-season retention campaigns in December–January to reduce seasonal drop-off.

---

## SQL Techniques Used

| Category | Techniques |
|---|---|
| Window Functions | `LAG`, `NTILE`, `ROW_NUMBER`, `FIRST_VALUE`, `SUM OVER` |
| Data Transformation | CTEs, Subqueries, Derived Tables, `CASE` Statements |
| Aggregation | `GROUP BY`, `HAVING`, Conditional Aggregation (`COUNT CASE`) |
| Joins | `INNER JOIN`, `LEFT JOIN`, `CROSS JOIN` |
| Date Functions | `DATEDIFF`, `DATE_FORMAT`, `TIMESTAMPDIFF` |
| Other | `COALESCE`, `NULLIF`, `ROUND`, `DISTINCT` |

---

## Tools & Technologies

- **MySQL Server** — database hosting, schema design, all SQL analysis
- **DBeaver** — SQL editor and query execution environment
- **Python** — data preprocessing (Pandas), visualization (Matplotlib, Seaborn)

---

## Conclusion

This project demonstrates that customer churn in e-commerce is not a single, uniform problem — it is a lifecycle challenge with distinct risk points, predictable behavioral signals, and high financial asymmetry across customer segments. The most critical intervention window is the period immediately after a customer's first purchase, where targeted engagement can reduce churn by more than 26 percentage points. Combined with RFM-based segmentation and proactive early-warning systems, these findings provide a concrete, data-driven foundation for building a more resilient retention strategy.
