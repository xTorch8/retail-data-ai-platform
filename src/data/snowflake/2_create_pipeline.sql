USE DATABASE RETAIL_ANALYTICS;

/*==============================================================================
 STEP 1: CREATE STREAMS ON BRONZE TABLES
 
 WHY STREAMS?
 - Captures changes (INSERT/UPDATE/DELETE) from Airbyte CDC
 - Enables incremental processing in Dynamic Tables
 - Reduces compute cost by processing only changed data
 - Automatic offset management (no manual watermarking)
==============================================================================*/

-- Stream on Bronze.Customers
CREATE OR REPLACE STREAM BRONZE.STREAM_CUSTOMERS 
ON TABLE BRONZE.CUSTOMERS
COMMENT = 'CDC stream for customer changes';

-- Stream on Bronze.Products
CREATE OR REPLACE STREAM BRONZE.STREAM_PRODUCTS 
ON TABLE BRONZE.PRODUCTS
COMMENT = 'CDC stream for product changes';

-- Stream on Bronze.Categories
CREATE OR REPLACE STREAM BRONZE.STREAM_CATEGORIES 
ON TABLE BRONZE.CATEGORIES
COMMENT = 'CDC stream for category changes';

-- Stream on Bronze.Stores
CREATE OR REPLACE STREAM BRONZE.STREAM_STORES 
ON TABLE BRONZE.STORES
COMMENT = 'CDC stream for store changes';

-- Stream on Bronze.Suppliers
CREATE OR REPLACE STREAM BRONZE.STREAM_SUPPLIERS 
ON TABLE BRONZE.SUPPLIERS
COMMENT = 'CDC stream for supplier changes';

-- Stream on Bronze.Orders
CREATE OR REPLACE STREAM BRONZE.STREAM_ORDERS 
ON TABLE BRONZE.ORDERS
COMMENT = 'CDC stream for order changes';

-- Stream on Bronze.Order_Items
CREATE OR REPLACE STREAM BRONZE.STREAM_ORDER_ITEMS 
ON TABLE BRONZE.ORDER_ITEMS
COMMENT = 'CDC stream for order item changes';

/*==============================================================================
 STEP 2: SILVER LAYER - CLEANED & TRANSFORMED DATA
 
 WHY DYNAMIC TABLES FOR SILVER?
 - Automatic incremental refresh based on TARGET_LAG
 - No need to write MERGE logic manually
 - Handles dependencies automatically
 - Self-optimizing query plans
 - Built-in monitoring and observability
 - Supports complex transformations
 
 TARGET_LAG SELECTION:
 - 5-10 minutes: Near real-time requirements
 - 1 hour: Hourly batch processing
 - DOWNSTREAM: Let Snowflake optimize based on dependencies
==============================================================================*/

-- Silver: Cleaned Customers
CREATE OR REPLACE DYNAMIC TABLE SILVER.CUSTOMERS
TARGET_LAG = '10 minutes'
WAREHOUSE = XS_ELT
COMMENT = 'Cleaned customer data with standardization and enrichment'
AS
SELECT
    -- Primary Key
    CUSTOMER_ID,
    
    -- Standardized Name Fields
    INITCAP(TRIM(FIRST_NAME)) AS FIRST_NAME,
    INITCAP(TRIM(LAST_NAME)) AS LAST_NAME,
    INITCAP(TRIM(FIRST_NAME)) || ' ' || INITCAP(TRIM(LAST_NAME)) AS FULL_NAME,
    
    -- Contact Information
    LOWER(TRIM(EMAIL)) AS EMAIL,
    TRIM(PHONE) AS PHONE,
    
    -- Location Data
    INITCAP(TRIM(CITY)) AS CITY,
    UPPER(TRIM(COUNTRY)) AS COUNTRY,
    
    -- Metadata (from Airbyte)
    CREATED_AT,
    UPDATED_AT,
    _AIRBYTE_EXTRACTED_AT AS SOURCE_EXTRACTED_AT,
    
    -- Processing Metadata
    CURRENT_TIMESTAMP() AS PROCESSED_AT,
    
    -- Data Quality Flag
    CASE 
        WHEN EMAIL IS NULL OR EMAIL = '' THEN FALSE
        WHEN FIRST_NAME IS NULL OR FIRST_NAME = '' THEN FALSE
        WHEN LAST_NAME IS NULL OR LAST_NAME = '' THEN FALSE
        ELSE TRUE
    END AS IS_VALID
    
FROM BRONZE.CUSTOMERS
WHERE CUSTOMER_ID IS NOT NULL
  AND _AB_CDC_DELETED_AT IS NULL;  -- Exclude soft-deleted records

-- Silver: Cleaned Products with Category Enrichment
CREATE OR REPLACE DYNAMIC TABLE SILVER.PRODUCTS
TARGET_LAG = '10 minutes'
WAREHOUSE = XS_ELT
COMMENT = 'Cleaned product data with category details and price calculations'
AS
SELECT
    -- Primary Key
    p.PRODUCT_ID,
    
    -- Product Details
    TRIM(p.PRODUCT_NAME) AS PRODUCT_NAME,
    UPPER(TRIM(p.SKU)) AS SKU,
    
    -- Category Information (denormalized from Categories table)
    p.CATEGORY_ID,
    INITCAP(TRIM(c.CATEGORY_NAME)) AS CATEGORY_NAME,
    TRIM(c.DESCRIPTION) AS CATEGORY_DESCRIPTION,
    
    -- Supplier
    p.SUPPLIER_ID,
    
    -- Pricing
    COALESCE(p.COST_PRICE, 0) AS COST_PRICE,
    COALESCE(p.SELLING_PRICE, 0) AS SELLING_PRICE,
    
    -- Calculated Metrics
    (COALESCE(p.SELLING_PRICE, 0) - COALESCE(p.COST_PRICE, 0)) AS PROFIT_MARGIN,
    CASE 
        WHEN COALESCE(p.COST_PRICE, 0) > 0 
        THEN ((COALESCE(p.SELLING_PRICE, 0) - COALESCE(p.COST_PRICE, 0)) / COALESCE(p.COST_PRICE, 0)) * 100
        ELSE 0
    END AS PROFIT_MARGIN_PCT,
    
    -- Price Tier Classification
    CASE
        WHEN COALESCE(p.SELLING_PRICE, 0) < 50 THEN 'Low'
        WHEN COALESCE(p.SELLING_PRICE, 0) < 200 THEN 'Medium'
        WHEN COALESCE(p.SELLING_PRICE, 0) < 500 THEN 'High'
        ELSE 'Premium'
    END AS PRICE_TIER,
    
    -- Metadata
    p.CREATED_AT,
    p.UPDATED_AT,
    p._AIRBYTE_EXTRACTED_AT AS SOURCE_EXTRACTED_AT,
    CURRENT_TIMESTAMP() AS PROCESSED_AT,
    
    -- Data Quality Flag
    CASE 
        WHEN p.PRODUCT_NAME IS NULL OR p.PRODUCT_NAME = '' THEN FALSE
        WHEN p.SKU IS NULL OR p.SKU = '' THEN FALSE
        WHEN p.SELLING_PRICE IS NULL OR p.SELLING_PRICE < 0 THEN FALSE
        ELSE TRUE
    END AS IS_VALID
    
