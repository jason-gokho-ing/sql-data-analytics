-- Switch to DWH_Analytics Database
USE DWH_Analytics;
GO



-- Generate a Report that shows all the key metrics of the business
SELECT 'Total Sales' AS measure_name, SUM(sales_amount) AS measure_value
FROM gold.fact_sales
UNION ALL
SELECT 'Total Quantity', SUM(quantity)
FROM gold.fact_sales
UNION ALL
SELECT 'Average Price', AVG(price)
FROM gold.fact_sales
UNION ALL
SELECT 'Total Number of Orders', COUNT(DISTINCT order_number)
FROM gold.fact_sales
UNION ALL
SELECT 'Total Number of Products', COUNT(DISTINCT product_name)
FROM gold.dim_product_info
UNION ALL
SELECT 'Total Number of Customers', COUNT(DISTINCT customer_key)
FROM gold.dim_customer_info;

-- Magnitude Analysis

-- Get total sales by customer
SELECT c.customer_key, c.first_name, c.last_name, 
SUM(s.sales_amount) AS [Total Sales]
FROM gold.fact_sales s
LEFT JOIN gold.dim_customer_info c ON s.customer_key = c.customer_key
GROUP BY c.customer_key, c.first_name, c.last_name
ORDER BY [Total Sales] DESC;


-- Get the age of customers
SELECT first_name, last_name, 
DATEDIFF(year, birthdate,GETDATE()) AS Age
FROM gold.dim_customer_info

-- Get total sales by product category
SELECT p.category, SUM(s.sales_amount) AS [Total Sales]
FROM gold.fact_sales s
LEFT JOIN gold.dim_product_info p ON s.product_key = p.product_key
GROUP BY p.category
ORDER BY[Total Sales] DESC;


-- Get Top 5 best performing products

SELECT * FROM (

    SELECT ROW_NUMBER() OVER(ORDER BY SUM(s.sales_amount) DESC) AS [Ranking],
    p.product_name, SUM(s.sales_amount) AS [Total Sales]
    FROM gold.fact_sales s
    LEFT JOIN gold.dim_product_info p ON s.product_key = p.product_key
    GROUP BY p.product_name

) t WHERE [Ranking] <= 5


-- Find the date of the first and last orders
SELECT MIN(order_date) as [First Order],
MAX(order_date) as [Last Order],
DATEDIFF(YEAR, MIN(order_date), MAX(order_date)) [Order Range]
FROM gold.fact_sales


-- Change Over Time Trends


-- Total Sales, Total Customers, and Total Quantity Sold by Month & Year

SELECT [Order Date], [Total sales], [Total Customers], [Total Quantity Sold] FROM (
    SELECT 
        FORMAT(order_date, 'MMM-yyyy') AS [Order Date],
        DATETRUNC(month, order_date) [Datetrunc Month],
        SUM(sales_amount) AS [Total Sales],
        COUNT(DISTINCT customer_key) AS [Total Customers],
        SUM(quantity) AS [Total Quantity Sold]
    FROM gold.fact_sales
        WHERE order_date IS NOT NULL
        GROUP BY FORMAT(order_date, 'MMM-yyyy'), DATETRUNC(month, order_date) 
) t
ORDER BY  [Datetrunc Month]


-- Calculate the total sales per month and running total of sales over time

SELECT 
    [Order Date], 
    [Total Sales], 
    -- Partition by year to reset the running total at the start of each year
    SUM([Total Sales]) OVER( ORDER BY [Order Date] ASC) AS [Running Total Sales]
FROM
(
    SELECT 
        DATETRUNC(year, order_date) AS [Order Date],
        SUM(sales_amount) AS [Total Sales]
    FROM gold.fact_sales
    WHERE order_date IS NOT NULL
    GROUP BY DATETRUNC(year, order_date)
) t 
ORDER BY [Order Date] ASC


-- Performance Analysis 

/* Analyze the yearly performance of each product by comparing the:

1) average sales performance of the product 
2) the previous' years performance 


*/


