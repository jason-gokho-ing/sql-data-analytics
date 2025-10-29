/*
===============================================================================
Product Report
===============================================================================
Purpose:
    - This report consolidates key product metrics and behaviors.

Highlights:
    1. Gathers essential fields such as product name, category, subcategory, and cost.
    2. Segments products by revenue to identify High-Performers, Mid-Range, or Low-Performers.
    3. Aggregates product-level metrics:
       - total orders
       - total sales
       - total quantity sold
       - total customers (unique)
       - lifespan (in months)
    4. Calculates valuable KPIs:
       - recency (months since last sale)
       - average order revenue (AOR)
       - average monthly revenue
===============================================================================
*/
-- =============================================================================
-- Create Report: gold.product_report
-- =============================================================================

USE DWH_Analytics;
GO

IF OBJECT_ID('gold.product_report', 'V') IS NOT NULL
    DROP VIEW gold.product_report;
GO

CREATE VIEW gold.product_report AS

    -- report_query used to gather and prepare product data
    WITH report_query AS (

        SELECT 
            s.product_key, 
            product_name, 
            category, 
            subcategory, 
            cost,
            s.order_number, 
            s.order_date,
            s.sales_amount,
            s.quantity,
            s.customer_key
        FROM gold.fact_sales s
        LEFT JOIN gold.dim_product_info pr ON s.product_key = pr.product_key
        WHERE s.order_date IS NOT NULL
    ),

    -- product_aggregation used to aggregate product-level metrics
    product_aggregation AS (
        SELECT
            product_key, product_name, category, subcategory, cost, 
            COUNT(DISTINCT order_number) AS total_orders,
            SUM(sales_amount) AS total_sales,
            SUM(quantity) AS total_quantity,
            COUNT(DISTINCT customer_key) AS total_customer,
            MAX(order_date) AS last_order_date,
            DATEDIFF(month, MIN(order_date),MAX(order_date)) AS product_lifespan
        FROM report_query
        GROUP BY product_key, product_name, category, subcategory, cost
    )

    SELECT 
        product_key,
        product_name,
        category,
        subcategory,
        cost,
        CASE
            WHEN total_sales > 50000 THEN 'High-Performers'
            WHEN total_sales BETWEEN 10000 AND 50000 THEN 'Mid-Performers'
        ELSE 'Low-Performers'
        END AS performance_segment,
        total_sales,
        total_orders,
        total_quantity,
        last_order_date,
        DATEDIFF(month, last_order_date, GETDATE()) AS recency,
        total_sales/total_orders AS [Average Order Value],
        product_lifespan,
        -- Computer average revenue by product
            CASE
            WHEN product_lifespan = 0 THEN total_sales
            ELSE total_sales / product_lifespan
        END AS [Average Monthly Revenue],
            -- Computer average order revenue by product
            CASE
            WHEN total_sales = 0 THEN total_sales
            ELSE total_orders / total_sales
        END AS [Average Order Monthly Revenue]
    FROM product_aggregation
