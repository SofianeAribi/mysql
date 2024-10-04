
/* 
QUESTIONS TO ANSWER:

1.What is the gender breakdown of employees in the company?
2.What is the race/ethnicity breakdown of employees in the company?
3.What is the age distribution of employees in the company?
4.How many employees work at headquarters versus remote locations?
5.What is the average length of employment for employees who have been terminated?
6.How does the gender distribution vary across departments and job titles?
7.What is the distribution of job titles across the company?
8.What is the turnover rate ?
9.What is the distribution of employees across locations by state?
10.How has the company's employee count changed over time based on hire and term dates?
11.What is the tenure distribution for each department?
*/


-- DATA CLEANING

Alter table human_resources Rename column ï»¿id to id;

select * from human_resources;

-- Birthdate cleaning

UPDATE human_resources
SET birthdate = REPLACE(birthdate, '-', '/');

select birthdate,
str_to_date(birthdate, '%m/%d/%Y')
from human_resources;


UPDATE human_resources
SET Birthdate = str_to_date(birthdate, '%m/%d/%Y');

-- -----------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- JobTitle Cleaning:

SELECT jobtitle,COUNT(jobtitle) FROM human_resources
group by jobtitle;

Update human_resources
SET jobtitle = REPLACE(jobtitle,'I','');

Update human_resources
SET jobtitle = REPLACE(jobtitle,'V','')
Where jobtitle LIKE '%V';

-- --------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- Hire Date CLEANING:

SELECT hire_date FROM human_resources;

UPDATE human_resources
SET hire_date = REPLACE(hire_date, '-', '/');

UPDATE human_resources
SET hire_date = str_to_date(hire_date, '%m/%d/%Y');


-- --------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- Cleaning termdate:

Update human_resources
SET termdate = replace(termdate,substring(termdate, 11),'');

SELECT * FROM human_resources;

-- ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- Checking duplicates:

select * from (
select id,first_name, last_name,
ROW_NUMBER() over (partition by id) as row_num
from human_resources) as row_num
where row_num > 1;

-- ------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- EDA :

-- 1.What is the gender breakdown of employees in the company?

SELECT gender,
COUNT(gender)
FROM human_resources
GROUP BY gender;

SELECT (SUM(CASE WHEN gender = 'Male' THEN 1 ELSE 0 END)-
	   SUM(CASE WHEN gender = 'Female' THEN 1 ELSE 0 END)) as Gender_diff
FROM human_resources;

/* we notice that there is 967 Male more than Females while we have 605 person that didn't confirm their gender*/

-- ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- 2.What is the race/ethnicity breakdown of employees in the company?

SELECT race,
COUNT(race) as race_count
FROM human_resources
GROUP BY race
ORDER BY race_count DESC;

/* White race is most popular whitin the company with 6328 person, mixed race comes in second with 3648 person*/

-- ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- 3.What is the age distribution of employees in the company?

-- Cleaning age errors:


UPDATE human_resources
SET birthdate = DATE_SUB(birthdate, INTERVAL 100 YEAR)
WHERE YEAR(birthdate) > 2024;

ALTER TABLE human_resources
ADD COLUMN age INT after birthdate;

UPDATE human_resources
SET age = Year(curdate()) - YEAR(birthdate);

SELECT age,
COUNT(age)
FROM human_resources
GROUP BY age
ORDER BY age;

-- Adding age categories:

ALTER TABLE human_resources
ADD COLUMN age_category varchar(50) After age;

select * from human_resources;

UPDATE human_resources
SET age_category = CASE 
    WHEN age >= 20 AND age < 35 THEN 'Young Adults'
    WHEN age >= 36 AND age < 55 THEN 'Adults'
    WHEN age >= 56 AND age < 64 THEN 'Middle-aged Adults'
    WHEN age >= 65 THEN 'Seniors'
    ELSE age_category
END;

