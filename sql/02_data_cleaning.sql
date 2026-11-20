-- =====================================================================
-- World Layoffs (2020–2023) | Step 2: data cleaning
-- Plan:
--   1. Work on a copy (staging table), never on the raw table
--   2. Remove duplicate rows
--   3. Standardize text (spaces, spelling, country names, dates)
--   4. Handle blanks and NULLs (fill what we can from other rows)
--   5. Remove rows and columns we cannot use
-- Rows: 2,361 raw  ->  1,995 clean
-- =====================================================================

USE world_layoffs;
SET SQL_SAFE_UPDATES = 0;   -- Workbench blocks UPDATE/DELETE without a key otherwise


-- ---------------------------------------------------------------------
-- 1. Staging table + row number to spot duplicates
-- ---------------------------------------------------------------------
-- There is no ID column, so a row is a duplicate only if ALL 9 columns match.
-- (Matching on just company + date would wrongly flag real separate layoff rounds.)

DROP TABLE IF EXISTS layoffs_staging;
CREATE TABLE layoffs_staging (
    company               TEXT,
    location              TEXT,
    industry              TEXT,
    total_laid_off        INT,
    percentage_laid_off   TEXT,
    `date`                TEXT,
    stage                 TEXT,
    country               TEXT,
    funds_raised_millions INT,
    row_num               INT
);

INSERT INTO layoffs_staging
SELECT *,
       ROW_NUMBER() OVER (
           PARTITION BY company, location, industry, total_laid_off, percentage_laid_off,
                        `date`, stage, country, funds_raised_millions
       ) AS row_num
FROM layoffs;


-- ---------------------------------------------------------------------
-- 2. Remove duplicates
-- ---------------------------------------------------------------------
-- MySQL cannot DELETE from a CTE, which is why row_num is stored as a real column.

SELECT * FROM layoffs_staging WHERE row_num > 1;        -- 5 duplicate rows (e.g. Casper, Cazoo, Hibob, Wildlife Studios, Yahoo)

DELETE FROM layoffs_staging WHERE row_num > 1;

SELECT COUNT(*) FROM layoffs_staging;                    -- 2356


-- ---------------------------------------------------------------------
-- 3. Standardize the data
-- ---------------------------------------------------------------------

-- 3a. Company names with extra spaces at the start/end (11 rows, e.g. ' E Inc.')
SELECT company, TRIM(company) FROM layoffs_staging WHERE company <> TRIM(company);
UPDATE layoffs_staging SET company = TRIM(company);

-- 3b. Industry: 'Crypto', 'Crypto Currency' and 'CryptoCurrency' are the same thing
SELECT DISTINCT industry FROM layoffs_staging ORDER BY industry;
UPDATE layoffs_staging SET industry = 'Crypto' WHERE industry LIKE 'Crypto%';

-- 3c. Country: some rows say 'United States.' with a full stop
SELECT DISTINCT country FROM layoffs_staging ORDER BY country;
UPDATE layoffs_staging SET country = TRIM(TRAILING '.' FROM country);

-- 3d. Location: the same city spelled two ways ('Dusseldorf'/'Düsseldorf', 'Malmo'/'Malmö').
--     MySQL's default collation ignores accents, so GROUP BY already merges them, but the stored
--     text is different and would split into two cities in Excel or Power BI exports.
SELECT location, COUNT(*) FROM layoffs_staging
WHERE location IN ('Dusseldorf', 'Malmo') GROUP BY location;
UPDATE layoffs_staging SET location = 'Düsseldorf' WHERE location = 'Dusseldorf';
UPDATE layoffs_staging SET location = 'Malmö'      WHERE location = 'Malmo';

-- 3e. Date is stored as text like '3/6/2023' -> convert to a real DATE
SELECT `date`, STR_TO_DATE(`date`, '%m/%d/%Y') FROM layoffs_staging;
UPDATE layoffs_staging SET `date` = STR_TO_DATE(`date`, '%m/%d/%Y');
ALTER TABLE layoffs_staging MODIFY COLUMN `date` DATE;

-- 3f. percentage_laid_off is text -> make it a number (0.05 = 5%)
ALTER TABLE layoffs_staging MODIFY COLUMN percentage_laid_off DECIMAL(5,4);


-- ---------------------------------------------------------------------
-- 4. Blanks and NULLs
-- ---------------------------------------------------------------------

-- 4a. Industry: 3 blank + 1 NULL. Turn blanks into NULL so there is only one "missing" value.
SELECT * FROM layoffs_staging WHERE industry IS NULL OR industry = '';
UPDATE layoffs_staging SET industry = NULL WHERE industry = '';

-- 4b. If the same company has another row WITH an industry, copy it across (self join).
--     Airbnb -> Travel, Carvana -> Transportation, Juul -> Consumer.
SELECT t1.company, t1.industry, t2.industry
FROM layoffs_staging t1
JOIN layoffs_staging t2 ON t1.company = t2.company
WHERE t1.industry IS NULL AND t2.industry IS NOT NULL;

UPDATE layoffs_staging t1
JOIN layoffs_staging t2 ON t1.company = t2.company
SET t1.industry = t2.industry
WHERE t1.industry IS NULL
  AND t2.industry IS NOT NULL;

-- Bally's Interactive has only one row, so there is nothing to copy from. It stays NULL
-- rather than guessing.
SELECT * FROM layoffs_staging WHERE industry IS NULL;

-- 4c. NULLs in total_laid_off / percentage_laid_off / funds_raised_millions are left as NULL:
--     we don't know the real number, and filling them with 0 or an average would distort SUMs.


-- ---------------------------------------------------------------------
-- 5. Remove rows and columns we can't use
-- ---------------------------------------------------------------------

-- Rows with neither a layoff count nor a percentage tell us nothing about layoffs (361 rows).
SELECT COUNT(*) FROM layoffs_staging
WHERE total_laid_off IS NULL AND percentage_laid_off IS NULL;

DELETE FROM layoffs_staging
WHERE total_laid_off IS NULL AND percentage_laid_off IS NULL;

-- row_num was only a helper for removing duplicates
ALTER TABLE layoffs_staging DROP COLUMN row_num;


-- ---------------------------------------------------------------------
-- Final check
-- ---------------------------------------------------------------------
SELECT COUNT(*) AS clean_rows FROM layoffs_staging;      -- 1995
SELECT * FROM layoffs_staging LIMIT 20;
