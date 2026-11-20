-- =====================================================================
-- World Layoffs (2020–2023) | Step 3: exploratory data analysis
-- Table: world_layoffs.layoffs_staging (cleaned, 1,995 rows)
-- Numbers in the comments are the results on the cleaned data (2,361 raw rows -> 1,995).
-- =====================================================================

USE world_layoffs;


-- ---------------------------------------------------------------------
-- A. Overview
-- ---------------------------------------------------------------------

-- Time period and total covered
SELECT MIN(`date`) AS first_date,
       MAX(`date`) AS last_date,
       COUNT(*) AS layoff_events,
       SUM(total_laid_off) AS total_laid_off
FROM layoffs_staging;                                    -- 2020-03-11 to 2023-03-06, 383,659 people

-- Biggest single layoff and the range of percentages
SELECT MAX(total_laid_off) AS biggest_single_layoff,     -- 12,000 (Google, Jan 2023)
       MIN(percentage_laid_off) AS min_pct,
       MAX(percentage_laid_off) AS max_pct                -- 1 = the whole company
FROM layoffs_staging;

-- Companies that laid off 100% of staff (they shut down): 116 rows
SELECT COUNT(*) FROM layoffs_staging WHERE percentage_laid_off = 1;

-- ...and the best-funded of them: Britishvolt ($2.4B raised), Quibi ($1.8B), Deliveroo Australia ($1.7B)
SELECT company, country, industry, funds_raised_millions
FROM layoffs_staging
WHERE percentage_laid_off = 1
ORDER BY funds_raised_millions DESC
LIMIT 10;


-- ---------------------------------------------------------------------
-- B. Who was hit hardest (GROUP BY)
-- ---------------------------------------------------------------------

-- By company: Amazon 18,150 | Google 12,000 | Meta 11,000 | Salesforce 10,090 | Microsoft and Philips 10,000 each
SELECT company, SUM(total_laid_off) AS total
FROM layoffs_staging
GROUP BY company
ORDER BY total DESC
LIMIT 10;

-- By country: United States 256,559 (about 67% of all layoffs) | India 35,993 | Netherlands 17,220
SELECT country,
       SUM(total_laid_off) AS total,
       ROUND(100 * SUM(total_laid_off) / (SELECT SUM(total_laid_off) FROM layoffs_staging), 1) AS pct_of_all
FROM layoffs_staging
GROUP BY country
ORDER BY total DESC
LIMIT 10;

-- By city: SF Bay Area 125,631 | Seattle 34,743 | New York City 29,364 | Bengaluru 21,787
SELECT location, country, SUM(total_laid_off) AS total
FROM layoffs_staging
GROUP BY location, country
ORDER BY total DESC
LIMIT 10;

-- By industry: Consumer 45,182 | Retail 43,613 | Other 36,289 | Transportation 33,748 | Finance 28,344
SELECT industry, SUM(total_laid_off) AS total
FROM layoffs_staging
GROUP BY industry
ORDER BY total DESC;

-- By company stage: Post-IPO companies account for 204,132 (big public companies)
SELECT stage, SUM(total_laid_off) AS total
FROM layoffs_staging
GROUP BY stage
ORDER BY total DESC;


-- ---------------------------------------------------------------------
-- C. Trends over time
-- ---------------------------------------------------------------------

-- By year: 2020 80,998 | 2021 15,823 | 2022 160,661 | 2023 125,677 (only Jan–Mar!)
SELECT YEAR(`date`) AS yr, SUM(total_laid_off) AS total
FROM layoffs_staging
WHERE `date` IS NOT NULL
GROUP BY yr
ORDER BY yr;

-- Monthly totals with a running (rolling) total
-- The worst month is January 2023 with 84,714 layoffs.
WITH monthly AS (
    SELECT DATE_FORMAT(`date`, '%Y-%m') AS month,
           SUM(total_laid_off) AS total
    FROM layoffs_staging
    WHERE `date` IS NOT NULL
    GROUP BY month
)
SELECT month,
       total,
       SUM(total) OVER (ORDER BY month) AS rolling_total
FROM monthly
ORDER BY month;


-- ---------------------------------------------------------------------
-- D. Top 3 companies per year (CTE + DENSE_RANK)
-- ---------------------------------------------------------------------
-- 2020: Uber, Booking.com, Groupon
-- 2021: Bytedance, Katerra, Zillow
-- 2022: Meta, Amazon, Cisco
-- 2023: Google, Microsoft, Ericsson
WITH company_year AS (
    SELECT company, YEAR(`date`) AS yr, SUM(total_laid_off) AS total
    FROM layoffs_staging
    WHERE `date` IS NOT NULL
    GROUP BY company, yr
),
ranked AS (
    SELECT company, yr, total,
           DENSE_RANK() OVER (PARTITION BY yr ORDER BY total DESC) AS rnk
    FROM company_year
    WHERE total IS NOT NULL
)
SELECT yr, rnk, company, total
FROM ranked
WHERE rnk <= 3
ORDER BY yr, rnk;