SELECT age_category,
COUNT(age_category)
FROM human_resources
GROUP BY age_category
ORDER BY COUNT(age_category) DESC;

/* We notice that the majority of employees are Adults with 11379 employee followed by 8972 Young adults */


-- ------------------------------------------------------------------------------------------------------------------------------------------------------------------------

 -- 4.How many employees work at headquarters versus remote locations?

SELECT location,
COUNT(location) as location_count
FROM human_resources
GROUP BY (location);


-- ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- 5.What is the average length of employment for employees who have been terminated?

SELECT FLOOR(AVG(datediff(termdate, hire_date)) /365) as years,
	   FLOOR(AVG(datediff(termdate, hire_date)) %365 /30) as months
FROM human_resources
WHERE termdate <= 2024 and termdate != '';

/* The average lenths of employment in the company is 8 years.*/

-- -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- 6.How does the gender distribution vary across departments and job titles?

SELECT department,
	   jobtitle,
       SUM((CASE WHEN gender = 'Male' Then 1 ELSE 0 END)) as Male, 
	   SUM((CASE WHEN gender = 'Female' THEN 1 ELSE 0 END)) as Female
FROM human_resources
GROUP BY department,
	   jobtitle
ORDER BY department;

-- -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- 7.What is the distribution of job titles across the company?

SELECT jobtitle,
	   COUNT(jobtitle) as jobtitle_count
FROM human_resources
GROUP BY jobtitle
ORDER BY jobtitle_count DESC;


-- ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- 8. 8.Which department has the highest turnover rate?

WITH left_employees AS (
SELECT COUNT(termdate) as left_count
FROM human_resources
WHERE termdate != '' and year(termdate) <= 2024
)

,
min_max_date AS (
SELECT MIN(hire_date) as Min_date, MAX(hire_date) as Max_date FROM human_resources
)
,
Average_employees AS (

SELECT (
	(SELECT COUNT(*) FROM human_resources WHERE hire_date <= (SELECT Min_date from min_max_date )) + 
    (SELECT COUNT(*) FROM human_resources WHERE hire_date <= (SELECT Max_date from min_max_date ))
	) /2 As avg_emp_num
)

Select (
	Round(((SELECT left_count FROM left_employees) / (SELECT avg_emp_num FROM Average_employees))*  100,2)
    ) AS turnover_rate;
    

-- 9.What is the distribution of employees across locations by state? ----------------------------------------------------------------------------------------------------------------

SELECT 
	location,
    location_state,
    count(*) as employee_count 
FROM human_resources
GROUP BY location_state,location
ORDER BY location_state;

-- 10.How has the company's employee count changed over time based on hire and term dates?------------------------------------------------------------------------------------------------------

SELECT year(hire_date) as hire_year,
COUNT(*) OVER (ORDER BY year(hire_date)) FROM human_resources
ORDER BY year(hire_date);


WITH hire_date AS (

SELECT year(hire_date) As year,
	COUNT(*) AS hire_count FROM human_resources
GROUP BY year
),

term_date AS (

SELECT year(termdate) As year,
	Count(*) As term_count  FROM human_resources
    WHERE termdate IS NOT NULL
    GROUP BY year
)

SELECT 
	coalesce(hd.year,td.year) AS year,
    coalesce(hire_count,0) AS hires,
	coalesce(term_count,0) AS Terminations,
    SUM(coalesce(hire_count,0) - coalesce(term_count,0) ) OVER (ORDER BY coalesce(hd.year,td.year) ) AS net_employee_count

FROM hire_date hd
LEFT JOIN term_date td ON hd.year = td.year
ORDER BY year;

-- 11.What is the tenure distribution for each department? ------------------------------------------------------------------------------------------------------------------------------------------

SELECT department,
	ROUND(AVG(coalesce(year(termdate) - year(hire_date), year(curdate())- year(hire_date))),1) AS tenure
FROM human_resources
GROUP BY department








