-- This entire script takes 42 seconds and 584 msec to run completely.
-- Some of the queries are creating tables for the following queries to use.
-- These sql queries investigate a number of questions, "Which of the building amenities has the most checkins?",
-- "Whether there are any friends who have checked in together in that location?", 
-- and then "Where are other places in Melbourne where they have checked in as well?"

-- This query asks the first question, i.e. getting the number of checkins that were made in amenity buildings
-- This query's results returns the amenity building with the most number of checkins that have been made in it.
-- The building with the highest number of checkins is selected in later queries for further analysis.
-- The table that is created contains one row which contains the name of the amenity building, geometry, and the number of checkins made in 
-- that amenity building.
drop table if exists mneguib.amenity_building_with_max_checkins;
create table mneguib.amenity_building_with_max_checkins
as
select amenity, way, count(building_type) as number_of_checkins
from spatial.checkins_melbourne as mnc, (
select tags, tags->'name' as name, tags->'building' as building_type, tags->'amenity' as amenity, st_transform(way,4326) as way
from spatial.melbourne_osm_polygon
where tags?'building' and tags?'amenity'
) as mn
where ST_Intersects(geom, way)
group by amenity, way
order by number_of_checkins desc
limit 1;

-- The following queries investigate the checkins that have been made at the townhall which was found out to have the most number 
-- of checkins, unless specified in the comment above the query.

-- Townhall was found out to have the highest number of checkins so we decided to further investigate the checkins made in 
-- townhall. This query gets the trend of checkins for townhall over the years by day along with the number of checkins that were
-- made on that day. After plotting the results for this query a pattern was emerged, where on some days the number of checkins
-- was quite high as opposed to other days, so it might be interesting to see whether those checkins were made on a weekday or a weekend.
select date, count(id) as number_of_checkins from (	
select *,row_number() over() as id
from spatial.checkins_melbourne as mnc, (
select tags, tags->'name' as name, tags->'building' as building_type, tags->'amenity' as amenity, st_transform(way,4326) as way
from spatial.melbourne_osm_polygon 
where tags?'building' and tags?'amenity' and tags->'amenity' in (
select amenity from mneguib.amenity_building_with_max_checkins
)
) as mn
where ST_Intersects(geom, st_transform(way,4326))
) as day_of_week_nums
group by date
order by date asc;
					   
-- This query gets information about how many checkins were made on the weekday and on the weekend. This helps us further figure
-- out when people mostly visit the townhall, and we may even be able to guess whether it might be for business reasons or
-- for leisure reasons. The results of the query turned out that the majority of the checkins were made on the weekdays (54) and 
-- on the weekends only 14 were made. This is not surprising at all, because usually townhalls usually receive alot of visitors
-- for business reasons, but we can not be certain for sure. We have to now investigate the time of day the checkins were made in.					
select day_of_week, count(id) as number_of_checkins from (	
select *,row_number() over() as id, CASE
WHEN extract(dow from date )>=1 and extract(dow from date )<=5 THEN 'Weekday' 
ELSE 'Weekend'
END as day_of_week
from spatial.checkins_melbourne as mnc, (
select tags, tags->'name' as name, tags->'building' as building_type, tags->'amenity' as amenity, st_transform(way,4326) as way
from spatial.melbourne_osm_polygon 
where tags?'building' and tags?'amenity' and tags->'amenity' in (
select amenity from mneguib.amenity_building_with_max_checkins
)
) as mn
where ST_Intersects(geom, st_transform(way,4326))
) as day_of_week_nums
group by day_of_week
order by day_of_week asc;
										
