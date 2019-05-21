-- These sql queries investigate a number of questions, "Which of the building amenities has the most checkins?", "Whether there are any friends who have checked in together in that location?", and then "Where are other places in Melbourne where they have checked in as well?"

-- This query asks the first question, i.e. getting the number of checkins that were made in amenity buildings.
drop table if exists amenity_building_with_max_checkins;
create table amenity_building_with_max_checkins
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

-- Get the trend of checkins for the building amenity with the most number of check ins over the years. Then find numbers for the time of day stats, and day of type stats.
select date, count(id) as number_of_checkins from (	
select *,row_number() over() as id, CASE 
WHEN extract(hour from time)>=0 and extract(hour from time)<=11 THEN 'Morning'
WHEN extract(hour from time)>=12 and extract(hour from time)<=15 THEN 'Afternoon'
WHEN extract(hour from time)>=16 and extract(hour from time)<=19 THEN 'Evening'	
WHEN extract(hour from time)>=20 and extract(hour from time)<=23 THEN 'Night'	
END as hour_type 
from spatial.checkins_melbourne as mnc, (
select tags, tags->'name' as name, tags->'building' as building_type, tags->'amenity' as amenity, st_transform(way,4326) as way
from spatial.melbourne_osm_polygon 
where tags?'building' and tags?'amenity' and tags->'amenity' in (
select amenity from amenity_building_with_max_checkins
)
) as mn
where ST_Intersects(geom, st_transform(way,4326))
) as day_of_week_nums
group by date
order by date asc;
					   
-- Get the trend of checkins for the building amenity with the most number of check ins over the years over the years. Then find numbers for the time of day stats, and day of type stats.

select day_of_week, count(id) as number_of_checkins from (	
select *,row_number() over() as id, CASE
WHEN extract(dow from date )>=1 and extract(dow from date )<=5 THEN 'Weekday' 
ELSE 'Weekend'
END as day_of_week
from spatial.checkins_melbourne as mnc, (
select tags, tags->'name' as name, tags->'building' as building_type, tags->'amenity' as amenity, st_transform(way,4326) as way
from spatial.melbourne_osm_polygon 
where tags?'building' and tags?'amenity' and tags->'amenity' in (
select amenity from amenity_building_with_max_checkins
)
) as mn
where ST_Intersects(geom, st_transform(way,4326))
) as day_of_week_nums
group by day_of_week
order by day_of_week asc;
					
					
-- I want to find out what the time of day was for the check ins.				
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
select amenity from amenity_building_with_max_checkins
)
) as mn
where ST_Intersects(geom, st_transform(way,4326))
) as day_of_week_nums
group by day_of_week, hour_type
order by day_of_week, hour_type asc;					
					
-- This query gets the number of friends for each user who have posted a checkin.
select user_id, count(user_id) from (
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

-- This query gets those people who had checked in the most popular amenity building and were also friends. This query is also creating a table of the results 
-- which is then used in later queries.
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
select amenity from amenity_building_with_max_checkins
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
select amenity from amenity_building_with_max_checkins
)
) as mn
where ST_Intersects(geom, st_transform(way,4326))	
) as checkins_by_users1	
where checkins_by_users.user_id!=checkins_by_users1.friend_id
) as checkins_users
) as checkins
where user_id=aid and friend_id=bid;					
					
-- This query shows the friends who checked in at the building amenity with the most number of check ins over the years and also shows the dates along with at what time of the day (morning, afternoon, evening, or night)
-- the check in was made. This query has been developed to see whether the two friends posted on the same days and around the same time or not.
-- This results from this query are not being used in any other queries.					
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
select amenity from amenity_building_with_max_checkins
)
) as mn
where uid in (select * from mneguib.users_checked_in_with_friends)
group by uid, date, time
order by date
) as checkins_by_friends;	
					

-- This query gets the buildings where ever the friends have checked in along with the number of times they have checked in there as well.
-- The final result of this will be a map of locations(buildings) where the friends have checked in.
select uid, 
case when name is null then 'N/A'
else name
end
, building_type, count(*),
way, geom
from (
select *
from (
select *
from 
spatial.checkins_melbourne
where uid in(
select aid as user_id from spatial.friends,
(
select * from (
select * from (
select distinct uid as user_id
from spatial.checkins_melbourne as mnc, (
select tags, tags->'name' as name, tags->'building' as building_type, tags->'amenity' as amenity, st_transform(way,4326) as way
from spatial.melbourne_osm_polygon 
where tags?'building' and tags?'amenity' and tags->'amenity' in (
select amenity from amenity_building_with_max_checkins
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
select amenity from amenity_building_with_max_checkins
)
) as mn
where ST_Intersects(geom, st_transform(way,4326))	
) as checkins_by_users1	
where checkins_by_users.user_id!=checkins_by_users1.friend_id
) as checkins_users
) as checkins
where user_id=aid and friend_id=bid)
) checkins_of_townhall_friends,
(
select tags, tags->'name' as name, tags->'building' as building_type, tags->'amenity' as amenity, st_transform(way,4326) as way
from spatial.melbourne_osm_polygon 
--where tags?'building'	
) as polygons	
where ST_Intersects(geom, way)
) type_buildings_checked_in	
group by uid, name, building_type, way, geom
order by count(*) desc;					
					
drop table if exists mneguib.users_checked_in_with_friends;
drop table if exists amenity_building_with_max_checkins;
					
				