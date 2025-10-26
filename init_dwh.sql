USE master;
GO

-- Drop and recreate the 'DWH_Analytics' database
IF EXISTS (SELECT 1 FROM sys.databases WHERE name = 'DWH_Analytics')
BEGIN
    ALTER DATABASE DWH_Analytics SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE DWH_Analytics;
END;
GO

-- Create the 'DWH_Analytics' database
CREATE DATABASE DWH_Analytics;
GO

USE DWH_Analytics;
GO

-- Creating Schemas within database to organize data warehouse objects
CREATE SCHEMA gold;
GO

-- Note: Tables will be created in subsequent scripts

 
 CREATE TABLE gold.dim_customer_info(
	customer_key int,
	customer_id int,
	customer_number nvarchar(50),
	first_name nvarchar(50),
	last_name nvarchar(50),
	country nvarchar(50),
	marital_status nvarchar(50),
	gender nvarchar(50),
	birthdate date,
	create_date date
);
GO

CREATE TABLE gold.dim_product_info(
	product_key int ,
	product_id int ,
	product_number varchar(30) ,
	product_name varchar(50) ,
	category_id varchar(30) ,
	category varchar(30) ,
	subcategory varchar(30) ,
	maintenance varchar(30) ,
	cost decimal(12,2),
	product_line varchar(30),
	start_date date 
);
GO

CREATE TABLE gold.fact_sales(
	order_number varchar(50),
	product_key int,
	customer_key int,
	order_date date,
	shipping_date date,
	due_date date,
	sales_amount decimal(12,2),
	quantity tinyint,
	price decimal(12,2) 
);
GO

TRUNCATE TABLE gold.dim_customer_info;
GO

BULK INSERT gold.dim_customer_info
FROM 'C:\SQL Server Management Studio 21\sql-data-analytics\csv-files\gold.dim_customer_info.csv'
WITH (
	FIRSTROW = 2,
	FIELDTERMINATOR = ',',
	TABLOCK
);
GO

PRINT 'Data successfully loaded into dim_customer_info';

TRUNCATE TABLE gold.dim_product_info;
GO

BULK INSERT gold.dim_product_info
FROM 'C:\SQL Server Management Studio 21\sql-data-analytics\csv-files\gold.dim_product_info.csv'
WITH (
	FIRSTROW = 2,
	FIELDTERMINATOR = ',',
	TABLOCK
);
GO

PRINT 'Data successfully loaded into dim_product_info';


TRUNCATE TABLE gold.fact_sales;
GO

BULK INSERT gold.fact_sales
FROM 'C:\SQL Server Management Studio 21\sql-data-analytics\csv-files\gold.fact_sales.csv'
WITH (
	FIRSTROW = 2,
	FIELDTERMINATOR = ',',
	TABLOCK
);
GO

PRINT 'Data successfully loaded into fact_sales';