-- The results of this query returned the number of checkins made at the time of day (Morning, Afternoon, Night) and
-- the day type (Weekday, Weekend). There were surprising results. Firstly it was expected that on a weekday in the morning the townhall
-- would see the most people as it is expected, but infact night on a weekday is the one with the most number of checkins (28). The checkins on
-- on the weekday in the morning come in second(24). It is quite possible to see that the townhall may be having functions/events at night or the people
-- might be going there just for leisure activities.					
select day_of_week||'-'||hour_type as day_of_type_hour_type, count(id) as number_of_checkins from (	
select *,row_number() over() as id, CASE
WHEN extract(dow from date )>=1 and extract(dow from date )<=5 THEN 'Weekday' 
ELSE 'Weekend'
END as day_of_week,
CASE 
WHEN extract(hour from time)>=0 and extract(hour from time)<=11 THEN 'Morning'
WHEN extract(hour from time)>=12 and extract(hour from time)<=15 THEN 'Afternoon'
WHEN extract(hour from time)>=16 and extract(hour from time)<=19 THEN 'Evening'	
WHEN extract(hour from time)>=20 and extract(hour from time)<=23 THEN 'Night'	
END as hour_type	
from spatial.checkins_melbourne as mnc, (
select tags, tags->'name' as name, tags->'building' as building_type, tags->'amenity' as amenity, st_transform(way,4326) as way
from spatial.melbourne_osm_polygon 
where tags?'building' and tags?'amenity' and tags->'amenity' in (
select amenity from mneguib.amenity_building_with_max_checkins
)
) as mn
where ST_Intersects(geom, st_transform(way,4326))
) as day_of_week_nums
group by day_of_week, hour_type
order by day_of_week, hour_type asc;					
					
-- This query finds a list of people who have made checkins and then gets the number of friends that they have in the table spatial.friends
-- and have also made checkins all over melbourne. This particular query was an exercise to just see how the friends table works.					
select user_id, count(user_id) as number_of_friends from (
select distinct user_id, friend_id
from spatial.checkins_melbourne as checkins,
(
select aid as user_id, bid as friend_id
from spatial.friends
where aid in (
select distinct uid
from spatial.checkins_melbourne as checkins
left join spatial.friends as friends
on checkins.uid=friends.aid
where checkins.uid!=friends.bid
order by uid
)
) as friends_checkins
where friends_checkins.user_id=checkins.uid
) as number_of_friends
group by user_id;

-- Next we wanted to find out among those people who checked in to the townhall and were friends with each other. 
-- This information can further tell us more about what kind of people who are checking in to the townhall. 
-- The query returns only two people who were friends and they are user 122796 and user 122797. Among the 
-- long list that we retrieved from the previous query only two people were found to be friends.
-- This is quite interesting and we want to find out more information about these two people. This query creates a table which is then 
-- used in the following queries.
drop table if exists mneguib.users_checked_in_with_friends;
create table mneguib.users_checked_in_with_friends
as					
select aid as user_id from spatial.friends,
(
select * from (
select * from (
select distinct uid as user_id
from spatial.checkins_melbourne as mnc, (
select tags, tags->'name' as name, tags->'building' as building_type, tags->'amenity' as amenity, st_transform(way,4326) as way
from spatial.melbourne_osm_polygon 
where tags?'building' and tags?'amenity' and tags->'amenity' in (
select amenity from mneguib.amenity_building_with_max_checkins
)
) as mn
where ST_Intersects(geom, st_transform(way,4326))
) as checkins_by_users,
(
select distinct uid as friend_id
from spatial.checkins_melbourne as mnc, (
select tags, tags->'name' as name, tags->'building' as building_type, tags->'amenity' as amenity, st_transform(way,4326) as way
from spatial.melbourne_osm_polygon 
where tags?'building' and tags?'amenity' and tags->'amenity' in (
select amenity from mneguib.amenity_building_with_max_checkins
)
) as mn
where ST_Intersects(geom, st_transform(way,4326))	
) as checkins_by_users1	
where checkins_by_users.user_id!=checkins_by_users1.friend_id
) as checkins_users
) as checkins
where user_id=aid and friend_id=bid;					
					