WITH yearly_product_sales AS (

    SELECT 
        YEAR(s.order_date) AS [Order Year],
       pr.product_name AS [Product Name],
        SUM(s.sales_amount) AS [Current Sales]
    FROM gold.fact_sales s
    LEFT JOIN gold.dim_product_info pr ON pr.product_id = s.product_key
        WHERE order_date IS NOT NULL
        GROUP BY YEAR(s.order_date), pr.product_name

)

SELECT 
    [Order Year],
    [Product Name], 
    [Current Sales],
AVG([Current Sales]) AS [Average Sales],
LAG([Current Sales]) OVER(PARTITION BY [Product Name] ORDER BY [Order Year]) AS [Previous Year Sales]
FROM yearly_product_sales
GROUP BY [Order Year], [Product Name], [Current Sales];


-- Performance Analysis - Yearly product performance
WITH yearly_product_sales AS (
    SELECT 
        YEAR(s.order_date) AS OrderYear,
        p.product_name AS ProductName,
        SUM(s.sales_amount) AS CurrentSales
    FROM gold.fact_sales s
    LEFT JOIN gold.dim_product_info p ON s.product_key = p.product_key
    WHERE s.order_date IS NOT NULL
    GROUP BY YEAR(s.order_date), p.product_name
)

SELECT
    OrderYear,
    ProductName,
    CurrentSales,
    AverageSales,
    PreviousYearSales,
    CurrentSales - COALESCE(PreviousYearSales, 0) AS DifferenceFromPreviousYear,
    CASE
        WHEN PreviousYearSales IS NULL THEN 'No Prior Year'
        WHEN CurrentSales > PreviousYearSales THEN 'Higher Than Prev'
        WHEN CurrentSales < PreviousYearSales THEN 'Lower Than Prev'
        ELSE 'No Change'
    END AS Level
FROM (
    SELECT
        OrderYear,
        ProductName,
        CurrentSales,
        AVG(CurrentSales) OVER (PARTITION BY ProductName) AS AverageSales,
        LAG(CurrentSales) OVER (PARTITION BY ProductName ORDER BY OrderYear) AS PreviousYearSales
    FROM yearly_product_sales
) t
ORDER BY ProductName, OrderYear;


-- Performance Analysis - Monthly comparisons (per product)
WITH monthly_product_sales AS (
    SELECT
        FORMAT(s.order_date, 'yyyy-MM') AS OrderMonthKey,
        DATETRUNC(month, s.order_date) AS OrderMonthDate,
        p.product_name AS ProductName,
        SUM(s.sales_amount) AS CurrentSales
    FROM gold.fact_sales s
    LEFT JOIN gold.dim_product_info p ON s.product_key = p.product_key
    WHERE s.order_date IS NOT NULL
    GROUP BY FORMAT(s.order_date, 'yyyy-MM'), DATETRUNC(month, s.order_date), p.product_name
)

SELECT
    OrderMonthKey AS OrderMonth,
    ProductName,
    CurrentSales,
    AVG(CurrentSales) OVER (PARTITION BY ProductName) AS AverageProductSales,
    CurrentSales - AVG(CurrentSales) OVER (PARTITION BY ProductName) AS DifferenceFromAverage,
    CASE
        WHEN CurrentSales > AVG(CurrentSales) OVER (PARTITION BY ProductName) THEN 'Above Avg'
        WHEN CurrentSales < AVG(CurrentSales) OVER (PARTITION BY ProductName) THEN 'Below Avg'
        ELSE 'Avg'
    END AS Level
FROM monthly_product_sales
WHERE ProductName = 'Mountain-100 Black- 38'
ORDER BY OrderMonthDate, ProductName;


-- Part-to-Whole Analysis 

-- Category contribution
SELECT
    p.category AS ProductCategory,
    SUM(s.sales_amount) AS TotalSalesPerCategory,
    SUM(s.sales_amount) * 1.0 / NULLIF(SUM(SUM(s.sales_amount)) OVER (), 0) AS ShareOfTotal
FROM gold.fact_sales s
LEFT JOIN gold.dim_product_info p ON s.product_key = p.product_key
WHERE s.order_date IS NOT NULL
GROUP BY p.category
ORDER BY TotalSalesPerCategory DESC;