FROM BRONZE.PRODUCTS p
LEFT JOIN BRONZE.CATEGORIES c 
    ON p.CATEGORY_ID = c.CATEGORY_ID
    AND c._AB_CDC_DELETED_AT IS NULL
WHERE p.PRODUCT_ID IS NOT NULL
  AND p._AB_CDC_DELETED_AT IS NULL;

-- Silver: Cleaned Stores
CREATE OR REPLACE DYNAMIC TABLE SILVER.STORES
TARGET_LAG = '10 minutes'
WAREHOUSE = XS_ELT
COMMENT = 'Cleaned store data with location standardization'
AS
SELECT
    -- Primary Key
    STORE_ID,
    
    -- Store Information
    TRIM(STORE_NAME) AS STORE_NAME,
    
    -- Location Data
    INITCAP(TRIM(CITY)) AS CITY,
    UPPER(TRIM(PROVINCE)) AS PROVINCE,
    UPPER(TRIM(COUNTRY)) AS COUNTRY,
    
    -- Store Details
    OPENED_DATE,
    
    -- Calculated Fields
    DATEDIFF('year', OPENED_DATE, CURRENT_DATE()) AS STORE_AGE_YEARS,
    CASE 
        WHEN DATEDIFF('year', OPENED_DATE, CURRENT_DATE()) < 1 THEN 'New'
        WHEN DATEDIFF('year', OPENED_DATE, CURRENT_DATE()) < 5 THEN 'Established'
        ELSE 'Mature'
    END AS STORE_MATURITY,
    
    -- Metadata
    CREATED_AT,
    UPDATED_AT,
    _AIRBYTE_EXTRACTED_AT AS SOURCE_EXTRACTED_AT,
    CURRENT_TIMESTAMP() AS PROCESSED_AT,
    
    -- Data Quality Flag
    CASE 
        WHEN STORE_NAME IS NULL OR STORE_NAME = '' THEN FALSE
        WHEN CITY IS NULL OR CITY = '' THEN FALSE
        ELSE TRUE
    END AS IS_VALID
    
FROM BRONZE.STORES
WHERE STORE_ID IS NOT NULL
  AND _AB_CDC_DELETED_AT IS NULL;

-- Silver: Cleaned Suppliers
CREATE OR REPLACE DYNAMIC TABLE SILVER.SUPPLIERS
TARGET_LAG = '10 minutes'
WAREHOUSE = XS_ELT
COMMENT = 'Cleaned supplier data'
AS
SELECT
    -- Primary Key
    SUPPLIER_ID,
    
    -- Supplier Information
    TRIM(SUPPLIER_NAME) AS SUPPLIER_NAME,
    TRIM(CONTACT_NAME) AS CONTACT_NAME,
    LOWER(TRIM(EMAIL)) AS EMAIL,
    UPPER(TRIM(COUNTRY)) AS COUNTRY,
    
    -- Metadata
    CREATED_AT,
    UPDATED_AT,
    _AIRBYTE_EXTRACTED_AT AS SOURCE_EXTRACTED_AT,
    CURRENT_TIMESTAMP() AS PROCESSED_AT,
    
    -- Data Quality Flag
    CASE 
        WHEN SUPPLIER_NAME IS NULL OR SUPPLIER_NAME = '' THEN FALSE
        WHEN EMAIL IS NULL OR EMAIL = '' THEN FALSE
        ELSE TRUE
    END AS IS_VALID
    
FROM BRONZE.SUPPLIERS
WHERE SUPPLIER_ID IS NOT NULL
  AND _AB_CDC_DELETED_AT IS NULL;

-- Silver: Cleaned Orders
CREATE OR REPLACE DYNAMIC TABLE SILVER.ORDERS
TARGET_LAG = '5 minutes'  -- Lower lag for transactional data
WAREHOUSE = XS_ELT
COMMENT = 'Cleaned order header data'
AS
SELECT
    -- Primary Key
    ORDER_ID,
    
    -- Foreign Keys
    CUSTOMER_ID,
    STORE_ID,
    
    -- Order Information
    ORDER_DATE,
    DATE(ORDER_DATE) AS ORDER_DATE_KEY,
    UPPER(TRIM(ORDER_STATUS)) AS ORDER_STATUS,
    UPPER(TRIM(PAYMENT_METHOD)) AS PAYMENT_METHOD,
    
    -- Date Parts for Analysis
    YEAR(ORDER_DATE) AS ORDER_YEAR,
    QUARTER(ORDER_DATE) AS ORDER_QUARTER,
    MONTH(ORDER_DATE) AS ORDER_MONTH,
    DAY(ORDER_DATE) AS ORDER_DAY,
    DAYOFWEEK(ORDER_DATE) AS ORDER_DAY_OF_WEEK,
    DAYNAME(ORDER_DATE) AS ORDER_DAY_NAME,
    
    -- Metadata
    CREATED_AT,
    UPDATED_AT,
    _AIRBYTE_EXTRACTED_AT AS SOURCE_EXTRACTED_AT,
    CURRENT_TIMESTAMP() AS PROCESSED_AT,
    
    -- Data Quality Flag
    CASE 
        WHEN CUSTOMER_ID IS NULL THEN FALSE
        WHEN STORE_ID IS NULL THEN FALSE
        WHEN ORDER_DATE IS NULL THEN FALSE
        ELSE TRUE
    END AS IS_VALID
    
