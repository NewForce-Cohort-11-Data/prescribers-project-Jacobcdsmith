-- ## Prescribers Database

-- For this exercise, you'll be working with a database derived from the [Medicare Part D Prescriber Public Use File](https://www.hhs.gov/guidance/document/medicare-provider-utilization-and-payment-data-part-d-prescriber-0). More information about the data is contained in the Methodology PDF file. See also the included entity-relationship diagram.

-- 1. 
--     a. Which prescriber had the highest total number of claims (totaled over all drugs)? Report the npi and the total number of claims.
    
SELECT npi, SUM(total_claim_count) AS total_claims
FROM prescription
GROUP BY npi
ORDER BY total_claims DESC
LIMIT 1;
-- Answer: NPI 1881634483 with 99,707 total claims

--     b. Repeat the above, but this time report the nppes_provider_first_name, nppes_provider_last_org_name,  specialty_description, and the total number of claims.

SELECT p.nppes_provider_first_name, p.nppes_provider_last_org_name, p.specialty_description, 
       SUM(pr.total_claim_count) AS total_claims
FROM prescription pr
JOIN prescriber p ON pr.npi = p.npi
GROUP BY p.npi, p.nppes_provider_first_name, p.nppes_provider_last_org_name, p.specialty_description
ORDER BY total_claims DESC
LIMIT 1;
-- Answer: BRUCE PENDLEY, Family Practice, with 99,707 total claims



-- 2. 
--     a. Which specialty had the most total number of claims (totaled over all drugs)?

SELECT p.specialty_description, SUM(pr.total_claim_count) AS total_claims
FROM prescription pr
JOIN prescriber p ON pr.npi = p.npi
GROUP BY p.specialty_description
ORDER BY total_claims DESC
LIMIT 1;
-- Answer: Family Practice with 9,752,347 total claims

--     b. Which specialty had the most total number of claims for opioids?

SELECT p.specialty_description, SUM(pr.total_claim_count) AS total_claims
FROM prescription pr
JOIN prescriber p ON pr.npi = p.npi
JOIN drug d ON pr.drug_name = d.drug_name
WHERE d.opioid_drug_flag = 'Y'
GROUP BY p.specialty_description
ORDER BY total_claims DESC
LIMIT 1;
-- Answer: Nurse Practitioner with 900,845 total opioid claims

-- c. **Challenge Question:** Are there any specialties that appear in the prescriber table that have no associated prescriptions in the prescription table?

SELECT p.specialty_description, COUNT(pr.npi) as prescription_count
FROM prescriber p
LEFT JOIN prescription pr ON p.npi = pr.npi
GROUP BY p.specialty_description
HAVING COUNT(pr.npi) = 0;
-- Answer: 15 specialties have no associated prescriptions, including: Marriage & Family Therapist, 
-- Contractor, Physical Therapist in Private Practice, and others

--     d. **Difficult Bonus:** *Do not attempt until you have solved all other problems!* For each specialty, report the percentage of total claims by that specialty which are for opioids. Which specialties have a high percentage of opioids?

WITH specialty_claims AS (SELECT p.specialty_description,
           SUM(CASE WHEN d.opioid_drug_flag = 'Y' THEN pr.total_claim_count ELSE 0 END) AS opioid_claims,
           SUM(pr.total_claim_count) AS total_claims
    FROM prescriber p
    JOIN prescription pr ON p.npi = pr.npi
    JOIN drug d ON pr.drug_name = d.drug_name
    GROUP BY p.specialty_description
    HAVING SUM(pr.total_claim_count) > 0)
SELECT specialty_description,
       opioid_claims,
       total_claims,
       ROUND(opioid_claims * 100.0 / total_claims, 2) AS opioid_percentage
FROM specialty_claims
ORDER BY opioid_percentage DESC;
-- Answer: Specialties with highest opioid percentages are Case Manager/Care Coordinator (72%), 
-- Orthopaedic Surgery (68.98%), Interventional Pain Management (59.47%)

-- 3. 
--     a. Which drug (generic_name) had the highest total drug cost?

SELECT d.generic_name, SUM(p.total_drug_cost) AS total_cost
FROM prescription p
JOIN drug d ON p.drug_name = d.drug_name
GROUP BY d.generic_name
ORDER BY total_cost DESC
LIMIT 1;
-- Answer: INSULIN GLARGINE,HUM.REC.ANLOG with total cost of $104,264,066.35

--     b. Which drug (generic_name) has the highest total cost per day? **Bonus: Round your cost per day column to 2 decimal places. Google ROUND to see how this works.**

