CREATE DATABASE sales_project;
USE sales_project;
/* Exploring the data */
SELECT * FROM retail_sales_dataset LIMIT 10;

/* Before starting cleaning, Let's make a replica to save our source intact */
CREATE TABLE retail_clone AS
SELECT * FROM retail_sales_dataset;

/* Chaning the dtype for Date */
SELECT str_to_date(Date, '%Y-%m-%d') as cleaned_date FROM retail_clone;

Alter table retail_clone
ADD COLUMN cleaned_date DATE;

UPDATE retail_clone
SET cleaned_date = str_to_date(Date, '%Y-%m-%d');

SELECT * FROM retail_clone LIMIT 10;

ALTER TABLE retail_clone DROP COLUMN `Date`;
ALTER TABLE retail_clone RENAME COLUMN cleaned_date TO `Date`;

/* Renaming some columns for easey quering */
ALTER TABLE retail_clone RENAME COLUMN `Transaction ID` TO transaction_id;
ALTER TABLE retail_clone RENAME COLUMN `Customer ID` TO customer_id;
ALTER TABLE retail_clone RENAME COLUMN `Product Category` TO product_catagory;
ALTER TABLE retail_clone RENAME COLUMN `Price per Unit` TO price_per_unit;
ALTER TABLE retail_clone RENAME COLUMN `Total Amount` TO total_amount;

/* Checking unique values for some columns*/
SELECT DISTINCT Gender FROM retail_clone;
SELECT DISTINCT product_catagory FROM retail_clone;





/* Show me which customers are not one-time buyers — and how often they bought. */
SELECT customer_id, Count(*) num_of_transactions 
FROM retail_clone 
GROUP BY customer_id 
HAVING COUNT(*) > 1
ORDER BY num_of_transactions DESC;




/* Consistency, Logical tie between Qty, Pricer_per_unit and Total_amount, The latter is the product of the former two values */
SELECT transaction_id,
Quantity,
price_per_unit,
total_amount,
(Quantity * price_per_unit) AS expected_total
FROM retail_clone
WHERE ABS(ROUND(total_amount,2) - ROUND((Quantity * price_per_unit),2)) > 0.01
AND
total_amount IS NOT NULL
AND 
Quantity IS NOT NULL
AND 
price_per_unit IS NOT NULL;





/* Checking the range for Age */
SELECT MIN(Age) minimum,
MAX(Age) maximum,
MAX(Age) - MIN(Age) AS age_range
FROM retail_clone
WHERE Age IS NOT NULL;




/* Which Gender is buying more */
SELECT Gender, 
COUNT(*) AS transactions_by_gender,
ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM retail_clone), 2) AS percentage_of_total
FROM retail_clone 
WHERE Gender IS NOT NULL
GROUP BY Gender
ORDER BY transactions_by_gender DESC;




/* % Within Each Product Category */
SELECT product_catagory,
Gender,
COUNT(*) total_transactions,
ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (PARTITION BY product_catagory), 2) AS percentage_within_category
FROM retail_clone 
GROUP BY 1,2
ORDER BY 1;

/* For each product category, which gender is buying more? */
SELECT product_catagory,
Gender,
COUNT(*) AS transactions_by_catagory_and_gender,
ROUND(COUNT(*) * 100 / SUM(COUNT(*)) OVER (PARTITION BY product_catagory),2) AS percentage_of_catagory_total /* SUM(transactions_by_catagory_and_gender) */
FROM retail_clone 
WHERE Gender IS NOT NULL
AND
product_catagory IS NOT NULL
GROUP BY product_catagory, Gender
ORDER BY product_catagory, transactions_by_catagory_and_gender DESC;

/* For each product category, which gender is Paying more? */
SELECT product_catagory,
Gender,
AVG(total_amount) AS avg_by_catagory_and_gender,
ROUND(AVG(total_amount) * 100 / SUM(AVG(total_amount)) OVER (PARTITION BY product_catagory),2) AS percentage_of_catagory_total /* SUM(transactions_by_catagory_and_gender) */
FROM retail_clone 
WHERE Gender IS NOT NULL
AND
product_catagory IS NOT NULL
GROUP BY product_catagory, Gender
ORDER BY product_catagory, avg_by_catagory_and_gender DESC;