FROM BRONZE.ORDERS
WHERE ORDER_ID IS NOT NULL
  AND _AB_CDC_DELETED_AT IS NULL;

-- Silver: Cleaned Order Items (Fact-like table)
CREATE OR REPLACE DYNAMIC TABLE SILVER.ORDER_ITEMS
TARGET_LAG = '5 minutes'  -- Lower lag for transactional data
WAREHOUSE = XS_ELT
COMMENT = 'Cleaned order item details with calculations'
AS
SELECT
    -- Primary Key
    ORDER_ITEM_ID,
    
    -- Foreign Keys
    ORDER_ID,
    PRODUCT_ID,
    
    -- Quantities and Prices
    COALESCE(QUANTITY, 0) AS QUANTITY,
    COALESCE(UNIT_PRICE, 0) AS UNIT_PRICE,
    COALESCE(UNIT_COST, 0) AS UNIT_COST,
    COALESCE(DISCOUNT_AMOUNT, 0) AS DISCOUNT_AMOUNT,
    
    -- Calculated Metrics
    (COALESCE(QUANTITY, 0) * COALESCE(UNIT_PRICE, 0)) AS GROSS_AMOUNT,
    ((COALESCE(QUANTITY, 0) * COALESCE(UNIT_PRICE, 0)) - COALESCE(DISCOUNT_AMOUNT, 0)) AS NET_AMOUNT,
    (COALESCE(QUANTITY, 0) * COALESCE(UNIT_COST, 0)) AS TOTAL_COST,
    
    -- Profit Calculation
    ((COALESCE(QUANTITY, 0) * COALESCE(UNIT_PRICE, 0)) - COALESCE(DISCOUNT_AMOUNT, 0) - (COALESCE(QUANTITY, 0) * COALESCE(UNIT_COST, 0))) AS PROFIT,
    
    -- Discount Percentage
    CASE 
        WHEN (COALESCE(QUANTITY, 0) * COALESCE(UNIT_PRICE, 0)) > 0
        THEN (COALESCE(DISCOUNT_AMOUNT, 0) / (COALESCE(QUANTITY, 0) * COALESCE(UNIT_PRICE, 0))) * 100
        ELSE 0
    END AS DISCOUNT_PCT,
    
    -- Metadata
    CREATED_AT,
    UPDATED_AT,
    _AIRBYTE_EXTRACTED_AT AS SOURCE_EXTRACTED_AT,
    CURRENT_TIMESTAMP() AS PROCESSED_AT,
    
    -- Data Quality Flag
    CASE 
        WHEN ORDER_ID IS NULL THEN FALSE
        WHEN PRODUCT_ID IS NULL THEN FALSE
        WHEN QUANTITY IS NULL OR QUANTITY <= 0 THEN FALSE
        WHEN UNIT_PRICE IS NULL OR UNIT_PRICE < 0 THEN FALSE
        ELSE TRUE
    END AS IS_VALID
    
FROM BRONZE.ORDER_ITEMS
WHERE ORDER_ITEM_ID IS NOT NULL
  AND _AB_CDC_DELETED_AT IS NULL;

/*==============================================================================
 STEP 3: GOLD LAYER - STAR SCHEMA (DIMENSIONS & FACTS)
 
 WHY STAR SCHEMA?
 - Optimized for analytical queries and BI tools
 - Denormalized structure improves query performance
 - Clear business semantics (Facts = Measures, Dims = Context)
 - Easy to understand for business users
 - Supports drill-down and roll-up operations
 - Reduces join complexity in queries
 
 WHY DYNAMIC TABLES FOR GOLD?
 - Automatic refresh when SILVER data changes
 - Built-in dependency management
 - No manual orchestration needed
 - Optimized for analytical workloads
==============================================================================*/

/*------------------------------------------------------------------------------
 DIMENSION TABLES
 
 SCD TYPE 2 CONSIDERATIONS:
 - Tracks historical changes with VALID_FROM/VALID_TO
 - IS_CURRENT flag for latest records
 - Enables point-in-time analysis
 - Future enhancement: Implement full SCD Type 2 logic with MERGE
------------------------------------------------------------------------------*/

-- Dimension: Date
-- WHY? Enables time-series analysis, trending, and period comparisons
CREATE OR REPLACE TABLE GOLD.DIM_DATE (
    DATE_KEY DATE PRIMARY KEY,
    FULL_DATE DATE NOT NULL,
    DAY_OF_WEEK NUMBER,
    DAY_OF_WEEK_NAME VARCHAR(10),
    DAY_OF_MONTH NUMBER,
    DAY_OF_YEAR NUMBER,
    WEEK_OF_YEAR NUMBER,
    MONTH_NUMBER NUMBER,
    MONTH_NAME VARCHAR(10),
    MONTH_NAME_SHORT VARCHAR(3),
    QUARTER_NUMBER NUMBER,
    QUARTER_NAME VARCHAR(10),
    YEAR_NUMBER NUMBER,
    IS_WEEKEND BOOLEAN,
    IS_HOLIDAY BOOLEAN,
    HOLIDAY_NAME VARCHAR(100),
    FISCAL_YEAR NUMBER,
    FISCAL_QUARTER NUMBER,
    FISCAL_MONTH NUMBER,
    CREATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
)
COMMENT = 'Date dimension for time-series analysis';

-- Dimension: Customer (SCD Type 2 Ready)
-- WHY? Centralized customer master data for consistent analytics
CREATE OR REPLACE DYNAMIC TABLE GOLD.DIM_CUSTOMER
TARGET_LAG = '15 minutes'
WAREHOUSE = XS_ELT
COMMENT = 'Customer dimension with standardized attributes'
AS
SELECT
    -- Surrogate Key (for SCD Type 2)
    CUSTOMER_ID AS CUSTOMER_KEY,
    
    -- Business Key
    CUSTOMER_ID AS CUSTOMER_BUSINESS_KEY,
    
    -- Attributes
    FIRST_NAME,
    LAST_NAME,
    FULL_NAME,
    EMAIL,
    PHONE,
    CITY,
    COUNTRY,
    
    -- SCD Type 2 Columns
    PROCESSED_AT AS VALID_FROM,
    NULL::TIMESTAMP_NTZ AS VALID_TO,
    TRUE AS IS_CURRENT,
    
    -- Metadata
    SOURCE_EXTRACTED_AT,
    PROCESSED_AT,
    IS_VALID
    