SELECT d.generic_name, 
       ROUND(SUM(p.total_drug_cost) / SUM(p.total_day_supply), 2) AS cost_per_day
FROM prescription p
JOIN drug d ON p.drug_name = d.drug_name
GROUP BY d.generic_name
ORDER BY cost_per_day DESC
LIMIT 1;
-- Answer: C1 ESTERASE INHIBITOR with cost per day of $3,495.22





-- 4. 
--     a. For each drug in the drug table, return the drug name and then a column named 'drug_type' which says 'opioid' for drugs which have opioid_drug_flag = 'Y', says 'antibiotic' for those drugs which have antibiotic_drug_flag = 'Y', and says 'neither' for all other drugs. **Hint:** You may want to use a CASE expression for this. See https://www.postgresqltutorial.com/postgresql-tutorial/postgresql-case/ 

SELECT drug_name,
       CASE 
           WHEN opioid_drug_flag = 'Y' THEN 'opioid'
           WHEN antibiotic_drug_flag = 'Y' THEN 'antibiotic'
           ELSE 'neither'
       END AS drug_type
FROM drug;
-- This query categorizes all drugs in the database

--     b. Building off of the query you wrote for part a, determine whether more was spent (total_drug_cost) on opioids or on antibiotics. Hint: Format the total costs as MONEY for easier comparision.

SELECT 
       CASE 
           WHEN d.opioid_drug_flag = 'Y' THEN 'opioid'
           WHEN d.antibiotic_drug_flag = 'Y' THEN 'antibiotic'
           ELSE 'neither'
       END AS drug_type,
       TO_CHAR(SUM(p.total_drug_cost), 'FM$999,999,999,999.99') AS total_cost
FROM prescription p
JOIN drug d ON p.drug_name = d.drug_name
GROUP BY 
       CASE 
           WHEN d.opioid_drug_flag = 'Y' THEN 'opioid'
           WHEN d.antibiotic_drug_flag = 'Y' THEN 'antibiotic'
           ELSE 'neither'
       END
ORDER BY SUM(p.total_drug_cost) DESC;
-- Answer: More was spent on opioids ($105,080,626.37) than antibiotics ($38,435,121.26)




-- 5. 
--     a. How many CBSAs are in Tennessee? **Warning:** The cbsa table contains information for all states, not just Tennessee.

SELECT COUNT(DISTINCT cbsa) 
FROM cbsa
JOIN fips_county ON cbsa.fipscounty = fips_county.fipscounty
WHERE state = 'TN';
-- Answer: There are 10 CBSAs in Tennessee

--     b. Which cbsa has the largest combined population? Which has the smallest? Report the CBSA name and total population.
-- Largest CBSA by population
WITH cbsa_populations AS (
    SELECT c.cbsa, c.cbsaname, SUM(p.population) AS total_population
    FROM cbsa c
    JOIN population p ON c.fipscounty = p.fipscounty
    GROUP BY c.cbsa, c.cbsaname
)
SELECT cbsaname, total_population
FROM cbsa_populations
ORDER BY total_population DESC
LIMIT 1;
-- Answer: Largest - Nashville-Davidson--Murfreesboro--Franklin, TN with 1,830,410 population

-- Smallest CBSA by population
WITH cbsa_populations AS (
    SELECT c.cbsa, c.cbsaname, SUM(p.population) AS total_population
    FROM cbsa c
    JOIN population p ON c.fipscounty = p.fipscounty
    GROUP BY c.cbsa, c.cbsaname
)
SELECT cbsaname, total_population
FROM cbsa_populations
ORDER BY total_population ASC
LIMIT 1;
-- Answer: Smallest - Morristown, TN with 116,352 population

--    c. What is the largest (in terms of population) county which is not included in a CBSA? Report the county name and population.

SELECT f.county, p.population
FROM fips_county f
JOIN population p ON f.fipscounty = p.fipscounty
LEFT JOIN cbsa c ON f.fipscounty = c.fipscounty
WHERE c.cbsa IS NULL
ORDER BY p.population DESC
LIMIT 1;
-- Answer: SEVIER county with population of 95,523

-- 6. 
--     a. Find all rows in the prescription table where total_claims is at least 3000. Report the drug_name and the total_claim_count.

SELECT drug_name, total_claim_count
FROM prescription
WHERE total_claim_count >= 3000
ORDER BY total_claim_count DESC;
-- Answer: There are 9 rows with at least 3000 claims. The highest is OXYCODONE HCL with 4538 claims.

--     b. For each instance that you found in part a, add a column that indicates whether the drug is an opioid.

