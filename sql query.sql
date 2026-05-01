create database live_project;
use live_project;
CREATE TABLE wdiasia_data (
  country_name TEXT,
  country_code TEXT,
  indicator_name TEXT,
  indicator_code TEXT,
  year INT,
  indicator_value DOUBLE
);



CREATE TABLE wdifootnote_data (
    country_code TEXT,
    series_code TEXT,
    Year INT,
    Description TEXT
);

CREATE TABLE series_data (
    series_code TEXT,
    Topic TEXT,
    indicator_name TEXT,
    short_definition TEXT,
    long_definition TEXT,
    unit_of_measure TEXT,
    Periodicity TEXT,
    other_notes TEXT,
    aggregation_method TEXT,
    limitations_and_exceptions TEXT,
    notes_from_original_source TEXT,
    General_comments TEXT,
    Source TEXT,
    statistical_concept_and_methodology TEXT,
    development_relevance TEXT,
    related_source_links TEXT,
    other_web_links TEXT,
    related_indicators TEXT,
    license_type TEXT
);
-- set primary key to master table
ALTER TABLE series_data
MODIFY series_code VARCHAR(50);

ALTER TABLE series_data
ADD PRIMARY KEY (series_code);

-- set primary key

ALTER TABLE wdicountry_data
MODIFY countrycode VARCHAR(50);
alter table wdicountry_data
add primary key (countrycode);


-- set foreign key
alter table wdiasia_data
modify country_code varchar(50);

alter table wdiasia_data
add foreign key (country_code )
references wdicountry_data(countrycode);


alter table wdicountry_series_data
modify countrycode varchar(50);

alter table wdicountry_series_data
add foreign key (countrycode) references wdicountry_data(countrycode);

alter table wdicountry_series_data
modify seriescode varchar(50);

alter table wdicountry_series_data
add foreign key (seriescode) references series_data(series_code);


alter table series_time
modify seriescode varchar(50);

alter table series_time
add foreign key (seriescode) references series_data(series_code);

alter table wdifootnote_data
modify series_code varchar(50);

alter table wdifootnote_data
modify country_code varchar(50);


alter table wdifootnote_data
add foreign key (series_code) references series_data(series_code);

alter table wdifootnote_data
add foreign key (country_code) references wdicountry_data(countrycode);


-- changing table name --
RENAME TABLE wdiasia_data TO asia_data;

RENAME TABLE wdicountry_data TO country_data;

RENAME TABLE wdicountry_series_data TO country_series_data;

RENAME TABLE wdifootnote_data TO footnote_data;


-- changing column name for all table --

alter table country_data
rename column countrycode to country_code;

alter table country_series_data
rename column countrycode to country_code;

alter table country_series_data
rename column seriescode to series_code;

alter table series_time
rename column seriescode to series_code;

-- Top 5 Populous Countries in 2020 --
select country_name, country_code, sum(indicator_value) as total_population
from asia_data
where year=2020 and indicator_name in ('population, female' , 'population, male')
group by country_name, country_code
order by total_population desc
limit 5;


-- GDP Growth Percentage by Decade -- 

select distinct indicator_name
from asia_data
where indicator_name like '%GDP %';


select
    country_name,
    concat(floor(year / 10) * 10, 's') as decade,
    round(avg(indicator_value), 2) as avg_gdp_growth_percentage
from asia_data
where indicator_code = 'NY.GDP.MKTP.KD.ZG' 
group by country_name, decade
order by country_name, decade;


-- Average Life Expectancy by Continent--


-- a) Average Life Expectancy by Countries

select country_code,country_name, round(avg(indicator_value),2) as Average_life_expectancy
from asia_data
where indicator_name='Life expectancy at birth, total (years)'
group by country_code,country_name
order by Average_life_expectancy desc;

-- b) Average Life Expectancy by Continent
select round(avg(indicator_value),2) as Average_life_expectancy
from asia_data
where indicator_name='Life expectancy at birth, total (years)';






-- Countries with Literacy Rate Above 90%-- 
select distinct indicator_name
from asia_data
where indicator_name like '%Literacy%';

select country_code,country_name,max(indicator_value) as literacy_rate
from asia_data
where indicator_name = 'Literacy rate, adult total (% of people ages 15 and above)'
group by country_code, country_name
having MAX(indicator_value) > 90
order by literacy_rate desc;

  
  
 --  1) YoY Growth %
 -- Calculates the year-on-year percentage change of an indicator (like GDP) for each country to show how fast it is rising or falling annually.

select country_name, year,indicator_value,
    round(
        ((indicator_value - lag(indicator_value) over (partition by  country_name order by year)) 
        / lag (indicator_value) over (partition by country_name order by year)) ,2) as yoy_growth_percent
from asia_data
where indicator_code = 'NY.GDP.MKTP.KD.ZG'
order by country_name, year;


