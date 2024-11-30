-- ********************
-- 1. Database Setup
-- ********************

-- Ensure no database with the same name exists before creating a new one
DROP DATABASE IF EXISTS layoff_db;
CREATE DATABASE layoff_db;
USE layoff_db;


-- ********************
-- 2. Checking Data Types
-- ********************

-- Way 1: Querying the information schema for column data types
SELECT 
    DATA_TYPE
FROM
    INFORMATION_SCHEMA.COLUMNS
WHERE
    TABLE_SCHEMA = 'layoff_db'
        AND TABLE_NAME = 'layoffs';
        
-- Way 2: Using SHOW COLUMNS to display the columns and their types
SHOW COLUMNS FROM `layoffs` FROM `layoff_db`;
-- TakeAway: Date is a text type, In the data cleaning process (Validity) we'd make sure it's changed

-- Takeaway: The "date" column is a text type. It will be standardized later.


-- ********************
-- 3. Data Backup
-- ********************

-- We will create a clone of the table for data safety
-- Way 1: Clone the data using SELECT INTO
CREATE TABLE layoffs_staging AS SELECT * FROM
    layoffs;
    
    -- Clean up the staging table after backup
DROP TABLE IF EXISTS layoffs_staging;

-- Way 2: Create an empty table with the same structure, then insert data
CREATE TABLE layoffs_staging LIKE layoffs;
INSERT layoffs_staging
SELECT * FROM layoffs;

-- Checkpoint: Verify that the data has been cloned successfully
SELECT 
    *
FROM
    layoffs_staging
LIMIT 10;


-- ********************
-- 4. Removing Duplicates
-- ********************

-- First step: Number rows with the same values (i.e., partitioning by unique key)
WITH numbering AS (
SELECT ROW_NUMBER() OVER (PARTITION BY company, location, industry, total_laid_off, percentage_laid_off, 'date', stage, country, funds_raised_millions) AS ID, layoffs_staging.*
FROM layoffs_staging)
-- Identify duplicates by checking where the row number is greater than 1
SELECT * FROM numbering WHERE ID > 1;

-- We have 22 duplicates out of 2361 rows. We will handle this by recreating the table with the ID column

-- Create a new staging table to include the ID column
CREATE TABLE `layoffs_staging2` (
    `ID` INT,
    `company` TEXT,
    `location` TEXT,
    `industry` TEXT,
    `total_laid_off` INT DEFAULT NULL,
    `percentage_laid_off` TEXT,
    `date` TEXT,
    `stage` TEXT,
    `country` TEXT,
    `funds_raised_millions` INT DEFAULT NULL
)  ENGINE=INNODB DEFAULT CHARSET=UTF8MB4 COLLATE = UTF8MB4_0900_AI_CI;

-- Insert data with row numbers into the new table
INSERT layoffs_staging2
SELECT ROW_NUMBER() OVER (PARTITION BY company, location, industry, total_laid_off, percentage_laid_off, 'date', stage, country, funds_raised_millions) AS ID, layoffs_staging.*
FROM layoffs_staging;

-- CHECKPOINT, We shall get 2361 rows
SELECT 
    COUNT(*)
FROM
    layoffs_staging2;

-- Removing duplicates: Deleting rows where ID is greater than 1
DELETE FROM layoffs_staging2 
WHERE
    ID > 1;
-- Safe mode was on, let's turn it off first from SQL EDITOR

DELETE FROM layoffs_staging2 
WHERE
    ID > 1;
    
-- CheckPoint, We shall get 2361 - 22 = 2339
SELECT 
    COUNT(*)
FROM
    layoffs_staging2;
    
-- Drop the ID column since it's no longer needed
ALTER TABLE layoffs_staging2
DROP COLUMN ID;

-- Checkpoint: Verify that the ID column is gone
SHOW COLUMNS FROM layoffs_staging2;


-- ********************
-- 5. Standardizing Strings
-- ********************

-- Check for misspelled company names
SELECT DISTINCT
    (company)
FROM
    layoffs_staging2
ORDER BY 1;
-- Here there's 3 different companies starting with ada (Ada,Ada Health, Ada Support), Let's check the full records to see if they're refering to the same company

-- Check for companies starting with "Ada" to identify potential misspelling
SELECT 
    *
FROM
    layoffs_staging2
WHERE
    company LIKE 'Ada%';
/* They're not similar, Ada health is in Germany working in HealthCare industry, 
Ada and Ada Support are similar since both are in Toronto and both in Support industry 
but after checking it turned out that they're different companies */

-- Remove any extra spaces around company names using TRIM
SELECT 
    company, TRIM(company)
FROM
    layoffs_staging2
ORDER BY 1 , 2;

UPDATE layoffs_staging2 
SET 
    company = TRIM(company);
    
-- Verify that trimming was successful
SELECT 
    company, TRIM(company)
FROM
    layoffs_staging2
ORDER BY 1;
-- Works fine

-- During data cleaning I usually need to check the date from time to time to check the columns etc, to make it easier let's create a procedure
DELIMITER //

