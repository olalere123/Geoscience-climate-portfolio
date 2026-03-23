SELECT project_status, COUNT(*) as project_count,
SUM(estimated_capacity) as total_capacity
FROM ccus
WHERE sector = 'Iron_and_steel'
GROUP BY project_status
ORDER BY project_count DESC;



SELECT DISTINCT region, COUNT(*) as projects
FROM ccus
WHERE region IS NOT NULL
GROUP BY region
ORDER BY projects DESC;


CREATE TABLE sector_emissions (
    sector VARCHAR(100),
    annual_co2_gt FLOAT,
    source VARCHAR(200),
    year_of_data INT
);

INSERT INTO sector_emissions VALUES
('Power_and_heat', 13.8, 
 'IEA CO2 Emissions 2024', 2024),
('Iron_and_steel', 2.6, 
 'IEA Iron and Steel Technology Roadmap', 2023),
('Cement', 1.6, 
 'IEA / WEF Cement Report', 2024),
('Chemicals', 0.94, 
 'IEA Chemicals Report', 2022),
('Natural_gas_processing_LNG', 0.245, 
 'IEA LNG Emissions Report', 2025),
('Hydrogen_or_ammonia', 0.92, 
 'IEA Global Hydrogen Review 2024', 2023);

SELECT 
    cc.sector,
    COUNT(cc.project_name) as ccus_projects,
    ROUND(SUM(cc.estimated_capacity)::numeric, 2) 
        as ccus_capacity_mt,
    se.annual_co2_gt as sector_emissions_gt,
    ROUND((100.0 * COUNT(cc.project_name) / 
          SUM(COUNT(cc.project_name)) OVER())::numeric, 2) 
        as pct_of_ccus_projects,
    ROUND((100.0 * se.annual_co2_gt / 
          SUM(se.annual_co2_gt) OVER())::numeric, 2) 
        as pct_of_global_emissions,
    ROUND((100.0 * se.annual_co2_gt / 
          SUM(se.annual_co2_gt) OVER() -
          100.0 * COUNT(cc.project_name) / 
          SUM(COUNT(cc.project_name)) OVER())::numeric, 2) 
        as coverage_gap
FROM ccus cc
INNER JOIN sector_emissions se ON cc.sector = se.sector
WHERE cc.sector NOT IN 
    ('Storage', 'T&S', 'Transport', 'TBD', 
     'Biofuels', 'Other_industry', 'DAC')
GROUP BY cc.sector, se.annual_co2_gt
ORDER BY coverage_gap DESC;


CREATE TABLE regional_emissions (
    region VARCHAR(100),
    annual_co2_gt FLOAT,
    pct_global_emissions FLOAT,
    source VARCHAR(200),
    year_of_data INT
);


INSERT INTO regional_emissions VALUES
('Other Asia Pacific', 18.184, 52.4, 
 'IEA Asia Pacific Regional Report', 2023),
('North America', 5.371, 15.48, 
 'IEA North America Regional Report', 2023),
('Europe', 3.347, 9.65, 
 'IEA Europe Regional Report', 2023),
('Eurasia', 2.208, 6.37, 
 'IEA Eurasia Regional Report', 2023),
('Middle East', 2.018, 5.82, 
 'IEA Middle East Regional Report', 2023),
('Africa', 1.100, 3.17, 
 'IEA Africa Energy Outlook', 2023),
('Central and South America', 1.085, 3.13, 
 'IEA Central & South America Regional Report', 2023),
('Australia and New Zealand', 0.383, 1.10, 
 'IEA Australia + New Zealand Regional Reports', 2023);