FROM SILVER.CUSTOMERS
WHERE IS_VALID = TRUE;

-- Dimension: Product (SCD Type 2 Ready)
-- WHY? Product master data with enriched attributes for analysis
CREATE OR REPLACE DYNAMIC TABLE GOLD.DIM_PRODUCT
TARGET_LAG = '15 minutes'
WAREHOUSE = XS_ELT
COMMENT = 'Product dimension with category and pricing attributes'
AS
SELECT
    -- Surrogate Key
    PRODUCT_ID AS PRODUCT_KEY,
    
    -- Business Key
    PRODUCT_ID AS PRODUCT_BUSINESS_KEY,
    
    -- Product Attributes
    PRODUCT_NAME,
    SKU,
    
    -- Category Hierarchy (denormalized for query performance)
    CATEGORY_ID,
    CATEGORY_NAME,
    CATEGORY_DESCRIPTION,
    
    -- Supplier
    SUPPLIER_ID,
    
    -- Pricing
    COST_PRICE,
    SELLING_PRICE,
    PROFIT_MARGIN,
    PROFIT_MARGIN_PCT,
    PRICE_TIER,
    
    -- SCD Type 2 Columns
    PROCESSED_AT AS VALID_FROM,
    NULL::TIMESTAMP_NTZ AS VALID_TO,
    TRUE AS IS_CURRENT,
    
    -- Metadata
    SOURCE_EXTRACTED_AT,
    PROCESSED_AT,
    IS_VALID
    
FROM SILVER.PRODUCTS
WHERE IS_VALID = TRUE;

-- Dimension: Store
-- WHY? Store location and attributes for geographic analysis
CREATE OR REPLACE DYNAMIC TABLE GOLD.DIM_STORE
TARGET_LAG = '15 minutes'
WAREHOUSE = XS_ELT
COMMENT = 'Store dimension with location and maturity attributes'
AS
SELECT
    -- Surrogate Key
    STORE_ID AS STORE_KEY,
    
    -- Business Key
    STORE_ID AS STORE_BUSINESS_KEY,
    
    -- Store Attributes
    STORE_NAME,
    
    -- Location Hierarchy (denormalized)
    CITY,
    PROVINCE AS STATE,
    COUNTRY,
    
    -- Store Metrics
    OPENED_DATE,
    STORE_AGE_YEARS,
    STORE_MATURITY,
    
    -- SCD Type 2 Columns
    PROCESSED_AT AS VALID_FROM,
    NULL::TIMESTAMP_NTZ AS VALID_TO,
    TRUE AS IS_CURRENT,
    
    -- Metadata
    SOURCE_EXTRACTED_AT,
    PROCESSED_AT,
    IS_VALID
    
FROM SILVER.STORES
WHERE IS_VALID = TRUE;

-- Dimension: Supplier
-- WHY? Supplier master data for procurement and vendor analysis
CREATE OR REPLACE DYNAMIC TABLE GOLD.DIM_SUPPLIER
TARGET_LAG = '15 minutes'
WAREHOUSE = XS_ELT
COMMENT = 'Supplier dimension'
AS
SELECT
    -- Surrogate Key
    SUPPLIER_ID AS SUPPLIER_KEY,
    
    -- Business Key
    SUPPLIER_ID AS SUPPLIER_BUSINESS_KEY,
    
    -- Supplier Attributes
    SUPPLIER_NAME,
    CONTACT_NAME,
    EMAIL,
    COUNTRY,
    
    -- SCD Type 2 Columns
    PROCESSED_AT AS VALID_FROM,
    NULL::TIMESTAMP_NTZ AS VALID_TO,
    TRUE AS IS_CURRENT,
    
    -- Metadata
    SOURCE_EXTRACTED_AT,
    PROCESSED_AT,
    IS_VALID
    
FROM SILVER.SUPPLIERS
WHERE IS_VALID = TRUE;

/*------------------------------------------------------------------------------
 FACT TABLES
 
 WHY FACT TABLES?
 - Contains measurable business events (transactions)
 - Additive measures (can be summed across dimensions)
 - Foreign keys to dimensions for context
 - Optimized for aggregations
 - Supports multiple grain levels (transaction, daily, monthly)
------------------------------------------------------------------------------*/

-- Fact: Order Items (Transaction Grain)
-- WHY? Most granular level - supports all analytical queries
CREATE OR REPLACE DYNAMIC TABLE GOLD.FACT_ORDER_ITEMS
TARGET_LAG = '10 minutes'
WAREHOUSE = XS_ELT
COMMENT = 'Transaction-level fact table for order items'
AS
SELECT
    -- Surrogate Key
    oi.ORDER_ITEM_ID AS ORDER_ITEM_KEY,
    
    -- Dimension Foreign Keys (Star Schema)
    oi.ORDER_ID,
    o.CUSTOMER_ID AS CUSTOMER_KEY,
    oi.PRODUCT_ID AS PRODUCT_KEY,
    o.STORE_ID AS STORE_KEY,
    o.ORDER_DATE_KEY AS DATE_KEY,
    
    -- Degenerate Dimensions (attributes without separate dimension table)
    o.ORDER_STATUS,
    o.PAYMENT_METHOD,
    
    -- Date/Time
    o.ORDER_DATE,
    o.ORDER_YEAR,
    o.ORDER_QUARTER,
    o.ORDER_MONTH,
    
    -- Measures (Additive - can be summed)
    oi.QUANTITY,
    oi.UNIT_PRICE,
    oi.UNIT_COST,
    oi.DISCOUNT_AMOUNT,
    oi.GROSS_AMOUNT,
    oi.NET_AMOUNT,
    oi.TOTAL_COST,
    oi.PROFIT,
    oi.DISCOUNT_PCT,
    
    -- Semi-Additive Measures (average, not sum)
    p.PROFIT_MARGIN_PCT AS PRODUCT_PROFIT_MARGIN_PCT,
    
    -- Metadata
    oi.PROCESSED_AT AS FACT_PROCESSED_AT
    
FROM SILVER.ORDER_ITEMS oi
INNER JOIN SILVER.ORDERS o 
    ON oi.ORDER_ID = o.ORDER_ID
    AND o.IS_VALID = TRUE
LEFT JOIN SILVER.PRODUCTS p
    ON oi.PRODUCT_ID = p.PRODUCT_ID
    AND p.IS_VALID = TRUE
