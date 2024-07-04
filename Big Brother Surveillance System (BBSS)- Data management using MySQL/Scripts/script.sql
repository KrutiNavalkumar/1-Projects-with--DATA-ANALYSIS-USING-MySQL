USE G3T9;

#Question 1:
SET @sd = '2021-01-01';
SET @ed = '2022-12-31';

WITH photos AS (
SELECT *
FROM photo WHERE datetime BETWEEN @sd AND @ed
), 
related_pois AS (
SELECT a.photoid, d.name AS poi1name, e.name AS poi2name, c.description 
FROM photopoi a JOIN photopoi b ON a.photoid = b.photoid AND a.poiid <> b.poiid
JOIN poirelation c ON a.poiid = c.poi1 AND b.poiid = c.poi2 
JOIN poi d ON d.id = a.poiid 
JOIN poi e ON e.id = b.poiid
) 
SELECT a.id AS `Photo ID`, a.DateTime, b.poi1name AS `POI 1 Name`, b.poi2name AS `POI 2 Name`, b.description AS Relationship,
CASE 
WHEN a.dronecamnum IS NOT NULL THEN 'Drone'
WHEN a.camerasn IS NOT NULL THEN 'Camera'
END AS `Taken By`
FROM photos a JOIN related_pois b ON a.id = b.photoid;

#Question 2
SET @drone_id = 17;
SELECT 
a.id AS `Mission Id`,
b.operatoreid AS `Operator EID`,
b.piloteid AS `Pilot EID`,
a.startdatetime AS `Start DateTime`,
a.enddatetime AS `End DateTime`,
d.id AS `Tracker ID`
FROM mission a JOIN dronegroup b ON a.id = b.id
JOIN grpdrones c ON b.id = c.id AND b.operatoreid = c.operatoreid AND b.piloteid = c.piloteid
JOIN tracker d ON c.droneid = d.droneid
WHERE 
c.droneid = @drone_id
AND 
(
d.assigndate <= CAST(a.startdatetime AS DATE) AND d.disposedate >= CAST(a.startdatetime AS DATE) -- Tracker assigned before mission period and not disposed before mission start date
OR d.assigndate BETWEEN CAST(a.startdatetime AS DATE) AND CAST(a.enddatetime  AS DATE)-- Tracker assigned within mission period
)
ORDER BY 
a.startdatetime;

#Question 3
WITH y AS (
SELECT piloteid, count(distinct id) AS count FROM dronegroup GROUP BY piloteid 
),
z AS (
SELECT piloteid, count(id) AS count FROM grpdrones GROUP BY piloteid
),
stats AS (
SELECT y.piloteid, (5 * y.count + z.count) AS score from y JOIN z ON y.piloteid = z.piloteid
), 
topxscore AS (
SELECT DISTINCT score FROM stats ORDER BY score DESC LIMIT 4
) 
SELECT piloteid AS `Pilot EID`, score AS `5Y + Z` FROM stats 
WHERE score IN (SELECT score FROM topxscore)
ORDER BY score DESC;

#Question 5
DELIMITER $$
CREATE PROCEDURE Mission_Report(IN mission_id INT)
BEGIN
	DECLARE start_date_time DATETIME;
    DECLARE end_date_time DATETIME;
    DECLARE mission_desc VARCHAR(100);
    DECLARE num_drone_groups INT;
    DECLARE num_cat3_agents INT;
    DECLARE num_cat12_agents INT;
    DECLARE num_drones INT;
    DECLARE num_drone_cameras INT;
    DECLARE num_photos_with_pois INT;
    
    SELECT startdatetime, enddatetime, description INTO start_date_time, end_date_time, mission_desc 
    FROM mission WHERE id = mission_id;
    
    SELECT COUNT(*) INTO num_drone_groups FROM dronegroup WHERE id = mission_id;

	WITH t1 AS (SELECT * FROM dronegroup WHERE id =mission_id)
	SELECT COUNT(distinct eid) INTO num_cat3_agents FROM agent a JOIN t1 ON (t1.operatoreid = a.eid OR t1.piloteid = a.eid) AND a.securityclearance = 3 ; 

	WITH t1 AS (SELECT * FROM dronegroup WHERE id =mission_id)
	SELECT COUNT(distinct eid) INTO num_cat12_agents FROM agent a JOIN t1 ON (t1.operatoreid = a.eid or t1.piloteid = a.eid) AND a.securityclearance IN (1,2) ; 

	SELECT COUNT(distinct droneid) INTO num_drones FROM grpdrones WHERE id=mission_id; 

	SELECT COUNT(distinct number) INTO num_drone_cameras FROM grpdrones a JOIN drone b ON a.droneid = b.id AND a.id = mission_id JOIN dronecamera c ON b.id = c.id ;

	SELECT COUNT(DISTINCT e.photoid) INTO num_photos_with_pois FROM grpdrones a JOIN drone b ON a.droneid = b.id AND a.id = mission_id JOIN dronecamera c ON b.id = c.id 
	JOIN photo d ON c.id = d.droneid AND c.number = d.dronecamnum 
	JOIN photopoi e ON e.photoid = d.id;
    
    SELECT start_date_time AS `Mission StartTime`,
		end_date_time AS `Mission EndTime`,
		mission_desc AS `Description`,
		num_drone_groups AS `Num Drone Groups`,
		num_cat3_agents AS `Num Cat3 Agents`,
		num_cat12_agents AS `Num Cat12 Agents`,
		num_drones AS `Num of drones`,
		num_drone_cameras AS `Num of drone cameras`,
		num_photos_with_pois AS `Number of photos WITH POIs`;
     
END$$
DELIMITER ;

call Mission_Report(1);

#Question 6
SET @y1 = '2020';
SET @m1 = '01';
SET @y2 = '2020';
SET @m2 = '12';

WITH t1 AS (
SELECT a.eid, b.operatoreid, b.piloteid, COALESCE(TIMESTAMPDIFF(minute, c.startdatetime, c.enddatetime), 0) AS timediff_minutes
FROM agent a
LEFT JOIN dronegroup b 
ON a.eid = b.piloteid OR a.eid = b.operatoreid
LEFT JOIN mission c 
ON b.id = c.id
AND DATE_FORMAT(c.startdatetime, '%Y-%m') BETWEEN  CONCAT(@y1, '-', @m1) AND CONCAT(@y2, '-', @m2)
),
t2 AS (
SELECT eid, SUM(CASE WHEN eid = operatoreid THEN timediff_minutes ELSE 0 END) AS operator_sum, SUM(CASE WHEN eid = piloteid THEN timediff_minutes ELSE 0 END) AS pilot_sum
FROM t1 GROUP BY eid
)
SELECT eid,
CASE WHEN operator_sum = 0 AND pilot_sum <> 0 THEN 'NA' ELSE operator_sum END AS operator_credits,
CASE WHEN pilot_sum = 0 AND operator_sum <> 0 THEN 'NA' ELSE pilot_sum END AS pilot_credits
FROM t2;
