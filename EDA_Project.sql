-- ********************
-- Exploratory Data Analysis
-- ********************


-- CheckPoint
CALL checking();


-- Total fixed number of layoffs per year
SELECT YEAR(`date`) as the_year, SUM(total_laid_off) as Total_layoffs
FROM layoffs_staging2
WHERE YEAR(`date`) IS NOT NULL
GROUP BY YEAR(`date`)
ORDER BY YEAR(`date`) asc;

-- Percentage of layoffs per year and month across all layoffs
WITH percentage_off_PerYear AS (
SELECT SUBSTR(`date`,1,7) as the_month_year, SUM(total_laid_off) as Total_layoffs
FROM layoffs_staging2
WHERE SUBSTR(`date`,1,7) IS NOT NULL
GROUP BY SUBSTR(`date`,1,7)
ORDER BY the_month_year asc
)
SELECT *, ROUND((Total_layoffs * 100) /(SELECT SUM(total_laid_off) FROM layoffs_staging2 WHERE SUBSTR(`date`,1,7) IS NOT NULL)) AS percentage
FROM
percentage_off_PerYear
ORDER BY percentage DESC;
SELECT SUBSTR(`date`,1,7)
FROM layoffs_staging2;

-- Total number of companies
SELECT COUNT(DISTINCT company) as Total_companies
FROM layoffs_staging2;

-- Total number of layoffs
SELECT SUM(total_laid_off) AS total_layoffs
FROM layoffs_staging2;



-- Percentage of the layoffs per industry
WITH perc_offs_PerCompany AS (
-- fixed number of the layoffs per industry
SELECT industry, SUM(total_laid_off) as Total_layoffs
FROM layoffs_staging2
WHERE total_laid_off IS NOT NULL
GROUP BY industry
ORDER BY total_layoffs DESC)
SELECT *, ROUND ((Total_layoffs * 100) / (SELECT SUM(total_laid_off) FROM layoffs_staging2 WHERE total_laid_off IS NOT NULL)) as percentange 
FROM perc_offs_PerCompany;


-- The percentage of Companies per Country
WITH companies_per_country AS (
SELECT country, COUNT(DISTINCT company) as num_of_companies
FROM layoffs_staging2
GROUP BY country
ORDER BY 2 DESC)
-- Let's The ratio between (The number of unique companies per country) AND (The total number of unqiue companies)
SELECT *, ROUND((num_of_companies * 100) / (SELECT COUNT(DISTINCT company) FROM layoffs_staging2)) AS percentange_of_companies
FROM
companies_per_country;



-- The percentage of Companies per industry
WITH companies_per_industry AS (
SELECT industry, COUNT(DISTINCT company) as num_of_companies
FROM layoffs_staging2
GROUP BY industry
ORDER BY 2 DESC)
-- Let's The ratio between (The number of unique companies per industry) AND (The total number of unqiue companies)
SELECT *, ROUND((num_of_companies * 100) / (SELECT COUNT(DISTINCT company) FROM layoffs_staging2)) AS percentange_of_companies
FROM
companies_per_industry;


-- Avg funds per industry in million
WITH avg_funds_per_industry AS (
SELECT industry, COUNT(DISTINCT company) as num_of_companies, SUM(funds_raised_millions) as total_funds
FROM
layoffs_staging2
GROUP BY industry),
Ranking AS (
SELECT *, ROUND((total_funds/num_of_companies)) AS avg_funds
FROM avg_funds_per_industry
GROUP BY industry, num_of_companies)
SELECT *, DENSE_RANK() OVER (ORDER BY avg_funds DESC) as avg_funds_rank
FROM Ranking;