WHERE oi.IS_VALID = TRUE;

/*------------------------------------------------------------------------------
 AGGREGATED FACT TABLES
 
 WHY AGGREGATED FACTS?
 - Pre-aggregated for common queries (performance optimization)
 - Reduces query execution time for dashboards
 - Lower compute costs for repeated queries
 - Trade-off: Storage vs. Compute
------------------------------------------------------------------------------*/

-- Fact: Daily Sales Summary (Daily Grain)
-- WHY? Most dashboard queries use daily aggregates
CREATE OR REPLACE DYNAMIC TABLE GOLD.FACT_SALES_DAILY
TARGET_LAG = '30 minutes'
WAREHOUSE = XS_ELT
COMMENT = 'Daily aggregated sales fact - optimized for dashboard queries'
AS
SELECT
    -- Dimension Keys
    DATE_KEY,
    STORE_KEY,
    
    -- Aggregated Metrics (pre-calculated for performance)
    COUNT(DISTINCT ORDER_ID) AS ORDER_COUNT,
    COUNT(DISTINCT CUSTOMER_KEY) AS UNIQUE_CUSTOMER_COUNT,
    COUNT(DISTINCT PRODUCT_KEY) AS UNIQUE_PRODUCT_COUNT,
    COUNT(*) AS ORDER_ITEM_COUNT,
    
    -- Sum of Measures
    SUM(QUANTITY) AS TOTAL_QUANTITY,
    SUM(GROSS_AMOUNT) AS TOTAL_GROSS_AMOUNT,
    SUM(DISCOUNT_AMOUNT) AS TOTAL_DISCOUNT_AMOUNT,
    SUM(NET_AMOUNT) AS TOTAL_NET_AMOUNT,
    SUM(TOTAL_COST) AS TOTAL_COST,
    SUM(PROFIT) AS TOTAL_PROFIT,
    
    -- Averages
    AVG(NET_AMOUNT) AS AVG_ORDER_VALUE,
    AVG(PROFIT) AS AVG_PROFIT_PER_ORDER,
    AVG(DISCOUNT_PCT) AS AVG_DISCOUNT_PCT,
    
    -- Metadata
    CURRENT_TIMESTAMP() AS AGGREGATED_AT
    
FROM GOLD.FACT_ORDER_ITEMS
GROUP BY DATE_KEY, STORE_KEY;

-- Fact: Monthly Product Category Performance (Monthly Grain)
-- WHY? Category managers need monthly views
CREATE OR REPLACE DYNAMIC TABLE GOLD.FACT_SALES_MONTHLY_CATEGORY
TARGET_LAG = '1 hour'
WAREHOUSE = XS_ELT
COMMENT = 'Monthly category performance metrics'
AS
SELECT
    -- Dimension Keys
    DATE_TRUNC('month', f.DATE_KEY) AS MONTH_KEY,
    p.CATEGORY_NAME,
    p.SUPPLIER_ID,
    
    -- Aggregated Metrics
    COUNT(DISTINCT f.ORDER_ID) AS ORDER_COUNT,
    COUNT(DISTINCT f.CUSTOMER_KEY) AS UNIQUE_CUSTOMER_COUNT,
    SUM(f.QUANTITY) AS TOTAL_QUANTITY_SOLD,
    SUM(f.NET_AMOUNT) AS TOTAL_REVENUE,
    SUM(f.TOTAL_COST) AS TOTAL_COST,
    SUM(f.PROFIT) AS TOTAL_PROFIT,
    
    -- Averages
    AVG(f.PROFIT) AS AVG_PROFIT_PER_ORDER,
    AVG(p.PROFIT_MARGIN_PCT) AS AVG_PRODUCT_MARGIN_PCT,
    
    -- Metadata
    CURRENT_TIMESTAMP() AS AGGREGATED_AT
    
FROM GOLD.FACT_ORDER_ITEMS f
INNER JOIN GOLD.DIM_PRODUCT p 
    ON f.PRODUCT_KEY = p.PRODUCT_KEY
    AND p.IS_CURRENT = TRUE
GROUP BY DATE_TRUNC('month', f.DATE_KEY), p.CATEGORY_NAME, p.SUPPLIER_ID;

-- Fact: Customer Lifetime Value (Customer Grain)
-- WHY? Marketing and CRM teams need customer-level metrics
CREATE OR REPLACE DYNAMIC TABLE GOLD.FACT_CUSTOMER_LIFETIME_VALUE
TARGET_LAG = '1 hour'
WAREHOUSE = XS_ELT
COMMENT = 'Customer lifetime value and RFM segmentation'
AS
SELECT
    -- Customer Key
    CUSTOMER_KEY,
    
    -- Lifetime Metrics
    COUNT(DISTINCT ORDER_ID) AS LIFETIME_ORDER_COUNT,
    MIN(ORDER_DATE) AS FIRST_ORDER_DATE,
    MAX(ORDER_DATE) AS LAST_ORDER_DATE,
    DATEDIFF('day', MIN(ORDER_DATE), MAX(ORDER_DATE)) AS CUSTOMER_LIFESPAN_DAYS,
    
    -- Monetary Metrics
    SUM(NET_AMOUNT) AS LIFETIME_VALUE,
    AVG(NET_AMOUNT) AS AVG_ORDER_VALUE,
    SUM(PROFIT) AS LIFETIME_PROFIT,
    
    -- RFM Analysis (Recency, Frequency, Monetary)
    DATEDIFF('day', MAX(ORDER_DATE), CURRENT_DATE()) AS RECENCY_DAYS,
    COUNT(DISTINCT ORDER_ID) AS FREQUENCY,
    SUM(NET_AMOUNT) AS MONETARY_VALUE,
    
    -- RFM Scores (1-5 scale)
    CASE 
        WHEN DATEDIFF('day', MAX(ORDER_DATE), CURRENT_DATE()) <= 30 THEN 5
        WHEN DATEDIFF('day', MAX(ORDER_DATE), CURRENT_DATE()) <= 60 THEN 4
        WHEN DATEDIFF('day', MAX(ORDER_DATE), CURRENT_DATE()) <= 90 THEN 3
        WHEN DATEDIFF('day', MAX(ORDER_DATE), CURRENT_DATE()) <= 180 THEN 2
        ELSE 1
    END AS RECENCY_SCORE,
    
    CASE 
        WHEN COUNT(DISTINCT ORDER_ID) >= 10 THEN 5
        WHEN COUNT(DISTINCT ORDER_ID) >= 7 THEN 4
        WHEN COUNT(DISTINCT ORDER_ID) >= 4 THEN 3
        WHEN COUNT(DISTINCT ORDER_ID) >= 2 THEN 2
        ELSE 1
    END AS FREQUENCY_SCORE,
    
    CASE 
        WHEN SUM(NET_AMOUNT) >= 2000 THEN 5
        WHEN SUM(NET_AMOUNT) >= 1000 THEN 4
        WHEN SUM(NET_AMOUNT) >= 500 THEN 3
        WHEN SUM(NET_AMOUNT) >= 200 THEN 2
        ELSE 1
    END AS MONETARY_SCORE,
    
    -- Metadata
    CURRENT_TIMESTAMP() AS CALCULATED_AT
    