-- This query shows the friends who checked in at townhall and also shows the dates along with at what time of
-- the day (morning, afternoon, evening, or night) the check in was made. This query has been developed to see 
-- whether the two friends posted on the same days and around the same time or not.					
select uid, date,
CASE 
WHEN extract(hour from time)>=0 and extract(hour from time)<=11 THEN 'Morning'
WHEN extract(hour from time)>=12 and extract(hour from time)<=15 THEN 'Afternoon'
WHEN extract(hour from time)>=16 and extract(hour from time)<=19 THEN 'Evening'	
WHEN extract(hour from time)>=20 and extract(hour from time)<=23 THEN 'Night'	
END as hour_type					
from (
select uid, date, time, count(uid)
from spatial.checkins_melbourne as mnc, (
select tags, tags->'name' as name, tags->'building' as building_type, tags->'amenity' as amenity, st_transform(way,4326) as way
from spatial.melbourne_osm_polygon 
where tags?'building' and tags?'amenity' and tags->'amenity' in (
select amenity from mneguib.amenity_building_with_max_checkins
)
) as mn
where uid in (select * from mneguib.users_checked_in_with_friends)
and ST_Intersects(geom, st_transform(way,4326))
group by uid, date, time
order by date
) as checkins_by_friends;

-- This query tells us the number of times for the time of day(morning, afternoon, night) the two friends have checked in at the townhall.
-- It can be seen that 122797 has posted more than 122796 posted. This also tells us that the two friends did not checkin in the during the afternoon 
-- and the evening at the townhall. It looks like they must have gone to get some work done, and then also visit the townhall for some activities
-- which the townhall may be holding.				  
select uid, hour_type, count(hour_type) as number_of_times_checked_in from (
select uid, date,
CASE 
WHEN extract(hour from time)>=0 and extract(hour from time)<=11 THEN 'Morning'
WHEN extract(hour from time)>=12 and extract(hour from time)<=15 THEN 'Afternoon'
WHEN extract(hour from time)>=16 and extract(hour from time)<=19 THEN 'Evening'	
WHEN extract(hour from time)>=20 and extract(hour from time)<=23 THEN 'Night'	
END as hour_type					
from (
select uid, date, time, count(uid)
from spatial.checkins_melbourne as mnc, (
select tags, tags->'name' as name, tags->'building' as building_type, tags->'amenity' as amenity, st_transform(way,4326) as way
from spatial.melbourne_osm_polygon 
where tags?'building' and tags?'amenity' and tags->'amenity' in (
select amenity from mneguib.amenity_building_with_max_checkins
)
) as mn
where uid in (select * from mneguib.users_checked_in_with_friends)
and ST_Intersects(geom, st_transform(way,4326))
group by uid, date, time
order by date
) as checkins_by_friends
) as checkins_by_time_of_day
group by uid, hour_type
order by hour_type desc;					


-- This query gets the number of times the two friends have checked in different buildings. The results from this query tell us more 
-- about the kind of people these two might be. By knowing where a person goes, we can infer quite alot about that person.
select user_id, type_building_not_null, count(type_building_not_null) as num_checkins from (
select *, 
case 
when amenity is not null then amenity
when type_building is not null then type_building
end as type_building_not_null
from (
select * from(
select * 
from mneguib.users_checked_in_with_friends
join spatial.checkins_melbourne on uid=user_id
) as friends_checkins,
(
select tags, tags->'name' as name, tags->'building' as type_building, tags->'amenity' as amenity, st_transform(way,4326) as way
from spatial.melbourne_osm_polygon 
where tags?'building'	
) as melbourne_polygon
where ST_Intersects(geom,way)
) as checkins
) as num_checkins	
group by user_id, type_building_not_null
order by user_id;
	