CREATE PROCEDURE checking()
BEGIN
	SELECT *  FROM layoffs_staging2 LIMIT 10;
END //

DELIMITER ;
CALL checking();

-- Let's check the location standards
SELECT DISTINCT
    (location)
FROM
    layoffs_staging2
ORDER BY 1;
-- No misspelling, but we can conduct trim as a good practice since the spacing afterwards doesn't appear

UPDATE layoffs_staging2 
SET 
    location = TRIM(location);

CALL checking();

-- Let's check the industry standards
SELECT DISTINCT
    (industry)
FROM
    layoffs_staging2
ORDER BY 1;
-- Misspelling (Crypto)/(Crypto Currency)/(CryptoCurrency) are referring to the same industry + some are empty not null

-- Uniform the values in industry
UPDATE layoffs_staging2 
SET 
    industry = 'Crypto Currency'
WHERE
    industry LIKE ('Crypto%');

-- Verify if uniformed
SELECT DISTINCT
    (industry)
FROM
    layoffs_staging2
WHERE
    industry LIKE ('Crypto%');
-- Works fine

-- Update empty fields to be NULL
UPDATE layoffs_staging2 
SET 
    industry = NULL
WHERE
    industry IS NULL OR industry = '';

-- Verify if empty fields are reflected as NULL
SELECT DISTINCT
    (industry)
FROM
    layoffs_staging2
ORDER BY 1;
-- Worked fine

-- Update the values to be trimed of extra white spaces
UPDATE layoffs_staging2 
SET 
    industry = TRIM(industry);
    
-- Checking data    
CALL checking();

-- Let's check the Country standards
SELECT DISTINCT
    (country)
FROM
    layoffs_staging2
ORDER BY 1;
-- (United Stated) and (United States.) refer to the same country

-- Let's remove the extra (.)
UPDATE layoffs_staging2 
SET 
    country = TRIM(TRAILING '.' FROM country);

-- Let's trim spaces if found
UPDATE layoffs_staging2 
SET 
    country = TRIM(country);

-- Checking data
CALL checking();

-- Let's check the stage and modify if needed
SELECT DISTINCT
    (stage)
FROM
    layoffs_staging2
ORDER BY 1;
-- no misspelling, let's trim for saftey

-- Let's trim spaces if found 
UPDATE layoffs_staging2 
SET 
    stage = TRIM(stage);


-- ********************
-- 6. Date Formatting and Conversion
-- ********************

-- Check the current format of the "date" column
SELECT 
    `date`, STR_TO_DATE(`date`, '%m/%d/%Y')
FROM
    layoffs_staging2;

-- Standardize the date format
UPDATE layoffs_staging2 
SET 
    `date` = STR_TO_DATE(`date`, '%m/%d/%Y');

-- Change the column type from TEXT to DATE
ALTER TABLE layoffs_staging2
MODIFY COLUMN `date`DATE;

-- Verify that the column type has been updated
SHOW COLUMNS FROM layoffs_staging2;



-- ********************
-- 7. Handling Missing Data
-- ********************

-- Procedure to check for missing data in any column
DELIMITER //

CREATE PROCEDURE CheckMissing(IN theColumn VARCHAR(255))
BEGIN
    -- Declare a variable to hold the SQL query
    SET @sql_query = CONCAT('SELECT * FROM layoffs_staging2 WHERE ', theColumn, ' IS NULL OR ', theColumn, ' = ""');
    
    -- Prepare the dynamic SQL query
    PREPARE stmt FROM @sql_query;
    
    -- Execute the prepared statement
    EXECUTE stmt;
    
    -- Deallocate the prepared statement to free resources
    DEALLOCATE PREPARE stmt;
END //

DELIMITER ;


-- Check for missing values in each column

CALL CheckMissing('company');  -- No missing values
CALL CheckMissing('location');  -- No missing values
CALL CheckMissing('industry');  -- 4 missing
CALL CheckMissing('total_laid_off');  -- 725 missing
CALL CheckMissing('percentage_laid_off');  -- 769 missing
CALL CheckMissing('stage');  -- 6 missing
CALL CheckMissing('country');  -- No missing values
CALL CheckMissing('funds_raised_millions');  -- 213 missing

/*Date - 1 missing*/
SELECT 
    *
FROM
    layoffs_staging2
WHERE
    `date` IS NULL;
    
    
-- Checking if we can conduct hot-deck imputation   
SELECT t1.`date`, t2.`date`
FROM layoffs_staging2 t1 
JOIN layoffs_staging2 t2 
ON t1.company = t2.company 
   AND t1.location = t2.location 
   AND t1.industry = t2.industry 
   AND t1.total_laid_off = t2.total_laid_off 
   AND t1.stage = t2.stage 
   AND t1.country = t2.country 
   AND t1.funds_raised_millions = t2.funds_raised_millions
WHERE t1.`date` IS NULL 
  AND t2.`date` IS NOT NULL;
-- No records found, but the number if missing is very low, we can keep it as pairwise



-- ********************
-- 8. Filling Missing Data
-- ********************