-- 2) CAGR (2000→2020)
-- Computes the average annual growth rate across a period (like 20 years), smoothing out ups and downs to show long-term growth.

select   country_code,  
    round(
        (
            power(
                max(case when year = 2020 then indicator_value end) /
                max(case when year = 2000 then indicator_value end),
                1.0 / 20
            ) - 1
        ) * 100,
        2
    ) as cagr_percent
from asia_data
where  indicator_code = 'NY.GDP.PCAP.CD'
group by country_code
having
    max(case when year = 2000 then indicator_value end) is not null
AND MAX(case when year = 2020 then indicator_value end) is not null
order by cagr_percent desc;



-- 3) Rolling Average (5-year moving average)
-- Takes the average of the last 5 years at each year point to reduce noise and show a smoother trend line.

select country_name,(year - mod(year, 5)) as period_start_year,
    ROUND(avg(indicator_value), 2) as avg_5yr_value
  from asia_data
  where indicator_code = 'NY.GDP.PCAP.CD'
  and indicator_value is not null
  group by country_name,(year - MOD(year, 5))
  order by country_name ,period_start_year;


-- 4) Rank countries by latest available value
-- Finds each country’s most recent non-null year value and ranks countries based on that, even when data is missing for the latest year.


select country_code, year as latest_year, indicator_value,
    rank() over(order by indicator_value desc) as country_rank
from asia_data
where indicator_code = 'NY.GDP.PCAP.CD'
  and indicator_value is not null
  and year = (
      select max(year)
      from asia_data )
order by country_rank;


-- 5) Coverage analysis (% missing by country)
-- Checks how complete the data is by calculating how many years are missing for each country for a chosen indicator.

    SELECT a.country_code,
       SUM(CASE WHEN d.indicator_value IS NULL THEN 1 ELSE 0 END) AS missing_years,
       COUNT(*) AS total_years,
       100.0 * SUM(CASE WHEN d.indicator_value IS NULL THEN 1 ELSE 0 END) / COUNT(*) AS missing_pct
FROM asia_data a
LEFT JOIN asia_data d
  ON d.country_code=a.country_code AND d.year=a.year
GROUP BY a.country_code
ORDER BY missing_pct DESC, missing_years DESC;





-- 6) Correlation between two indicators
-- Measures whether two indicators move together (example: GDP per capita and life expectancy) from -1 to +1 (strong negative to strong positive).

WITH life_expectancy AS (
    SELECT country_code, year,indicator_value AS y
    FROM asia_data
    WHERE indicator_code = 'SP.DYN.LE00.IN'
      AND year BETWEEN 2000 AND 2020
      AND indicator_value IS NOT NULL
),
gdp_per_capita AS (
    SELECT country_code, year, indicator_value AS x
    FROM asia_data
    WHERE indicator_code = 'NY.GDP.PCAP.KD'
      AND year BETWEEN 2000 AND 2020
      AND indicator_value IS NOT NULL
)
SELECT l.country_code, l.year, g.x, l.y
FROM life_expectancy l
JOIN gdp_per_capita g
  ON l.country_code = g.country_code
 AND l.year = g.year
ORDER BY l.country_code, l.year;

SELECT
    g.Country_Code,
    g.year,
    g.indicator_value AS gdp_per_capita,
    l.indicator_value AS life_expectancy
FROM asia_data g
JOIN asia_data l
    ON g.Country_Code = l.Country_Code
   AND g.year = l.year
WHERE g.indicator_code = 'NY.GDP.PCAP.CD'
  AND l.indicator_code = 'SP.DYN.LE00.IN'
  AND g.year BETWEEN 2000 AND 2020;



-- 7) Income-group benchmarking
-- Compares a country’s indicator value against the average of its income group, showing whether it performs above or below peers.

-- 8) Composite “Development Score” (z-score)
-- Creates a single score by standardizing multiple indicators (z-scores) and averaging them; CO2 is inverted so lower emissions improve the score.

with stats as (
    select
        indicator_name,
        avg(indicator_value) as mean,
        STDDEV(indicator_value) as stddev
    from asia_data
    where 
       indicator_name in ( 
          'GDP per capita (constant 2015 US$)',
          'Life expectancy at birth, total (years)',
          'CO2 emissions (metric tons per capita)'
      )
    group by indicator_name
),

z_scores as (
    select
        a.country_name,
        a.indicator_name,
        (a.indicator_value - s.mean) / s.stddev as z
    from asia_data a
    join stats s on a.indicator_name = s.indicator_name
    where 
      a.indicator_name in (
          'GDP per capita (constant 2015 US$)',
          'Life expectancy at birth, total (years)',
          'CO2 emissions (metric tons per capita)'
      )
)
select
    country_name,
    avg(z) as country_z_score
from z_scores
group by country_name
order by country_z_score desc;





