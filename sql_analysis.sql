-- How many clients does the bank have and are above the age of 50?

SELECT COUNT(*) AS clients_above_50
FROM basic_client_info
WHERE customer_age > 50
;

-- What’s the distribution (in %) between male and female clients?
WITH total_count AS (
    SELECT 
        COUNT(*) AS total 
    FROM basic_client_info
)
SELECT 
    gender,
    ROUND(COUNT(*) * 100.0 / total, 1) AS percent_distribution
FROM 
    basic_client_info
JOIN 
    total_count ON true
GROUP BY 
    gender, total;
    
    
-- Let’s define a new variable called age_group:

--10 < x ≤ 30
--30 < x ≤ 40
--40 < x ≤ 50
--50 < x ≤ 60
--60 <x ≤ 120

-- Rather than permanently updating the table, I am including this new variable in a view. This way I can easily refer to it without creating it every time its needed. 

DROP VIEW IF EXISTS demographics;
CREATE VIEW demographics AS (

    SELECT 
        clientnum,
        CASE WHEN customer_age > 10 and customer_age <= 30 THEN '11 - 30' 
        WHEN customer_age > 30 and customer_age <= 40 THEN '31 - 40'
        WHEN customer_age > 40 and customer_age <= 50 THEN '41 - 50'
        WHEN customer_age > 50 and customer_age <= 60 THEN '51 - 60'
        WHEN customer_age > 60 and customer_age <= 120 THEN '61 - 120'
        END AS age_group,
        marital_status,
        income_category
    FROM basic_client_info
    )
;

-- Solution approach: Created a Pivot Table that groups the dataset by demographic variables: age group, marital status and income category, while also aggregating individual values into a summary of the churn rate, avg total relationship count, minimum total amount change [Q1-Q4] and number of customers, per each demographic group.

WITH churned AS (
    SELECT 
        dem.clientnum AS clientnum,
        dem.age_group AS age_group,
        dem.marital_status AS marital_status,
        dem.income_category AS income_category,
        ecd.total_relationship_count AS total_relationship_count,
        ecd.total_amt_chng_q4_q1 AS total_amt_chng_q4_q1,
        CASE 
            WHEN bc.attrition_flag = 'Attrited Customer' THEN 1
            ELSE 0 
        END AS is_churned
    FROM demographics AS dem
    JOIN bankchurners AS bc
        ON dem.clientnum = bc.clientnum
    JOIN enriched_churn_data AS ecd
        ON dem.clientnum = ecd.clientnum
)
SELECT 
    age_group, 
    marital_status, 
    income_category,
    ROUND(100.0 * SUM(is_churned) / (SELECT COUNT(*) FROM bankchurners), 1) AS churn_rate_percent,
    ROUND(AVG(total_relationship_count), 1) AS avg_total_product_count,
    MIN(total_amt_chng_q4_q1) AS min_amt_chng_q4_q1,
    COUNT(clientnum) AS client_count
FROM churned
GROUP BY age_group, marital_status, income_category
ORDER BY age_group, client_count DESC;

WITH total_count AS (
    SELECT 
        COUNT(*) AS total
    FROM basic_client_info AS bci
    JOIN bankchurners AS bc
        ON bci.clientnum = bc.clientnum
    WHERE gender = 'M'
        AND card_category = 'Blue'
),
male_blue_card_holders AS (
    SELECT 
        bci.income_category
    FROM basic_client_info AS bci
    JOIN bankchurners AS bc
        ON bci.clientnum = bc.clientnum
    WHERE gender = 'M'
        AND card_category = 'Blue'
)
SELECT 
    income_category,
    ROUND(100.0 * COUNT(income_category) / total, 2) AS percent_of_male_blue_card_holders
FROM male_blue_card_holders
CROSS JOIN total_count
GROUP BY income_category, total
LIMIT 1 OFFSET 3;

SELECT 
    clientnum
FROM enriched_churn_data
ORDER BY total_amt_chng_q4_q1 DESC
LIMIT 2 OFFSET 2
;

-- Which client (CLIENTNUM) has the 2nd highest Total_Trans_Amt, Per each Marital_Status.

WITH t1 AS (
    SELECT
        bci.clientnum,
        marital_status,
        total_trans_amt,
        DENSE_RANK() OVER (PARTITION BY marital_status ORDER BY total_trans_amt Desc) AS rnk
FROM basic_client_info AS bci
JOIN enriched_churn_data AS ecd
    ON bci.clientnum = ecd.clientnum
)
SELECT 
    marital_status,
    clientnum AS client_with_2nd_highest_trans_amt
FROM t1
WHERE rnk=2
;