SELECT
    cc.region,
    COUNT(cc.project_name) as ccus_projects,
    ROUND(SUM(cc.estimated_capacity)::numeric, 2)
        as ccus_capacity_mt,
    re.annual_co2_gt as regional_emissions_gt,
    re.pct_global_emissions,
    ROUND((100.0 * COUNT(cc.project_name) /
          SUM(COUNT(cc.project_name)) OVER())::numeric, 2)
        as pct_of_ccus_projects,
    ROUND((100.0 * re.annual_co2_gt /
          SUM(re.annual_co2_gt) OVER())::numeric, 2)
        as pct_of_global_emissions_calculated,
    ROUND((100.0 * re.annual_co2_gt /
          SUM(re.annual_co2_gt) OVER() -
          100.0 * COUNT(cc.project_name) /
          SUM(COUNT(cc.project_name)) OVER())::numeric, 2)
        as coverage_gap,
    CASE
        WHEN COUNT(cc.project_name) >= 50 THEN 'Hub'
        WHEN COUNT(cc.project_name) BETWEEN 10 AND 49 THEN 'Emerging'
        ELSE 'Isolated'
    END as infrastructure_status
FROM ccus cc
INNER JOIN regional_emissions re ON cc.region = re.region
WHERE cc.region NOT IN ('Unknown')
GROUP BY cc.region, re.annual_co2_gt, re.pct_global_emissions
ORDER BY coverage_gap DESC;



SELECT
    cc.region,
    COUNT(*) as projects,
    re.annual_co2_gt as emissions_gt,
    CASE
        WHEN COUNT(*) >= 50 THEN 'Hub'
        WHEN COUNT(*) BETWEEN 10 AND 49 THEN 'Emerging'
        ELSE 'Isolated'
    END as infrastructure_status,
    CASE
        WHEN re.annual_co2_gt >= 5.0 THEN 'Heavy Emitter'
        WHEN re.annual_co2_gt BETWEEN 1.0 AND 4.9 THEN 'Moderate Emitter'
        ELSE 'Light Emitter'
    END as emission_category
FROM ccus cc
INNER JOIN regional_emissions re ON cc.region = re.region
WHERE cc.region NOT IN ('Unknown')
GROUP BY cc.region, re.annual_co2_gt
ORDER BY re.annual_co2_gt DESC;
 

SELECT
    project_status,
    COUNT(*) as projects,
    ROUND(SUM(estimated_capacity)::numeric, 2)
        as total_capacity_mt
FROM ccus
WHERE operation <= 2030
AND operation IS NOT NULL
AND project_status NOT IN ('Cancelled', 'Decommissioned')
GROUP BY project_status
ORDER BY total_capacity_mt DESC;


SELECT 
    cc.sector,
    COUNT(cc.project_name) as operational_projects,
    ROUND(SUM(cc.estimated_capacity)::numeric, 2)
        as operational_capacity_mt,
    se.annual_co2_gt as sector_emissions_gt,
    ROUND((100.0 * SUM(cc.estimated_capacity) /
          (se.annual_co2_gt * 1000))::numeric, 4)
        as capacity_as_pct_of_emissions
FROM ccus cc
INNER JOIN sector_emissions se ON cc.sector = se.sector
WHERE cc.project_status = 'Operational'
AND cc.sector NOT IN 
    ('Storage', 'T&S', 'Transport', 'TBD',
     'Biofuels', 'Other_industry', 'DAC')
GROUP BY cc.sector, se.annual_co2_gt
ORDER BY capacity_as_pct_of_emissions ASC;

SELECT
    COUNT(*) as total_fid_projects,
    SUM(CASE WHEN project_status = 'Operational'
        THEN 1 ELSE 0 END) as became_operational,
    ROUND((100.0 * SUM(CASE WHEN project_status = 'Operational'
        THEN 1 ELSE 0 END) / COUNT(*))::numeric, 2)
        as fid_to_operation_success_rate
FROM ccus
WHERE fid IS NOT NULL;


select sector,
       fate_of_carbon,
	   count(*) as project_count,
	   ROUND(sum(estimated_capacity)::numeric, 2) as total_capacity
From ccus
Where sector IN ('Cement', 'Iron and Steel','Chemicals')
AND fate_of_carbon IN ('EOR','Dedicated storage')
Group by sector, fate_of_carbon
order by sector, total_capacity Desc;