-- This query gets the actual buildings where the two friends have checked in.
select user_id, date, time, geom as checkin_location, way as building, 
case 
when amenity is not null then amenity
when type_building is not null then type_building
end as type_building_not_null
from (
select * from(
select * 
from mneguib.users_checked_in_with_friends
join spatial.checkins_melbourne on uid=user_id
) as friends_checkins,
(
select tags, tags->'name' as name, tags->'building' as type_building, tags->'amenity' as amenity, st_transform(way,4326) as way
from spatial.melbourne_osm_polygon 
where tags?'building'	
) as melbourne_polygon
where ST_Intersects(geom,way)
) as checkins;

	
-- The following queries are analysing the trajectory of the the friend (122797) who also has made the most number of checkins
-- amongst the two friends whom we have been studying. Unfortunately due to limited space in the report, we have not 
-- given the results of this analysis in the report.
	
-- I am getting the friend who has made the most number of checkins amongs the two. I want to
-- study and analyse this person further.
drop table if exists mneguib.user_to_study_trajectory_of;
create table mneguib.user_to_study_trajectory_of
as	
select checkins.uid, count(checkins.uid) from mneguib.users_checked_in_with_friends as friends
join spatial.checkins_melbourne as checkins
on friends.user_id=checkins.uid 
group by checkins.uid
order by count(checkins.uid) desc
limit 1;

-- I am performing trajectory analysis on the user who has the most number of checkins in the checkins_melbourne table.
-- This analysis is in order to perform a technically advanced task, and also to understand how people move about the city.
-- Only get those days where more than one checkin was made. In order to be able to analysis we 
-- need atleast two checkins.
-- The table that is created returns the user id of the user and the date of the checkins where more than one checkin was made.
drop table if exists mneguib.checkins_of_user_with_most_more_than_one_per_day;
create table mneguib.checkins_of_user_with_most_more_than_one_per_day
as
select checkins.uid, checkins.date
from spatial.checkins_melbourne as checkins
join (select checkins.uid, count(checkins.uid) from mneguib.users_checked_in_with_friends as friends
join spatial.checkins_melbourne as checkins
on friends.user_id=checkins.uid 
group by checkins.uid
order by count(checkins.uid) desc
limit 1) as user_with_most
on checkins.uid=user_with_most.uid
group by checkins.uid, checkins.date
having count(checkins.date)>1;

-- This query is getting the details of the checkin for the user and the days that were retreieved and stored in a table
-- which is being used in this query and as a result a new table is being created which will be used later on.	
drop table if exists mneguib.more_than_one_checkins_per_day_of_most_user;
create table mneguib.more_than_one_checkins_per_day_of_most_user
as
select *,row_number() over() as id from (
select uid_checkins, poi_checkins, date_checkins, time_checkins, geom_checkins from (
select checkins.uid as uid_checkins, checkins.poi as poi_checkins, checkins.date as date_checkins, checkins.time as time_checkins, checkins.geom as geom_checkins
from spatial.checkins_melbourne as checkins
join mneguib.user_with_most_checkins as user_with_most
on checkins.uid=user_with_most.uid
) as checkins
join mneguib.checkins_of_user_with_most_more_than_one_per_day as checkins_of_user
on checkins.date_checkins=checkins_of_user.date
order by checkins.date_checkins, checkins.time_checkins asc
) as table1;

-- In this query i am calculating the distance travelled and the time it took in minutes between two consecutive checkins on the same day.
-- In order to join two consecutive rows together i am joining the rows for example row 1 with row 2, row 2 with row 3 and so on. This allows me to compare
-- the rows sequentially.																				 
select *, ST_Distance(t1.geom_checkins::geography, t2.geom_checkins::geography, true)/1000 as distance_km, ((EXTRACT(EPOCH FROM (t1.date_checkins ||' ' || t1.time_checkins)::timestamp) - EXTRACT(EPOCH FROM (t2.date_checkins ||' ' || t2.time_checkins)::timestamp))*-1)/60 as minutes
from mneguib.more_than_one_checkins_per_day_of_most_user as t1
join mneguib.more_than_one_checkins_per_day_of_most_user as t2
on t1.id+1=t2.id
where t1.date_checkins=t2.date_checkins;

