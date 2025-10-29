/*
===============================================================================
Customer Report
===============================================================================
Purpose:
    - This report consolidates key customer metrics and behaviors

Highlights:
    1. Gathers essential fields such as names, ages, and transaction details.
	2. Segments customers into categories (VIP, Regular, New) and age group
    3. Aggregates customer-level metrics:
	   - total orders
	   - total sales
	   - total quantity purchased
	   - total products
	   - lifespan (in months)
    4. Calculates valuable KPIs:
	    - recency (months since last order)
		- average order value
		- average monthly spend
===============================================================================
*/

-- =============================================================================
-- Create Report: gold.customer_report
-- =============================================================================

USE DWH_Analytics;
GO

IF OBJECT_ID('gold.customer_report', 'V') IS NOT NULL
    DROP VIEW gold.customer_report;
GO

CREATE VIEW gold.customer_report AS 

    -- report_query used to gather and prepare customer data
    WITH report_query AS (

        SELECT 
            s.order_number, 
            s.order_date,
            s.sales_amount,
            s.quantity,
            ci.customer_key,
            s.product_key,
            ci.customer_number,
            CONCAT(ci.first_name, ' ', ci.last_name) AS customer_name,
            DATEDIFF(year, ci.birthdate, GETDATE()) AS customer_age
        FROM gold.fact_sales s
        LEFT JOIN gold.dim_customer_info ci ON s.customer_key = ci.customer_key
        WHERE s.order_date IS NOT NULL
    ),

    -- customer_aggregation used to aggregate customer-level metrics
    customer_aggregation AS (

        SELECT 
            customer_key, 
            customer_number,
            customer_name,
            customer_age,
            COUNT(order_date) AS total_orders,
            SUM(sales_amount) AS total_sales,
            SUM(quantity) AS total_quantity,
            COUNT(DISTINCT product_key) AS total_products,
            MAX(order_date) AS last_order_date,
            DATEDIFF(month, MIN(order_date),MAX(order_date)) AS customer_lifespan
        FROM report_query
        GROUP BY customer_key, customer_number,customer_name,customer_age
    )

    SELECT 
        customer_key, 
        customer_number,
        customer_name,
        customer_age,
            CASE
        WHEN customer_age < 20 THEN 'Under 18'
            WHEN customer_age BETWEEN 18 AND 24 THEN '18-24'
            WHEN customer_age BETWEEN 25 AND 35 THEN '25-34'
            WHEN customer_age BETWEEN 35 AND 49 THEN '35-49'
            WHEN customer_age BETWEEN 50 AND 64 THEN '50-64'
        ELSE 'Older than 65'
        END AS age_category,
        CASE
            WHEN customer_lifespan >= 12 AND total_sales > 5000 THEN 'VIP'
            WHEN customer_lifespan >= 12 AND total_sales <= 5000 THEN 'Regular'
            ELSE 'New'
        END AS customer_segment,
        total_sales,
        total_orders,
        total_quantity,
        total_products,
        last_order_date,
        DATEDIFF(month, last_order_date, GETDATE()) AS recency,
        total_sales/total_orders AS [Average Order Value],
        customer_lifespan,
        -- Computer average monthly spending of customers
            CASE
            WHEN customer_lifespan = 0 THEN total_sales
            ELSE total_sales / customer_lifespan
        END AS [Average Monthly Spending]
    FROM customer_aggregation