FROM GOLD.FACT_ORDER_ITEMS
GROUP BY CUSTOMER_KEY;

/*==============================================================================
 STEP 4: POPULATE DATE DIMENSION
 
 WHY STORED PROCEDURE?
 - One-time setup for date dimension
 - Reusable for extending date range
 - Encapsulates complex date logic
==============================================================================*/

CREATE OR REPLACE PROCEDURE GOLD.POPULATE_DATE_DIMENSION(
    START_DATE DATE, 
    END_DATE DATE
)
RETURNS STRING
LANGUAGE SQL
COMMENT = 'Populates date dimension table with date attributes'
AS
$$
DECLARE
    v_current_date DATE;
    v_counter INT DEFAULT 0;
BEGIN
    v_current_date := START_DATE;
    
    -- Delete existing dates in range (idempotent)
    DELETE FROM GOLD.DIM_DATE 
    WHERE DATE_KEY BETWEEN :START_DATE AND :END_DATE;
    
    -- Loop through each date and insert
    WHILE (v_current_date <= END_DATE) DO
        INSERT INTO GOLD.DIM_DATE (
            DATE_KEY,
            FULL_DATE,
            DAY_OF_WEEK,
            DAY_OF_WEEK_NAME,
            DAY_OF_MONTH,
            DAY_OF_YEAR,
            WEEK_OF_YEAR,
            MONTH_NUMBER,
            MONTH_NAME,
            MONTH_NAME_SHORT,
            QUARTER_NUMBER,
            QUARTER_NAME,
            YEAR_NUMBER,
            IS_WEEKEND,
            IS_HOLIDAY,
            FISCAL_YEAR,
            FISCAL_QUARTER,
            FISCAL_MONTH
        )
        SELECT
            :v_current_date,
            :v_current_date,
            DAYOFWEEK(:v_current_date),
            DAYNAME(:v_current_date),
            DAY(:v_current_date),
            DAYOFYEAR(:v_current_date),
            WEEKOFYEAR(:v_current_date),
            MONTH(:v_current_date),
            MONTHNAME(:v_current_date),
            LEFT(MONTHNAME(:v_current_date), 3),
            QUARTER(:v_current_date),
            'Q' || QUARTER(:v_current_date),
            YEAR(:v_current_date),
            DAYOFWEEK(:v_current_date) IN (0, 6),
            FALSE,
            YEAR(:v_current_date),
            QUARTER(:v_current_date),
            MONTH(:v_current_date);
            
        v_current_date := DATEADD(day, 1, v_current_date);
        v_counter := v_counter + 1;
    END WHILE;
    
    RETURN 'Successfully populated ' || v_counter || ' dates from ' || 
           START_DATE || ' to ' || END_DATE;
END;
$$;

-- Execute: Populate 1 years of dates
CALL GOLD.POPULATE_DATE_DIMENSION('2026-01-01'::DATE, '2026-12-31'::DATE);

/*==============================================================================
 STEP 5: DATA QUALITY & MONITORING VIEWS
 
 WHY?
 - Proactive data quality monitoring
 - Early detection of pipeline issues
 - Transparency for data consumers
 - SLA monitoring
==============================================================================*/

CREATE OR REPLACE VIEW GOLD.VW_DATA_QUALITY_DASHBOARD AS
WITH bronze_stats AS (
    SELECT 
        'BRONZE.CUSTOMERS' AS layer_table,
        COUNT(*) AS total_records,
        COUNT(DISTINCT CUSTOMER_ID) AS unique_keys,
        SUM(CASE WHEN _AB_CDC_DELETED_AT IS NOT NULL THEN 1 ELSE 0 END) AS deleted_records,
        MAX(_AIRBYTE_EXTRACTED_AT) AS last_extracted_at
    FROM BRONZE.CUSTOMERS
    UNION ALL
    SELECT 
        'BRONZE.PRODUCTS',
        COUNT(*),
        COUNT(DISTINCT PRODUCT_ID),
        SUM(CASE WHEN _AB_CDC_DELETED_AT IS NOT NULL THEN 1 ELSE 0 END),
        MAX(_AIRBYTE_EXTRACTED_AT)
    FROM BRONZE.PRODUCTS
    UNION ALL
    SELECT 
        'BRONZE.ORDERS',
        COUNT(*),
        COUNT(DISTINCT ORDER_ID),
        SUM(CASE WHEN _AB_CDC_DELETED_AT IS NOT NULL THEN 1 ELSE 0 END),
        MAX(_AIRBYTE_EXTRACTED_AT)
    FROM BRONZE.ORDERS
    UNION ALL
    SELECT 
        'BRONZE.ORDER_ITEMS',
        COUNT(*),
        COUNT(DISTINCT ORDER_ITEM_ID),
        SUM(CASE WHEN _AB_CDC_DELETED_AT IS NOT NULL THEN 1 ELSE 0 END),
        MAX(_AIRBYTE_EXTRACTED_AT)
    FROM BRONZE.ORDER_ITEMS
),
silver_stats AS (
    SELECT 
        'SILVER.CUSTOMERS' AS layer_table,
        COUNT(*) AS total_records,
        SUM(CASE WHEN IS_VALID = FALSE THEN 1 ELSE 0 END) AS invalid_records,
        MAX(PROCESSED_AT) AS last_processed_at
    FROM SILVER.CUSTOMERS
    UNION ALL
    SELECT 
        'SILVER.PRODUCTS',
        COUNT(*),
        SUM(CASE WHEN IS_VALID = FALSE THEN 1 ELSE 0 END),
        MAX(PROCESSED_AT)
    FROM SILVER.PRODUCTS
    UNION ALL
    SELECT 
        'SILVER.ORDERS',
        COUNT(*),
        SUM(CASE WHEN IS_VALID = FALSE THEN 1 ELSE 0 END),
        MAX(PROCESSED_AT)
    FROM SILVER.ORDERS
    UNION ALL
    SELECT 
        'SILVER.ORDER_ITEMS',
        COUNT(*),
        SUM(CASE WHEN IS_VALID = FALSE THEN 1 ELSE 0 END),
        MAX(PROCESSED_AT)
    FROM SILVER.ORDER_ITEMS
)
SELECT 
    b.layer_table AS bronze_table,
    b.total_records AS bronze_records,
    b.unique_keys AS bronze_unique_keys,
    b.deleted_records AS bronze_deleted,
    b.last_extracted_at AS bronze_last_extract,
    s.layer_table AS silver_table,
    s.total_records AS silver_records,
    s.invalid_records AS silver_invalid,
    s.last_processed_at AS silver_last_processed,
    DATEDIFF('minute', b.last_extracted_at, s.last_processed_at) AS lag_minutes