/* Let's begin with the Industry column. There are 4 missing values, which is a small number, and they can be fixed if found. 
We'll first check if there are any duplicate rows where the company is the same and the industry is already filled 
(e.g., Airbnb, Carvana, Bally's Interactive, Juul).
*/

SELECT 
    *
FROM
    layoffs_staging2
WHERE
    company IN ('Airbnb' , 'Carvana',
        'Bally\'s Interactive',
        'Juul');
/*
For Airbnb, there is another record where the industry is listed as 'Travel'. 
For Carvana, it's 'Transportation', 
and for Juul, it's 'Consumer'. 
However, for Bally's Interactive, there is no industry listed. 
We can fill this missing value by querying generative AI: 'What is the industry of Bally's Interactive in Providence, USA?' 
The answer is 'Gaming'.
*/


/* Verify before updating 'Airbnb' , 'Carvana' and 'Juul' */
SELECT 
    t1.company, t1.industry, t2.company, t2.industry
FROM
    layoffs_staging2 t1
        JOIN
    layoffs_staging2 t2 ON t1.company = t2.company
        AND t1.location = t2.location
WHERE
    (t1.industry IS NULL)
        AND t2.industry IS NOT NULL;
        
        
-- Update 'Airbnb' , 'Carvana' and 'Juul'
UPDATE layoffs_staging2 t1
        JOIN
    layoffs_staging2 t2 ON t1.company = t2.company
        AND t1.location = t2.location 
SET 
    t1.industry = t2.industry
WHERE
    (t1.industry IS NULL)
        AND t2.industry IS NOT NULL;

-- Update 'Bally's Interactive'
UPDATE layoffs_staging2 
SET 
    industry = 'Gaming'
WHERE
    company = 'Bally\'s Interactive';


-- Checkpoint: Verify that all missing industry values are filled
CALL CheckMissing('industry');
SELECT DISTINCT
    (industry)
FROM
    layoffs_staging2;




-- ********************
-- 9. Handling Missing Values in Specific Columns
-- ********************


-- Check percentage of missing values and decide whether to drop the column or not
-- If missing percentage is high (e.g., > 70%), consider dropping the column
-- Otherwise, we keep the data and analyze it further
SELECT 
    (COUNT(*) * 100 / (SELECT 
            COUNT(*)
        FROM
            layoffs_staging2)) AS missing_percentage
FROM
    layoffs_staging2
WHERE
    total_laid_off IS NULL;
-- Below 70% , no need to drop, Also no point to check if it's MAR/MNAR since we cannot deduce such columns 

SELECT 
    (COUNT(*) * 100 / (SELECT 
            COUNT(*)
        FROM
            layoffs_staging2)) AS missing_percentage
FROM
    layoffs_staging2
WHERE
    percentage_laid_off IS NULL;
-- Below 70% , no need to drop, Also no point to check if it's MAR/MNAR since we cannot deduce such columns 

SELECT 
    (COUNT(*) * 100 / (SELECT 
            COUNT(*)
        FROM
            layoffs_staging2)) AS missing_percentage
FROM
    layoffs_staging2
WHERE
    Stage IS NULL;
-- Below 70% , no need to drop, Also no point to check if it's MAR/MNAR since we cannot deduce such columns 

SELECT 
    (COUNT(*) * 100 / (SELECT 
            COUNT(*)
        FROM
            layoffs_staging2)) AS missing_percentage
FROM
    layoffs_staging2
WHERE
    `date` IS NULL;
-- Below 70% , no need to drop, Also no point to check if it's MAR/MNAR since we cannot deduce such columns 

SELECT 
    (COUNT(*) * 100 / (SELECT 
            COUNT(*)
        FROM
            layoffs_staging2)) AS missing_percentage
FROM
    layoffs_staging2
WHERE
    funds_raised_millions IS NULL;
-- Below 70% , no need to drop, Also no point to check if it's MAR/MNAR since we cannot deduce such columns 

-- For columns with both `total_laid_off` and `percentage_laid_off` missing, delete the rows
DELETE FROM layoffs_staging2 
WHERE
    total_laid_off IS NULL
    AND percentage_laid_off IS NULL;

-- Checkpoint: Verify that the data is now clean
CALL checking();


/* 
Part of data cleaning is ensuring Consistency
For example, in our case, Country cannot be USA and location is Berlin
So let's check each location for each country
*/

SELECT DISTINCT 
    country, 
    location
FROM layoffs_staging2
ORDER BY country;
-- This is consistent and clean but a location in Germany was under 'DÃ¼sseldorf', let's clean that

-- Update location
UPDATE layoffs_staging2
SET location = 'Düsseldorf'
WHERE location = 'DÃ¼sseldorf';


/* 
As a takeaway, We've worked on:
1- Validity: Ensuring data type of columns
2- Unqiueness: Ensuring there's no duplicates
3- Completeness: Ensuring there's no MNAR data, Imputing data if needed, And making sure it's not greater than 70% missed at each column
4- Removing unneeded Rows
5- Consistency: Ensuring the row's values are consitent with each other
*/