SELECT p.drug_name, p.total_claim_count,
       CASE WHEN d.opioid_drug_flag = 'Y' THEN 'opioid' ELSE 'not_opioid' END AS drug_type
FROM prescription p
JOIN drug d ON p.drug_name = d.drug_name
WHERE p.total_claim_count >= 3000
ORDER BY p.total_claim_count DESC;
-- Answer: Two of the top drugs are opioids: OXYCODONE HCL and HYDROCODONE-ACETAMINOPHEN.

--     c. Add another column to you answer from the previous part which gives the prescriber first and last name associated with each row.

SELECT p.drug_name, p.total_claim_count,
       CASE WHEN d.opioid_drug_flag = 'Y' THEN 'opioid' ELSE 'not_opioid' END AS drug_type,
       pr.nppes_provider_first_name, pr.nppes_provider_last_org_name
FROM prescription p
JOIN drug d ON p.drug_name = d.drug_name
JOIN prescriber pr ON p.npi = pr.npi
WHERE p.total_claim_count >= 3000
ORDER BY p.total_claim_count DESC;
-- Answer: The prescriber with the most claims over 3000 is DAVID COFFEY for OXYCODONE HCL.

-- 7. The goal of this exercise is to generate a full list of all pain management specialists in Nashville and the number of claims they had for each opioid. **Hint:** The results from all 3 parts will have 637 rows.