/*  Each Gender's Avg Spending as % of Combined Avg 
Which group tends to spend more on average, and how big that average is compared to others.*/
WITH gender_avg AS (
  SELECT 
    Gender,
    ROUND(AVG(total_amount), 2) AS avg_spending
  FROM retail_clone
  WHERE Gender IS NOT NULL
  GROUP BY Gender
),
total_avg AS (
  SELECT SUM(avg_spending) AS sum_of_avg FROM gender_avg
)
SELECT 
  g.Gender,
  g.avg_spending,
  ROUND(g.avg_spending * 100.0 / t.sum_of_avg, 2) AS percentage_of_total_avg
FROM 
  gender_avg g, total_avg t;
  
  
  

SELECT * FROM retail_clone LIMIT 10;



/* Percentage of Transactions by Age_Group: Which age_group tends to purchase more */
SELECT CASE WHEN Age BETWEEN 18 AND 25 THEN 'Young Adult'
WHEN Age BETWEEN 26 AND 44 THEN 'Adult'
WHEN Age BETWEEN 45 AND 59 THEN 'Middle Age'
WHEN Age >= 60 THEN 'Senior'
ELSE 'N/A'
END as age_group,
COUNT(*) num_of_transactions,
ROUND(COUNT(*) * 100 / (SELECT COUNT(*) FROM retail_clone),2) as percentage_per_grp
FROM retail_clone
WHERE Age IS NOT NULL
GROUP BY 1;



/* Adding age_group as a column*/
ALTER TABLE retail_clone ADD COLUMN age_group enum('Young Adult','Adult','Middle Age','Senior');
/* Populating age_group with values */
UPDATE retail_clone 
SET age_group = CASE WHEN Age BETWEEN 18 AND 25 THEN 'Young Adult'
WHEN Age BETWEEN 26 AND 44 THEN 'Adult'
WHEN Age BETWEEN 45 AND 59 THEN 'Middle Age'
WHEN Age >= 60 THEN 'Senior'
ELSE 'N/A'
END;


/* The group who tends to pay more on average:
Which age_group tends to spend more on average, and how big that average is compared to others. */
WITH age_grp_avg AS (
SELECT age_group, AVG(total_amount) as average_per_group
FROM retail_clone
GROUP BY 1
),
total_average AS (
SELECT SUM(average_per_group) as sum_of_avg
FROM age_grp_avg
)
SELECT 
  a.age_group,
  a.average_per_group,
  ROUND(a.average_per_group * 100.0 / t.sum_of_avg, 2) AS percentage_of_total_avg
FROM 
  age_grp_avg a, total_average t;
  


/* AVG for gender per each group*/
WITH age_gender_avg_spending AS (
  SELECT 
    age_group, 
    Gender, 
    ROUND(AVG(total_amount), 2) AS average_per_group
  FROM retail_clone
  GROUP BY age_group, Gender
),
age_group_total_avg AS (
  SELECT 
    age_group, 
    SUM(average_per_group) AS total_average_per_group
  FROM age_gender_avg_spending
  GROUP BY age_group
)
SELECT 
  a.age_group,
  a.Gender,
  a.average_per_group,
  ROUND(a.average_per_group * 100.0 / b.total_average_per_group, 2) AS percentage_of_total_avg
FROM 
  age_gender_avg_spending a
JOIN 
  age_group_total_avg b ON a.age_group = b.age_group
ORDER BY 
  a.age_group, a.Gender;
  
  
  
  /*Which Gender tends to pay more quantities*/
  SELECT Quantity, 
  Gender, 
  COUNT(*) num_of_transactions,
  COUNT(*) * 100 / SUM(COUNT(*)) OVER (PARTITION BY Quantity) as percentage
  FROM retail_clone
  GROUP BY 1,2
  ORDER BY 1, 3 DESC;
  
  /*Which age_grp tends to pay more quantities*/
  SELECT Quantity, 
  age_group, 
  COUNT(*) num_of_transactions,
  COUNT(*) * 100 / SUM(COUNT(*)) OVER (PARTITION BY Quantity) as percentage
  FROM retail_clone
  GROUP BY 1,2
  ORDER BY 1, 3 DESC;
  
  
  
/* The highest product_catagory the money is spent on */
SELECT product_catagory, 
SUM(total_amount) total,
ROUND(SUM(total_amount) * 100 / (SELECT SUM(total_amount) FROM retail_clone),2) percentage
FROM retail_clone
GROUP BY 1;



