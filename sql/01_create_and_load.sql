-- =====================================================================
-- World Layoffs (2020–2023) | Step 1: create the database and load the raw CSV
-- Database: MySQL 8.0+
-- =====================================================================

CREATE DATABASE IF NOT EXISTS world_layoffs;
USE world_layoffs;

-- Raw table: keep everything as it comes from the file. We never edit this table.
DROP TABLE IF EXISTS layoffs;
CREATE TABLE layoffs (
    company               TEXT,
    location              TEXT,
    industry              TEXT,
    total_laid_off        INT,
    percentage_laid_off   TEXT,
    `date`                TEXT,
    stage                 TEXT,
    country               TEXT,
    funds_raised_millions INT
);

-- Option A (recommended): LOAD DATA turns the text 'NULL' in the file into real NULLs.
-- 1. Run once as admin:   SET GLOBAL local_infile = 1;
-- 2. In MySQL Workbench: edit the connection > Advanced > Others, add OPT_LOCAL_INFILE=1
-- 3. Change the path below to where layoffs_raw.csv is on your computer (use forward slashes).
LOAD DATA LOCAL INFILE 'C:/path/to/data/layoffs_raw.csv'
INTO TABLE layoffs
FIELDS TERMINATED BY ','
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(company, location, industry, @total, @pct, @dt, stage, country, @funds)
SET total_laid_off        = NULLIF(@total, 'NULL'),
    percentage_laid_off   = NULLIF(@pct,   'NULL'),
    `date`                = NULLIF(@dt,    'NULL'),
    funds_raised_millions = NULLIF(TRIM(@funds), 'NULL'),
    industry              = NULLIF(industry, 'NULL'),
    stage                 = NULLIF(stage,    'NULL');

-- Option B: Workbench "Table Data Import Wizard" (right-click the table > Table Data Import Wizard).
-- It works too, but it may skip rows that have 'NULL' text in number columns,
-- so always run the row-count check below after importing.

SELECT COUNT(*) AS raw_rows FROM layoffs;   -- expected: 2361