-- This query is giving us information for each day such as total distance travelled in km, minutes travelled, and average speed in km per hour

select uid_checkins as user_id, date_checkins, sum(distance_km) as total_distance_km, sum(minutes) as minutes_travelled, avg(speed_km_per_hour) as average_speed_km_hour from (
select t1.uid_checkins, t1.date_checkins, ST_Distance(t1.geom_checkins::geography, t2.geom_checkins::geography, true)/1000 as distance_km, ((EXTRACT(EPOCH FROM (t1.date_checkins ||' ' || t1.time_checkins)::timestamp) - EXTRACT(EPOCH FROM (t2.date_checkins ||' ' || t2.time_checkins)::timestamp))*-1)/60 as minutes, (ST_Distance(t1.geom_checkins::geography, t2.geom_checkins::geography, true)/1000/((((EXTRACT(EPOCH FROM (t1.date_checkins ||' ' || t1.time_checkins)::timestamp) - EXTRACT(EPOCH FROM (t2.date_checkins ||' ' || t2.time_checkins)::timestamp))*-1)/60)/60)) as speed_km_per_hour
from mneguib.more_than_one_checkins_per_day_of_most_user as t1
join mneguib.more_than_one_checkins_per_day_of_most_user as t2
on t1.id+1=t2.id
where t1.date_checkins=t2.date_checkins
) as stats
group by uid_checkins, date_checkins
order by total_distance_km desc;

-- This table contains top 10 trajectories based on their length of user 122797
drop table if exists date_with_max_most_distance_travelled;
create table date_with_max_most_distance_travelled
as	
select uid_checkins as user_id, date_checkins, sum(distance_km) as total_distance_km, sum(minutes) as minutes_travelled, avg(speed_km_per_hour) as average_speed_km_hour
from (
select t1.uid_checkins, t1.date_checkins, ST_Distance(t1.geom_checkins::geography, t2.geom_checkins::geography, true)/1000 as distance_km, ((EXTRACT(EPOCH FROM (t1.date_checkins ||' ' || t1.time_checkins)::timestamp) - EXTRACT(EPOCH FROM (t2.date_checkins ||' ' || t2.time_checkins)::timestamp))*-1)/60 as minutes, (ST_Distance(t1.geom_checkins::geography, t2.geom_checkins::geography, true)/1000/((((EXTRACT(EPOCH FROM (t1.date_checkins ||' ' || t1.time_checkins)::timestamp) - EXTRACT(EPOCH FROM (t2.date_checkins ||' ' || t2.time_checkins)::timestamp))*-1)/60)/60)) as speed_km_per_hour
from mneguib.more_than_one_checkins_per_day_of_most_user as t1
join mneguib.more_than_one_checkins_per_day_of_most_user as t2
on t1.id+1=t2.id
where t1.date_checkins=t2.date_checkins
) as stats
group by uid_checkins, date_checkins
order by total_distance_km desc
limit 10;	
	
-- This table gets the checkin locations of the user 122797 based on the top 10 trajectories have been retrieved and
-- the aim of this table is to be able to generate a visualization map.	
drop table if exists trajectories;
create table trajectories
as	
select checkins.date, ST_MakeLine(geom) as trajectory_path
from date_with_max_most_distance_travelled as max_distance_travelled
join spatial.checkins_melbourne as checkins
on checkins.uid=max_distance_travelled.user_id and checkins.date=max_distance_travelled.date_checkins
group by checkins.date;
	
--drop table if exists mneguib.users_checked_in_with_friends;
--drop table if exists mneguib.amenity_building_with_max_checkins;
--drop table if exists mneguib.checkins_of_user_with_most_more_than_one_per_day;
--drop table if exists mneguib.more_than_one_checkins_per_day_of_most_user;					
--drop table if exists mneguib.user_to_study_trajectory_of;				