FROM bronze_stats b
LEFT JOIN silver_stats s 
    ON REPLACE(b.layer_table, 'BRONZE.', 'SILVER.') = s.layer_table
ORDER BY b.layer_table;

-- Pipeline Health Check
CREATE OR REPLACE VIEW GOLD.VW_PIPELINE_HEALTH AS
SELECT
    'FACT_ORDER_ITEMS' AS table_name,
    COUNT(*) AS record_count,
    MIN(ORDER_DATE) AS earliest_date,
    MAX(ORDER_DATE) AS latest_date,
    MAX(FACT_PROCESSED_AT) AS last_refresh,
    DATEDIFF('minute', MAX(FACT_PROCESSED_AT), CURRENT_TIMESTAMP()) AS minutes_since_refresh,
    CASE 
        WHEN DATEDIFF('minute', MAX(FACT_PROCESSED_AT), CURRENT_TIMESTAMP()) <= 15 THEN 'HEALTHY'
        WHEN DATEDIFF('minute', MAX(FACT_PROCESSED_AT), CURRENT_TIMESTAMP()) <= 60 THEN 'WARNING'
        ELSE 'CRITICAL'
    END AS health_status
FROM GOLD.FACT_ORDER_ITEMS
UNION ALL
SELECT
    'FACT_SALES_DAILY',
    COUNT(*),
    MIN(DATE_KEY),
    MAX(DATE_KEY),
    MAX(AGGREGATED_AT),
    DATEDIFF('minute', MAX(AGGREGATED_AT), CURRENT_TIMESTAMP()),
    CASE 
        WHEN DATEDIFF('minute', MAX(AGGREGATED_AT), CURRENT_TIMESTAMP()) <= 45 THEN 'HEALTHY'
        WHEN DATEDIFF('minute', MAX(AGGREGATED_AT), CURRENT_TIMESTAMP()) <= 120 THEN 'WARNING'
        ELSE 'CRITICAL'
    END
FROM GOLD.FACT_SALES_DAILY;

/*==============================================================================
 STEP 6: BUSINESS INTELLIGENCE VIEWS
 
 WHY?
 - Simplified interface for BI tools (Tableau, Power BI, Looker)
 - Pre-joined data for common queries
 - Business-friendly column names
 - Performance optimization
==============================================================================*/

-- BI View: Sales Performance Dashboard
CREATE OR REPLACE VIEW GOLD.VW_SALES_PERFORMANCE AS
SELECT
    -- Date Dimensions
    d.FULL_DATE AS DATE,
    d.YEAR_NUMBER AS YEAR,
    d.QUARTER_NAME AS QUARTER,
    d.MONTH_NAME AS MONTH,
    d.DAY_OF_WEEK_NAME AS DAY_OF_WEEK,
    d.IS_WEEKEND,
    
    -- Store Dimensions
    st.STORE_NAME,
    st.CITY AS STORE_CITY,
    st.STATE AS STORE_STATE,
    st.COUNTRY AS STORE_COUNTRY,
    st.STORE_MATURITY,
    
    -- Customer Dimensions
    c.FULL_NAME AS CUSTOMER_NAME,
    c.CITY AS CUSTOMER_CITY,
    c.COUNTRY AS CUSTOMER_COUNTRY,
    
    -- Product Dimensions
    p.PRODUCT_NAME,
    p.CATEGORY_NAME,
    p.PRICE_TIER,
    
    -- Order Details
    f.ORDER_ID,
    f.ORDER_STATUS,
    f.PAYMENT_METHOD,
    
    -- Measures
    f.QUANTITY,
    f.GROSS_AMOUNT,
    f.DISCOUNT_AMOUNT,
    f.NET_AMOUNT,
    f.TOTAL_COST,
    f.PROFIT,
    f.DISCOUNT_PCT,
    p.PROFIT_MARGIN_PCT AS PRODUCT_MARGIN_PCT
    
FROM GOLD.FACT_ORDER_ITEMS f
INNER JOIN GOLD.DIM_DATE d ON f.DATE_KEY = d.DATE_KEY
INNER JOIN GOLD.DIM_STORE st ON f.STORE_KEY = st.STORE_KEY AND st.IS_CURRENT = TRUE
INNER JOIN GOLD.DIM_CUSTOMER c ON f.CUSTOMER_KEY = c.CUSTOMER_KEY AND c.IS_CURRENT = TRUE
INNER JOIN GOLD.DIM_PRODUCT p ON f.PRODUCT_KEY = p.PRODUCT_KEY AND p.IS_CURRENT = TRUE;