--     a. First, create a list of all npi/drug_name combinations for pain management specialists (specialty_description = 'Pain Management) in the city of Nashville (nppes_provider_city = 'NASHVILLE'), where the drug is an opioid (opiod_drug_flag = 'Y'). **Warning:** Double-check your query before running it. You will only need to use the prescriber and drug tables since you don't need the claims numbers yet.

SELECT p.npi, d.drug_name
FROM prescriber p
CROSS JOIN drug d
WHERE p.specialty_description = 'Pain Management'
  AND p.nppes_provider_city = 'NASHVILLE'
  AND d.opioid_drug_flag = 'Y';
-- This query returns 637 rows, representing all possible combinations of pain management specialists and opioids in Nashville.

--     b. Next, report the number of claims per drug per prescriber. Be sure to include all combinations, whether or not the prescriber had any claims. You should report the npi, the drug name, and the number of claims (total_claim_count).
    
WITH pain_management_nashville AS (
    SELECT p.npi, d.drug_name
    FROM prescriber p
    CROSS JOIN drug d
    WHERE p.specialty_description = 'Pain Management'
      AND p.nppes_provider_city = 'NASHVILLE'
      AND d.opioid_drug_flag = 'Y'
)
SELECT 
    pm.npi,
    pm.drug_name,
    rx.total_claim_count
FROM pain_management_nashville pm
LEFT JOIN prescription rx 
    ON pm.npi = rx.npi 
    AND pm.drug_name = rx.drug_name
ORDER BY rx.total_claim_count DESC NULLS LAST;
-- This query shows the number of claims for each combination, with NULL for those with no claims.

--     c. Finally, if you have not done so already, fill in any missing values for total_claim_count with 0. Hint - Google the COALESCE function.

WITH pain_management_nashville AS (
    SELECT p.npi, d.drug_name
    FROM prescriber p
    CROSS JOIN drug d
    WHERE p.specialty_description = 'Pain Management'
      AND p.nppes_provider_city = 'NASHVILLE'
      AND d.opioid_drug_flag = 'Y'
)
SELECT 
    pm.npi,
    pm.drug_name,
    COALESCE(rx.total_claim_count, 0) AS total_claims
FROM pain_management_nashville pm
LEFT JOIN prescription rx 
    ON pm.npi = rx.npi 
    AND pm.drug_name = rx.drug_name
ORDER BY total_claims DESC;






In this set of exercises you are going to explore additional ways to group and organize the output of a query when using postgres. 

For the first few exercises, we are going to compare the total number of claims from Interventional Pain Management Specialists compared to those from Pain Management specialists.

1. Write a query which returns the total number of claims for these two groups. Your output should look like this: 

specialty_description         |total_claims|
------------------------------|------------|
Interventional Pain Management|       55906|
Pain Management               |       70853|

SELECT p.specialty_description, SUM(pr.total_claim_count) AS total_claims
FROM prescription pr
JOIN prescriber p ON pr.npi = p.npi
WHERE p.specialty_description IN ('Interventional Pain Management', 'Pain Management')
GROUP BY p.specialty_description
ORDER BY p.specialty_description;
-- Answer: Interventional Pain Management has 55,906 claims and Pain Management has 70,853 claims

-- -- 2. Now, lets say that we want our output to also include the total number of claims between these two groups. Combine two queries with the UNION keyword to accomplish this. Your output should look like this:

-- specialty_description         |total_claims|
-- ------------------------------|------------|
--                               |      126759|
-- Interventional Pain Management|       55906|
-- Pain Management               |       70853|

SELECT '' AS specialty_description, SUM(pr.total_claim_count) AS total_claims
FROM prescription pr
JOIN prescriber p ON pr.npi = p.npi
WHERE p.specialty_description IN ('Interventional Pain Management', 'Pain Management')
UNION
SELECT p.specialty_description, SUM(pr.total_claim_count) AS total_claims
FROM prescription pr
JOIN prescriber p ON pr.npi = p.npi
WHERE p.specialty_description IN ('Interventional Pain Management', 'Pain Management')
GROUP BY p.specialty_description
ORDER BY specialty_description;
-- Answer: Total combined claims is 126,759

-- 3. Now, instead of using UNION, make use of GROUPING SETS (https://www.postgresql.org/docs/10/queries-table-expressions.html#QUERIES-GROUPING-SETS) to achieve the same output.

SELECT p.specialty_description, SUM(pr.total_claim_count) AS total_claims
FROM prescription pr
JOIN prescriber p ON pr.npi = p.npi
WHERE p.specialty_description IN ('Interventional Pain Management', 'Pain Management')
GROUP BY GROUPING SETS ((specialty_description), ())
ORDER BY specialty_description;
-- Answer: GROUPING SETS provides the same result as UNION but in a single query

-- 4. In addition to comparing the total number of prescriptions by specialty, lets also bring in information about the number of opioid vs. non-opioid claims by these two specialties. Modify your query (still making use of GROUPING SETS) so that your output also shows the total number of opioid claims vs. non-opioid claims by these two specialties:

-- specialty_description         |opioid_drug_flag|total_claims|
-- ------------------------------|----------------|------------|
--                               |                |      129726|
--                               |Y               |       76143|
--                               |N               |       53583|
-- Pain Management               |                |       72487|
-- Interventional Pain Management|                |       57239|

SELECT p.specialty_description, d.opioid_drug_flag, SUM(pr.total_claim_count) AS total_claims
FROM prescription pr
JOIN prescriber p ON pr.npi = p.npi
JOIN drug d ON pr.drug_name = d.drug_name
WHERE p.specialty_description IN ('Interventional Pain Management', 'Pain Management')
GROUP BY GROUPING SETS ((specialty_description), (opioid_drug_flag), ())
ORDER BY specialty_description, opioid_drug_flag;
-- Answer: Total 129,726 claims with 76,143 opioid and 53,583 non-opioid claims

-- 5. Modify your query by replacing the GROUPING SETS with ROLLUP(opioid_drug_flag, specialty_description). How is the result different from the output from the previous query?

SELECT p.specialty_description, d.opioid_drug_flag, SUM(pr.total_claim_count) AS total_claims
FROM prescription pr
JOIN prescriber p ON pr.npi = p.npi
JOIN drug d ON pr.drug_name = d.drug_name
WHERE p.specialty_description IN ('Interventional Pain Management', 'Pain Management')
GROUP BY ROLLUP(opioid_drug_flag, specialty_description)
ORDER BY opioid_drug_flag, specialty_description;
-- Answer: ROLLUP creates a hierarchical breakdown showing subtotals for each opioid flag 
-- and then the grand total, providing more detailed groupings than GROUPING SETS

-- 6. Switch the order of the variables inside the ROLLUP. That is, use ROLLUP(specialty_description, opioid_drug_flag). How does this change the result?

SELECT p.specialty_description, d.opioid_drug_flag, SUM(pr.total_claim_count) AS total_claims
FROM prescription pr
JOIN prescriber p ON pr.npi = p.npi
JOIN drug d ON pr.drug_name = d.drug_name
WHERE p.specialty_description IN ('Interventional Pain Management', 'Pain Management')
GROUP BY ROLLUP(specialty_description, opioid_drug_flag)
ORDER BY specialty_description, opioid_drug_flag;
-- Answer: Switching the order changes the hierarchy - now we get subtotals for each specialty
-- (showing opioid vs non-opioid breakdown within each specialty) then the grand total

-- 7. Finally, change your query to use the CUBE function instead of ROLLUP. How does this impact the output?

SELECT p.specialty_description, d.opioid_drug_flag, SUM(pr.total_claim_count) AS total_claims
FROM prescription pr
JOIN prescriber p ON pr.npi = p.npi
JOIN drug d ON pr.drug_name = d.drug_name
WHERE p.specialty_description IN ('Interventional Pain Management', 'Pain Management')
GROUP BY CUBE(specialty_description, opioid_drug_flag)
ORDER BY specialty_description, opioid_drug_flag;
-- Answer: CUBE provides all possible combinations of groupings - it includes both 
-- the specialty subtotals AND the opioid flag subtotals, giving the most comprehensive view

-- 8. In this question, your goal is to create a pivot table showing for each of the 4 largest cities in Tennessee (Nashville, Memphis, Knoxville, and Chattanooga), the total claim count for each of six common types of opioids: Hydrocodone, Oxycodone, Oxymorphone, Morphine, Codeine, and Fentanyl. For the purpose of this question, we will put a drug into one of the six listed categories if it has the category name as part of its generic name. For example, we could count both of "ACETAMINOPHEN WITH CODEINE" and "CODEINE SULFATE" as being "CODEINE" for the purposes of this question.

-- The end result of this question should be a table formatted like this:

-- city       |codeine|fentanyl|hydrocodone|morphine|oxycodone|oxymorphone|
-- -----------|-------|--------|-----------|--------|---------|-----------|
-- CHATTANOOGA|   1323|    3689|      68315|   12126|    49519|       1317|
-- KNOXVILLE  |   2744|    4811|      78529|   20946|    84730|       9186|
-- MEMPHIS    |   4697|    3666|      68036|    4898|    38295|        189|
-- NASHVILLE  |   2043|    6119|      88669|   13572|    62859|       1261|

-- For this question, you should look into use the crosstab function, which is part of the tablefunc extension (https://www.postgresql.org/docs/9.5/tablefunc.html). In order to use this function, you must (one time per database) run the command
-- 	CREATE EXTENSION tablefunc;

-- Hint #1: First write a query which will label each drug in the drug table using the six categories listed above.
-- Hint #2: In order to use the crosstab function, you need to first write a query which will produce a table with one row_name column, one category column, and one value column. So in this case, you need to have a city column, a drug label column, and a total claim count column.
-- Hint #3: The sql statement that goes inside of crosstab must be surrounded by single quotes. If the query that you are using also uses single quotes, youll need to escape them by turning them into double-single quotes.

-- -- First enable the tablefunc extension
-- CREATE EXTENSION IF NOT EXISTS tablefunc;

-- Create the pivot table using crosstab
SELECT * FROM crosstab
    ('WITH drug_categories AS (
        SELECT drug_name,
               CASE 
                   WHEN UPPER(generic_name) LIKE ''%HYDROCODONE%'' THEN ''hydrocodone''
                   WHEN UPPER(generic_name) LIKE ''%OXYCODONE%'' THEN ''oxycodone''
                   WHEN UPPER(generic_name) LIKE ''%OXYMORPHONE%'' THEN ''oxymorphone''
                   WHEN UPPER(generic_name) LIKE ''%MORPHINE%'' THEN ''morphine''
                   WHEN UPPER(generic_name) LIKE ''%CODEINE%'' THEN ''codeine''
                   WHEN UPPER(generic_name) LIKE ''%FENTANYL%'' THEN ''fentanyl''
               END AS drug_category
        FROM drug
        WHERE UPPER(generic_name) LIKE ''%HYDROCODONE%'' 
           OR UPPER(generic_name) LIKE ''%OXYCODONE%''
           OR UPPER(generic_name) LIKE ''%OXYMORPHONE%''
           OR UPPER(generic_name) LIKE ''%MORPHINE%''
           OR UPPER(generic_name) LIKE ''%CODEINE%''
           OR UPPER(generic_name) LIKE ''%FENTANYL%'' )
    SELECT 
        pr.nppes_provider_city,
        dc.drug_category,
        SUM(rx.total_claim_count)
    FROM prescription rx
    JOIN prescriber pr ON rx.npi = pr.npi
    JOIN drug_categories dc ON rx.drug_name = dc.drug_name
    WHERE pr.nppes_provider_city IN (''NASHVILLE'', ''MEMPHIS'', ''KNOXVILLE'', ''CHATTANOOGA'')
    GROUP BY pr.nppes_provider_city, dc.drug_category
    ORDER BY pr.nppes_provider_city, dc.drug_category',
    'SELECT unnest(ARRAY[''codeine'', ''fentanyl'', ''hydrocodone'', ''morphine'', ''oxycodone'', ''oxymorphone''])') 
    AS pivot_table (
    city text,
    codeine int,
    fentanyl int,
    hydrocodone int,
    morphine int,
    oxycodone int,
    oxymorphone int
);
-- Answer: Successfully created pivot table showing opioid claims by city and drug type