-- BI View: Customer Segmentation
CREATE OR REPLACE VIEW GOLD.VW_CUSTOMER_SEGMENTS AS
SELECT
    c.CUSTOMER_KEY,
    c.FULL_NAME,
    c.EMAIL,
    c.CITY,
    c.COUNTRY,
    
    -- CLV Metrics
    clv.LIFETIME_ORDER_COUNT,
    clv.LIFETIME_VALUE,
    clv.AVG_ORDER_VALUE,
    clv.LIFETIME_PROFIT,
    clv.FIRST_ORDER_DATE,
    clv.LAST_ORDER_DATE,
    clv.CUSTOMER_LIFESPAN_DAYS,
    
    -- RFM
    clv.RECENCY_DAYS,
    clv.FREQUENCY,
    clv.MONETARY_VALUE,
    clv.RECENCY_SCORE,
    clv.FREQUENCY_SCORE,
    clv.MONETARY_SCORE,
    (clv.RECENCY_SCORE + clv.FREQUENCY_SCORE + clv.MONETARY_SCORE) AS RFM_TOTAL_SCORE,
    
    -- Segmentation
    CASE
        WHEN (clv.RECENCY_SCORE + clv.FREQUENCY_SCORE + clv.MONETARY_SCORE) >= 13 THEN 'Champions'
        WHEN clv.RECENCY_SCORE >= 4 AND clv.FREQUENCY_SCORE >= 3 THEN 'Loyal Customers'
        WHEN clv.RECENCY_SCORE >= 4 AND clv.MONETARY_SCORE >= 4 THEN 'Big Spenders'
        WHEN clv.RECENCY_SCORE >= 3 AND clv.FREQUENCY_SCORE <= 2 THEN 'Potential Loyalists'
        WHEN clv.RECENCY_SCORE <= 2 AND clv.FREQUENCY_SCORE >= 3 THEN 'At Risk'
        WHEN clv.RECENCY_SCORE <= 2 AND clv.FREQUENCY_SCORE <= 2 THEN 'Lost'
        ELSE 'Others'
    END AS CUSTOMER_SEGMENT
    
FROM GOLD.DIM_CUSTOMER c
INNER JOIN GOLD.FACT_CUSTOMER_LIFETIME_VALUE clv 
    ON c.CUSTOMER_KEY = clv.CUSTOMER_KEY
WHERE c.IS_CURRENT = TRUE;

-- BI View: Product Performance
CREATE OR REPLACE VIEW GOLD.VW_PRODUCT_PERFORMANCE AS
SELECT
    p.PRODUCT_NAME,
    p.SKU,
    p.CATEGORY_NAME,
    p.PRICE_TIER,
    p.COST_PRICE,
    p.SELLING_PRICE,
    p.PROFIT_MARGIN,
    p.PROFIT_MARGIN_PCT,
    
    -- Sales Metrics
    COUNT(DISTINCT f.ORDER_ID) AS TOTAL_ORDERS,
    SUM(f.QUANTITY) AS TOTAL_UNITS_SOLD,
    SUM(f.NET_AMOUNT) AS TOTAL_REVENUE,
    SUM(f.PROFIT) AS TOTAL_PROFIT,
    AVG(f.NET_AMOUNT) AS AVG_ORDER_VALUE,
    
    -- Ranking
    RANK() OVER (PARTITION BY p.CATEGORY_NAME ORDER BY SUM(f.NET_AMOUNT) DESC) AS REVENUE_RANK_IN_CATEGORY
    
FROM GOLD.DIM_PRODUCT p
LEFT JOIN GOLD.FACT_ORDER_ITEMS f 
    ON p.PRODUCT_KEY = f.PRODUCT_KEY
WHERE p.IS_CURRENT = TRUE
GROUP BY 
    p.PRODUCT_NAME, p.SKU, p.CATEGORY_NAME, p.PRICE_TIER,
    p.COST_PRICE, p.SELLING_PRICE, p.PROFIT_MARGIN, p.PROFIT_MARGIN_PCT;

-- BI View: Store Performance
CREATE OR REPLACE VIEW GOLD.VW_STORE_PERFORMANCE AS
SELECT
    s.STORE_NAME,
    s.CITY,
    s.STATE,
    s.COUNTRY,
    s.STORE_MATURITY,
    s.STORE_AGE_YEARS,
    
    -- Sales Metrics
    COUNT(DISTINCT f.ORDER_ID) AS TOTAL_ORDERS,
    COUNT(DISTINCT f.CUSTOMER_KEY) AS UNIQUE_CUSTOMERS,
    SUM(f.NET_AMOUNT) AS TOTAL_REVENUE,
    SUM(f.PROFIT) AS TOTAL_PROFIT,
    AVG(f.NET_AMOUNT) AS AVG_ORDER_VALUE,
    
    -- Ranking
    RANK() OVER (ORDER BY SUM(f.NET_AMOUNT) DESC) AS REVENUE_RANK
    
FROM GOLD.DIM_STORE s
LEFT JOIN GOLD.FACT_ORDER_ITEMS f 
    ON s.STORE_KEY = f.STORE_KEY
WHERE s.IS_CURRENT = TRUE
GROUP BY 
    s.STORE_NAME, s.CITY, s.STATE, s.COUNTRY, 
    s.STORE_MATURITY, s.STORE_AGE_YEARS;

/*==============================================================================
 STEP 7: GRANT PERMISSIONS
 
 WHY?
 - Least privilege principle
 - Separate read/write access
 - Role-based access control
==============================================================================*/

-- Grant usage on schemas
GRANT USAGE ON SCHEMA RETAIL_ANALYTICS.BRONZE TO ROLE PUBLIC;
GRANT USAGE ON SCHEMA RETAIL_ANALYTICS.SILVER TO ROLE PUBLIC;
GRANT USAGE ON SCHEMA RETAIL_ANALYTICS.GOLD TO ROLE PUBLIC;

-- Grant read access to GOLD layer (analytics users)
GRANT SELECT ON ALL TABLES IN SCHEMA RETAIL_ANALYTICS.GOLD TO ROLE PUBLIC;
GRANT SELECT ON ALL VIEWS IN SCHEMA RETAIL_ANALYTICS.GOLD TO ROLE PUBLIC;
GRANT SELECT ON FUTURE TABLES IN SCHEMA RETAIL_ANALYTICS.GOLD TO ROLE PUBLIC;
GRANT SELECT ON FUTURE VIEWS IN SCHEMA RETAIL_ANALYTICS.GOLD TO ROLE PUBLIC;

-- Grant read access to SILVER layer (data engineers)
GRANT SELECT ON ALL TABLES IN SCHEMA RETAIL_ANALYTICS.SILVER TO ROLE PUBLIC;
GRANT SELECT ON FUTURE TABLES IN SCHEMA RETAIL_ANALYTICS.SILVER TO ROLE PUBLIC;