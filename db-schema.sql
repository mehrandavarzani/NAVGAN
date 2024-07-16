--
-- PostgreSQL database dump
--

-- Dumped from database version 10.15 (Ubuntu 10.15-0ubuntu0.18.04.1)
-- Dumped by pg_dump version 10.14 (Ubuntu 10.14-1.pgdg18.04+1)

-- Started on 2021-04-29 11:46:31 +0430

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 14 (class 2615 OID 19617)
-- Name: api; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA api;


--
-- TOC entry 16 (class 2615 OID 21713)
-- Name: data; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA data;


--
-- TOC entry 1 (class 3079 OID 13004)
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- TOC entry 7600 (class 0 OID 0)
-- Dependencies: 1
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


--
-- TOC entry 2 (class 3079 OID 19620)
-- Name: postgis; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS postgis WITH SCHEMA public;


--
-- TOC entry 7601 (class 0 OID 0)
-- Dependencies: 2
-- Name: EXTENSION postgis; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION postgis IS 'PostGIS geometry, geography, and raster spatial types and functions';


--
-- TOC entry 1019 (class 1255 OID 21714)
-- Name: alarm_count(integer, date, date); Type: FUNCTION; Schema: data; Owner: -
--

CREATE FUNCTION data.alarm_count(input_sensor_id integer, from_date date, to_date date) RETURNS json
    LANGUAGE plpgsql
    AS $$
DECLARE
	result json default null;
	sensor_type char(2);
BEGIN

	if input_sensor_id is not null then

		select type into sensor_type from api.core_sensor where id=input_sensor_id;

		if sensor_type='th' then
			result=json_build_object(
				'temperature_min_alarm_count',
				data.temperature_min_alarm_count(input_sensor_id,from_date,to_date),
				'temperature_max_alarm_count',
				data.temperature_max_alarm_count(input_sensor_id,from_date,to_date),
				'humidity_min_alarm_count',
				data.humidity_min_alarm_count(input_sensor_id,from_date,to_date),
				'humidity_max_alarm_count',
				data.humidity_max_alarm_count(input_sensor_id,from_date,to_date)
				);
		elseif sensor_type='t' then
			result=json_build_object(
				'temperature_min_alarm_count',
				data.temperature_min_alarm_count(input_sensor_id,from_date,to_date),
				'temperature_max_alarm_count',
				data.temperature_max_alarm_count(input_sensor_id,from_date,to_date)
			);
		end if;
	end if;
	return result;
END;
$$;


--
-- TOC entry 936 (class 1255 OID 21715)
-- Name: alarm_count_sum(integer, date, date); Type: FUNCTION; Schema: data; Owner: -
--

CREATE FUNCTION data.alarm_count_sum(input_sensor_id integer, from_date date, to_date date) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
	result int default 0;
	sensor_type char(2);
BEGIN
	if input_sensor_id is not null then
		
		select type into sensor_type from api.core_sensor where id=input_sensor_id;
		
		if sensor_type='th' then
			
			result=data.temperature_min_alarm_count(input_sensor_id,from_date,to_date)+
				data.temperature_max_alarm_count(input_sensor_id,from_date,to_date)+
				data.humidity_min_alarm_count(input_sensor_id,from_date,to_date)+
				data.humidity_max_alarm_count(input_sensor_id,from_date,to_date);
		
		elsif sensor_type='t' then
			
			result=data.temperature_min_alarm_count(input_sensor_id,from_date,to_date)+
				data.temperature_max_alarm_count(input_sensor_id,from_date,to_date);
		
		end if;
		
	end if;
	return result;
END;
$$;


--
-- TOC entry 931 (class 1255 OID 21716)
-- Name: alarms(text, date, date); Type: FUNCTION; Schema: data; Owner: -
--

CREATE FUNCTION data.alarms(sensor_ids text, from_date date, to_date date) RETURNS json
    LANGUAGE plpgsql
    AS $$
DECLARE
	_id int;
	result json default '[]'::json;
BEGIN
	SET TIMEZONE='Asia/Tehran';
	drop table if exists sensor_ids_temp_table;
	create temp table sensor_ids_temp_table(
		id int
	);
	foreach _id in array string_to_array(sensor_ids,',')
	loop
		insert into sensor_ids_temp_table (id) values(_id);
 	end loop;
	select json_agg(
			row_to_json(
				(select cname from(
					 select p.name as province,u.name as university,
					 c.name as center,w.name as warehouse,r.name as room,
					 s.name as sensor,s.type as sensor_type,
					 case
					     when s.type='th' then
							 json_build_object(
								'temperature_max',data.temperature_max_alarm(s.id,from_date,to_date),
								'temperature_min',data.temperature_min_alarm(s.id,from_date,to_date),
								'humidity_max',data.humidity_max_alarm(s.id,from_date,to_date),
								'humidity_min',data.humidity_min_alarm(s.id,from_date,to_date)
							 )
				 	 	 when s.type='t' then
							 json_build_object(
								'temperature_max',data.temperature_max_alarm(s.id,from_date,to_date),
								'temperature_min',data.temperature_min_alarm(s.id,from_date,to_date)
							 )
				 	 end as alarms)as cname
				 )
			)
		) into result
	from api.core_province p
	left join api.core_university u on p.id=u.province_id
	left join api.core_center c on u.id=c.university_id
	left join api.core_warehouse w on c.id=w.center_id
	left join api.core_room r on w.id=r.warehouse_id
	left join api.core_sensor s on r.id=s.room_id
	right join sensor_ids_temp_table si on si.id=s.id;
		
	return result;
END;
$$;


--
-- TOC entry 949 (class 1255 OID 21717)
-- Name: alarms_report(integer, date, date); Type: FUNCTION; Schema: data; Owner: -
--

CREATE FUNCTION data.alarms_report(input_sensor_id integer, from_date date, to_date date) RETURNS json
    LANGUAGE plpgsql
    AS $_$

DECLARE
    start_rec RECORD;
	mid_rec RECORD;
	end_rec RECORD;
	last_rec RECORD;
	sensor_rec RECORD;
	table_rec RECORD;
	_province text;
	_university text;
	_center text;
	_warehouse text;
	_room text;
	_sensor text;
	_sensor_id char(8);
	_room_id char(8);
	_warehouse_id char(8);
	q text;
	result json;
	timediff time;
	inserted boolean;
	is_first boolean default true;
	is_single boolean default false;
	sum_humidity double precision default 0;
	counter int default 0;
	max_humidity double precision default 0;
	is_in_alarm boolean default false;
BEGIN
	set timezone='Asia/Tehran';
	if input_sensor_id is null then
 		return null;
	end if;
	
	select into _sensor,_room,_warehouse,_center,_university,
	_province,_sensor_id,_room_id,_warehouse_id
	s.name,r.name,w.name,c.name,u.name,p.name,s.sensor_id,
	r.room_id,w.warehouse_id
	from api.core_province p
	left join api.core_university u on u.province_id=p.id
	left join api.core_center c on c.university_id=u.id
	left join api.core_warehouse w on w.center_id=c.id
	left join api.core_room r on w.id=r.warehouse_id
	left join api.core_sensor s on r.id=s.room_id
	where s.id=input_sensor_id;
	
	if _sensor_id is null or _room_id is null or _warehouse_id is null then
		return null;
	end if;
	
	drop table if exists alarms_report_temp_table;
	CREATE TEMPORARY TABLE alarms_report_temp_table(
		
		date date,
		start_time time,
		end_time time,
		duration time,
		mean float,
		max float,
		is_done boolean
	);
	

	FOR table_rec IN select created,table_name from data.tables where 
					created between from_date AND to_date
	LOOP
		EXECUTE('select w.name as warehouse_name,r.name as room_name,
				s.name as sensor_name,s.hum_max_val,s.allowed_hum_max_violation_time
				from api.core_warehouse w
				left join api.core_room r on w.id=r.warehouse_id
				left join api.core_sensor s on r.id=s.room_id') into sensor_rec;
		q='SELECT longitude,latitude,humidity,log_date_time
		FROM data.'||table_rec.table_name||'
		where branch_id=$1 and room_id=$2 and sensor_id=$3 
		order by log_date_time';
		EXECUTE(CONCAT(q,' asc limit 1')) into start_rec
		using _warehouse_id,_room_id,_sensor_id;
		EXECUTE(CONCAT(q,' desc limit 1')) into last_rec
		using _warehouse_id,_room_id,_sensor_id;
		mid_rec = start_rec;
		inserted = false;
		FOR end_rec IN EXECUTE(q) using _warehouse_id,_room_id,_sensor_id
		LOOP
			if end_rec.humidity > sensor_rec.hum_max_val
			then
				sum_humidity = sum_humidity + end_rec.humidity;
				counter = counter + 1;
				if end_rec.humidity>max_humidity then
					max_humidity = end_rec.humidity;
				end if;
				if is_first then
					start_rec = end_rec;
					mid_rec = end_rec;
					is_first = false;
					is_single = true;
				else
					mid_rec=end_rec;
					is_single = false;
					inserted = false;
				end if;
				if end_rec<>last_rec then
					continue;
				end if;
			end if;
			if (start_rec.log_date_time::time<mid_rec.log_date_time::time) or is_single then
				if is_single then
					mid_rec = end_rec;
				end if;
				if last_rec=mid_rec then
					if table_rec.created=now()::date then
						is_in_alarm = true;
					end if;
				end if;
				timediff =  mid_rec.log_date_time - start_rec.log_date_time;
				if extract(EPOCH from (timediff))>sensor_rec.allowed_hum_max_violation_time then
					insert into humidity_max_alarm_temp_table(
						warehouse_id,warehouse_name,room_id,room_name,
					 	sensor_id,sensor_name,start_lon,start_lat,end_lon,
						end_lat,date,start_time,end_time,duration,mean,max,is_done
					)values (
						_warehouse_id,sensor_rec.warehouse_name,
						_room_id,sensor_rec.room_name,
						_sensor_id,sensor_rec.sensor_name,
						start_rec.longitude,start_rec.latitude,
						mid_rec.longitude,mid_rec.latitude,
						mid_rec.log_date_time::date,
						start_rec.log_date_time::time,
						mid_rec.log_date_time::time,
						(mid_rec.log_date_time-start_rec.log_date_time)::time,
						round((sum_humidity/counter)::numeric,2),max_humidity,
						not is_in_alarm
					);
					max_humidity = 0;
					sum_humidity = 0;
					counter = 0;
				end if;
				inserted = true;
				is_first = true;
				is_single = false;
				is_in_alarm = false;
			end if;
			start_rec = end_rec;
			mid_rec = end_rec;
		END LOOP;
		if not inserted then
			if (start_rec.log_date_time::time<mid_rec.log_date_time::time) or is_single then
				if is_single then
					mid_rec = end_rec;
				end if;
				if last_rec=mid_rec then
					if table_rec.created=now()::date then
						is_in_alarm = true;
					end if;
				end if;
				timediff =  mid_rec.log_date_time - start_rec.log_date_time;
				if extract(EPOCH from (timediff))>sensor_rec.allowed_hum_max_violation_time then
					insert into humidity_max_alarm_temp_table(
						warehouse_id,warehouse_name,room_id,room_name,
						sensor_id,sensor_name,start_lon,start_lat,end_lon,
						end_lat,date,start_time,end_time,duration,mean,max,is_done
					)values (
						_warehouse_id,sensor_rec.warehouse_name,
						_room_id,sensor_rec.room_name,
						_sensor_id,sensor_rec.sensor_name,
						start_rec.longitude,start_rec.latitude,
						mid_rec.longitude,mid_rec.latitude,
						mid_rec.log_date_time::date,
						start_rec.log_date_time::time,
						mid_rec.log_date_time::time,
						(mid_rec.log_date_time-start_rec.log_date_time)::time,
						round((sum_humidity/counter)::numeric,2),max_humidity,
						not is_in_alarm
					);
					inserted = true;
				end if;
			end if;
		end if;
	END LOOP;
	
	select json_agg(
		row_to_json(
		(select cname from(select warehouse_name,warehouse_id,room_name,
						   room_id,sensor_name,sensor_id,start_lon,
						   start_lat,end_lon,end_lat,date,start_time,end_time,
						   duration,mean,max,is_done) as cname)
		)
	) into result
	from humidity_max_alarm_temp_table;
	return result;
END;
$_$;


--
-- TOC entry 930 (class 1255 OID 21719)
-- Name: all_alarms(integer, date, date, time without time zone, time without time zone); Type: FUNCTION; Schema: data; Owner: -
--

CREATE FUNCTION data.all_alarms(input_sensor_id integer, from_date date, to_date date, from_time time without time zone DEFAULT '00:00:00'::time without time zone, to_time time without time zone DEFAULT '23:59:59'::time without time zone) RETURNS json
    LANGUAGE plpgsql
    AS $$
DECLARE
	result json default '[]';
	sensor_type char(2);
BEGIN
	set timezone='Asia/Tehran';
	if input_sensor_id is null then
 		return null;
	end if;
	
	select type into sensor_type from api.core_sensor where id=input_sensor_id;
	if sensor_type='th' then
		select json_agg(p) from (
			select json_build_object(
				'date',t.date,
				'start_time',t.start_time,
				'alarms',
					json_agg(
						row_to_json(
							(select cname from 
								(select type,date,start_time,end_time,duration,
								 start_lon,start_lat,end_lon,end_lat,humidity,
								 temperature,mean,max,min,is_done 
								) as cname))
					)
				) p into result
				from(
					select * from data.hmin_alarm_report(input_sensor_id,from_date,to_date,from_time,to_time)
					union
					select * from data.hmax_alarm_report(input_sensor_id,from_date,to_date,from_time,to_time)
					union
					select * from data.tmin_alarm_report(input_sensor_id,from_date,to_date,from_time,to_time)
					union
					select * from data.tmax_alarm_report(input_sensor_id,from_date,to_date,from_time,to_time)
				) t
				group by t.date,t.start_time
				order by t.date,t.start_time
		) p;
	elsif sensor_type='t' then
		select json_agg(p) from (
			select json_build_object(
				'date',t.date,
				'start_time',t.start_time,
				'alarms',
					json_agg(
						row_to_json(
							(select cname from 
								(select type,date,start_time,end_time,duration,
								 start_lon,start_lat,end_lon,end_lat,
								 temperature,mean,max,min,is_done 
								) as cname))
					)
				) p into result
				from(
					select * from data.tmin_alarm_report(input_sensor_id,from_date,to_date,from_time,to_time)
					union
					select * from data.tmax_alarm_report(input_sensor_id,from_date,to_date,from_time,to_time)
				) t
				group by t.date,t.start_time
				order by t.date,t.start_time
		) p;
	end if;
	return result;
END;
$$;


--
-- TOC entry 889 (class 1255 OID 21720)
-- Name: approximate_in_iran(double precision, double precision); Type: FUNCTION; Schema: data; Owner: -
--

CREATE FUNCTION data.approximate_in_iran(longitude double precision, latitude double precision) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
	
DECLARE
	iran geometry(polygon);
	result boolean;
BEGIN
	iran = st_makepolygon('LINESTRING(48.49365234375 29.897805610155874,47.61474609375 31.39115752282472,47.87841796875 31.784216884487385,47.3291015625 32.52828936482526,46.05468749999999 33.04550781490999,45.439453125 34.615126683462194,46.23046874999999 35.29943548054545,46.021728515625 35.71083783530009,46.3623046875 35.808904044068626,45.32958984374999 35.98689628443789,44.23095703125 37.92686760148135,44.4287109375 38.324420427006544,43.9892578125 39.40224434029275,44.62646484375 39.740986355883564,45.59326171875 38.94232097947902,46.58203125 38.87392853923629,47.98828124999999 39.690280594818034,48.40576171875 39.35129035526705,48.18603515625 39.21523130910491,48.31787109375 38.94232097947902,47.96630859375 38.805470223177466,48.88916015625 38.44498466889473,49.0869140625 37.50972584293751,50.25146484375 37.33522435930639,54.140625 36.79169061907076,53.96484375 37.33522435930639,54.7998046875 37.43997405227057,54.7998046875 37.70120736474139,55.74462890625 38.16911413556086,56.31591796875 38.048091067457236,56.84326171875 38.272688535980976,59.45800781249999 37.49229399862877,61.19384765625 36.54494944148322,60.77636718749999 34.470335121217474,61.04003906249999 34.34343606848294,60.57861328125 34.288991865037524,60.53466796874999 33.55970664841198,60.97412109375 33.55970664841198,60.55664062499999 33.100745405144245,60.8642578125 31.50362930577303,61.787109375 31.353636941500987,61.87499999999999 30.826780904779774,60.88623046875001 29.80251790576445,61.80908203125 28.555576049185973,62.75390625 28.285033294640684,62.7978515625 27.235094607795503,63.369140625 27.196014383173306,63.21533203124999 26.588527147308614,61.94091796875 26.23430203240673,61.65527343749999 25.105497373014686,57.2607421875 25.799891182088334,56.66748046875 27.196014383173306,55.74462890625 26.293415004265796,52.6904296875 26.54922257769204,49.9658203125 30.164126343161097,48.88916015625 30.334953881988564,48.988037109375 30.066716983885613,48.6749267578125 30.012030680358613,48.69140625 29.916852233070173,48.49365234375 29.897805610155874)');
	result=st_within(st_makepoint(longitude,latitude),iran);
	return result;
END;
$$;


--
-- TOC entry 922 (class 1255 OID 2145726)
-- Name: check_last_status(); Type: FUNCTION; Schema: data; Owner: -
--

CREATE FUNCTION data.check_last_status() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
	last_rec RECORD;
	last_rec_exists boolean default false;
	snsr_id int default null;
BEGIN
SET TIMEZONE='Asia/Tehran';
	if NEW.sensor_type='02' then
		if not data.is_inside_iran(NEW.longitude,NEW.latitude) then
			return null;
		end if;
	end if;
	select into snsr_id s.id
	from api.core_warehouse w left join
	api.core_room r on w.id=r.warehouse_id left join
	api.core_sensor s on r.id=s.room_id
	where w.warehouse_id=NEW.branch_id and
	r.room_id = NEW.room_id and
	s.sensor_id=NEW.sensor_id;
	if snsr_id is null then
		return null;
	end if;
	if NEW.longitude is not null and NEW.latitude is not null then
		if not data.approximate_in_iran(NEW.longitude,NEW.latitude) then
			return null;
		end if;
	end if;

	select into last_rec_exists exists(select 1 from data.sensor_last_data
	where sensor_id=snsr_id and last_log_date_time::date=NEW.log_date_time::date);
	if last_rec_exists then
		select * into last_rec from data.sensor_last_data
		where sensor_id=snsr_id and last_log_date_time::date=NEW.log_date_time::date;
	else
		select null into last_rec;
	end if;
	if last_rec_exists then
		if last_rec.last_log_date_time::time<NEW.log_date_time::time then
			update data.sensor_last_data
			set latitude=NEW.latitude,longitude=NEW.longitude,
			temperature=NEW.temperature,humidity=NEW.humidity,
			temperature_max=NEW.temperature_max,temperature_min=NEW.temperature_min,
			humidity_max=NEW.humidity_max,humidity_min=NEW.humidity_min,
			last_log_date_time=NEW.log_date_time,last_update=now()
			where sensor_id=snsr_id
			and last_log_date_time::date=NEW.log_date_time::date;
		end if;
	else
		insert into data.sensor_last_data (
			sensor_id,latitude,longitude,temperature,humidity,
		 	temperature_max,temperature_min,humidity_max,humidity_min,
		 	first_log_date_time,last_log_date_time,create_date,last_update)
		values(
			 snsr_id,NEW.latitude,NEW.longitude,NEW.temperature,
		  	NEW.humidity,NEW.temperature_max,NEW.temperature_min,
		  	NEW.humidity_max,NEW.humidity_min,NEW.log_date_time,
			NEW.log_date_time,now(),now()
		);
	end if;
	RETURN NEW;
END;
$$;


--
-- TOC entry 893 (class 1255 OID 21723)
-- Name: date_to_jalali(date); Type: FUNCTION; Schema: data; Owner: -
--

CREATE FUNCTION data.date_to_jalali(gdate date) RETURNS text
    LANGUAGE plpgsql
    AS $$

DECLARE
	g_days_in_month int[] default '{31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31}';
	j_days_in_month int[] default '{31, 31, 31, 31, 31, 31, 30, 30, 30, 30, 30, 29}';
	gyear int;
	gmonth int;
	gday int;
	gy int default 0;
	gm int default 0;
	gd int default 0;
	g_day_no int default 0;
	j_day_no int default 0;
	j_np int default 0;
	jy int default 0;
	jm int default 0;
	jd int default 0;
	counter int default 0;
	last_counter_val int default 0;
BEGIN
	if gdate is null then
		return null;
	end if;
	SET TIMEZONE='Asia/Tehran';
	select date_part('year',gdate) into gyear;
	select date_part('month',gdate) into gmonth;
	select date_part('day',gdate) into gday;
	gy = gyear-1600;
    gm = gmonth-1;
    gd = gday-1;
    g_day_no = 365*gy+(gy+3)/4-(gy+99)/100+(gy+399)/400;
	for counter in 0..gm-1 loop
        g_day_no = g_day_no + g_days_in_month[counter+1];
	end loop;
     if gm>1 and ((gy%4=0 and gy%100<>0) or (gy%400=0)) then
     	g_day_no = g_day_no + 1;
 	end if;
    g_day_no = g_day_no + gd;
    j_day_no = g_day_no - 79;
	j_np = j_day_no/12053;
    j_day_no = j_day_no % 12053;
    jy = 979+33*j_np+4*(j_day_no/1461);
    j_day_no = j_day_no % 1461;
    if j_day_no>=366 then
    	jy = jy + (j_day_no-1)/365;
        j_day_no = (j_day_no-1)%365;
	end if;

    for counter in 0..10 loop
		last_counter_val = counter;
		if not j_day_no >= j_days_in_month[counter+1] then
			last_counter_val = counter-1;
			exit;
		end if;
		j_day_no = j_day_no - j_days_in_month[counter+1];
	end loop;
	jm = last_counter_val+2;
	jd = j_day_no+1;
	return format('%s-%s-%s',jy,jm,jd);
END;
$$;


--
-- TOC entry 890 (class 1255 OID 21724)
-- Name: drop_tables(date, date); Type: FUNCTION; Schema: data; Owner: -
--

CREATE FUNCTION data.drop_tables(from_date date, to_date date) RETURNS void
    LANGUAGE plpgsql
    AS $$

DECLARE
	rec RECORD;
BEGIN

	for rec in select table_name from data.tables
	loop
		if exists(SELECT 1 FROM information_schema.tables 
			  WHERE table_schema='data' and TABLE_NAME=rec.table_name)
		then
			execute(format('drop table data.%s cascade;',rec.table_name));
			execute(format('drop sequence data.%s_id_seq cascade;',rec.table_name));
		end if;
	end loop;
	delete from data.tables where created between from_date and to_date;
END;
$$;


--
-- TOC entry 925 (class 1255 OID 11731271)
-- Name: fix_data(date, date); Type: FUNCTION; Schema: data; Owner: -
--

CREATE FUNCTION data.fix_data(_from_date date, _to_date date) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
	rec RECORD;
	tbl_name text;
BEGIN

	for rec in select table_name from data.tables where created between _from_date and _to_date
	loop
	    raise info '%r',rec.table_name;
		execute(
			format(
				'update data.%s
				set humidity=temperature_max,temperature_max=temperature_min,
				temperature_min=humidity',rec.table_name
			)
		);
	end loop;
END;
$$;


--
-- TOC entry 924 (class 1255 OID 11731214)
-- Name: fix_data(character, character, character, date); Type: FUNCTION; Schema: data; Owner: -
--

CREATE FUNCTION data.fix_data(_branch_id character, _room_id character, _sensor_id character, _date date) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
	snsr_id int default null;
	rec RECORD;
	tbl_name text;
BEGIN
	select into snsr_id s.id
	from api.core_warehouse w left join
	api.core_room r on w.id=r.warehouse_id left join
	api.core_sensor s on r.id=s.room_id
	where w.warehouse_id=_branch_id and
	r.room_id = _room_id and
	s.sensor_id=_sensor_id;

	if snsr_id is not null then
		select table_name into tbl_name from data.tables where created=_date;
		execute(
			format(
				'update data.%s
				set humidity=temperature_max,temperature_max=temperature_min,
				temperature_min=humidity',tbl_name
			)
		);
	end if;
END;
$$;


--
-- TOC entry 892 (class 1255 OID 21725)
-- Name: get_data(character, character, character, date, date); Type: FUNCTION; Schema: data; Owner: -
--

CREATE FUNCTION data.get_data(_branch_id character, _room_id character, _sensor_id character, _from_date date, _to_date date) RETURNS json
    LANGUAGE plpgsql
    AS $_$
DECLARE
	snsr_id int default null;
	rec RECORD;
	start_rec RECORD;
	last_rec RECORD;
	table_rec RECORD;
	q text default '';
	queries text[];
	result json default '[]'::json;
	tmin double precision default 99999;
	tmax double precision default 0;
	hmin double precision default 99999;
	hmax double precision default 0;
	counter int default 1;
	hsum double precision default 0;
	tsum double precision default 9;
	inserted boolean default false;
BEGIN
-- 	select into snsr_id s.id
-- 	from api.core_warehouse w left join
-- 	api.core_room r on w.id=r.warehouse_id left join
-- 	api.core_sensor s on r.id=s.room_id
-- 	where w.warehouse_id=_branch_id and
-- 	r.room_id = _room_id and
-- 	s.sensor_id=_sensor_id;
	drop table if exists sensor_data_temp_table;
	create temp table sensor_data_temp_table(
    branch_id character(8),
    room_id character(8),
    sensor_id character(8),
    sensor_type character(2),
    log_date_time text,
    latitude char(10),
    longitude char(10),
    temperature double precision,
    humidity double precision,
    temperature_max double precision,
    temperature_min double precision,
    humidity_max double precision,
    humidity_min double precision
	);
	for table_rec in select table_name from data.tables
					 where created between _from_date and _to_date
	loop
		q='select branch_id,room_id,sensor_id,
		 sensor_type,log_date_time,latitude,longitude,
		 temperature,humidity,temperature_max,
		 temperature_min,humidity_max,humidity_min
		 from data.'||table_rec.table_name||'
		 where branch_id=$1 and room_id=$2 and sensor_id=$3
		 order by log_date_time';
		EXECUTE(concat(q,' asc limit 1'))
		using _branch_id,_room_id,_sensor_id into start_rec;
		EXECUTE(concat(q,' desc limit 1'))
		using _branch_id,_room_id,_sensor_id into last_rec;
		inserted = false;
		for rec in execute('select branch_id,room_id,sensor_id,
		 sensor_type,log_date_time,latitude,longitude,
		 temperature,humidity,temperature_max,
		 temperature_min,humidity_max,humidity_min
		 from data.'||table_rec.table_name||'
		 where branch_id=$1 and room_id=$2 and sensor_id=$3
		 order by log_date_time asc'
		)using _branch_id,_room_id,_sensor_id
		loop
			inserted = false;
			if tmin>rec.temperature then
				tmin = rec.temperature;
			end if;
			if tmax<rec.temperature then
				tmax = rec.temperature;
			end if;
			if hmin>rec.humidity then
				hmin = rec.humidity;
			end if;
			if hmax<rec.humidity then
				hmax = rec.humidity;
			end if;
			hsum = hsum + rec.humidity;
			tsum = tsum + rec.temperature;
			if extract(epoch from(rec.log_date_time-start_rec.log_date_time))>=900 then
				insert into sensor_data_temp_table(
					branch_id,room_id,sensor_id,sensor_type,log_date_time,
					latitude,longitude,temperature,humidity,temperature_max,
					temperature_min,humidity_max,humidity_min
				)values(
					start_rec.branch_id,start_rec.room_id,start_rec.sensor_id,start_rec.sensor_type,
					to_char(start_rec.log_date_time,'YYYY-MM-DD HH24:MI:SS'),
					case when start_rec.latitude is not null then floor(start_rec.latitude*1e8)
					else start_rec.latitude end,
					case when start_rec.longitude is not null then floor(start_rec.longitude*1e8)
					else start_rec.longitude end,
					round((tsum/counter)::numeric,2),
					round((hsum/counter)::numeric,2),
					tmax,tmin,hmax,hmin
				);
				inserted = true;
				start_rec = rec;
				hmin = 99999;
				hmax = 0;
				tmin = 99999;
				tmax = 0;
				counter = 1;
				hsum = 0;
				tsum = 0;	
			end if;
			counter = counter + 1;
		end loop;
		if not inserted then
			insert into sensor_data_temp_table(
					branch_id,room_id,sensor_id,sensor_type,log_date_time,
					latitude,longitude,temperature,humidity,temperature_max,
					temperature_min,humidity_max,humidity_min
				)values(
					start_rec.branch_id,start_rec.room_id,start_rec.sensor_id,start_rec.sensor_type,
					to_char(start_rec.log_date_time,'YYYY-MM-DD HH24:MI:SS'),
					case when start_rec.latitude is not null then floor(start_rec.latitude*1e8)
					else start_rec.latitude end,
					case when start_rec.longitude is not null then floor(start_rec.longitude*1e8)
					else start_rec.longitude end,
					round((tsum/counter)::numeric,2),
					round((hsum/counter)::numeric,2),
					tmax,tmin,hmax,hmin
				);
		end if;
	end loop;
	select json_agg(
	row_to_json(
		(select cname from (select
		branch_id as "branch_ID",room_id,sensor_id,sensor_type as "sensor_Type",
		log_date_time as "logDateTime",latitude as "LAT",longitude as "LNG",
		temperature as "T",humidity as "H",temperature_max as "Tmax",
		temperature_min as "Tmin",humidity_max as "Hmax",
		humidity_min as "Hmin") as cname)
	)
	) into result
	from sensor_data_temp_table;
	return result;
	
END;
$_$;


--
-- TOC entry 918 (class 1255 OID 2127847)
-- Name: hmax_alarm_report(integer, date, date, time without time zone, time without time zone); Type: FUNCTION; Schema: data; Owner: -
--

CREATE FUNCTION data.hmax_alarm_report(input_sensor_id integer, from_date date, to_date date, from_time time without time zone DEFAULT '00:00:00'::time without time zone, to_time time without time zone DEFAULT '23:59:59'::time without time zone) RETURNS TABLE(type text, start_lon double precision, start_lat double precision, end_lon double precision, end_lat double precision, date text, start_time time without time zone, end_time time without time zone, duration time without time zone, temperature double precision, humidity double precision, mean double precision, max double precision, min double precision, is_done boolean)
    LANGUAGE plpgsql
    AS $_$

DECLARE
    start_rec RECORD;
	mid_rec RECORD;
	end_rec RECORD;
	last_rec RECORD;
	sensor_rec RECORD;
	table_rec RECORD;
	_sensor_id char(8);
	_room_id char(8);
	_warehouse_id char(8);
	q text;
	result json;
	timediff time;
	inserted boolean;
	is_first boolean default true;
	is_single boolean default false;
	sum_humidity double precision default 0;
	counter int default 0;
	max_humidity double precision default 0;
	min_humidity double precision default 99999;
	is_in_alarm boolean default false;
BEGIN
	set timezone='Asia/Tehran';
	if input_sensor_id is null then
 		return query select null;
	end if;

	drop table if exists humidity_max_alarm_temp_table;
	CREATE TEMPORARY TABLE humidity_max_alarm_temp_table(
		type text,
		start_lon double precision,
		start_lat double precision,
		end_lon double precision,
		end_lat double precision,
		date text,
		start_time time,
		end_time time,
		duration time,
		temperature double precision,
		humidity double precision,
		mean float,
		max float,
		min float,
		is_done boolean
	);

	select into _sensor_id,_room_id,_warehouse_id
	s.sensor_id,r.room_id,w.warehouse_id
	from api.core_warehouse w
	left join api.core_room r on w.id=r.warehouse_id
	left join api.core_sensor s on r.id=s.room_id
	where s.id=input_sensor_id;
	if _sensor_id is null or _room_id is null or _warehouse_id is null then
		return query select null;
	end if;
	FOR table_rec IN select created,table_name from data.tables where 
					created between from_date AND to_date
	LOOP
		EXECUTE('select hum_max_val,allowed_hum_max_violation_time
				from api.core_sensor where id=$1')
				into sensor_rec using input_sensor_id;
		if table_rec.created=from_date then
			q='SELECT longitude,latitude,temperature,humidity,log_date_time
			FROM data.'||table_rec.table_name||'
			where branch_id=$1 and room_id=$2 and sensor_id=$3 
			and log_date_time::time>='''||from_time||'''
			order by log_date_time';
		elseif table_rec.created=to_date then
			q='SELECT longitude,latitude,temperature,humidity,log_date_time
			FROM data.'||table_rec.table_name||'
			where branch_id=$1 and room_id=$2 and sensor_id=$3 
			and log_date_time::time<='''||to_time||'''
			order by log_date_time';
		else
			q='SELECT longitude,latitude,temperature,humidity,log_date_time
			FROM data.'||table_rec.table_name||'
			where branch_id=$1 and room_id=$2 and sensor_id=$3 
			order by log_date_time';
		end if;
		EXECUTE(CONCAT(q,' asc limit 1')) into start_rec
		using _warehouse_id,_room_id,_sensor_id;
		EXECUTE(CONCAT(q,' desc limit 1')) into last_rec
		using _warehouse_id,_room_id,_sensor_id;
		mid_rec = start_rec;
		inserted = false;
		FOR end_rec IN EXECUTE(q) using _warehouse_id,_room_id,_sensor_id
		LOOP
			if end_rec.humidity > sensor_rec.hum_max_val
			then
				sum_humidity = sum_humidity + end_rec.humidity;
				counter = counter + 1;
				if end_rec.humidity>max_humidity then
					max_humidity = end_rec.humidity;
				end if;
				if end_rec.humidity<min_humidity then
					min_humidity = end_rec.humidity;
				end if;
				if is_first then
					start_rec = end_rec;
					mid_rec = end_rec;
					is_first = false;
					is_single = true;
				else
					mid_rec=end_rec;
					is_single = false;
					inserted = false;
				end if;
				if end_rec<>last_rec then
					continue;
				end if;
			end if;
			if (start_rec.log_date_time::time<mid_rec.log_date_time::time) or is_single then
				if is_single then
					mid_rec = end_rec;
				end if;
				if last_rec=mid_rec then
					if table_rec.created=now()::date then
						is_in_alarm = true;
					end if;
				end if;
				timediff =  mid_rec.log_date_time - start_rec.log_date_time;
				if extract(EPOCH from (timediff))>sensor_rec.allowed_hum_max_violation_time then
					insert into humidity_max_alarm_temp_table(
					 	type,start_lon,start_lat,end_lon,
						end_lat,date,start_time,end_time,duration,temperature,humidity,mean,max,min,is_done
					)values (
						'hmax',
						start_rec.longitude,start_rec.latitude,
						mid_rec.longitude,mid_rec.latitude,
						data.date_to_jalali(mid_rec.log_date_time::date),
						start_rec.log_date_time::time,
						mid_rec.log_date_time::time,
						(mid_rec.log_date_time-start_rec.log_date_time)::time,
						start_rec.temperature,start_rec.humidity,
						round((sum_humidity/counter)::numeric,2),max_humidity,
						min_humidity,not is_in_alarm
					);
					max_humidity = 0;
					min_humidity = 99999;
					sum_humidity = 0;
					counter = 0;
				end if;
				inserted = true;
				is_first = true;
				is_single = false;
				is_in_alarm = false;
			end if;
			start_rec = end_rec;
			mid_rec = end_rec;
		END LOOP;
		if not inserted then
			if (start_rec.log_date_time::time<mid_rec.log_date_time::time) or is_single then
				if is_single then
					mid_rec = end_rec;
				end if;
				if last_rec=mid_rec then
					if table_rec.created=now()::date then
						is_in_alarm = true;
					end if;
				end if;
				timediff =  mid_rec.log_date_time - start_rec.log_date_time;
				if extract(EPOCH from (timediff))>sensor_rec.allowed_hum_max_violation_time then
					insert into humidity_max_alarm_temp_table(
						type,start_lon,start_lat,end_lon,end_lat,date,
						start_time,end_time,duration,temperature,humidity,mean,max,min,is_done
					)values (
						'hmax',
						start_rec.longitude,start_rec.latitude,
						mid_rec.longitude,mid_rec.latitude,
						data.date_to_jalali(mid_rec.log_date_time::date),
						start_rec.log_date_time::time,
						mid_rec.log_date_time::time,
						(mid_rec.log_date_time-start_rec.log_date_time)::time,
						start_rec.temperature,start_rec.humidity,
						round((sum_humidity/counter)::numeric,2),max_humidity,
						min_humidity,not is_in_alarm
					);
					inserted = true;
				end if;
			end if;
		end if;
	END LOOP;

	return query select * from humidity_max_alarm_temp_table;
END;
$_$;


--
-- TOC entry 917 (class 1255 OID 2127837)
-- Name: hmin_alarm_report(integer, date, date, time without time zone, time without time zone); Type: FUNCTION; Schema: data; Owner: -
--

CREATE FUNCTION data.hmin_alarm_report(input_sensor_id integer, from_date date, to_date date, from_time time without time zone DEFAULT '00:00:00'::time without time zone, to_time time without time zone DEFAULT '23:59:59'::time without time zone) RETURNS TABLE(type text, start_lon double precision, start_lat double precision, end_lon double precision, end_lat double precision, date text, start_time time without time zone, end_time time without time zone, duration time without time zone, temperature double precision, humidity double precision, mean double precision, max double precision, min double precision, is_done boolean)
    LANGUAGE plpgsql
    AS $_$

DECLARE
    start_rec RECORD;
	mid_rec RECORD;
	end_rec RECORD;
	last_rec RECORD;
	sensor_rec RECORD;
	table_rec RECORD;
	_sensor_id char(8);
	_room_id char(8);
	_warehouse_id char(8);
	q text;
	result json;
	timediff time;
	inserted boolean;
	is_first boolean default true;
	is_single boolean default false;
	sum_humidity double precision default 0;
	counter int default 0;
	max_humidity double precision default 0;
	min_humidity double precision default 99999;
	is_in_alarm boolean default false;
BEGIN
	set timezone='Asia/Tehran';
	if input_sensor_id is null then
 		return query select null;
	end if;

	drop table if exists humidity_min_alarm_temp_table;
	CREATE TEMPORARY TABLE humidity_min_alarm_temp_table(
		type text,
		start_lon double precision,
		start_lat double precision,
		end_lon double precision,
		end_lat double precision,
		date text,
		start_time time,
		end_time time,
		duration time,
		temperature double precision,
		humidity double precision,
		mean float,
		max float,
		min float,
		is_done boolean
	);

	select into _sensor_id,_room_id,_warehouse_id
	s.sensor_id,r.room_id,w.warehouse_id
	from api.core_warehouse w
	left join api.core_room r on w.id=r.warehouse_id
	left join api.core_sensor s on r.id=s.room_id
	where s.id=input_sensor_id;
	if _sensor_id is null or _room_id is null or _warehouse_id is null then
		return query select null;
	end if;
	FOR table_rec IN select created,table_name from data.tables where 
					created between from_date AND to_date
	LOOP
		EXECUTE('select hum_min_val,allowed_hum_min_violation_time
				from api.core_sensor where id=$1')
				into sensor_rec using input_sensor_id;
		if table_rec.created=from_date then
			q='SELECT longitude,latitude,temperature,humidity,log_date_time
			FROM data.'||table_rec.table_name||'
			where branch_id=$1 and room_id=$2 and sensor_id=$3 
			and log_date_time::time>='''||from_time||'''
			order by log_date_time';
		elseif table_rec.created=to_date then
			q='SELECT longitude,latitude,temperature,humidity,log_date_time
			FROM data.'||table_rec.table_name||'
			where branch_id=$1 and room_id=$2 and sensor_id=$3 
			and log_date_time::time<='''||to_time||'''
			order by log_date_time';
		else
			q='SELECT longitude,latitude,temperature,humidity,log_date_time
			FROM data.'||table_rec.table_name||'
			where branch_id=$1 and room_id=$2 and sensor_id=$3 
			order by log_date_time';
		end if;
		EXECUTE(CONCAT(q,' asc limit 1')) into start_rec
		using _warehouse_id,_room_id,_sensor_id;
		EXECUTE(CONCAT(q,' desc limit 1')) into last_rec
		using _warehouse_id,_room_id,_sensor_id;
		mid_rec = start_rec;
		inserted = false;
		FOR end_rec IN EXECUTE(q) using _warehouse_id,_room_id,_sensor_id
		LOOP
			if end_rec.humidity < sensor_rec.hum_min_val
			then
				sum_humidity = sum_humidity + end_rec.humidity;
				counter = counter + 1;
				if end_rec.humidity>max_humidity then
					max_humidity = end_rec.humidity;
				end if;
				if end_rec.humidity<min_humidity then
					min_humidity = end_rec.humidity;
				end if;
				if is_first then
					start_rec = end_rec;
					mid_rec = end_rec;
					is_first = false;
					is_single = true;
				else
					mid_rec=end_rec;
					is_single = false;
					inserted = false;
				end if;
				if end_rec<>last_rec then
					continue;
				end if;
			end if;
			if (start_rec.log_date_time::time<mid_rec.log_date_time::time) or is_single then
				if is_single then
					mid_rec = end_rec;
				end if;
				if last_rec=mid_rec then
					if table_rec.created=now()::date then
						is_in_alarm = true;
					end if;
				end if;
				timediff =  mid_rec.log_date_time - start_rec.log_date_time;
				if extract(EPOCH from (timediff))>sensor_rec.allowed_hum_min_violation_time then
					insert into humidity_min_alarm_temp_table(
					 	type,start_lon,start_lat,end_lon,
						end_lat,date,start_time,end_time,duration,
						temperature,humidity,mean,max,min,is_done
					)values (
						'hmin',
						start_rec.longitude,start_rec.latitude,
						mid_rec.longitude,mid_rec.latitude,
						data.date_to_jalali(mid_rec.log_date_time::date),
						start_rec.log_date_time::time,
						mid_rec.log_date_time::time,
						(mid_rec.log_date_time-start_rec.log_date_time)::time,
						start_rec.temperature,start_rec.humidity,
						round((sum_humidity/counter)::numeric,2),max_humidity,
						min_humidity,not is_in_alarm
					);
					max_humidity = 0;
					min_humidity = 99999;
					sum_humidity = 0;
					counter = 0;
				end if;
				inserted = true;
				is_first = true;
				is_single = false;
				is_in_alarm = false;
			end if;
			start_rec = end_rec;
			mid_rec = end_rec;
		END LOOP;
		if not inserted then
			if (start_rec.log_date_time::time<mid_rec.log_date_time::time) or is_single then
				if is_single then
					mid_rec = end_rec;
				end if;
				if last_rec=mid_rec then
					if table_rec.created=now()::date then
						is_in_alarm = true;
					end if;
				end if;
				timediff =  mid_rec.log_date_time - start_rec.log_date_time;
				if extract(EPOCH from (timediff))>sensor_rec.allowed_hum_min_violation_time then
					insert into humidity_min_alarm_temp_table(
						type,start_lon,start_lat,end_lon,
						end_lat,date,start_time,end_time,duration,
						temperature,humidity,mean,max,min,is_done
					)values (
						'hmin',start_rec.longitude,start_rec.latitude,
						mid_rec.longitude,mid_rec.latitude,
						data.date_to_jalali(mid_rec.log_date_time::date),
						start_rec.log_date_time::time,
						mid_rec.log_date_time::time,
						(mid_rec.log_date_time-start_rec.log_date_time)::time,
						start_rec.temperature,start_rec.humidity,
						round((sum_humidity/counter)::numeric,2),max_humidity,
						min_humidity,not is_in_alarm
					);
					inserted = true;
				end if;
			end if;
		end if;
	END LOOP;

	return query select * from humidity_min_alarm_temp_table;
END;
$_$;


--
-- TOC entry 872 (class 1255 OID 21730)
-- Name: humidity_max_alarm(integer, date, date); Type: FUNCTION; Schema: data; Owner: -
--

CREATE FUNCTION data.humidity_max_alarm(input_sensor_id integer, from_date date, to_date date) RETURNS json
    LANGUAGE plpgsql
    AS $_$

DECLARE
    start_rec RECORD;
	mid_rec RECORD;
	end_rec RECORD;
	last_rec RECORD;
	sensor_rec RECORD;
	table_rec RECORD;
	_sensor_id char(8);
	_room_id char(8);
	_warehouse_id char(8);
	_hmin double precision;
	_hmax double precision;
	q text;
	result json;
	timediff time;
	inserted boolean;
	is_first boolean default true;
	is_single boolean default false;
	sum_humidity double precision default 0;
	counter int default 0;
	max_humidity double precision default 0;
	min_humidity double precision default 999999;
	is_in_alarm boolean default false;
BEGIN
	set timezone='Asia/Tehran';
	if input_sensor_id is null then
 		return null;
	end if;

	drop table if exists humidity_max_alarm_temp_table;
	CREATE TEMPORARY TABLE humidity_max_alarm_temp_table(
		warehouse_id char(8),
		warehouse_name text,
		room_id char(8),
		room_name text,
		sensor_id char(8),
		sensor_name text,
		start_lon double precision,
		start_lat double precision,
		end_lon double precision,
		end_lat double precision,
		date text,
		start_time time,
		end_time time,
		duration time,
		mean float,
		min float,
		max float,
		hmin float,
		hmax float,
		is_done boolean
	);

	select into _sensor_id,_room_id,_warehouse_id,_hmin,_hmax
	s.sensor_id,r.room_id,w.warehouse_id,s.hum_min_val,s.hum_max_val
	from api.core_warehouse w
	left join api.core_room r on w.id=r.warehouse_id
	left join api.core_sensor s on r.id=s.room_id
	where s.id=input_sensor_id;
	if _sensor_id is null or _room_id is null or _warehouse_id is null then
		return null;
	end if;
	FOR table_rec IN select created,table_name from data.tables where 
					created between from_date AND to_date
	LOOP
		EXECUTE('select w.name as warehouse_name,r.name as room_name,
				s.name as sensor_name,s.hum_max_val,s.allowed_hum_max_violation_time
				from api.core_warehouse w
				left join api.core_room r on w.id=r.warehouse_id
				left join api.core_sensor s on r.id=s.room_id
				where s.id=$1') using input_sensor_id into sensor_rec;
		q='SELECT longitude,latitude,humidity,log_date_time
		FROM data.'||table_rec.table_name||'
		where branch_id=$1 and room_id=$2 and sensor_id=$3 
		order by log_date_time';
		EXECUTE(CONCAT(q,' asc limit 1')) into start_rec
		using _warehouse_id,_room_id,_sensor_id;
		EXECUTE(CONCAT(q,' desc limit 1')) into last_rec
		using _warehouse_id,_room_id,_sensor_id;
		mid_rec = start_rec;
		inserted = false;
		FOR end_rec IN EXECUTE(q) using _warehouse_id,_room_id,_sensor_id
		LOOP
			if end_rec.humidity > sensor_rec.hum_max_val
			then
				sum_humidity = sum_humidity + end_rec.humidity;
				counter = counter + 1;
				if end_rec.humidity<min_humidity then
					min_humidity = end_rec.humidity;
				end if;
				if end_rec.humidity>max_humidity then
					max_humidity = end_rec.humidity;
				end if;
				if is_first then
					start_rec = end_rec;
					mid_rec = end_rec;
					is_first = false;
					is_single = true;
				else
					mid_rec=end_rec;
					is_single = false;
					inserted = false;
				end if;
				if end_rec<>last_rec then
					continue;
				end if;
			end if;
			if (start_rec.log_date_time::time<mid_rec.log_date_time::time) or is_single then
				if is_single then
					mid_rec = end_rec;
				end if;
				if last_rec=mid_rec then
					if table_rec.created=now()::date then
						is_in_alarm = true;
					end if;
				end if;
				timediff =  mid_rec.log_date_time - start_rec.log_date_time;
				if extract(EPOCH from (timediff))>sensor_rec.allowed_hum_max_violation_time then
					insert into humidity_max_alarm_temp_table(
						warehouse_id,warehouse_name,room_id,room_name,
					 	sensor_id,sensor_name,start_lon,start_lat,end_lon,
						end_lat,date,start_time,end_time,duration,mean,min,max,hmin,hmax,is_done
					)values (
						_warehouse_id,sensor_rec.warehouse_name,
						_room_id,sensor_rec.room_name,
						_sensor_id,sensor_rec.sensor_name,
						start_rec.longitude,start_rec.latitude,
						mid_rec.longitude,mid_rec.latitude,
						data.date_to_jalali(mid_rec.log_date_time::date),
						start_rec.log_date_time::time,
						mid_rec.log_date_time::time,
						(mid_rec.log_date_time-start_rec.log_date_time)::time,
						round((sum_humidity/counter)::numeric,2),min_humidity,
						max_humidity,_hmin,_hmax,not is_in_alarm
					);
					min_humidity = 999999;
					max_humidity = 0;
					sum_humidity = 0;
					counter = 0;
				end if;
				inserted = true;
				is_first = true;
				is_single = false;
				is_in_alarm = false;
			end if;
			start_rec = end_rec;
			mid_rec = end_rec;
		END LOOP;
		if not inserted then
			if (start_rec.log_date_time::time<mid_rec.log_date_time::time) or is_single then
				if is_single then
					mid_rec = end_rec;
				end if;
				if last_rec=mid_rec then
					if table_rec.created=now()::date then
						is_in_alarm = true;
					end if;
				end if;
				timediff =  mid_rec.log_date_time - start_rec.log_date_time;
				if extract(EPOCH from (timediff))>sensor_rec.allowed_hum_max_violation_time then
					insert into humidity_max_alarm_temp_table(
						warehouse_id,warehouse_name,room_id,room_name,
						sensor_id,sensor_name,start_lon,start_lat,end_lon,
						end_lat,date,start_time,end_time,duration,mean,min,max,hmin,hmax,is_done
					)values (
						_warehouse_id,sensor_rec.warehouse_name,
						_room_id,sensor_rec.room_name,
						_sensor_id,sensor_rec.sensor_name,
						start_rec.longitude,start_rec.latitude,
						mid_rec.longitude,mid_rec.latitude,
						data.date_to_jalali(mid_rec.log_date_time::date),
						start_rec.log_date_time::time,
						mid_rec.log_date_time::time,
						(mid_rec.log_date_time-start_rec.log_date_time)::time,
						round((sum_humidity/counter)::numeric,2),min_humidity,
						max_humidity,_hmin,_hmax,not is_in_alarm
					);
					inserted = true;
				end if;
			end if;
		end if;
	END LOOP;

	select json_agg(
		row_to_json(
		(select cname from(select warehouse_name,warehouse_id,room_name,
						   room_id,sensor_name,sensor_id,start_lon,
						   start_lat,end_lon,end_lat,date,start_time,end_time,
						   duration,mean,min,max,hmin,hmax,is_done) as cname)
		)
	) into result
	from humidity_max_alarm_temp_table;
	return result;
END;
$_$;


--
-- TOC entry 894 (class 1255 OID 21731)
-- Name: humidity_max_alarm_count(integer, date, date); Type: FUNCTION; Schema: data; Owner: -
--

CREATE FUNCTION data.humidity_max_alarm_count(input_sensor_id integer, from_date date, to_date date) RETURNS integer
    LANGUAGE plpgsql
    AS $_$

DECLARE
    start_rec RECORD;
	mid_rec RECORD;
	end_rec RECORD;
	sensor_rec RECORD;
	table_rec RECORD;
	_sensor_id char(8);
	_room_id char(8);
	_warehouse_id char(8);
	q text;
	alarm_count int default 0;
	result json;
	timediff time;
	inserted boolean;
	is_first boolean default true;
	is_single boolean default false;
BEGIN
	set timezone='Asia/Tehran';
	if input_sensor_id is null then
 		return null;
	end if;
	
	select into _sensor_id,_room_id,_warehouse_id
	s.sensor_id,r.room_id,w.warehouse_id
	from api.core_warehouse w
	left join api.core_room r on w.id=r.warehouse_id
	left join api.core_sensor s on r.id=s.room_id
	where s.id=input_sensor_id;
	if _sensor_id is null or _room_id is null or _warehouse_id is null then
		return null;
	end if;
	FOR table_rec IN select created,table_name from data.tables where 
					created between from_date AND to_date
	LOOP
		EXECUTE('select w.name as warehouse_name,r.name as room_name,
				s.name as sensor_name,s.hum_max_val,s.allowed_hum_max_violation_time
				from api.core_warehouse w
				left join api.core_room r on w.id=r.warehouse_id
				left join api.core_sensor s on r.id=s.room_id
				where s.id=$1') using input_sensor_id into sensor_rec;
		q='SELECT longitude,latitude,humidity,log_date_time
		FROM data.'||table_rec.table_name||'
		where branch_id=$1 and room_id=$2 and sensor_id=$3 
		order by log_date_time asc';
		EXECUTE(CONCAT(q,' limit 1')) into start_rec
		using _warehouse_id,_room_id,_sensor_id;
		mid_rec = start_rec;
		inserted = false;
		FOR end_rec IN EXECUTE(q) using _warehouse_id,_room_id,_sensor_id
		LOOP
			if end_rec.humidity > sensor_rec.hum_max_val
			then
				if is_first then
					start_rec = end_rec;
					mid_rec = end_rec;
					is_first = false;
					is_single = true;
				else
					mid_rec=end_rec;
					is_single = false;
				end if;
				inserted = false;
				continue;
			end if;
			if (start_rec.log_date_time::time<mid_rec.log_date_time::time) or is_single then
				if is_single then
					mid_rec = end_rec;
				end if;
				timediff =  mid_rec.log_date_time - start_rec.log_date_time;
				if extract(EPOCH from (timediff))>sensor_rec.allowed_hum_max_violation_time then
					alarm_count = alarm_count + 1;
				end if;
				inserted = true;
				is_first = true;
				is_single = false;
			end if;
			start_rec = end_rec;
			mid_rec = end_rec;
		END LOOP;
			if not inserted then
				if (start_rec.log_date_time::time<mid_rec.log_date_time::time) or is_single then
					if is_single then
						mid_rec = end_rec;
					end if;
					timediff =  mid_rec.log_date_time - start_rec.log_date_time;
					if extract(EPOCH from (timediff))>sensor_rec.allowed_hum_max_violation_time then
						alarm_count = alarm_count + 1;
						inserted = true;
					end if;
				end if;
			end if;
	END LOOP;

	return alarm_count;
END;
$_$;


--
-- TOC entry 1049 (class 1255 OID 21732)
-- Name: humidity_min_alarm(integer, date, date); Type: FUNCTION; Schema: data; Owner: -
--

CREATE FUNCTION data.humidity_min_alarm(input_sensor_id integer, from_date date, to_date date) RETURNS json
    LANGUAGE plpgsql
    AS $_$

DECLARE
    start_rec RECORD;
	mid_rec RECORD;
	end_rec RECORD;
	last_rec RECORD;
	sensor_rec RECORD;
	table_rec RECORD;
	_sensor_id char(8);
	_room_id char(8);
	_warehouse_id char(8);
	_hmin double precision;
	_hmax double precision;
	q text;
	result json;
	timediff time;
	inserted boolean;
	is_first boolean default true;
	is_single boolean default false;
	sum_humidity double precision default 0;
	counter int default 0;
	min_humidity double precision default 999999;
	max_humidity double precision default 0;
	is_in_alarm boolean default false;
BEGIN
	set timezone='Asia/Tehran';
	if input_sensor_id is null then
 		return null;
	end if;

	drop table if exists humidity_max_alarm_temp_table;
	CREATE TEMPORARY TABLE humidity_max_alarm_temp_table(
		warehouse_id char(8),
		warehouse_name text,
		room_id char(8),
		room_name text,
		sensor_id char(8),
		sensor_name text,
		start_lon double precision,
		start_lat double precision,
		end_lon double precision,
		end_lat double precision,
		date text,
		start_time time,
		end_time time,
		duration time,
		mean float,
		min float,
		max float,
		hmin float,
		hmax float,
		is_done boolean
	);

	select into _sensor_id,_room_id,_warehouse_id,_hmin,_hmax
	s.sensor_id,r.room_id,w.warehouse_id,s.hum_min_val,s.hum_max_val
	from api.core_warehouse w
	left join api.core_room r on w.id=r.warehouse_id
	left join api.core_sensor s on r.id=s.room_id
	where s.id=input_sensor_id;
	if _sensor_id is null or _room_id is null or _warehouse_id is null then
		return null;
	end if;
	FOR table_rec IN select created,table_name from data.tables where 
					created between from_date AND to_date
	LOOP
		EXECUTE('select w.name as warehouse_name,r.name as room_name,
				s.name as sensor_name,s.hum_min_val,s.allowed_hum_min_violation_time
				from api.core_warehouse w
				left join api.core_room r on w.id=r.warehouse_id
				left join api.core_sensor s on r.id=s.room_id
				where s.id=$1') using input_sensor_id into sensor_rec;
		q='SELECT longitude,latitude,humidity,log_date_time
		FROM data.'||table_rec.table_name||'
		where branch_id=$1 and room_id=$2 and sensor_id=$3 
		order by log_date_time';
		EXECUTE(CONCAT(q,' asc limit 1')) into start_rec
		using _warehouse_id,_room_id,_sensor_id;
		EXECUTE(CONCAT(q,' desc limit 1')) into last_rec
		using _warehouse_id,_room_id,_sensor_id;
		mid_rec = start_rec;
		inserted = false;
		FOR end_rec IN EXECUTE(q) using _warehouse_id,_room_id,_sensor_id
		LOOP
			if end_rec.humidity < sensor_rec.hum_min_val
			then
				sum_humidity = sum_humidity + end_rec.humidity;
				counter = counter + 1;
				if end_rec.humidity<min_humidity then
					min_humidity = end_rec.humidity;
				end if;
				if end_rec.humidity>max_humidity then
					max_humidity = end_rec.humidity;
				end if;
				if is_first then
					start_rec = end_rec;
					mid_rec = end_rec;
					is_first = false;
					is_single = true;
				else
					mid_rec=end_rec;
					is_single = false;
					inserted = false;
				end if;
				inserted = false;
				if end_rec<>last_rec then
					continue;
				end if;
			end if;
			if (start_rec.log_date_time::time<mid_rec.log_date_time::time) or is_single then
				if is_single then
					mid_rec = end_rec;
				end if;
				if last_rec=mid_rec then
					if table_rec.created=now()::date then
						is_in_alarm = true;
					end if;
				end if;
				timediff =  mid_rec.log_date_time - start_rec.log_date_time;
				if extract(EPOCH from (timediff))>sensor_rec.allowed_hum_min_violation_time then
					insert into humidity_max_alarm_temp_table(
						warehouse_id,warehouse_name,room_id,room_name,
					 	sensor_id,sensor_name,start_lon,start_lat,end_lon,
						end_lat,date,start_time,end_time,duration,mean,min,max,hmin,hmax,is_done
					)values (
						_warehouse_id,sensor_rec.warehouse_name,
						_room_id,sensor_rec.room_name,
						_sensor_id,sensor_rec.sensor_name,
						start_rec.longitude,start_rec.latitude,
						mid_rec.longitude,mid_rec.latitude,
						data.date_to_jalali(mid_rec.log_date_time::date),
						start_rec.log_date_time::time,
						mid_rec.log_date_time::time,
						(mid_rec.log_date_time-start_rec.log_date_time)::time,
						round((sum_humidity/counter)::numeric,2),min_humidity,
						max_humidity,_hmin,_hmax,not is_in_alarm
					);
					min_humidity = 999999;
					max_humidity = 0;
					sum_humidity = 0;
					counter = 0;
				end if;
				inserted = true;
				is_first = true;
				is_single = false;
				is_in_alarm = false;
			end if;
			start_rec = end_rec;
			mid_rec = end_rec;
		END LOOP;
		if not inserted then
			if (start_rec.log_date_time::time<mid_rec.log_date_time::time) or is_single then
				if is_single then
					mid_rec = end_rec;
				end if;
				if last_rec=mid_rec then
					if table_rec.created=now()::date then
						is_in_alarm = true;
					end if;
				end if;
				timediff =  mid_rec.log_date_time - start_rec.log_date_time;
				if extract(EPOCH from (timediff))>sensor_rec.allowed_hum_min_violation_time then
					insert into humidity_max_alarm_temp_table(
						warehouse_id,warehouse_name,room_id,room_name,
						sensor_id,sensor_name,start_lon,start_lat,end_lon,
						end_lat,date,start_time,end_time,duration,mean,min,max,hmin,hmax,is_done
					)values (
						_warehouse_id,sensor_rec.warehouse_name,
						_room_id,sensor_rec.room_name,
						_sensor_id,sensor_rec.sensor_name,
						start_rec.longitude,start_rec.latitude,
						mid_rec.longitude,mid_rec.latitude,
						data.date_to_jalali(mid_rec.log_date_time::date),
						start_rec.log_date_time::time,
						mid_rec.log_date_time::time,
						(mid_rec.log_date_time-start_rec.log_date_time)::time,
						round((sum_humidity/counter)::numeric,2),min_humidity,
						max_humidity,_hmin,_hmax,not is_in_alarm
					);
					inserted = true;
				end if;
			end if;
		end if;
	END LOOP;

	select json_agg(
		row_to_json(
		(select cname from(select warehouse_name,warehouse_id,room_name,
						   room_id,sensor_name,sensor_id,start_lon,
						   start_lat,end_lon,end_lat,date,start_time,end_time,
						   duration,mean,min,max,hmin,hmax,is_done) as cname)
		)
	) into result
	from humidity_max_alarm_temp_table;
	return result;
END;
$_$;


--
-- TOC entry 895 (class 1255 OID 21733)
-- Name: humidity_min_alarm_count(integer, date, date); Type: FUNCTION; Schema: data; Owner: -
--

CREATE FUNCTION data.humidity_min_alarm_count(input_sensor_id integer, from_date date, to_date date) RETURNS integer
    LANGUAGE plpgsql
    AS $_$

DECLARE
    start_rec RECORD;
	mid_rec RECORD;
	end_rec RECORD;
	sensor_rec RECORD;
	table_rec RECORD;
	_sensor_id char(8);
	_room_id char(8);
	_warehouse_id char(8);
	q text;
	alarm_count int default 0;
	result json;
	timediff time;
	inserted boolean;
	is_first boolean default true;
	is_single boolean default false;
BEGIN
	set timezone='Asia/Tehran';
	if input_sensor_id is null then
 		return null;
	end if;
	
	select into _sensor_id,_room_id,_warehouse_id
	s.sensor_id,r.room_id,w.warehouse_id
	from api.core_warehouse w
	left join api.core_room r on w.id=r.warehouse_id
	left join api.core_sensor s on r.id=s.room_id
	where s.id=input_sensor_id;
	if _sensor_id is null or _room_id is null or _warehouse_id is null then
		return null;
	end if;
	FOR table_rec IN select created,table_name from data.tables where 
					created between from_date AND to_date
	LOOP
		EXECUTE('select w.name as warehouse_name,r.name as room_name,
				s.name as sensor_name,s.hum_min_val,s.allowed_hum_min_violation_time
				from api.core_warehouse w
				left join api.core_room r on w.id=r.warehouse_id
				left join api.core_sensor s on r.id=s.room_id
				where s.id=$1') using input_sensor_id into sensor_rec;
		q='SELECT longitude,latitude,humidity,log_date_time
		FROM data.'||table_rec.table_name||'
		where branch_id=$1 and room_id=$2 and sensor_id=$3 
		order by log_date_time asc';
		EXECUTE(CONCAT(q,' limit 1')) into start_rec
		using _warehouse_id,_room_id,_sensor_id;
		mid_rec = start_rec;
		inserted = false;
		FOR end_rec IN EXECUTE(q) using _warehouse_id,_room_id,_sensor_id
		LOOP
			if end_rec.humidity < sensor_rec.hum_min_val
			then
				if is_first then
					start_rec = end_rec;
					mid_rec = end_rec;
					is_first = false;
					is_single = true;
				else
					mid_rec=end_rec;
					is_single = false;
				end if;
				inserted = false;
				continue;
			end if;

			if (start_rec.log_date_time::time<mid_rec.log_date_time::time) or is_single then
				if is_single then
					mid_rec = end_rec;
				end if;
				timediff =  mid_rec.log_date_time - start_rec.log_date_time;
				if extract(EPOCH from (timediff))>sensor_rec.allowed_hum_min_violation_time then
					alarm_count = alarm_count + 1;
				end if;
				inserted = true;
				is_first = true;
				is_single = false;
			end if;
			start_rec = end_rec;
			mid_rec = end_rec;
		END LOOP;
			if not inserted then
				if (start_rec.log_date_time::time<mid_rec.log_date_time::time) or is_single then
					if is_single then
						mid_rec = end_rec;
					end if;
					timediff =  mid_rec.log_date_time - start_rec.log_date_time;
					if extract(EPOCH from (timediff))>sensor_rec.allowed_hum_min_violation_time then
						alarm_count = alarm_count + 1;
						inserted = true;
					end if;
				end if;
			end if;
	END LOOP;

	return alarm_count;
END;
$_$;


--
-- TOC entry 923 (class 1255 OID 21734)
-- Name: insert_data(character, character, character, character, timestamp without time zone, double precision, double precision, double precision, double precision, double precision, double precision, double precision, double precision); Type: FUNCTION; Schema: data; Owner: -
--

CREATE FUNCTION data.insert_data(_branch_id character, _room_id character, _sensor_id character, _sensor_type character, _log_date_time timestamp without time zone, _latitude double precision, _longitude double precision, _temperature double precision, _humidity double precision, _temperature_max double precision, _temperature_min double precision, _humidity_max double precision, _humidity_min double precision) RETURNS bigint
    LANGUAGE plpgsql
    AS $_$
DECLARE
	snsr_id int default null;
	rec RECORD;
	tbl_name text;
BEGIN
	select into snsr_id s.id
	from api.core_warehouse w left join
	api.core_room r on w.id=r.warehouse_id left join
	api.core_sensor s on r.id=s.room_id
	where w.warehouse_id=_branch_id and
	r.room_id = _room_id and
	s.sensor_id=_sensor_id;

	if snsr_id is not null then
		select data.new_table(_log_date_time::date) into tbl_name;
		execute(
			format(
				'insert into data.%s(
					 branch_id,room_id,sensor_id,sensor_type,log_date_time,
					 latitude,longitude,temperature,humidity,temperature_max,
					 temperature_min,humidity_max,humidity_min
				 ) values ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13)
				returning id',tbl_name
			)
		) into rec using _branch_id,_room_id,_sensor_id,_sensor_type,
				_log_date_time,_latitude,_longitude,_temperature,_humidity,
				_temperature_max,_temperature_min,_humidity_max,_humidity_min;
		return rec.id;
	end if;
	return null;
--	exception when sqlstate '23505' then
--		raise exception 'Duplicate key value violates unique constraint.';
--	when others then
--		raise exception 'Error :%',SQLERRM;

END;
$_$;


--
-- TOC entry 937 (class 1255 OID 21735)
-- Name: is_inside_iran(double precision, double precision); Type: FUNCTION; Schema: data; Owner: -
--

CREATE FUNCTION data.is_inside_iran(longitude double precision, latitude double precision) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
	
DECLARE
	iran geometry(polygon);
BEGIN
	iran = st_makepolygon('LINESTRING(48.49365234375 29.897805610155874,47.61474609375 31.39115752282472,47.87841796875 31.784216884487385,47.3291015625 32.52828936482526,46.05468749999999 33.04550781490999,45.439453125 34.615126683462194,46.23046874999999 35.29943548054545,46.021728515625 35.71083783530009,46.3623046875 35.808904044068626,45.32958984374999 35.98689628443789,44.23095703125 37.92686760148135,44.4287109375 38.324420427006544,43.9892578125 39.40224434029275,44.62646484375 39.740986355883564,45.59326171875 38.94232097947902,46.58203125 38.87392853923629,47.98828124999999 39.690280594818034,48.40576171875 39.35129035526705,48.18603515625 39.21523130910491,48.31787109375 38.94232097947902,47.96630859375 38.805470223177466,48.88916015625 38.44498466889473,49.0869140625 37.50972584293751,50.25146484375 37.33522435930639,54.140625 36.79169061907076,53.96484375 37.33522435930639,54.7998046875 37.43997405227057,54.7998046875 37.70120736474139,55.74462890625 38.16911413556086,56.31591796875 38.048091067457236,56.84326171875 38.272688535980976,59.45800781249999 37.49229399862877,61.19384765625 36.54494944148322,60.77636718749999 34.470335121217474,61.04003906249999 34.34343606848294,60.57861328125 34.288991865037524,60.53466796874999 33.55970664841198,60.97412109375 33.55970664841198,60.55664062499999 33.100745405144245,60.8642578125 31.50362930577303,61.787109375 31.353636941500987,61.87499999999999 30.826780904779774,60.88623046875001 29.80251790576445,61.80908203125 28.555576049185973,62.75390625 28.285033294640684,62.7978515625 27.235094607795503,63.369140625 27.196014383173306,63.21533203124999 26.588527147308614,61.94091796875 26.23430203240673,61.65527343749999 25.105497373014686,57.2607421875 25.799891182088334,56.66748046875 27.196014383173306,55.74462890625 26.293415004265796,52.6904296875 26.54922257769204,49.9658203125 30.164126343161097,48.88916015625 30.334953881988564,48.988037109375 30.066716983885613,48.6749267578125 30.012030680358613,48.69140625 29.916852233070173,48.49365234375 29.897805610155874)');
	return st_within(st_makepoint(longitude,latitude),iran);
END;
$$;


--
-- TOC entry 927 (class 1255 OID 21737)
-- Name: last_status(text, date); Type: FUNCTION; Schema: data; Owner: -
--

CREATE FUNCTION data.last_status(sensor_ids text, input_date date) RETURNS json
    LANGUAGE plpgsql
    AS $$
DECLARE
 rec RECORD;
 _id int;
 sensor_status text;
 result json;
 end_of_day timestamp;
 alarm_count int default 0;
BEGIN
 SET TIMEZONE='Asia/Tehran';
 drop table if exists sensor_ids_temp_table;
 create temp table sensor_ids_temp_table(id int);
 foreach _id in array string_to_array(sensor_ids,',')
  loop
  	insert into sensor_ids_temp_table (id)values(_id);
  end loop;
  if input_date=now()::date then
   select json_agg(
   row_to_json(
    (select cname from(
     select s.id as sensor_id,p.name as province,u.name as university,
     c.name as center,w.name as warehouse,r.name as room,
     s.name as sensor,s.is_fixed as is_fixed,s.type as type,
     case when s.is_fixed then s.latitude else d.latitude end as latitude,
     case when s.is_fixed then s.longitude else d.longitude end as longitude,
     case when d.temperature between -50 and 100 then text(d.temperature) else 'xx' end as temperature,
	 case when d.humidity between 0 and 100 then text(d.humidity) else 'xx' end as humidity,
	 case when d.temperature_max between -50 and 100 then text(d.temperature_max) else 'xx' end as temperature_max,
	 case when d.temperature_min between -50 and 100 then text(d.temperature_min) else 'xx' end as temperature_min,
     case when d.humidity_max between 0 and 100 then text(d.humidity_max) else 'xx' end as humidity_max,
	 case when d.humidity_min between 0 and 100 then text(d.humidity_min) else 'xx' end as humidity_min,
	 s.number_plate as number_plate,
     concat('/media/',c.logo) as logo,
     (
       select data.timestamp_to_jalali(min(fldt.first_log_date_time))
       from data.sensor_last_data fldt where fldt.sensor_id=s.id
	 ) as first_log_date_time,
     data.timestamp_to_jalali(d.last_log_date_time) as last_log_date_time,
     case
     when not s.is_active then
     'deactive'
     when not s.is_at_service then
     'out-of-service'
     when d.last_log_date_time::date<now()::date then
     'offline'
	 when d.last_log_date_time::date=now()::date
      and data.alarm_count_sum(s.id,now()::date,now()::date)>0 then
     'alarm'
	 when extract(epoch from(now() - d.last_log_date_time))>1800 then
     'half-online'
	 when extract(epoch from(now() - d.last_log_date_time))<=1800 then
     'online'
    end as status,
    json_build_object(
    'temperature_max',data.temperature_max_alarm(s.id,input_date,input_date),
    'temperature_min',data.temperature_min_alarm(s.id,input_date,input_date),
    'humidity_max',data.humidity_max_alarm(s.id,input_date,input_date),
    'humidity_min',data.humidity_min_alarm(s.id,input_date,input_date)
    ) as alarms)as cname)
    )
   ) into result
  from api.core_province p
  left join api.core_university u on p.id=u.province_id
  left join api.core_center c on u.id=c.university_id
  left join api.core_warehouse w on c.id=w.center_id
  left join api.core_room r on w.id=r.warehouse_id
  left join api.core_sensor s on r.id=s.room_id
  left join (
    select distinct on (sensor_id)
	sensor_id,temperature,humidity,temperature_min,temperature_max,
	humidity_min,humidity_max,latitude,longitude,
	max(last_log_date_time) over(partition by sensor_id) as last_log_date_time
    from data.sensor_last_data
    where last_log_date_time::date<=input_date
  ) d on s.id=d.sensor_id
  right join sensor_ids_temp_table si on si.id=s.id;
-- previous days
  else
   end_of_day = format('%s %s',input_date,'23:59:59');
   select json_agg(
   row_to_json(
    (select cname from(
     select s.id as sensor_id,p.name as province,u.name as university,
     c.name as center,w.name as warehouse,r.name as room,
     s.name as sensor,s.is_fixed as is_fixed,s.type as type,
     case when s.is_fixed then s.latitude else d.latitude end as latitude,
     case when s.is_fixed then s.longitude else d.longitude end as longitude,
     case when d.temperature between -50 and 100 then text(d.temperature) else 'xx' end as temperature,
	 case when d.humidity between 0 and 100 then text(d.humidity) else 'xx' end as humidity,
	 case when d.temperature_max between -50 and 100 then text(d.temperature_max) else 'xx' end as temperature_max,
	 case when d.temperature_min between -50 and 100 then text(d.temperature_min) else 'xx' end as temperature_min,
     case when d.humidity_max between 0 and 100 then text(d.humidity_max) else 'xx' end as humidity_max,
	 case when d.humidity_min between 0 and 100 then text(d.humidity_min) else 'xx' end as humidity_min,
     concat('/media/',c.logo) as logo,
     (select data.timestamp_to_jalali(min(fldt.first_log_date_time))
				  from data.sensor_last_data fldt where fldt.sensor_id=s.id) as first_log_date_time,
     data.timestamp_to_jalali(d.last_log_date_time) as last_log_date_time,
     case
     when not s.is_active then
     'deactive'
     when not s.is_at_service then
     'out-of-service'
     when d.last_log_date_time::date<end_of_day::date then
     'offline'
	 when d.last_log_date_time::date=end_of_day::date
      and data.alarm_count_sum(s.id,end_of_day::date,end_of_day::date)>0 then
     'alarm'
	 when extract(epoch from(end_of_day - d.last_log_date_time))>1800 then
     'half-online'
	 when extract(epoch from(end_of_day - d.last_log_date_time))<=1800 then
     'online'
    end as status,
    json_build_object(
    'temperature_max',data.temperature_max_alarm(s.id,input_date,input_date),
    'temperature_min',data.temperature_min_alarm(s.id,input_date,input_date),
    'humidity_max',data.humidity_max_alarm(s.id,input_date,input_date),
    'humidity_min',data.humidity_min_alarm(s.id,input_date,input_date)
    ) as alarms)as cname)
    )
   ) into result
  from api.core_province p
  left join api.core_university u on p.id=u.province_id
  left join api.core_center c on u.id=c.university_id
  left join api.core_warehouse w on c.id=w.center_id
  left join api.core_room r on w.id=r.warehouse_id
  left join api.core_sensor s on r.id=s.room_id
  left join (
    select distinct on (sensor_id)
	sensor_id,temperature,humidity,temperature_min,temperature_max,
	humidity_min,humidity_max,latitude,longitude,
	max(last_log_date_time) over(partition by sensor_id) as last_log_date_time
    from data.sensor_last_data
    where last_log_date_time::date<=input_date
  ) d on s.id=d.sensor_id
  right join sensor_ids_temp_table si on si.id=s.id;
  end if;
 return result;
END;
$$;


--
-- TOC entry 898 (class 1255 OID 21738)
-- Name: new_table(date); Type: FUNCTION; Schema: data; Owner: -
--

CREATE FUNCTION data.new_table(input_date date) RETURNS text
    LANGUAGE plpgsql
    AS $$

DECLARE
	tbl_name text default 
		concat('sensor_data_',to_char(input_date::date,'yymmdd')); 
	rec RECORD;
	counter int;
BEGIN
	if exists(SELECT 1 FROM information_schema.tables 
			  WHERE table_schema='data' and TABLE_NAME=tbl_name)
			  then
		return tbl_name;
	end if;
	insert into data.tables (created,table_name) values
	(input_date::date,tbl_name);
	execute(format('CREATE SEQUENCE data.%s_id_seq
			INCREMENT 1
			START 1
			MINVALUE 1
			MAXVALUE 2147483647
			CACHE 1;
			ALTER SEQUENCE data.%s_id_seq
			OWNER TO sensor;',tbl_name,tbl_name));
	execute(
		format('create table data.%s (like data.sensor_data);
			    alter table data.%s 
			    ALTER COLUMN id set default nextval(''data.%s_id_seq'')',
			  tbl_name,tbl_name,tbl_name)
		);
	execute(
		format('ALTER TABLE data.%s
    ADD UNIQUE (branch_id, room_id, sensor_id, log_date_time);',tbl_name)
	);
	execute(
		format('CREATE TRIGGER last_status 
			    BEFORE INSERT
    			ON data.%s
			    FOR EACH ROW
    			EXECUTE PROCEDURE data.check_last_status();'
			  ,tbl_name)
		);
	return tbl_name;
END;
$$;


--
-- TOC entry 896 (class 1255 OID 21739)
-- Name: sensor_details(integer, date); Type: FUNCTION; Schema: data; Owner: -
--

CREATE FUNCTION data.sensor_details(input_sensor_id integer, input_date date) RETURNS json
    LANGUAGE plpgsql
    AS $_$

DECLARE
    rec1 RECORD;
	rec2 RECORD;
	start_rec RECORD;
	stop_rec RECORD;
	total_distance double precision default 0;
	tbl_name text;
	q text;
	result json;
	dist float default 0;
	total_dist float default 0;
	_sensor_id char(8);
	_room_id char(8);
	_warehouse_id char(8);
	_latitude double precision default null;
	_longitude double precision default null;
	is_fixed_sensor boolean default true;
	tmin double precision;
	tmax double precision;
	hmin double precision;
	hmax double precision;
BEGIN

	select into _sensor_id,_room_id,_warehouse_id,tmin,tmax,hmin,hmax,
	is_fixed_sensor,_latitude,_longitude
	s.sensor_id,r.room_id,w.warehouse_id,s.temp_min_val,s.temp_max_val,
	s.hum_min_val,s.hum_max_val,s.is_fixed,s.latitude,s.longitude
	from api.core_warehouse w
	left join api.core_room r on w.id=r.warehouse_id
	left join api.core_sensor s on r.id=s.room_id
	where s.id=input_sensor_id;
	
	if _sensor_id is null or input_date is null then
 		return null;
	end if;
	
	select table_name into tbl_name from data.tables where created=input_date;
	if tbl_name is null then
		return null;
	end if;
	
	tbl_name = concat('data.',tbl_name);

-- 	execute('select max(temperature) as mean_speed
-- 			from '||tbl_name||' where device_id='||dvc_id) into speed_rec;
	EXECUTE('SELECT sensor_type FROM '||tbl_name||' where branch_id=$1 and room_id=$2 and
	sensor_id=$3') into start_rec
	using _warehouse_id,_room_id,_sensor_id;
	
	if is_fixed_sensor then -- fixed sensor
		drop table if exists sensor_details_temp_table;
		CREATE TEMPORARY TABLE sensor_details_temp_table(
			temperature double precision,
			humidity double precision,
			log_date_time timestamp
		);
		q='SELECT temperature,humidity,log_date_time
		FROM '||tbl_name||' where branch_id=$1 and room_id=$2 and
		sensor_id=$3';
		EXECUTE(CONCAT(q,' order by log_date_time asc limit 1')) into start_rec
		using _warehouse_id,_room_id,_sensor_id;
		EXECUTE(CONCAT(q,' order by log_date_time desc limit 1')) into stop_rec
		using _warehouse_id,_room_id,_sensor_id;
		rec1=start_rec;
		for rec2 in execute(q) using _warehouse_id,_room_id,_sensor_id
		loop

			insert into sensor_details_temp_table(
				temperature,humidity,log_date_time
			)values(
				rec2.temperature,rec2.humidity,
				rec2.log_date_time
			);
			rec1=rec2;
		end loop;
		if not exists(select 1 from sensor_details_temp_table) then
			return null;
		end if;
		select json_build_object(
			'points',
			json_agg(
				row_to_json(
					(select cname from(select temperature,humidity,
							   data.timestamp_to_jalali(log_date_time)) as cname)
				)
			),
-- 			'start',row_to_json(start_rec),
-- 			'stop',row_to_json(stop_rec),
			'longitude',_longitude,
			'latitude',_latitude,
			'tmin',tmin,
			'tmax',tmax,
			'hmin',hmin,
			'hmax',hmax,
			'alarms',
			json_build_object(
				'temperature_max',data.temperature_max_alarm(input_sensor_id,input_date,input_date),
				'temperature_min',data.temperature_min_alarm(input_sensor_id,input_date,input_date),
				'humidity_max',data.humidity_max_alarm(input_sensor_id,input_date,input_date),
				'humidity_min',data.humidity_min_alarm(input_sensor_id,input_date,input_date)
			)
		) into result
		from sensor_details_temp_table;
	else -- moving sensor
		drop table if exists sensor_details_temp_table;
		CREATE TEMPORARY TABLE sensor_details_temp_table(
			longitude double precision,
			latitude double precision,
			temperature double precision,
			humidity double precision,
			log_date_time timestamp
		);
		q='SELECT longitude,latitude,temperature,humidity,log_date_time
		FROM '||tbl_name||' where branch_id=$1 and room_id=$2 and
		sensor_id=$3';
		EXECUTE(CONCAT(q,' order by log_date_time asc limit 1')) into start_rec
		using _warehouse_id,_room_id,_sensor_id;
		EXECUTE(CONCAT(q,' order by log_date_time desc limit 1')) into stop_rec
		using _warehouse_id,_room_id,_sensor_id;
		rec1=start_rec;
		for rec2 in execute(q) using _warehouse_id,_room_id,_sensor_id
		loop
			dist = dist + st_distance(st_makepoint(rec2.longitude,rec2.latitude),
	 						   st_makepoint(rec1.longitude,rec1.latitude),false);
			insert into sensor_details_temp_table(
				longitude,latitude,temperature,humidity,log_date_time
			)values(
				rec2.longitude,rec2.latitude,rec2.temperature,rec2.humidity,
				rec2.log_date_time
			);
			rec1=rec2;
		end loop;
		if not exists(select 1 from sensor_details_temp_table) then
			return null;
		end if;
	 	dist = dist/1000;
		select json_build_object(
			'points',
			json_agg(
				row_to_json(
					(select cname from(select longitude,latitude,temperature,humidity,
							   data.timestamp_to_jalali(log_date_time)) as cname)
				)
			),
-- 			'start',row_to_json(start_rec),
-- 			'stop',row_to_json(stop_rec)
			'tmin',tmin,
			'tmax',tmax,
			'hmin',hmin,
			'hmax',hmax,
			'alarms',
			json_build_object(
				'temperature_max',data.temperature_max_alarm(input_sensor_id,input_date,input_date),
				'temperature_min',data.temperature_min_alarm(input_sensor_id,input_date,input_date),
				'humidity_max',data.humidity_max_alarm(input_sensor_id,input_date,input_date),
				'humidity_min',data.humidity_min_alarm(input_sensor_id,input_date,input_date)
			)
		) into result
		from sensor_details_temp_table;
	end if;
	return result;
END;
$_$;


--
-- TOC entry 929 (class 1255 OID 21740)
-- Name: sensor_details(integer, date, date); Type: FUNCTION; Schema: data; Owner: -
--

CREATE FUNCTION data.sensor_details(input_sensor_id integer, from_date date, to_date date) RETURNS json
    LANGUAGE plpgsql
    AS $_$
DECLARE
    rec1 RECORD;
	rec2 RECORD;
	start_rec RECORD;
	stop_rec RECORD;
	tbl_rec RECORD;
	total_distance double precision default 0;
	tbl_name text;
	q text;
	result json;
	dist float default 0;
	total_dist float default 0;
	_sensor_id char(8);
	_room_id char(8);
	_warehouse_id char(8);
	_latitude double precision default null;
	_longitude double precision default null;
	_sensor_type char(2);
	is_fixed_sensor boolean default true;
	tmin double precision;
	tmax double precision;
	hmin double precision;
	hmax double precision;
BEGIN
	select into _sensor_id,_room_id,_warehouse_id,tmin,tmax,hmin,hmax,
	is_fixed_sensor,_latitude,_longitude,_sensor_type
	s.sensor_id,r.room_id,w.warehouse_id,s.temp_min_val,s.temp_max_val,
	s.hum_min_val,s.hum_max_val,s.is_fixed,s.latitude,s.longitude,s.type
	from api.core_warehouse w
	left join api.core_room r on w.id=r.warehouse_id
	left join api.core_sensor s on r.id=s.room_id
	where s.id=input_sensor_id;
	
	if _sensor_id is null or from_date is null or to_date is null then
 		return null;
	end if;
	
	if is_fixed_sensor then -- fixed sensor
		if _sensor_type='th' then
			select json_build_object(
				'points',
				data.summarize_data(_warehouse_id,_room_id,_sensor_id,from_date,to_date),
				'longitude',_longitude,
				'latitude',_latitude,
				'tmin',tmin,
				'tmax',tmax,
				'hmin',hmin,
				'hmax',hmax,
				'sensor_type',_sensor_type,
				'alarms',
				json_build_object(
					'temperature_max',data.temperature_max_alarm(input_sensor_id,from_date,to_date),
					'temperature_min',data.temperature_min_alarm(input_sensor_id,from_date,to_date),
					'humidity_max',data.humidity_max_alarm(input_sensor_id,from_date,to_date),
					'humidity_min',data.humidity_min_alarm(input_sensor_id,from_date,to_date)
				)
			) into result;
		elseif _sensor_type='t' then
			select json_build_object(
				'points',
				data.summarize_data(_warehouse_id,_room_id,_sensor_id,from_date,to_date),
				'longitude',_longitude,
				'latitude',_latitude,
				'tmin',tmin,
				'tmax',tmax,
				'sensor_type',_sensor_type,
				'alarms',
				json_build_object(
					'temperature_max',data.temperature_max_alarm(input_sensor_id,from_date,to_date),
					'temperature_min',data.temperature_min_alarm(input_sensor_id,from_date,to_date)
				)
			) into result;
		end if;
	else -- moving sensor
		for tbl_rec in select table_name from data.tables
			where created between from_date and to_date
		loop
			tbl_name = concat('data.',tbl_rec.table_name);
			q='SELECT longitude,latitude FROM '||tbl_name||
			' where branch_id=$1 and room_id=$2 and sensor_id=$3';
			EXECUTE(CONCAT(q,' order by log_date_time asc limit 1')) into start_rec
			using _warehouse_id,_room_id,_sensor_id;
			EXECUTE(CONCAT(q,' order by log_date_time desc limit 1')) into stop_rec
			using _warehouse_id,_room_id,_sensor_id;
			rec1=start_rec;
			for rec2 in execute(q) using _warehouse_id,_room_id,_sensor_id
			loop
				dist = dist + st_distance(st_makepoint(rec2.longitude,rec2.latitude),
								   st_makepoint(rec1.longitude,rec1.latitude),false);
				rec1=rec2;
			end loop;
		end loop;
		
	 	dist = dist/1000;
		if _sensor_type='th' then
			select json_build_object(
				'points',
				data.summarize_data(_warehouse_id,_room_id,_sensor_id,from_date,to_date),
				'tmin',tmin,
				'tmax',tmax,
				'hmin',hmin,
				'hmax',hmax,
				'sensor_type',_sensor_type,
				'alarms',
				json_build_object(
					'temperature_max',data.temperature_max_alarm(input_sensor_id,from_date,to_date),
					'temperature_min',data.temperature_min_alarm(input_sensor_id,from_date,to_date),
					'humidity_max',data.humidity_max_alarm(input_sensor_id,from_date,to_date),
					'humidity_min',data.humidity_min_alarm(input_sensor_id,from_date,to_date)
				)
			) into result;
		elseif _sensor_type='t' then
			select json_build_object(
				'points',
				data.summarize_data(_warehouse_id,_room_id,_sensor_id,from_date,to_date),
				'tmin',tmin,
				'tmax',tmax,
				'sensor_type',_sensor_type,
				'alarms',
				json_build_object(
					'temperature_max',data.temperature_max_alarm(input_sensor_id,from_date,to_date),
					'temperature_min',data.temperature_min_alarm(input_sensor_id,from_date,to_date)
				)
			) into result;
		end if;
	end if;
	return result;
END;
$_$;


--
-- TOC entry 904 (class 1255 OID 21741)
-- Name: sensor_details_report(integer, date, date); Type: FUNCTION; Schema: data; Owner: -
--

CREATE FUNCTION data.sensor_details_report(input_sensor_id integer, from_date date, to_date date) RETURNS json
    LANGUAGE plpgsql
    AS $_$

DECLARE
    rec1 RECORD;
	rec2 RECORD;
	start_rec RECORD;
	stop_rec RECORD;
	total_distance double precision default 0;
	tbl_rec RECORD;
	tbl_name text;
	q text;
	result json;
	dist float default 0;
	total_dist float default 0;
	_sensor_id char(8);
	_room_id char(8);
	_warehouse_id char(8);
	is_fixed_sensor boolean default true;
	tmin double precision;
	tmax double precision;
	hmin double precision;
	hmax double precision;
BEGIN

	select into _sensor_id,_room_id,_warehouse_id,tmin,tmax,hmin,hmax,
	is_fixed_sensor
	s.sensor_id,r.room_id,w.warehouse_id,s.temp_min_val,s.temp_max_val,
	s.hum_min_val,s.hum_max_val,s.is_fixed
	from api.core_warehouse w
	left join api.core_room r on w.id=r.warehouse_id
	left join api.core_sensor s on r.id=s.room_id
	where s.id=input_sensor_id;

	if _sensor_id is null or from_date is null or to_date is null then
 		return null;
	end if;

	if is_fixed_sensor then -- fixed sensor
		drop table if exists sensor_details_temp_table;
		CREATE TEMPORARY TABLE sensor_details_temp_table(
			temperature double precision,
			humidity double precision,
			log_date_time timestamp
		);
		for tbl_rec in select table_name from data.tables 
			where created>=from_date and created<=to_date
		loop
			tbl_name = concat('data.',tbl_rec.table_name);
			q='SELECT temperature,humidity,log_date_time
			FROM '||tbl_name||' where branch_id=$1 and room_id=$2 and
			sensor_id=$3';
			EXECUTE(CONCAT(q,' order by log_date_time asc limit 1')) into start_rec
			using _warehouse_id,_room_id,_sensor_id;
			EXECUTE(CONCAT(q,' order by log_date_time desc limit 1')) into stop_rec
			using _warehouse_id,_room_id,_sensor_id;
			rec1=start_rec;
			for rec2 in execute(q) using _warehouse_id,_room_id,_sensor_id
			loop
				insert into sensor_details_temp_table(
					temperature,humidity,log_date_time
				)values(
					rec2.temperature,rec2.humidity,
					rec2.log_date_time
				);
				rec1=rec2;
			end loop;
		end loop;
		if not exists(select 1 from sensor_details_temp_table) then
			return null;
		end if;
		select json_build_object(
			'points',
			json_agg(
				row_to_json(
					(select cname from(select temperature,humidity,
							   log_date_time) as cname)
				)
			),
-- 			'start',row_to_json(start_rec),
-- 			'stop',row_to_json(stop_rec),
			'tmin',tmin,
			'tmax',tmax,
			'hmin',hmin,
			'hmax',hmax,
			'alarms',
			json_build_object(
				'temperature_max',data.temperature_max_alarm(input_sensor_id,from_date,to_date),
				'temperature_min',data.temperature_min_alarm(input_sensor_id,from_date,to_date),
				'humidity_max',data.humidity_max_alarm(input_sensor_id,from_date,to_date),
				'humidity_min',data.humidity_min_alarm(input_sensor_id,from_date,to_date)
			)
		) into result
		from sensor_details_temp_table;
	else -- moving sensor
		drop table if exists sensor_details_temp_table;
		CREATE TEMPORARY TABLE sensor_details_temp_table(
			longitude double precision,
			latitude double precision,
			temperature double precision,
			humidity double precision,
			log_date_time timestamp
		);
		for tbl_rec in select table_name from data.tables 
			where created between from_date and to_date
		loop
			tbl_name = concat('data.',tbl_rec.table_name);
			q='SELECT longitude,latitude,temperature,humidity,log_date_time
			FROM '||tbl_name||' where branch_id=$1 and room_id=$2 and
			sensor_id=$3';
			EXECUTE(CONCAT(q,' order by log_date_time asc limit 1')) into start_rec
			using _warehouse_id,_room_id,_sensor_id;
			EXECUTE(CONCAT(q,' order by log_date_time desc limit 1')) into stop_rec
			using _warehouse_id,_room_id,_sensor_id;
			rec1=start_rec;
			for rec2 in execute(q) using _warehouse_id,_room_id,_sensor_id
			loop
				dist = dist + st_distance(st_makepoint(rec2.longitude,rec2.latitude),
								   st_makepoint(rec1.longitude,rec1.latitude),false);
				insert into sensor_details_temp_table(
					longitude,latitude,temperature,humidity,log_date_time
				)values(
					rec2.longitude,rec2.latitude,rec2.temperature,rec2.humidity,
					rec2.log_date_time
				);
				rec1=rec2;
			end loop;
		end loop;
		if not exists(select 1 from sensor_details_temp_table) then
			return null;
		end if;
	 	dist = dist/1000;
		select json_build_object(
			'points',
			json_agg(
				row_to_json(
					(select cname from(select longitude,latitude,temperature,humidity,
							   log_date_time) as cname)
				)
			),
-- 			'start',row_to_json(start_rec),
-- 			'stop',row_to_json(stop_rec)
			'tmin',tmin,
			'tmax',tmax,
			'hmin',hmin,
			'hmax',hmax,
	 		'total_distance',to_json(dist),
			'alarms',
			json_build_object(
				'temperature_max',data.temperature_max_alarm(input_sensor_id,from_date,to_date),
				'temperature_min',data.temperature_min_alarm(input_sensor_id,from_date,to_date),
				'humidity_max',data.humidity_max_alarm(input_sensor_id,from_date,to_date),
				'humidity_min',data.humidity_min_alarm(input_sensor_id,from_date,to_date)
			)
		) into result
		from sensor_details_temp_table;
	end if;
	return result;
END;
$_$;


--
-- TOC entry 916 (class 1255 OID 21742)
-- Name: sensor_details_report(integer, date, date, time without time zone, time without time zone); Type: FUNCTION; Schema: data; Owner: -
--

CREATE FUNCTION data.sensor_details_report(input_sensor_id integer, from_date date, to_date date, from_time time without time zone DEFAULT '00:00:00'::time without time zone, to_time time without time zone DEFAULT '23:59:59'::time without time zone) RETURNS json
    LANGUAGE plpgsql
    AS $_$

DECLARE
    rec1 RECORD;
	rec2 RECORD;
	start_rec RECORD;
	stop_rec RECORD;
	total_distance double precision default 0;
	tbl_rec RECORD;
	tbl_name text;
	q text;
	result json;
	dist float default 0;
	total_dist float default 0;
	_sensor_id char(8);
	_room_id char(8);
	_warehouse_id char(8);
	is_fixed_sensor boolean default true;
	start_datetime timestamp default null;
	end_datetime timestamp default null;
	tmin double precision;
	tmax double precision;
	hmin double precision;
	hmax double precision;
BEGIN

	select into _sensor_id,_room_id,_warehouse_id,tmin,tmax,hmin,hmax,
	is_fixed_sensor
	s.sensor_id,r.room_id,w.warehouse_id,s.temp_min_val,s.temp_max_val,
	s.hum_min_val,s.hum_max_val,s.is_fixed
	from api.core_warehouse w
	left join api.core_room r on w.id=r.warehouse_id
	left join api.core_sensor s on r.id=s.room_id
	where s.id=input_sensor_id;

	if _sensor_id is null or from_date is null or to_date is null then
 		return null;
	end if;

	if is_fixed_sensor then -- fixed sensor
		drop table if exists sensor_details_temp_table;
		CREATE TEMPORARY TABLE sensor_details_temp_table(
			temperature double precision,
			humidity double precision,
			date text,
			time time
		);
		for tbl_rec in select table_name from data.tables 
			where created between from_date and to_date
		loop
			tbl_name = concat('data.',tbl_rec.table_name);
			q='SELECT temperature,humidity,log_date_time
			FROM '||tbl_name||' where branch_id=$1 and room_id=$2 and
			sensor_id=$3';
			EXECUTE(CONCAT(q,' order by log_date_time asc limit 1')) into start_rec
			using _warehouse_id,_room_id,_sensor_id;
			EXECUTE(CONCAT(q,' order by log_date_time desc limit 1')) into stop_rec
			using _warehouse_id,_room_id,_sensor_id;
			rec1=start_rec;
			if start_datetime is null then
				start_datetime = start_rec.log_date_time;
			end if;
			for rec2 in execute(q) using _warehouse_id,_room_id,_sensor_id
			loop
				insert into sensor_details_temp_table(
					temperature,humidity,date,time
				)values(
					rec2.temperature,rec2.humidity,
					data.date_to_jalali(rec2.log_date_time::date),
					rec2.log_date_time::time
				);
				rec1=rec2;
			end loop;
		end loop;
		if not exists(select 1 from sensor_details_temp_table) then
			return null;
		end if;
		select json_build_object(
			'points',
			json_agg(
				row_to_json(
					(select cname from(select temperature,humidity,
							   date,time) as cname)
				)
			),
-- 			'start',row_to_json(start_rec),
-- 			'stop',row_to_json(stop_rec),
			'from',data.timestamp_to_jalali(start_datetime),
			'to',data.timestamp_to_jalali(rec2.log_date_time),
			'tmin',tmin,
			'tmax',tmax,
			'hmin',hmin,
			'hmax',hmax,
			'alarms',data.all_alarms(input_sensor_id,from_date,to_date,from_time,to_time)

		) into result
		from sensor_details_temp_table;
	else -- moving sensor
		drop table if exists sensor_details_temp_table;
		CREATE TEMPORARY TABLE sensor_details_temp_table(
			longitude double precision,
			latitude double precision,
			temperature double precision,
			humidity double precision,
			date text,
			time time
		);
		for tbl_rec in select table_name from data.tables
			where created between from_date and to_date
		loop
			tbl_name = concat('data.',tbl_rec.table_name);
			q='SELECT longitude,latitude,temperature,humidity,log_date_time
			FROM '||tbl_name||' where branch_id=$1 and room_id=$2 and
			sensor_id=$3';
			EXECUTE(CONCAT(q,' order by log_date_time asc limit 1')) into start_rec
			using _warehouse_id,_room_id,_sensor_id;
			EXECUTE(CONCAT(q,' order by log_date_time desc limit 1')) into stop_rec
			using _warehouse_id,_room_id,_sensor_id;
			rec1=start_rec;
			if start_datetime is null then
				start_datetime = start_rec.log_date_time;
			end if;
			for rec2 in execute(q) using _warehouse_id,_room_id,_sensor_id
			loop
				dist = dist + st_distance(st_makepoint(rec2.longitude,rec2.latitude),
								   st_makepoint(rec1.longitude,rec1.latitude),false);
				insert into sensor_details_temp_table(
					longitude,latitude,temperature,humidity,date,time
				)values(
					rec2.longitude,rec2.latitude,rec2.temperature,rec2.humidity,
					data.date_to_jalali(rec2.log_date_time::date),
					rec2.log_date_time::time
				);
				rec1=rec2;
			end loop;
		end loop;
		if not exists(select 1 from sensor_details_temp_table) then
			return null;
		end if;
	 	dist = dist/1000;
		select json_build_object(
			'points',
			json_agg(
				row_to_json(
					(select cname from(select longitude,latitude,temperature,humidity,
							   date,time) as cname)
				)
			),
-- 			'start',row_to_json(start_rec),
-- 			'stop',row_to_json(stop_rec)
			'from',data.timestamp_to_jalali(start_datetime),
			'to',data.timestamp_to_jalali(rec2.log_date_time),
			'tmin',tmin,
			'tmax',tmax,
			'hmin',hmin,
			'hmax',hmax,
	 		'total_distance',to_json(dist),
			'alarms',data.all_alarms(input_sensor_id,from_date,to_date,from_time,to_time)

		) into result
		from sensor_details_temp_table;
	end if;
	return result;
END;
$_$;


--
-- TOC entry 905 (class 1255 OID 21743)
-- Name: sensor_details_report_old(integer, date, date); Type: FUNCTION; Schema: data; Owner: -
--

CREATE FUNCTION data.sensor_details_report_old(input_sensor_id integer, from_date date, to_date date) RETURNS json
    LANGUAGE plpgsql
    AS $_$

DECLARE
    rec1 RECORD;
	rec2 RECORD;
	start_rec RECORD;
	stop_rec RECORD;
	total_distance double precision default 0;
	tbl_rec RECORD;
	tbl_name text;
	q text;
	result json;
	dist float default 0;
	total_dist float default 0;
	_sensor_id char(8);
	_room_id char(8);
	_warehouse_id char(8);
	is_fixed_sensor boolean default true;
	start_datetime timestamp default null;
	end_datetime timestamp default null;
	tmin double precision;
	tmax double precision;
	hmin double precision;
	hmax double precision;
BEGIN

	select into _sensor_id,_room_id,_warehouse_id,tmin,tmax,hmin,hmax,
	is_fixed_sensor
	s.sensor_id,r.room_id,w.warehouse_id,s.temp_min_val,s.temp_max_val,
	s.hum_min_val,s.hum_max_val,s.is_fixed
	from api.core_warehouse w
	left join api.core_room r on w.id=r.warehouse_id
	left join api.core_sensor s on r.id=s.room_id
	where s.id=input_sensor_id;

	if _sensor_id is null or from_date is null or to_date is null then
 		return null;
	end if;

	if is_fixed_sensor then -- fixed sensor
		drop table if exists sensor_details_temp_table;
		CREATE TEMPORARY TABLE sensor_details_temp_table(
			temperature double precision,
			humidity double precision,
			date text,
			time time
		);
		for tbl_rec in select table_name from data.tables 
			where created between from_date and to_date
		loop
			tbl_name = concat('data.',tbl_rec.table_name);
			q='SELECT temperature,humidity,log_date_time
			FROM '||tbl_name||' where branch_id=$1 and room_id=$2 and
			sensor_id=$3';
			EXECUTE(CONCAT(q,' order by log_date_time asc limit 1')) into start_rec
			using _warehouse_id,_room_id,_sensor_id;
			EXECUTE(CONCAT(q,' order by log_date_time desc limit 1')) into stop_rec
			using _warehouse_id,_room_id,_sensor_id;
			rec1=start_rec;
			if start_datetime is null then
				start_datetime = start_rec.log_date_time;
			end if;
			for rec2 in execute(q) using _warehouse_id,_room_id,_sensor_id
			loop
				insert into sensor_details_temp_table(
					temperature,humidity,date,time
				)values(
					rec2.temperature,rec2.humidity,
					data.date_to_jalali(rec2.log_date_time::date),
					rec2.log_date_time::time
				);
				rec1=rec2;
			end loop;
		end loop;
		if not exists(select 1 from sensor_details_temp_table) then
			return null;
		end if;
		select json_build_object(
			'points',
			json_agg(
				row_to_json(
					(select cname from(select temperature,humidity,
							   date,time) as cname)
				)
			),
-- 			'start',row_to_json(start_rec),
-- 			'stop',row_to_json(stop_rec),
			'from',data.timestamp_to_jalali(start_datetime),
			'to',data.timestamp_to_jalali(rec2.log_date_time),
			'tmin',tmin,
			'tmax',tmax,
			'hmin',hmin,
			'hmax',hmax,
			'alarms',
			json_build_object(
				'temperature_max',data.temperature_max_alarm(input_sensor_id,from_date,to_date),
				'temperature_min',data.temperature_min_alarm(input_sensor_id,from_date,to_date),
				'humidity_max',data.humidity_max_alarm(input_sensor_id,from_date,to_date),
				'humidity_min',data.humidity_min_alarm(input_sensor_id,from_date,to_date)
			)
		) into result
		from sensor_details_temp_table;
	else -- moving sensor
		drop table if exists sensor_details_temp_table;
		CREATE TEMPORARY TABLE sensor_details_temp_table(
			longitude double precision,
			latitude double precision,
			temperature double precision,
			humidity double precision,
			date text,
			time time
		);
		for tbl_rec in select table_name from data.tables 
			where created between from_date and to_date
		loop
			tbl_name = concat('data.',tbl_rec.table_name);
			q='SELECT longitude,latitude,temperature,humidity,log_date_time
			FROM '||tbl_name||' where branch_id=$1 and room_id=$2 and
			sensor_id=$3';
			EXECUTE(CONCAT(q,' order by log_date_time asc limit 1')) into start_rec
			using _warehouse_id,_room_id,_sensor_id;
			EXECUTE(CONCAT(q,' order by log_date_time desc limit 1')) into stop_rec
			using _warehouse_id,_room_id,_sensor_id;
			rec1=start_rec;
			if start_datetime is null then
				start_datetime = start_rec.log_date_time;
			end if;
			for rec2 in execute(q) using _warehouse_id,_room_id,_sensor_id
			loop
				dist = dist + st_distance(st_makepoint(rec2.longitude,rec2.latitude),
								   st_makepoint(rec1.longitude,rec1.latitude),false);
				insert into sensor_details_temp_table(
					longitude,latitude,temperature,humidity,log_date_time
				)values(
					rec2.longitude,rec2.latitude,rec2.temperature,rec2.humidity,
					data.date_to_jalali(rec2.log_date_time::date),
					rec2.log_date_time::time
				);
				rec1=rec2;
			end loop;
		end loop;
		if not exists(select 1 from sensor_details_temp_table) then
			return null;
		end if;
	 	dist = dist/1000;
		select json_build_object(
			'points',
			json_agg(
				row_to_json(
					(select cname from(select longitude,latitude,temperature,humidity,
							   date,time) as cname)
				)
			),
-- 			'start',row_to_json(start_rec),
-- 			'stop',row_to_json(stop_rec)
			'from',data.timestamp_to_jalali(start_datetime),
			'to',data.timestamp_to_jalali(rec2.log_date_time),
			'tmin',tmin,
			'tmax',tmax,
			'hmin',hmin,
			'hmax',hmax,
	 		'total_distance',to_json(dist),
			'alarms',
			json_build_object(
				'temperature_max',data.temperature_max_alarm(input_sensor_id,from_date,to_date),
				'temperature_min',data.temperature_min_alarm(input_sensor_id,from_date,to_date),
				'humidity_max',data.humidity_max_alarm(input_sensor_id,from_date,to_date),
				'humidity_min',data.humidity_min_alarm(input_sensor_id,from_date,to_date)
			)
		) into result
		from sensor_details_temp_table;
	end if;
	return result;
END;
$_$;


--
-- TOC entry 915 (class 1255 OID 22170)
-- Name: sensor_details_report_t(integer, date, date, time without time zone, time without time zone); Type: FUNCTION; Schema: data; Owner: -
--

CREATE FUNCTION data.sensor_details_report_t(input_sensor_id integer, from_date date, to_date date, from_time time without time zone DEFAULT '00:00:00'::time without time zone, to_time time without time zone DEFAULT '23:59:59'::time without time zone) RETURNS json
    LANGUAGE plpgsql
    AS $_$
DECLARE
    rec1 RECORD;
	rec2 RECORD;
	start_rec RECORD;
	stop_rec RECORD;
	total_distance double precision default 0;
	tbl_rec RECORD;
	tbl_name text;
	q text;
	result json;
	dist float default 0;
	total_dist float default 0;
	_sensor_id char(8);
	_room_id char(8);
	_warehouse_id char(8);
	_sensor_type char(2);
	is_fixed_sensor boolean default true;
	start_datetime timestamp default null;
	end_datetime timestamp default null;
	tmin double precision;
	tmax double precision;
	hmin double precision;
	hmax double precision;
BEGIN

	select into _sensor_id,_room_id,_warehouse_id,tmin,tmax,hmin,hmax,
	is_fixed_sensor,_sensor_type
	s.sensor_id,r.room_id,w.warehouse_id,s.temp_min_val,s.temp_max_val,
	s.hum_min_val,s.hum_max_val,s.is_fixed,s.type
	from api.core_warehouse w
	left join api.core_room r on w.id=r.warehouse_id
	left join api.core_sensor s on r.id=s.room_id
	where s.id=input_sensor_id;

	if _sensor_id is null or from_date is null or to_date is null then
 		return null;
	end if;

	if is_fixed_sensor then -- fixed sensor
	    if _sensor_type='th' then
			drop table if exists sensor_details_temp_table;
			CREATE TEMPORARY TABLE sensor_details_temp_table(
				temperature double precision,
				humidity double precision,
				date text,
				time time
			);
			for tbl_rec in select table_name from data.tables 
				where created between from_date and to_date
			loop
				tbl_name = concat('data.',tbl_rec.table_name);
				q='SELECT temperature,humidity,log_date_time
				FROM '||tbl_name||' where branch_id=$1 and room_id=$2 and
				sensor_id=$3';
				EXECUTE(CONCAT(q,' order by log_date_time asc limit 1')) into start_rec
				using _warehouse_id,_room_id,_sensor_id;
				EXECUTE(CONCAT(q,' order by log_date_time desc limit 1')) into stop_rec
				using _warehouse_id,_room_id,_sensor_id;
				rec1=start_rec;
				if start_datetime is null then
					start_datetime = start_rec.log_date_time;
					end_datetime = start_datetime;
				end if;
				for rec2 in execute(q) using _warehouse_id,_room_id,_sensor_id
				loop
					insert into sensor_details_temp_table(
						temperature,humidity,date,time
					)values(
						rec2.temperature,rec2.humidity,
						data.date_to_jalali(rec2.log_date_time::date),
						rec2.log_date_time::time
					);
					rec1=rec2;
						end_datetime = rec2.log_date_time;
				end loop;
			end loop;
			if not exists(select 1 from sensor_details_temp_table) then
				return null;
			end if;
			select json_build_object(
				'points',
				json_agg(
					row_to_json(
						(select cname from(select temperature,humidity,
								   date,time) as cname)
					)
				),
	-- 			'start',row_to_json(start_rec),
	-- 			'stop',row_to_json(stop_rec),
				'from',data.timestamp_to_jalali(start_datetime),
				'to',data.timestamp_to_jalali(end_datetime),
				'tmin',tmin,
				'tmax',tmax,
				'hmin',hmin,
				'hmax',hmax,
				'alarms',data.all_alarms(input_sensor_id,from_date,to_date,from_time,to_time)

			) into result
			from sensor_details_temp_table;
		elseif _sensor_type='t' then
			drop table if exists sensor_details_temp_table;
			CREATE TEMPORARY TABLE sensor_details_temp_table(
				temperature double precision,
				date text,
				time time
			);
			for tbl_rec in select table_name from data.tables 
				where created between from_date and to_date
			loop
				tbl_name = concat('data.',tbl_rec.table_name);
				q='SELECT temperature,log_date_time
				FROM '||tbl_name||' where branch_id=$1 and room_id=$2 and
				sensor_id=$3';
				EXECUTE(CONCAT(q,' order by log_date_time asc limit 1')) into start_rec
				using _warehouse_id,_room_id,_sensor_id;
				EXECUTE(CONCAT(q,' order by log_date_time desc limit 1')) into stop_rec
				using _warehouse_id,_room_id,_sensor_id;
				rec1=start_rec;
				if start_datetime is null then
					start_datetime = start_rec.log_date_time;
					end_datetime = start_datetime;
				end if;
				for rec2 in execute(q) using _warehouse_id,_room_id,_sensor_id
				loop
					insert into sensor_details_temp_table(
						temperature,date,time
					)values(
						rec2.temperature,
						data.date_to_jalali(rec2.log_date_time::date),
						rec2.log_date_time::time
					);
					rec1=rec2;
						end_datetime = rec2.log_date_time;
				end loop;
			end loop;
			if not exists(select 1 from sensor_details_temp_table) then
				return null;
			end if;
			select json_build_object(
				'points',
				json_agg(
					row_to_json(
						(select cname from(select temperature,
								   date,time) as cname)
					)
				),
	-- 			'start',row_to_json(start_rec),
	-- 			'stop',row_to_json(stop_rec),
				'from',data.timestamp_to_jalali(start_datetime),
				'to',data.timestamp_to_jalali(end_datetime),
				'tmin',tmin,
				'tmax',tmax,
				'alarms',data.all_alarms(input_sensor_id,from_date,to_date,from_time,to_time)

			) into result
			from sensor_details_temp_table;
		end if;
	else -- moving sensor
		if _sensor_type='th' then
			drop table if exists sensor_details_temp_table;
			CREATE TEMPORARY TABLE sensor_details_temp_table(
				longitude double precision,
				latitude double precision,
				temperature double precision,
				humidity double precision,
				date text,
				time time
			);
			for tbl_rec in select table_name from data.tables 
				where created between from_date and to_date
			loop
				tbl_name = concat('data.',tbl_rec.table_name);
				q='SELECT longitude,latitude,temperature,humidity,log_date_time
				FROM '||tbl_name||' where branch_id=$1 and room_id=$2 and
				sensor_id=$3';
				EXECUTE(CONCAT(q,' order by log_date_time asc limit 1')) into start_rec
				using _warehouse_id,_room_id,_sensor_id;
				EXECUTE(CONCAT(q,' order by log_date_time desc limit 1')) into stop_rec
				using _warehouse_id,_room_id,_sensor_id;
				rec1=start_rec;
				if start_datetime is null then
					start_datetime = start_rec.log_date_time;
					end_datetime = start_datetime;
				end if;
				for rec2 in execute(q) using _warehouse_id,_room_id,_sensor_id
				loop
					dist = dist + st_distance(st_makepoint(rec2.longitude,rec2.latitude),
									   st_makepoint(rec1.longitude,rec1.latitude),false);
					insert into sensor_details_temp_table(
						longitude,latitude,temperature,humidity,date,time
					)values(
						rec2.longitude,rec2.latitude,rec2.temperature,rec2.humidity,
						data.date_to_jalali(rec2.log_date_time::date),
						rec2.log_date_time::time
					);
					rec1=rec2;
					end_datetime = rec2.log_date_time;

				end loop;
			end loop;
			if not exists(select 1 from sensor_details_temp_table) then
				return null;
			end if;
			dist = dist/1000;
			select json_build_object(
				'points',
				json_agg(
					row_to_json(
						(select cname from(select longitude,latitude,temperature,humidity,
								   date,time) as cname)
					)
				),
	-- 			'start',row_to_json(start_rec),
	-- 			'stop',row_to_json(stop_rec)
				'from',data.timestamp_to_jalali(start_datetime),
				'to',data.timestamp_to_jalali(end_datetime),
				'tmin',tmin,
				'tmax',tmax,
				'hmin',hmin,
				'hmax',hmax,
				'total_distance',to_json(dist),
				'alarms',data.all_alarms(input_sensor_id,from_date,to_date,from_time,to_time)

			) into result
			from sensor_details_temp_table;
		elsif _sensor_type='t' then
			drop table if exists sensor_details_temp_table;
			CREATE TEMPORARY TABLE sensor_details_temp_table(
				longitude double precision,
				latitude double precision,
				temperature double precision,
				date text,
				time time
			);
			for tbl_rec in select table_name from data.tables 
				where created between from_date and to_date
			loop
				tbl_name = concat('data.',tbl_rec.table_name);
				q='SELECT longitude,latitude,temperature,log_date_time
				FROM '||tbl_name||' where branch_id=$1 and room_id=$2 and
				sensor_id=$3';
				EXECUTE(CONCAT(q,' order by log_date_time asc limit 1')) into start_rec
				using _warehouse_id,_room_id,_sensor_id;
				EXECUTE(CONCAT(q,' order by log_date_time desc limit 1')) into stop_rec
				using _warehouse_id,_room_id,_sensor_id;
				rec1=start_rec;
				if start_datetime is null then
					start_datetime = start_rec.log_date_time;
					end_datetime = start_datetime;
				end if;
				for rec2 in execute(q) using _warehouse_id,_room_id,_sensor_id
				loop
					dist = dist + st_distance(st_makepoint(rec2.longitude,rec2.latitude),
									   st_makepoint(rec1.longitude,rec1.latitude),false);
					insert into sensor_details_temp_table(
						longitude,latitude,temperature,date,time
					)values(
						rec2.longitude,rec2.latitude,rec2.temperature,
						data.date_to_jalali(rec2.log_date_time::date),
						rec2.log_date_time::time
					);
					rec1=rec2;
					end_datetime = rec2.log_date_time;

				end loop;
			end loop;
			if not exists(select 1 from sensor_details_temp_table) then
				return null;
			end if;
			dist = dist/1000;
			select json_build_object(
				'points',
				json_agg(
					row_to_json(
						(select cname from(select longitude,latitude,temperature,
								   date,time) as cname)
					)
				),
	-- 			'start',row_to_json(start_rec),
	-- 			'stop',row_to_json(stop_rec)
				'from',data.timestamp_to_jalali(start_datetime),
				'to',data.timestamp_to_jalali(end_datetime),
				'tmin',tmin,
				'tmax',tmax,
				'total_distance',to_json(dist),
				'alarms',data.all_alarms(input_sensor_id,from_date,to_date,from_time,to_time)
			) into result
			from sensor_details_temp_table;
		end if;
	end if;
	return result;
END;
$_$;


--
-- TOC entry 928 (class 1255 OID 21744)
-- Name: summarize_data(character, character, character, date, date); Type: FUNCTION; Schema: data; Owner: -
--

CREATE FUNCTION data.summarize_data(_branch_id character, _room_id character, _sensor_id character, _from_date date, _to_date date) RETURNS json
    LANGUAGE plpgsql
    AS $_$
DECLARE
	snsr_id int default null;
	sensor_type char(2);
	rec RECORD;
	start_rec RECORD;
	last_rec RECORD;
	table_rec RECORD;
	q text default '';
	queries text[];
	result json default '[]'::json;
	tmin double precision default 99999;
	tmax double precision default 0;
	hmin double precision default 99999;
	hmax double precision default 0;
	hcounter int default 0;
	tcounter int default 0;
	hsum double precision default null;
	tsum double precision default null;
	tavg double precision default null;
	havg double precision default null;
	inserted boolean default false;
BEGIN
 	select s.type into sensor_type
 	from api.core_warehouse w left join
 	api.core_room r on w.id=r.warehouse_id left join
 	api.core_sensor s on r.id=s.room_id
 	where w.warehouse_id=_branch_id and
	r.room_id = _room_id and
	s.sensor_id=_sensor_id;

	if sensor_type='th' then
		drop table if exists sensor_data_temp_table;
		create temp table sensor_data_temp_table(
			log_date_time timestamp,
			latitude char(10),
			longitude char(10),
			temperature double precision,
			humidity double precision
		);
		for table_rec in select table_name from data.tables
			where created between _from_date and _to_date order by created asc
		loop
			q='select branch_id,room_id,sensor_id,sensor_type,log_date_time,
			 latitude,longitude,temperature,humidity
			 from data.'||table_rec.table_name||'
			 where branch_id=$1 and room_id=$2 and sensor_id=$3
			 order by log_date_time';
			EXECUTE(concat(q,' asc limit 1')) using _branch_id,_room_id,_sensor_id into start_rec;
			EXECUTE(concat(q,' desc limit 1')) using _branch_id,_room_id,_sensor_id into last_rec;
			inserted = false;
			for rec in execute('select branch_id,room_id,sensor_id,
			 sensor_type,log_date_time,latitude,longitude,temperature,humidity
			 from data.'||table_rec.table_name||'
			 where branch_id=$1 and room_id=$2 and sensor_id=$3
			 order by log_date_time asc'
			)using _branch_id,_room_id,_sensor_id
			loop
				inserted = false;
				if rec.humidity is not null and rec.humidity between 0 and 100 then
					if hsum is null then
						hsum = rec.humidity;
					else
						hsum = hsum + rec.humidity;
					end if;
					hcounter = hcounter + 1;
				end if;
				if rec.temperature is not null and rec.temperature between -50 and 100 then
					if tsum is null then
						tsum = rec.temperature;
					else
						tsum = tsum + rec.temperature;
					end if;
					tcounter = tcounter + 1;
				end if;
				--raise info '%r %r %r %r',counter,rec.temperature,tsum,extract(epoch from(rec.log_date_time-start_rec.log_date_time));
				if extract(epoch from(rec.log_date_time-start_rec.log_date_time))>=900 then

					if tcounter<>0 then
						tavg = round((tsum/tcounter)::numeric,2);
					end if;

					if hcounter<>0 then
						havg = round((hsum/hcounter)::numeric,2);
					end if;

					insert into sensor_data_temp_table(
						log_date_time,latitude,longitude,temperature,humidity
					)values(
						rec.log_date_time,
						case when start_rec.latitude is not null then floor(start_rec.latitude*1e8)
						else start_rec.latitude end,
						case when start_rec.longitude is not null then floor(start_rec.longitude*1e8)
						else start_rec.longitude end,
						tavg,havg
					);
					--raise info '%r',round((hsum/counter)::numeric,2);
					inserted = true;
					start_rec = rec;
					hcounter = 0;
					tcounter = 0;
					hsum = null;
					tsum = null;
				end if;
			end loop;
			if not inserted and start_rec.log_date_time is not null then
				if tcounter<>0 then
					tavg = round((tsum/tcounter)::numeric,2);
				end if;

				if hcounter<>0 then
					havg = round((hsum/hcounter)::numeric,2);
				end if;

				insert into sensor_data_temp_table(
						log_date_time,latitude,longitude,temperature,humidity
				)values(
					rec.log_date_time,
					case when start_rec.latitude is not null then floor(start_rec.latitude*1e8)
					else start_rec.latitude end,
					case when start_rec.longitude is not null then floor(start_rec.longitude*1e8)
					else start_rec.longitude end,
					tavg,havg
				);
			end if;
		end loop;
		select json_agg(
			row_to_json(
				(select cname from (
					select data.timestamp_to_jalali(log_date_time),
					latitude,longitude,temperature,humidity) as cname
				)
			)
		) into result
		from sensor_data_temp_table;
	elsif sensor_type='t' then
		drop table if exists sensor_data_temp_table;
		create temp table sensor_data_temp_table(
			log_date_time timestamp,
			latitude char(10),
			longitude char(10),
			temperature double precision
		);
		for table_rec in select table_name from data.tables
			where created between _from_date and _to_date order by created asc
		loop
			q='select branch_id,room_id,sensor_id,sensor_type,log_date_time,
			 latitude,longitude,temperature
			 from data.'||table_rec.table_name||'
			 where branch_id=$1 and room_id=$2 and sensor_id=$3
			 order by log_date_time';
			EXECUTE(concat(q,' asc limit 1'))
			using _branch_id,_room_id,_sensor_id into start_rec;
			EXECUTE(concat(q,' desc limit 1'))
			using _branch_id,_room_id,_sensor_id into last_rec;
			inserted = false;
			for rec in execute('select branch_id,room_id,sensor_id,
			 sensor_type,log_date_time,latitude,longitude,temperature
			 from data.'||table_rec.table_name||'
			 where branch_id=$1 and room_id=$2 and sensor_id=$3
			 order by log_date_time asc'
			)using _branch_id,_room_id,_sensor_id
			loop
				inserted = false;
				if rec.temperature is not null and rec.temperature between -50 and 100 then
					if tsum is null then
						tsum = rec.temperature;
					else
						tsum = tsum + rec.temperature;
					end if;
					tcounter = tcounter + 1;
				end if;
				--raise info '%r %r %r %r',counter,rec.temperature,tsum,extract(epoch from(rec.log_date_time-start_rec.log_date_time));
				if extract(epoch from(rec.log_date_time-start_rec.log_date_time))>=900 then
				
					if tcounter<>0 then
						tavg = round((tsum/tcounter)::numeric,2);
					end if;
					
					insert into sensor_data_temp_table(
						log_date_time,latitude,longitude,temperature
					)values(
						rec.log_date_time,
						case when start_rec.latitude is not null then floor(start_rec.latitude*1e8)
						else start_rec.latitude end,
						case when start_rec.longitude is not null then floor(start_rec.longitude*1e8)
						else start_rec.longitude end,
						tavg
					);
					inserted = true;
					start_rec = rec;
					tcounter = 0;
					tsum = null;
				end if;
			end loop;
			if not inserted and start_rec.log_date_time is not null then
			
				if tcounter<>0 then
					tavg = round((tsum/tcounter)::numeric,2);
				end if;
				
				insert into sensor_data_temp_table(
					log_date_time,latitude,longitude,temperature
				)values(
					rec.log_date_time,
					case when start_rec.latitude is not null then floor(start_rec.latitude*1e8)
					else start_rec.latitude end,
					case when start_rec.longitude is not null then floor(start_rec.longitude*1e8)
					else start_rec.longitude end,
					tavg
				);
			end if;
		end loop;
		select json_agg(
		row_to_json(
			(select cname from (select
			data.timestamp_to_jalali(log_date_time),latitude,longitude,temperature) as cname)
		)
		) into result
		from sensor_data_temp_table;
	end if;
	return result;
END;
$_$;


--
-- TOC entry 907 (class 1255 OID 21745)
-- Name: summary_report(integer, date, date); Type: FUNCTION; Schema: data; Owner: -
--

CREATE FUNCTION data.summary_report(input_sensor_id integer, from_date date, to_date date) RETURNS json
    LANGUAGE plpgsql
    AS $$

DECLARE
	result json default '[]'::json;
BEGIN
	SET TIMEZONE='Asia/Tehran';
	select 
			row_to_json(
				(select cname from(
					 select p.name as province,u.name as university,
					 c.name as center,w.name as warehouse,r.name as room,
					 s.name as sensor,
					 data.sensor_details_report(s.id,from_date,to_date)as details
					)as cname
				)
			
		) into result
	from api.core_province p
	left join api.core_university u on p.id=u.province_id
	left join api.core_center c on u.id=c.university_id
	left join api.core_warehouse w on c.id=w.center_id
	left join api.core_room r on w.id=r.warehouse_id
	left join api.core_sensor s on r.id=s.room_id
	where s.id=input_sensor_id;
		
	return result;
END;
$$;


--
-- TOC entry 1051 (class 1255 OID 21746)
-- Name: summary_report(integer, date, date, time without time zone, time without time zone); Type: FUNCTION; Schema: data; Owner: -
--

CREATE FUNCTION data.summary_report(input_sensor_id integer, from_date date, to_date date, from_time time without time zone DEFAULT '00:00:00'::time without time zone, to_time time without time zone DEFAULT '23:59:59'::time without time zone) RETURNS json
    LANGUAGE plpgsql
    AS $$

DECLARE
	result json default '[]'::json;
BEGIN
	SET TIMEZONE='Asia/Tehran';
	select
			row_to_json(
				(select cname from(
					 select p.name as province,u.name as university,
					 c.name as center,w.name as warehouse,r.name as room,
					 s.name as sensor,
					 data.sensor_details_report(s.id,from_date,to_date,from_time,to_time)as details
				 )as cname)
		) into result
	from api.core_province p
	left join api.core_university u on p.id=u.province_id
	left join api.core_center c on u.id=c.university_id
	left join api.core_warehouse w on c.id=w.center_id
	left join api.core_room r on w.id=r.warehouse_id
	left join api.core_sensor s on r.id=s.room_id
	where s.id=input_sensor_id;

	return result;
END;
$$;


--
-- TOC entry 900 (class 1255 OID 21747)
-- Name: summary_report_old(integer, date, date); Type: FUNCTION; Schema: data; Owner: -
--

CREATE FUNCTION data.summary_report_old(input_sensor_id integer, from_date date, to_date date) RETURNS json
    LANGUAGE plpgsql
    AS $$

DECLARE
	result json default '[]'::json;
BEGIN
	SET TIMEZONE='Asia/Tehran';
	select 
			row_to_json(
				(select cname from(
					 select p.name as province,u.name as university,
					 c.name as center,w.name as warehouse,r.name as room,
					 s.name as sensor,
					 data.sensor_details_report(s.id,from_date,to_date)as details
				 )as cname)
		) into result
	from api.core_province p
	left join api.core_university u on p.id=u.province_id
	left join api.core_center c on u.id=c.university_id
	left join api.core_warehouse w on c.id=w.center_id
	left join api.core_room r on w.id=r.warehouse_id
	left join api.core_sensor s on r.id=s.room_id
	where s.id=input_sensor_id;
		
	return result;
END;
$$;


--
-- TOC entry 914 (class 1255 OID 22171)
-- Name: summary_report_t(integer, date, date, time without time zone, time without time zone); Type: FUNCTION; Schema: data; Owner: -
--

CREATE FUNCTION data.summary_report_t(input_sensor_id integer, from_date date, to_date date, from_time time without time zone DEFAULT '00:00:00'::time without time zone, to_time time without time zone DEFAULT '23:59:59'::time without time zone) RETURNS json
    LANGUAGE plpgsql
    AS $$
DECLARE
	result json default '[]'::json;
BEGIN
	SET TIMEZONE='Asia/Tehran';
	select 
		row_to_json(
			(select cname from(
				 select p.name as province,u.name as university,
				 c.name as center,w.name as warehouse,r.name as room,
				 s.name as sensor,s.type as sensor_type,
				 data.sensor_details_report_t(s.id,from_date,to_date,from_time,to_time)as details
			 )as cname)
	) into result
	from api.core_province p
	left join api.core_university u on p.id=u.province_id
	left join api.core_center c on u.id=c.university_id
	left join api.core_warehouse w on c.id=w.center_id
	left join api.core_room r on w.id=r.warehouse_id
	left join api.core_sensor s on r.id=s.room_id
	where s.id=input_sensor_id;
		
	return result;
END;
$$;


--
-- TOC entry 908 (class 1255 OID 21748)
-- Name: summary_reports(text, date, date); Type: FUNCTION; Schema: data; Owner: -
--

CREATE FUNCTION data.summary_reports(sensor_ids text, from_date date, to_date date) RETURNS json
    LANGUAGE plpgsql
    AS $$

DECLARE
	_id int;
	result json default '[]'::json;
BEGIN
	SET TIMEZONE='Asia/Tehran';
	drop table if exists sensor_ids_temp_table;
	create temp table sensor_ids_temp_table(
		id int
	);
	foreach _id in array string_to_array(sensor_ids,',')
	loop
		insert into sensor_ids_temp_table (id)values(_id);
 	end loop;
	select json_agg(
			row_to_json(
				(select cname from(
					 select p.name as province,u.name as university,
					 c.name as center,w.name as warehouse,r.name as room,
					 s.name as sensor,
					 data.sensor_details_report(s.id,from_date,to_date)as details
					)as cname
				)
			)
		) into result
	from api.core_province p
	left join api.core_university u on p.id=u.province_id
	left join api.core_center c on u.id=c.university_id
	left join api.core_warehouse w on c.id=w.center_id
	left join api.core_room r on w.id=r.warehouse_id
	left join api.core_sensor s on r.id=s.room_id
	right join sensor_ids_temp_table si on si.id=s.id;
		
	return result;
END;
$$;


--
-- TOC entry 909 (class 1255 OID 21749)
-- Name: t_alarm(integer, date, date, time without time zone, time without time zone); Type: FUNCTION; Schema: data; Owner: -
--

CREATE FUNCTION data.t_alarm(input_sensor_id integer, from_date date, to_date date, from_time time without time zone DEFAULT '00:00:00'::time without time zone, to_time time without time zone DEFAULT '23:59:59'::time without time zone) RETURNS TABLE(start_lon double precision, start_lat double precision, end_lon double precision, end_lat double precision, date date, start_time time without time zone, end_time time without time zone, duration time without time zone, mean double precision, max double precision, min double precision)
    LANGUAGE plpgsql
    AS $_$

DECLARE
    start_rec RECORD;
	mid_rec RECORD;
	end_rec RECORD;
	last_rec RECORD;
	sensor_rec RECORD;
	table_rec RECORD;
	_sensor_id char(8);
	_room_id char(8);
	_warehouse_id char(8);
	q text;
	result json;
	timediff time;
	inserted boolean;
	is_first boolean default true;
	is_single boolean default false;
	sum_humidity double precision default 0;
	counter int default 0;
	max_humidity double precision default 0;
	min_humidity double precision default 99999;
	is_in_alarm boolean default false;
BEGIN
	set timezone='Asia/Tehran';
	if input_sensor_id is null then
 		return query select null;
	end if;
	
	drop table if exists humidity_max_alarm_temp_table;
	CREATE TEMPORARY TABLE humidity_max_alarm_temp_table(
		start_lon double precision,
		start_lat double precision,
		end_lon double precision,
		end_lat double precision,
		date date,
		start_time time,
		end_time time,
		duration time,
		mean float,
		max float,
		min float
	);
	
	select into _sensor_id,_room_id,_warehouse_id
	s.sensor_id,r.room_id,w.warehouse_id
	from api.core_warehouse w
	left join api.core_room r on w.id=r.warehouse_id
	left join api.core_sensor s on r.id=s.room_id
	where s.id=input_sensor_id;
	if _sensor_id is null or _room_id is null or _warehouse_id is null then
		return query select null;
	end if;
	FOR table_rec IN select created,table_name from data.tables where 
					created between from_date AND to_date
	LOOP
		EXECUTE('select w.name as warehouse_name,r.name as room_name,
				s.name as sensor_name,s.hum_max_val,s.allowed_hum_max_violation_time
				from api.core_warehouse w
				left join api.core_room r on w.id=r.warehouse_id
				left join api.core_sensor s on r.id=s.room_id') into sensor_rec;
		q='SELECT longitude,latitude,humidity,log_date_time
		FROM data.'||table_rec.table_name||'
		where branch_id=$1 and room_id=$2 and sensor_id=$3 
		order by log_date_time';
		EXECUTE(CONCAT(q,' asc limit 1')) into start_rec
		using _warehouse_id,_room_id,_sensor_id;
		EXECUTE(CONCAT(q,' desc limit 1')) into last_rec
		using _warehouse_id,_room_id,_sensor_id;
		mid_rec = start_rec;
		inserted = false;
		FOR end_rec IN EXECUTE(q) using _warehouse_id,_room_id,_sensor_id
		LOOP
			if end_rec.humidity > sensor_rec.hum_max_val
			then
				sum_humidity = sum_humidity + end_rec.humidity;
				counter = counter + 1;
				if end_rec.humidity>max_humidity then
					max_humidity = end_rec.humidity;
				end if;
				if end_rec.humidity<min_humidity then
					min_humidity = end_rec.humidity;
				end if;
				if is_first then
					start_rec = end_rec;
					mid_rec = end_rec;
					is_first = false;
					is_single = true;
				else
					mid_rec=end_rec;
					is_single = false;
					inserted = false;
				end if;
				if end_rec<>last_rec then
					continue;
				end if;
			end if;
			if (start_rec.log_date_time::time<mid_rec.log_date_time::time) or is_single then
				if is_single then
					mid_rec = end_rec;
				end if;
				if last_rec=mid_rec then
					if table_rec.created=now()::date then
						is_in_alarm = true;
					end if;
				end if;
				timediff =  mid_rec.log_date_time - start_rec.log_date_time;
				if extract(EPOCH from (timediff))>sensor_rec.allowed_hum_max_violation_time then
					insert into humidity_max_alarm_temp_table(
					 	start_lon,start_lat,end_lon,
						end_lat,date,start_time,end_time,duration,mean,max,min,is_done
					)values (
						start_rec.longitude,start_rec.latitude,
						mid_rec.longitude,mid_rec.latitude,
						mid_rec.log_date_time::date,
						start_rec.log_date_time::time,
						mid_rec.log_date_time::time,
						(mid_rec.log_date_time-start_rec.log_date_time)::time,
						round((sum_humidity/counter)::numeric,2),max_humidity,
						min_humidity,not is_in_alarm
					);
					max_humidity = 0;
					min_humidity = 99999;
					sum_humidity = 0;
					counter = 0;
				end if;
				inserted = true;
				is_first = true;
				is_single = false;
				is_in_alarm = false;
			end if;
			start_rec = end_rec;
			mid_rec = end_rec;
		END LOOP;
		if not inserted then
			if (start_rec.log_date_time::time<mid_rec.log_date_time::time) or is_single then
				if is_single then
					mid_rec = end_rec;
				end if;
				if last_rec=mid_rec then
					if table_rec.created=now()::date then
						is_in_alarm = true;
					end if;
				end if;
				timediff =  mid_rec.log_date_time - start_rec.log_date_time;
				if extract(EPOCH from (timediff))>sensor_rec.allowed_hum_max_violation_time then
					insert into humidity_max_alarm_temp_table(
						start_lon,start_lat,end_lon,end_lat,date,
						start_time,end_time,duration,mean,max,min,is_done
					)values (
						start_rec.longitude,start_rec.latitude,
						mid_rec.longitude,mid_rec.latitude,
						mid_rec.log_date_time::date,
						start_rec.log_date_time::time,
						mid_rec.log_date_time::time,
						(mid_rec.log_date_time-start_rec.log_date_time)::time,
						round((sum_humidity/counter)::numeric,2),max_humidity,
						min_humidity,not is_in_alarm
					);
					inserted = true;
				end if;
			end if;
		end if;
	END LOOP;
	
	return query select * from humidity_max_alarm_temp_table;
END;
$_$;


--
-- TOC entry 921 (class 1255 OID 21751)
-- Name: temperature_max_alarm(integer, date, date); Type: FUNCTION; Schema: data; Owner: -
--

CREATE FUNCTION data.temperature_max_alarm(input_sensor_id integer, from_date date, to_date date) RETURNS json
    LANGUAGE plpgsql
    AS $_$

DECLARE
    start_rec RECORD;
	mid_rec RECORD;
	end_rec RECORD;
	last_rec RECORD;
	sensor_rec RECORD;
	table_rec RECORD;
	_sensor_id char(8);
	_room_id char(8);
	_warehouse_id char(8);
	_tmin double precision;
	_tmax double precision;
	q text;
	result json;
	timediff time;
	inserted boolean;
	is_first boolean default true;
	is_single boolean default false;
	sum_temperature double precision default 0;
	counter int default 0;
	max_temperature double precision default 0;
	min_temperature double precision default 999999;
	is_in_alarm boolean default false;
BEGIN
	set timezone='Asia/Tehran';
	if input_sensor_id is null then
 		return null;
	end if;

	drop table if exists temperature_max_alarm_temp_table;
	CREATE TEMPORARY TABLE temperature_max_alarm_temp_table(
		warehouse_id char(8),
		warehouse_name text,
		room_id char(8),
		room_name text,
		sensor_id char(8),
		sensor_name text,
		start_lon double precision,
		start_lat double precision,
		end_lon double precision,
		end_lat double precision,
		date text,
		start_time time,
		end_time time,
		duration time,
		mean float,
		min float,
		max float,
		tmin float,
		tmax float,
		is_done boolean
	);

	select into _sensor_id,_room_id,_warehouse_id,_tmin,_tmax
	s.sensor_id,r.room_id,w.warehouse_id,s.temp_min_val,s.temp_max_val
	from api.core_warehouse w
	left join api.core_room r on w.id=r.warehouse_id
	left join api.core_sensor s on r.id=s.room_id
	where s.id=input_sensor_id;
	if _sensor_id is null or _room_id is null or _warehouse_id is null then
		return null;
	end if;
	FOR table_rec IN select created,table_name from data.tables where 
					created between from_date AND to_date
	LOOP
		EXECUTE('select w.name as warehouse_name,r.name as room_name,
				s.name as sensor_name,s.temp_max_val,s.allowed_temp_max_violation_time
				from api.core_warehouse w
				left join api.core_room r on w.id=r.warehouse_id
				left join api.core_sensor s on r.id=s.room_id
				where s.id=$1') using input_sensor_id into sensor_rec;
		q='SELECT longitude,latitude,temperature,log_date_time
		FROM data.'||table_rec.table_name||'
		where branch_id=$1 and room_id=$2 and sensor_id=$3 
		order by log_date_time';
		EXECUTE(CONCAT(q,' asc limit 1')) into start_rec
		using _warehouse_id,_room_id,_sensor_id;
		EXECUTE(CONCAT(q,' desc limit 1')) into last_rec
		using _warehouse_id,_room_id,_sensor_id;
		mid_rec = start_rec;
		inserted = false;
		FOR end_rec IN EXECUTE(q) using _warehouse_id,_room_id,_sensor_id
		LOOP
			if end_rec.temperature > sensor_rec.temp_max_val
			then
				sum_temperature = sum_temperature + end_rec.temperature;
				counter = counter + 1;
				if end_rec.temperature<min_temperature then
					min_temperature = end_rec.temperature;
				end if;
				if end_rec.temperature>max_temperature then
					max_temperature = end_rec.temperature;
				end if;
				if is_first then
					start_rec = end_rec;
					mid_rec = end_rec;
					is_first = false;
					is_single = true;
				else
					mid_rec=end_rec;
					is_single = false;
					inserted = false;
				end if;
				if end_rec<>last_rec then
					continue;
				end if;
			end if;
			if (start_rec.log_date_time::time<mid_rec.log_date_time::time) or is_single then
				if is_single then
					mid_rec = end_rec;
				end if;
				if last_rec=mid_rec then
					if table_rec.created=now()::date then
						is_in_alarm = true;
					end if;
				end if;
				timediff =  mid_rec.log_date_time - start_rec.log_date_time;
				if extract(EPOCH from (timediff))>sensor_rec.allowed_temp_max_violation_time then
					insert into temperature_max_alarm_temp_table(
						warehouse_id,warehouse_name,room_id,room_name,
					 	sensor_id,sensor_name,start_lon,start_lat,end_lon,
						end_lat,date,start_time,end_time,duration,mean,min,max,tmin,tmax,is_done
					)values (
						_warehouse_id,sensor_rec.warehouse_name,
						_room_id,sensor_rec.room_name,
						_sensor_id,sensor_rec.sensor_name,
						start_rec.longitude,start_rec.latitude,
						mid_rec.longitude,mid_rec.latitude,
						data.date_to_jalali(mid_rec.log_date_time::date),
						start_rec.log_date_time::time,
						mid_rec.log_date_time::time,
						(mid_rec.log_date_time-start_rec.log_date_time)::time,
						round((sum_temperature/counter)::numeric,2),min_temperature,
						max_temperature,_tmin,_tmax,not is_in_alarm
					);
					max_temperature = 0;
					min_temperature = 99999;
					sum_temperature = 0;
					counter = 0;
				end if;
				inserted = true;
				is_first = true;
				is_single = false;
				is_in_alarm = false;
			end if;
			start_rec = end_rec;
			mid_rec = end_rec;
		END LOOP;
		if not inserted then
			if (start_rec.log_date_time::time<mid_rec.log_date_time::time) or is_single then
				if is_single then
					mid_rec = end_rec;
				end if;
				if last_rec=mid_rec then
					if table_rec.created=now()::date then
						is_in_alarm = true;
					end if;
				end if;
				timediff =  mid_rec.log_date_time - start_rec.log_date_time;
				if extract(EPOCH from (timediff))>sensor_rec.allowed_temp_max_violation_time then
					insert into temperature_max_alarm_temp_table(
						warehouse_id,warehouse_name,room_id,room_name,
						sensor_id,sensor_name,start_lon,start_lat,end_lon,
						end_lat,date,start_time,end_time,duration,mean,min,max,tmin,tmax,is_done
					)values (
						_warehouse_id,sensor_rec.warehouse_name,
						_room_id,sensor_rec.room_name,
						_sensor_id,sensor_rec.sensor_name,
						start_rec.longitude,start_rec.latitude,
						mid_rec.longitude,mid_rec.latitude,
						data.date_to_jalali(mid_rec.log_date_time::date),
						start_rec.log_date_time::time,
						mid_rec.log_date_time::time,
						(mid_rec.log_date_time-start_rec.log_date_time)::time,
						round((sum_temperature/counter)::numeric,2),
						min_temperature,max_temperature,_tmin,_tmax,not is_in_alarm
					);
					inserted = true;
				end if;
			end if;
		end if;
	END LOOP;

	select json_agg(
		row_to_json(
		(select cname from(select warehouse_name,warehouse_id,room_name,
						   room_id,sensor_name,sensor_id,start_lon,
						   start_lat,end_lon,end_lat,date,start_time,end_time,
						   duration,mean,min,max,tmin,tmax,is_done) as cname)
		)
	) into result
	from temperature_max_alarm_temp_table;
	return result;
END;
$_$;


--
-- TOC entry 913 (class 1255 OID 21752)
-- Name: temperature_max_alarm_count(integer, date, date); Type: FUNCTION; Schema: data; Owner: -
--

CREATE FUNCTION data.temperature_max_alarm_count(input_sensor_id integer, from_date date, to_date date) RETURNS integer
    LANGUAGE plpgsql
    AS $_$

DECLARE
    start_rec RECORD;
	mid_rec RECORD;
	end_rec RECORD;
	sensor_rec RECORD;
	table_rec RECORD;
	_sensor_id char(8);
	_room_id char(8);
	_warehouse_id char(8);
	q text;
	alarm_count int default 0;
	result json;
	timediff time;
	inserted boolean;
	is_first boolean default true;
	is_single boolean default false;
BEGIN
	set timezone='Asia/Tehran';
	if input_sensor_id is null then
 		return null;
	end if;
	
	select into _sensor_id,_room_id,_warehouse_id
	s.sensor_id,r.room_id,w.warehouse_id
	from api.core_warehouse w
	left join api.core_room r on w.id=r.warehouse_id
	left join api.core_sensor s on r.id=s.room_id
	where s.id=input_sensor_id;
	if _sensor_id is null or _room_id is null or _warehouse_id is null then
		return null;
	end if;
	FOR table_rec IN select created,table_name from data.tables where 
					created between from_date AND to_date
	LOOP
		EXECUTE('select w.name as warehouse_name,r.name as room_name,
				s.name as sensor_name,s.temp_max_val,s.allowed_temp_max_violation_time
				from api.core_warehouse w
				left join api.core_room r on w.id=r.warehouse_id
				left join api.core_sensor s on r.id=s.room_id
				where s.id=$1') using input_sensor_id into sensor_rec;
		q='SELECT longitude,latitude,temperature,log_date_time
		FROM data.'||table_rec.table_name||'
		where branch_id=$1 and room_id=$2 and sensor_id=$3 
		order by log_date_time asc';
		EXECUTE(CONCAT(q,' limit 1')) into start_rec
		using _warehouse_id,_room_id,_sensor_id;
		mid_rec = start_rec;
		inserted = false;
		FOR end_rec IN EXECUTE(q) using _warehouse_id,_room_id,_sensor_id
		LOOP
			if end_rec.temperature > sensor_rec.temp_max_val
			then
				if is_first then
					start_rec = end_rec;
					mid_rec = end_rec;
					is_first = false;
					is_single = true;
				else
					mid_rec=end_rec;
					is_single = false;
				end if;
				inserted = false;
				continue;
			end if;
			if (start_rec.log_date_time::time<mid_rec.log_date_time::time) or is_single then
				if is_single then
					mid_rec = end_rec;
				end if;
				timediff =  mid_rec.log_date_time - start_rec.log_date_time;
				if extract(EPOCH from (timediff))>sensor_rec.allowed_temp_max_violation_time then
					alarm_count = alarm_count+1;
				end if;
				inserted = true;
				is_first = true;
				is_single = false;
			end if;
			start_rec = end_rec;
			mid_rec = end_rec;
		END LOOP;
			if not inserted then
				if (start_rec.log_date_time::time<mid_rec.log_date_time::time) or is_single then
					if is_single then
						mid_rec = end_rec;
					end if;
					timediff =  mid_rec.log_date_time - start_rec.log_date_time;
					if extract(EPOCH from (timediff))>sensor_rec.allowed_temp_max_violation_time then
						alarm_count = alarm_count+1;
						inserted = true;
					end if;
				end if;
			end if;
	END LOOP;

	return alarm_count;
END;
$_$;


--
-- TOC entry 941 (class 1255 OID 21753)
-- Name: temperature_min_alarm(integer, date, date); Type: FUNCTION; Schema: data; Owner: -
--

CREATE FUNCTION data.temperature_min_alarm(input_sensor_id integer, from_date date, to_date date) RETURNS json
    LANGUAGE plpgsql
    AS $_$

DECLARE
    start_rec RECORD;
	mid_rec RECORD;
	end_rec RECORD;
	last_rec RECORD;
	sensor_rec RECORD;
	table_rec RECORD;
	_sensor_id char(8);
	_room_id char(8);
	_warehouse_id char(8);
	_tmin double precision;
	_tmax double precision;
	q text;
	result json;
	timediff time;
	inserted boolean;
	is_first boolean default true;
	is_single boolean default false;
	sum_temperature double precision default 0;
	counter int default 0;
	max_temperature double precision default 0;
	min_temperature double precision default 999999;
	is_in_alarm boolean default false;
BEGIN
	set timezone='Asia/Tehran';
	if input_sensor_id is null then
 		return null;
	end if;

	drop table if exists temperature_min_alarm_temp_table;
	CREATE TEMPORARY TABLE temperature_min_alarm_temp_table(
		warehouse_id char(8),
		warehouse_name text,
		room_id char(8),
		room_name text,
		sensor_id char(8),
		sensor_name text,
		start_lon double precision,
		start_lat double precision,
		end_lon double precision,
		end_lat double precision,
		date text,
		start_time time,
		end_time time,
		duration time,
		mean float,
		min float,
		max float,
		tmin float,
		tmax float,
		is_done boolean
	);

	select into _sensor_id,_room_id,_warehouse_id,_tmin,_tmax
	s.sensor_id,r.room_id,w.warehouse_id,s.temp_min_val,s.temp_max_val
	from api.core_warehouse w
	left join api.core_room r on w.id=r.warehouse_id
	left join api.core_sensor s on r.id=s.room_id
	where s.id=input_sensor_id;
	if _sensor_id is null or _room_id is null or _warehouse_id is null then
		return null;
	end if;
	FOR table_rec IN select created,table_name from data.tables where 
					created between from_date AND to_date
	LOOP
		EXECUTE('select w.name as warehouse_name,r.name as room_name,
				s.name as sensor_name,s.temp_min_val,s.allowed_temp_min_violation_time
				from api.core_warehouse w
				left join api.core_room r on w.id=r.warehouse_id
				left join api.core_sensor s on r.id=s.room_id
				where s.id=$1') using input_sensor_id into sensor_rec;
		q='SELECT longitude,latitude,temperature,log_date_time
		FROM data.'||table_rec.table_name||'
		where branch_id=$1 and room_id=$2 and sensor_id=$3 
		order by log_date_time';
		EXECUTE(CONCAT(q,' asc limit 1')) into start_rec
		using _warehouse_id,_room_id,_sensor_id;
		EXECUTE(CONCAT(q,' desc limit 1')) into last_rec
		using _warehouse_id,_room_id,_sensor_id;
		mid_rec = start_rec;
		inserted = false;
		FOR end_rec IN EXECUTE(q) using _warehouse_id,_room_id,_sensor_id
		LOOP
			if end_rec.temperature < sensor_rec.temp_min_val
			then
				sum_temperature = sum_temperature + end_rec.temperature;
				counter = counter + 1;
				if end_rec.temperature<min_temperature then
					min_temperature = end_rec.temperature;
				end if;
				if end_rec.temperature>max_temperature then
					max_temperature = end_rec.temperature;
				end if;
				if is_first then
					start_rec = end_rec;
					mid_rec = end_rec;
					is_first = false;
					is_single = true;
				else
					mid_rec=end_rec;
					is_single = false;
					inserted = false;
				end if;
				if end_rec<>last_rec then
					continue;
				end if;
			end if;
			if (start_rec.log_date_time::time<mid_rec.log_date_time::time) or is_single then
				if is_single then
					mid_rec = end_rec;
				end if;
				if last_rec=mid_rec then
					if table_rec.created=now()::date then
						is_in_alarm = true;
					end if;
				end if;
				timediff =  mid_rec.log_date_time - start_rec.log_date_time;
				if extract(EPOCH from (timediff))>sensor_rec.allowed_temp_min_violation_time then
					insert into temperature_min_alarm_temp_table(
						warehouse_id,warehouse_name,room_id,room_name,
					 	sensor_id,sensor_name,start_lon,start_lat,end_lon,
						end_lat,date,start_time,end_time,duration,mean,min,max,tmin,tmax,is_done
					)values (
						_warehouse_id,sensor_rec.warehouse_name,
						_room_id,sensor_rec.room_name,
						_sensor_id,sensor_rec.sensor_name,
						start_rec.longitude,start_rec.latitude,
						mid_rec.longitude,mid_rec.latitude,
						data.date_to_jalali(mid_rec.log_date_time::date),
						start_rec.log_date_time::time,
						mid_rec.log_date_time::time,
						(mid_rec.log_date_time-start_rec.log_date_time)::time,
						round((sum_temperature/counter)::numeric,2),min_temperature,
						max_temperature,_tmin,_tmax,not is_in_alarm
					);
					min_temperature = 999999;
					max_temperature = 0;
					sum_temperature = 0;
					counter = 0;
				end if;
				inserted = true;
				is_first = true;
				is_single = false;
				is_in_alarm = false;
			end if;
			start_rec = end_rec;
			mid_rec = end_rec;
		END LOOP;
		if not inserted then
			if (start_rec.log_date_time::time<mid_rec.log_date_time::time) or is_single then
				if is_single then
					mid_rec = end_rec;
				end if;
				if last_rec=mid_rec then
					if table_rec.created=now()::date then
						is_in_alarm = true;
					end if;
				end if;
				timediff =  mid_rec.log_date_time - start_rec.log_date_time;
				if extract(EPOCH from (timediff))>sensor_rec.allowed_temp_min_violation_time then
					insert into temperature_min_alarm_temp_table(
						warehouse_id,warehouse_name,room_id,room_name,
						sensor_id,sensor_name,start_lon,start_lat,end_lon,
						end_lat,date,start_time,end_time,duration,mean,min,max,tmin,tmax,is_done
					)values (
						_warehouse_id,sensor_rec.warehouse_name,
						_room_id,sensor_rec.room_name,
						_sensor_id,sensor_rec.sensor_name,
						start_rec.longitude,start_rec.latitude,
						mid_rec.longitude,mid_rec.latitude,
						data.date_to_jalali(mid_rec.log_date_time::date),
						start_rec.log_date_time::time,
						mid_rec.log_date_time::time,
						(mid_rec.log_date_time-start_rec.log_date_time)::time,
						round((sum_temperature/counter)::numeric,2),min_temperature,
						max_temperature,_tmin,_tmax,not is_in_alarm
					);
					inserted = true;
				end if;
			end if;
		end if;
	END LOOP;

	select json_agg(
		row_to_json(
		(select cname from(select warehouse_name,warehouse_id,room_name,
						   room_id,sensor_name,sensor_id,start_lon,
						   start_lat,end_lon,end_lat,date,start_time,end_time,
						   duration,mean,min,max,tmin,tmax,is_done) as cname)
		)
	) into result
	from temperature_min_alarm_temp_table;
	return result;
END;
$_$;


--
-- TOC entry 897 (class 1255 OID 21754)
-- Name: temperature_min_alarm_count(integer, date, date); Type: FUNCTION; Schema: data; Owner: -
--

CREATE FUNCTION data.temperature_min_alarm_count(input_sensor_id integer, from_date date, to_date date) RETURNS integer
    LANGUAGE plpgsql
    AS $_$

DECLARE
    start_rec RECORD;
	mid_rec RECORD;
	end_rec RECORD;
	sensor_rec RECORD;
	table_rec RECORD;
	_sensor_id char(8);
	_room_id char(8);
	_warehouse_id char(8);
	q text;
	alarm_count int default 0;
	result json;
	timediff time;
	inserted boolean;
	is_first boolean default true;
	is_single boolean default false;
BEGIN
	set timezone='Asia/Tehran';
	if input_sensor_id is null then
 		return null;
	end if;

	select into _sensor_id,_room_id,_warehouse_id
	s.sensor_id,r.room_id,w.warehouse_id
	from api.core_warehouse w
	left join api.core_room r on w.id=r.warehouse_id
	left join api.core_sensor s on r.id=s.room_id
	where s.id=input_sensor_id;
	if _sensor_id is null or _room_id is null or _warehouse_id is null then
		return null;
	end if;
	FOR table_rec IN select created,table_name from data.tables where 
					created between from_date AND to_date
	LOOP
		EXECUTE('select w.name as warehouse_name,r.name as room_name,
				s.name as sensor_name,s.temp_min_val,s.allowed_temp_min_violation_time
				from api.core_warehouse w
				left join api.core_room r on w.id=r.warehouse_id
				left join api.core_sensor s on r.id=s.room_id
				where s.id=$1') using input_sensor_id into sensor_rec;
		q='SELECT longitude,latitude,temperature,log_date_time
		FROM data.'||table_rec.table_name||'
		where branch_id=$1 and room_id=$2 and sensor_id=$3 
		order by log_date_time asc';
		EXECUTE(CONCAT(q,' limit 1')) into start_rec
		using _warehouse_id,_room_id,_sensor_id;
		mid_rec = start_rec;
		inserted = false;
		FOR end_rec IN EXECUTE(q) using _warehouse_id,_room_id,_sensor_id
		LOOP
			if end_rec.temperature < sensor_rec.temp_min_val
			then
				if is_first then
					start_rec = end_rec;
					mid_rec = end_rec;
					is_first = false;
					is_single = true;
				else
					mid_rec=end_rec;
					is_single = false;
				end if;
				inserted = false;
				continue;
			end if;
			if (start_rec.log_date_time::time<mid_rec.log_date_time::time) or is_single then
				if is_single then
					mid_rec = end_rec;
				end if;
				timediff =  mid_rec.log_date_time - start_rec.log_date_time;
				if extract(EPOCH from (timediff))>sensor_rec.allowed_temp_min_violation_time then
					alarm_count = alarm_count+1;
				end if;
				inserted = true;
				is_first = true;
				is_single = false;
			end if;
			start_rec = end_rec;
			mid_rec = end_rec;
		END LOOP;
			if not inserted then
				if (start_rec.log_date_time::time<mid_rec.log_date_time::time) or is_single then
					if is_single then
						mid_rec = end_rec;
					end if;
					timediff =  mid_rec.log_date_time - start_rec.log_date_time;
					if extract(EPOCH from (timediff))>sensor_rec.allowed_temp_min_violation_time then
						alarm_count = alarm_count+1;
						inserted = true;
					end if;
				end if;
			end if;
	END LOOP;
	
	return alarm_count;
END;
$_$;


--
-- TOC entry 926 (class 1255 OID 21755)
-- Name: timestamp_to_jalali(timestamp without time zone); Type: FUNCTION; Schema: data; Owner: -
--

CREATE FUNCTION data.timestamp_to_jalali(gdate timestamp without time zone) RETURNS text
    LANGUAGE plpgsql
    AS $$

DECLARE
	g_days_in_month int[] default '{31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31}';
	j_days_in_month int[] default '{31, 31, 31, 31, 31, 31, 30, 30, 30, 30, 30, 29}';
	gyear int;
	gmonth int;
	gday int;
	gy int default 0;
	gm int default 0;
	gd int default 0;
	g_day_no int default 0;
	j_day_no int default 0;
	j_np int default 0;
	jy int default 0;
	jm int default 0;
	jd int default 0;
	counter int default 0;
	last_counter_val int default 0;
BEGIN
	if gdate is null then
		return null;
	end if;
	SET TIMEZONE='Asia/Tehran';
	select date_part('year',gdate) into gyear;
	select date_part('month',gdate) into gmonth;
	select date_part('day',gdate) into gday;
	gy = gyear-1600;
        gm = gmonth-1;
	gd = gday-1;
	g_day_no = 365*gy+(gy+3)/4-(gy+99)/100+(gy+399)/400;
	for counter in 0..gm-1 loop
        	g_day_no = g_day_no + g_days_in_month[counter+1];
	end loop;
	if gm>1 and ((gy%4=0 and gy%100<>0) or (gy%400=0)) then
     		g_day_no = g_day_no + 1;
 	end if;
	g_day_no = g_day_no + gd;
	j_day_no = g_day_no - 79;
	j_np = j_day_no/12053;
	j_day_no = j_day_no % 12053;
	jy = 979+33*j_np+4*(j_day_no/1461);
	j_day_no = j_day_no % 1461;
	if j_day_no>=366 then
    		jy = jy + (j_day_no-1)/365;
        	j_day_no = (j_day_no-1)%365;
	end if;

	for counter in 0..10 loop
		last_counter_val = counter;
		if not j_day_no >= j_days_in_month[counter+1] then
			last_counter_val = counter-1;
			exit;
		end if;
		j_day_no = j_day_no - j_days_in_month[counter+1];
	end loop;
	jm = last_counter_val+2;
	jd = j_day_no+1;
	return format('%s-%s-%s %s',jy,jm,jd,gdate::time);
END;
$$;


--
-- TOC entry 919 (class 1255 OID 2127850)
-- Name: tmax_alarm_report(integer, date, date, time without time zone, time without time zone); Type: FUNCTION; Schema: data; Owner: -
--

CREATE FUNCTION data.tmax_alarm_report(input_sensor_id integer, from_date date, to_date date, from_time time without time zone DEFAULT '00:00:00'::time without time zone, to_time time without time zone DEFAULT '23:59:59'::time without time zone) RETURNS TABLE(type text, start_lon double precision, start_lat double precision, end_lon double precision, end_lat double precision, date text, start_time time without time zone, end_time time without time zone, duration time without time zone, temperature double precision, humidity double precision, mean double precision, max double precision, min double precision, is_done boolean)
    LANGUAGE plpgsql
    AS $_$

DECLARE
    start_rec RECORD;
	mid_rec RECORD;
	end_rec RECORD;
	last_rec RECORD;
	sensor_rec RECORD;
	table_rec RECORD;
	_sensor_id char(8);
	_room_id char(8);
	_warehouse_id char(8);
	q text;
	result json;
	timediff time;
	inserted boolean;
	is_first boolean default true;
	is_single boolean default false;
	sum_temperature double precision default 0;
	counter int default 0;
	max_temperature double precision default 0;
	min_temperature double precision default 99999;
	is_in_alarm boolean default false;
BEGIN
	set timezone='Asia/Tehran';
	if input_sensor_id is null then
 		return query select null;
	end if;

	drop table if exists temperature_max_alarm_temp_table;
	CREATE TEMPORARY TABLE temperature_max_alarm_temp_table(
		type text,
		start_lon double precision,
		start_lat double precision,
		end_lon double precision,
		end_lat double precision,
		date text,
		start_time time,
		end_time time,
		duration time,
		temperature double precision,
		humidity double precision,
		mean float,
		max float,
		min float,
		is_done boolean
	);

	select into _sensor_id,_room_id,_warehouse_id
	s.sensor_id,r.room_id,w.warehouse_id
	from api.core_warehouse w
	left join api.core_room r on w.id=r.warehouse_id
	left join api.core_sensor s on r.id=s.room_id
	where s.id=input_sensor_id;
	if _sensor_id is null or _room_id is null or _warehouse_id is null then
		return query select null;
	end if;
	FOR table_rec IN select created,table_name from data.tables where 
					created between from_date AND to_date
	LOOP
		EXECUTE('select temp_max_val,allowed_temp_max_violation_time
				from api.core_sensor where id=$1')
				into sensor_rec using input_sensor_id;
		if table_rec.created=from_date then
			q='SELECT longitude,latitude,temperature,humidity,log_date_time
			FROM data.'||table_rec.table_name||'
			where branch_id=$1 and room_id=$2 and sensor_id=$3 
			and log_date_time::time>='''||from_time||'''
			order by log_date_time';
		elseif table_rec.created=to_date then
			q='SELECT longitude,latitude,temperature,humidity,log_date_time
			FROM data.'||table_rec.table_name||'
			where branch_id=$1 and room_id=$2 and sensor_id=$3 
			and log_date_time::time<='''||to_time||'''
			order by log_date_time';
		else
			q='SELECT longitude,latitude,temperature,humidity,log_date_time
			FROM data.'||table_rec.table_name||'
			where branch_id=$1 and room_id=$2 and sensor_id=$3 
			order by log_date_time';
		end if;
		EXECUTE(CONCAT(q,' asc limit 1')) into start_rec
		using _warehouse_id,_room_id,_sensor_id;
		EXECUTE(CONCAT(q,' desc limit 1')) into last_rec
		using _warehouse_id,_room_id,_sensor_id;
		mid_rec = start_rec;
		inserted = false;
		FOR end_rec IN EXECUTE(q) using _warehouse_id,_room_id,_sensor_id
		LOOP
			if end_rec.temperature > sensor_rec.temp_max_val
			then
				sum_temperature = sum_temperature + end_rec.temperature;
				counter = counter + 1;
				if end_rec.temperature>max_temperature then
					max_temperature = end_rec.temperature;
				end if;
				if end_rec.temperature<min_temperature then
					min_temperature = end_rec.temperature;
				end if;
				if is_first then
					start_rec = end_rec;
					mid_rec = end_rec;
					is_first = false;
					is_single = true;
				else
					mid_rec=end_rec;
					is_single = false;
					inserted = false;
				end if;
				if end_rec<>last_rec then
					continue;
				end if;
			end if;
			if (start_rec.log_date_time::time<mid_rec.log_date_time::time) or is_single then
				if is_single then
					mid_rec = end_rec;
				end if;
				if last_rec=mid_rec then
					if table_rec.created=now()::date then
						is_in_alarm = true;
					end if;
				end if;
				timediff =  mid_rec.log_date_time - start_rec.log_date_time;
				if extract(EPOCH from (timediff))>sensor_rec.allowed_temp_max_violation_time then
					insert into temperature_max_alarm_temp_table(
						type,start_lon,start_lat,end_lon,
						end_lat,date,start_time,end_time,duration,
						temperature,humidity,mean,max,min,is_done
					 	)values (
						'tmax',
						start_rec.longitude,start_rec.latitude,
						mid_rec.longitude,mid_rec.latitude,
						data.date_to_jalali(mid_rec.log_date_time::date),
						start_rec.log_date_time::time,
						mid_rec.log_date_time::time,
						(mid_rec.log_date_time-start_rec.log_date_time)::time,
						start_rec.temperature,start_rec.humidity,
						round((sum_temperature/counter)::numeric,2),max_temperature,
						min_temperature,not is_in_alarm
					);
					max_temperature = 0;
					min_temperature = 99999;
					sum_temperature = 0;
					counter = 0;
				end if;
				inserted = true;
				is_first = true;
				is_single = false;
				is_in_alarm = false;
			end if;
			start_rec = end_rec;
			mid_rec = end_rec;
		END LOOP;
		if not inserted then
			if (start_rec.log_date_time::time<mid_rec.log_date_time::time) or is_single then
				if is_single then
					mid_rec = end_rec;
				end if;
				if last_rec=mid_rec then
					if table_rec.created=now()::date then
						is_in_alarm = true;
					end if;
				end if;
				timediff =  mid_rec.log_date_time - start_rec.log_date_time;
				if extract(EPOCH from (timediff))>sensor_rec.allowed_temp_max_violation_time then
					insert into temperature_max_alarm_temp_table(
						type,start_lon,start_lat,end_lon,
						end_lat,date,start_time,end_time,duration,
						temperature,humidity,mean,max,min,is_done
					)values (
						'tmax',
						start_rec.longitude,start_rec.latitude,
						mid_rec.longitude,mid_rec.latitude,
						data.date_to_jalali(mid_rec.log_date_time::date),
						start_rec.log_date_time::time,
						mid_rec.log_date_time::time,
						(mid_rec.log_date_time-start_rec.log_date_time)::time,
						start_rec.temperature,start_rec.humidity,
						round((sum_temperature/counter)::numeric,2),max_temperature,
						min_temperature,not is_in_alarm
					);
					inserted = true;
				end if;
			end if;
		end if;
	END LOOP;

	return query select * from temperature_max_alarm_temp_table;
END;
$_$;


--
-- TOC entry 920 (class 1255 OID 2127853)
-- Name: tmin_alarm_report(integer, date, date, time without time zone, time without time zone); Type: FUNCTION; Schema: data; Owner: -
--

CREATE FUNCTION data.tmin_alarm_report(input_sensor_id integer, from_date date, to_date date, from_time time without time zone DEFAULT '00:00:00'::time without time zone, to_time time without time zone DEFAULT '23:59:59'::time without time zone) RETURNS TABLE(type text, start_lon double precision, start_lat double precision, end_lon double precision, end_lat double precision, date text, start_time time without time zone, end_time time without time zone, duration time without time zone, temperature double precision, humidity double precision, mean double precision, max double precision, min double precision, is_done boolean)
    LANGUAGE plpgsql
    AS $_$

DECLARE
    start_rec RECORD;
	mid_rec RECORD;
	end_rec RECORD;
	last_rec RECORD;
	sensor_rec RECORD;
	table_rec RECORD;
	_sensor_id char(8);
	_room_id char(8);
	_warehouse_id char(8);
	q text;
	result json;
	timediff time;
	inserted boolean;
	is_first boolean default true;
	is_single boolean default false;
	sum_temperature double precision default 0;
	counter int default 0;
	max_temperature double precision default 0;
	min_temperature double precision default 99999;
	is_in_alarm boolean default false;
BEGIN
	set timezone='Asia/Tehran';
	if input_sensor_id is null then
 		return query select null;
	end if;

	drop table if exists temperature_min_alarm_temp_table;
	CREATE TEMPORARY TABLE temperature_min_alarm_temp_table(
		type text,
		start_lon double precision,
		start_lat double precision,
		end_lon double precision,
		end_lat double precision,
		date text,
		start_time time,
		end_time time,
		duration time,
		temperature double precision,
		humidity double precision,
		mean float,
		max float,
		min float,
		is_done boolean
	);

	select into _sensor_id,_room_id,_warehouse_id
	s.sensor_id,r.room_id,w.warehouse_id
	from api.core_warehouse w
	left join api.core_room r on w.id=r.warehouse_id
	left join api.core_sensor s on r.id=s.room_id
	where s.id=input_sensor_id;
	if _sensor_id is null or _room_id is null or _warehouse_id is null then
		return query select null;
	end if;
	FOR table_rec IN select created,table_name from data.tables where 
					created between from_date AND to_date
	LOOP
		EXECUTE('select temp_min_val,allowed_temp_min_violation_time
				from api.core_sensor where id=$1')
				into sensor_rec using input_sensor_id;
		if table_rec.created=from_date then
			q='SELECT longitude,latitude,temperature,humidity,log_date_time
			FROM data.'||table_rec.table_name||'
			where branch_id=$1 and room_id=$2 and sensor_id=$3 
			and log_date_time::time>='''||from_time||'''
			order by log_date_time';
		elseif table_rec.created=to_date then
			q='SELECT longitude,latitude,temperature,humidity,log_date_time
			FROM data.'||table_rec.table_name||'
			where branch_id=$1 and room_id=$2 and sensor_id=$3 
			and log_date_time::time<='''||to_time||'''
			order by log_date_time';
		else
			q='SELECT longitude,latitude,temperature,humidity,log_date_time
			FROM data.'||table_rec.table_name||'
			where branch_id=$1 and room_id=$2 and sensor_id=$3 
			order by log_date_time';
		end if;
		EXECUTE(CONCAT(q,' asc limit 1')) into start_rec
		using _warehouse_id,_room_id,_sensor_id;
		EXECUTE(CONCAT(q,' desc limit 1')) into last_rec
		using _warehouse_id,_room_id,_sensor_id;
		mid_rec = start_rec;
		inserted = false;
		FOR end_rec IN EXECUTE(q) using _warehouse_id,_room_id,_sensor_id
		LOOP
			if end_rec.temperature < sensor_rec.temp_min_val
			then
				sum_temperature = sum_temperature + end_rec.temperature;
				counter = counter + 1;
				if end_rec.temperature>max_temperature then
					max_temperature = end_rec.temperature;
				end if;
				if end_rec.temperature<min_temperature then
					min_temperature = end_rec.temperature;
				end if;
				if is_first then
					start_rec = end_rec;
					mid_rec = end_rec;
					is_first = false;
					is_single = true;
				else
					mid_rec=end_rec;
					is_single = false;
					inserted = false;
				end if;
				if end_rec<>last_rec then
					continue;
				end if;
			end if;
			if (start_rec.log_date_time::time<mid_rec.log_date_time::time) or is_single then
				if is_single then
					mid_rec = end_rec;
				end if;
				if last_rec=mid_rec then
					if table_rec.created=now()::date then
						is_in_alarm = true;
					end if;
				end if;
				timediff =  mid_rec.log_date_time - start_rec.log_date_time;
				if extract(EPOCH from (timediff))>sensor_rec.allowed_temp_min_violation_time then
					insert into temperature_min_alarm_temp_table(
					 	type,start_lon,start_lat,end_lon,
						end_lat,date,start_time,end_time,duration,
						temperature,humidity,mean,max,min,is_done
					)values (
						'tmin',
						start_rec.longitude,start_rec.latitude,
						mid_rec.longitude,mid_rec.latitude,
						data.date_to_jalali(mid_rec.log_date_time::date),
						start_rec.log_date_time::time,
						mid_rec.log_date_time::time,
						(mid_rec.log_date_time-start_rec.log_date_time)::time,
						start_rec.temperature,start_rec.humidity,
						round((sum_temperature/counter)::numeric,2),max_temperature,
						min_temperature,not is_in_alarm
					);
					max_temperature = 0;
					min_temperature = 99999;
					sum_temperature = 0;
					counter = 0;
				end if;
				inserted = true;
				is_first = true;
				is_single = false;
				is_in_alarm = false;
			end if;
			start_rec = end_rec;
			mid_rec = end_rec;
		END LOOP;
		if not inserted then
			if (start_rec.log_date_time::time<mid_rec.log_date_time::time) or is_single then
				if is_single then
					mid_rec = end_rec;
				end if;
				if last_rec=mid_rec then
					if table_rec.created=now()::date then
						is_in_alarm = true;
					end if;
				end if;
				timediff =  mid_rec.log_date_time - start_rec.log_date_time;
				if extract(EPOCH from (timediff))>sensor_rec.allowed_temp_min_violation_time then
					insert into temperature_min_alarm_temp_table(
						type,start_lon,start_lat,end_lon,
						end_lat,date,start_time,end_time,duration,
						temperature,humidity,mean,max,min,is_done
					)values (
						'tmin',
						start_rec.longitude,start_rec.latitude,
						mid_rec.longitude,mid_rec.latitude,
						data.date_to_jalali(mid_rec.log_date_time::date),
						start_rec.log_date_time::time,
						mid_rec.log_date_time::time,
						(mid_rec.log_date_time-start_rec.log_date_time)::time,
						start_rec.temperature,start_rec.humidity,
						round((sum_temperature/counter)::numeric,2),max_temperature,
						min_temperature,not is_in_alarm
					);
					inserted = true;
				end if;
			end if;
		end if;
	END LOOP;
	
	return query select * from temperature_min_alarm_temp_table;
END;
$_$;


SET default_with_oids = false;

--
-- TOC entry 269 (class 1259 OID 21334)
-- Name: account_accesscontrol; Type: TABLE; Schema: api; Owner: -
--

CREATE TABLE api.account_accesscontrol (
    id integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    modified_at timestamp with time zone NOT NULL,
    user_id integer
);


--
-- TOC entry 271 (class 1259 OID 21344)
-- Name: account_accesscontrol_centers; Type: TABLE; Schema: api; Owner: -
--

CREATE TABLE api.account_accesscontrol_centers (
    id integer NOT NULL,
    accesscontrol_id integer NOT NULL,
    center_id integer NOT NULL
);


--
-- TOC entry 270 (class 1259 OID 21342)
-- Name: account_accesscontrol_centers_id_seq; Type: SEQUENCE; Schema: api; Owner: -
--

CREATE SEQUENCE api.account_accesscontrol_centers_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 7602 (class 0 OID 0)
-- Dependencies: 270
-- Name: account_accesscontrol_centers_id_seq; Type: SEQUENCE OWNED BY; Schema: api; Owner: -
--

ALTER SEQUENCE api.account_accesscontrol_centers_id_seq OWNED BY api.account_accesscontrol_centers.id;


--
-- TOC entry 268 (class 1259 OID 21332)
-- Name: account_accesscontrol_id_seq; Type: SEQUENCE; Schema: api; Owner: -
--

CREATE SEQUENCE api.account_accesscontrol_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 7603 (class 0 OID 0)
-- Dependencies: 268
-- Name: account_accesscontrol_id_seq; Type: SEQUENCE OWNED BY; Schema: api; Owner: -
--

ALTER SEQUENCE api.account_accesscontrol_id_seq OWNED BY api.account_accesscontrol.id;


--
-- TOC entry 273 (class 1259 OID 21352)
-- Name: account_accesscontrol_provinces; Type: TABLE; Schema: api; Owner: -
--

CREATE TABLE api.account_accesscontrol_provinces (
    id integer NOT NULL,
    accesscontrol_id integer NOT NULL,
    province_id integer NOT NULL
);


--
-- TOC entry 272 (class 1259 OID 21350)
-- Name: account_accesscontrol_provinces_id_seq; Type: SEQUENCE; Schema: api; Owner: -
--

CREATE SEQUENCE api.account_accesscontrol_provinces_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 7604 (class 0 OID 0)
-- Dependencies: 272
-- Name: account_accesscontrol_provinces_id_seq; Type: SEQUENCE OWNED BY; Schema: api; Owner: -
--

ALTER SEQUENCE api.account_accesscontrol_provinces_id_seq OWNED BY api.account_accesscontrol_provinces.id;


--
-- TOC entry 275 (class 1259 OID 21360)
-- Name: account_accesscontrol_rooms; Type: TABLE; Schema: api; Owner: -
--

CREATE TABLE api.account_accesscontrol_rooms (
    id integer NOT NULL,
    accesscontrol_id integer NOT NULL,
    room_id integer NOT NULL
);


--
-- TOC entry 274 (class 1259 OID 21358)
-- Name: account_accesscontrol_rooms_id_seq; Type: SEQUENCE; Schema: api; Owner: -
--

CREATE SEQUENCE api.account_accesscontrol_rooms_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 7605 (class 0 OID 0)
-- Dependencies: 274
-- Name: account_accesscontrol_rooms_id_seq; Type: SEQUENCE OWNED BY; Schema: api; Owner: -
--

ALTER SEQUENCE api.account_accesscontrol_rooms_id_seq OWNED BY api.account_accesscontrol_rooms.id;


--
-- TOC entry 277 (class 1259 OID 21368)
-- Name: account_accesscontrol_universities; Type: TABLE; Schema: api; Owner: -
--

CREATE TABLE api.account_accesscontrol_universities (
    id integer NOT NULL,
    accesscontrol_id integer NOT NULL,
    university_id integer NOT NULL
);


--
-- TOC entry 276 (class 1259 OID 21366)
-- Name: account_accesscontrol_universities_id_seq; Type: SEQUENCE; Schema: api; Owner: -
--

CREATE SEQUENCE api.account_accesscontrol_universities_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 7606 (class 0 OID 0)
-- Dependencies: 276
-- Name: account_accesscontrol_universities_id_seq; Type: SEQUENCE OWNED BY; Schema: api; Owner: -
--

ALTER SEQUENCE api.account_accesscontrol_universities_id_seq OWNED BY api.account_accesscontrol_universities.id;


--
-- TOC entry 279 (class 1259 OID 21376)
-- Name: account_accesscontrol_warehouses; Type: TABLE; Schema: api; Owner: -
--

CREATE TABLE api.account_accesscontrol_warehouses (
    id integer NOT NULL,
    accesscontrol_id integer NOT NULL,
    warehouse_id integer NOT NULL
);


--
-- TOC entry 278 (class 1259 OID 21374)
-- Name: account_accesscontrol_warehouses_id_seq; Type: SEQUENCE; Schema: api; Owner: -
--

CREATE SEQUENCE api.account_accesscontrol_warehouses_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 7607 (class 0 OID 0)
-- Dependencies: 278
-- Name: account_accesscontrol_warehouses_id_seq; Type: SEQUENCE OWNED BY; Schema: api; Owner: -
--

ALTER SEQUENCE api.account_accesscontrol_warehouses_id_seq OWNED BY api.account_accesscontrol_warehouses.id;


--
-- TOC entry 263 (class 1259 OID 21305)
-- Name: account_user; Type: TABLE; Schema: api; Owner: -
--

CREATE TABLE api.account_user (
    id integer NOT NULL,
    password character varying(128) NOT NULL,
    last_login timestamp with time zone,
    is_superuser boolean NOT NULL,
    username character varying(150) NOT NULL,
    first_name character varying(150) NOT NULL,
    last_name character varying(150) NOT NULL,
    email character varying(254) NOT NULL,
    is_staff boolean NOT NULL,
    is_active boolean NOT NULL,
    date_joined timestamp with time zone NOT NULL,
    nid character varying(10),
    tel character varying(11)
);


--
-- TOC entry 265 (class 1259 OID 21318)
-- Name: account_user_groups; Type: TABLE; Schema: api; Owner: -
--

CREATE TABLE api.account_user_groups (
    id integer NOT NULL,
    user_id integer NOT NULL,
    group_id integer NOT NULL
);


--
-- TOC entry 264 (class 1259 OID 21316)
-- Name: account_user_groups_id_seq; Type: SEQUENCE; Schema: api; Owner: -
--

CREATE SEQUENCE api.account_user_groups_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 7608 (class 0 OID 0)
-- Dependencies: 264
-- Name: account_user_groups_id_seq; Type: SEQUENCE OWNED BY; Schema: api; Owner: -
--

ALTER SEQUENCE api.account_user_groups_id_seq OWNED BY api.account_user_groups.id;


--
-- TOC entry 262 (class 1259 OID 21303)
-- Name: account_user_id_seq; Type: SEQUENCE; Schema: api; Owner: -
--

CREATE SEQUENCE api.account_user_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 7609 (class 0 OID 0)
-- Dependencies: 262
-- Name: account_user_id_seq; Type: SEQUENCE OWNED BY; Schema: api; Owner: -
--

ALTER SEQUENCE api.account_user_id_seq OWNED BY api.account_user.id;


--
-- TOC entry 267 (class 1259 OID 21326)
-- Name: account_user_user_permissions; Type: TABLE; Schema: api; Owner: -
--

CREATE TABLE api.account_user_user_permissions (
    id integer NOT NULL,
    user_id integer NOT NULL,
    permission_id integer NOT NULL
);


--
-- TOC entry 266 (class 1259 OID 21324)
-- Name: account_user_user_permissions_id_seq; Type: SEQUENCE; Schema: api; Owner: -
--

CREATE SEQUENCE api.account_user_user_permissions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 7610 (class 0 OID 0)
-- Dependencies: 266
-- Name: account_user_user_permissions_id_seq; Type: SEQUENCE OWNED BY; Schema: api; Owner: -
--

ALTER SEQUENCE api.account_user_user_permissions_id_seq OWNED BY api.account_user_user_permissions.id;


--
-- TOC entry 259 (class 1259 OID 21261)
-- Name: auth_group; Type: TABLE; Schema: api; Owner: -
--

CREATE TABLE api.auth_group (
    id integer NOT NULL,
    name character varying(150) NOT NULL
);


--
-- TOC entry 258 (class 1259 OID 21259)
-- Name: auth_group_id_seq; Type: SEQUENCE; Schema: api; Owner: -
--

CREATE SEQUENCE api.auth_group_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 7611 (class 0 OID 0)
-- Dependencies: 258
-- Name: auth_group_id_seq; Type: SEQUENCE OWNED BY; Schema: api; Owner: -
--

ALTER SEQUENCE api.auth_group_id_seq OWNED BY api.auth_group.id;


--
-- TOC entry 261 (class 1259 OID 21271)
-- Name: auth_group_permissions; Type: TABLE; Schema: api; Owner: -
--

CREATE TABLE api.auth_group_permissions (
    id integer NOT NULL,
    group_id integer NOT NULL,
    permission_id integer NOT NULL
);


--
-- TOC entry 260 (class 1259 OID 21269)
-- Name: auth_group_permissions_id_seq; Type: SEQUENCE; Schema: api; Owner: -
--

CREATE SEQUENCE api.auth_group_permissions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 7612 (class 0 OID 0)
-- Dependencies: 260
-- Name: auth_group_permissions_id_seq; Type: SEQUENCE OWNED BY; Schema: api; Owner: -
--

ALTER SEQUENCE api.auth_group_permissions_id_seq OWNED BY api.auth_group_permissions.id;


--
-- TOC entry 257 (class 1259 OID 21253)
-- Name: auth_permission; Type: TABLE; Schema: api; Owner: -
--

CREATE TABLE api.auth_permission (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    content_type_id integer NOT NULL,
    codename character varying(100) NOT NULL
);


--
-- TOC entry 256 (class 1259 OID 21251)
-- Name: auth_permission_id_seq; Type: SEQUENCE; Schema: api; Owner: -
--

CREATE SEQUENCE api.auth_permission_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 7613 (class 0 OID 0)
-- Dependencies: 256
-- Name: auth_permission_id_seq; Type: SEQUENCE OWNED BY; Schema: api; Owner: -
--

ALTER SEQUENCE api.auth_permission_id_seq OWNED BY api.auth_permission.id;


--
-- TOC entry 282 (class 1259 OID 21610)
-- Name: authtoken_token; Type: TABLE; Schema: api; Owner: -
--

CREATE TABLE api.authtoken_token (
    key character varying(40) NOT NULL,
    created timestamp with time zone NOT NULL,
    user_id integer NOT NULL
);


--
-- TOC entry 473 (class 1259 OID 2608456)
-- Name: config_mapconfig; Type: TABLE; Schema: api; Owner: -
--

CREATE TABLE api.config_mapconfig (
    id integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    modified_at timestamp with time zone NOT NULL,
    center_lat double precision NOT NULL,
    center_lng double precision NOT NULL,
    zoom_level integer NOT NULL,
    CONSTRAINT config_mapconfig_zoom_level_check CHECK ((zoom_level >= 0))
);


--
-- TOC entry 472 (class 1259 OID 2608454)
-- Name: config_mapconfig_id_seq; Type: SEQUENCE; Schema: api; Owner: -
--

CREATE SEQUENCE api.config_mapconfig_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 7614 (class 0 OID 0)
-- Dependencies: 472
-- Name: config_mapconfig_id_seq; Type: SEQUENCE OWNED BY; Schema: api; Owner: -
--

ALTER SEQUENCE api.config_mapconfig_id_seq OWNED BY api.config_mapconfig.id;


--
-- TOC entry 241 (class 1259 OID 21140)
-- Name: core_center; Type: TABLE; Schema: api; Owner: -
--

CREATE TABLE api.core_center (
    id integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    modified_at timestamp with time zone NOT NULL,
    name character varying(75),
    technical_assistant_name character varying(100),
    technical_assistant_phone_number character varying(11),
    logo character varying(100),
    type_id integer,
    university_id integer,
    url character varying(200)
);


--
-- TOC entry 240 (class 1259 OID 21138)
-- Name: core_center_id_seq; Type: SEQUENCE; Schema: api; Owner: -
--

CREATE SEQUENCE api.core_center_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 7615 (class 0 OID 0)
-- Dependencies: 240
-- Name: core_center_id_seq; Type: SEQUENCE OWNED BY; Schema: api; Owner: -
--

ALTER SEQUENCE api.core_center_id_seq OWNED BY api.core_center.id;


--
-- TOC entry 243 (class 1259 OID 21148)
-- Name: core_centertype; Type: TABLE; Schema: api; Owner: -
--

CREATE TABLE api.core_centertype (
    id integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    modified_at timestamp with time zone NOT NULL,
    name character varying(75)
);


--
-- TOC entry 242 (class 1259 OID 21146)
-- Name: core_centertype_id_seq; Type: SEQUENCE; Schema: api; Owner: -
--

CREATE SEQUENCE api.core_centertype_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 7616 (class 0 OID 0)
-- Dependencies: 242
-- Name: core_centertype_id_seq; Type: SEQUENCE OWNED BY; Schema: api; Owner: -
--

ALTER SEQUENCE api.core_centertype_id_seq OWNED BY api.core_centertype.id;


--
-- TOC entry 245 (class 1259 OID 21156)
-- Name: core_province; Type: TABLE; Schema: api; Owner: -
--

CREATE TABLE api.core_province (
    id integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    modified_at timestamp with time zone NOT NULL,
    name character varying(50)
);


--
-- TOC entry 244 (class 1259 OID 21154)
-- Name: core_province_id_seq; Type: SEQUENCE; Schema: api; Owner: -
--

CREATE SEQUENCE api.core_province_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 7617 (class 0 OID 0)
-- Dependencies: 244
-- Name: core_province_id_seq; Type: SEQUENCE OWNED BY; Schema: api; Owner: -
--

ALTER SEQUENCE api.core_province_id_seq OWNED BY api.core_province.id;


--
-- TOC entry 251 (class 1259 OID 21182)
-- Name: core_room; Type: TABLE; Schema: api; Owner: -
--

CREATE TABLE api.core_room (
    id integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    modified_at timestamp with time zone NOT NULL,
    room_id character varying(8),
    name character varying(75),
    warehouse_id integer
);


--
-- TOC entry 250 (class 1259 OID 21180)
-- Name: core_room_id_seq; Type: SEQUENCE; Schema: api; Owner: -
--

CREATE SEQUENCE api.core_room_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 7618 (class 0 OID 0)
-- Dependencies: 250
-- Name: core_room_id_seq; Type: SEQUENCE OWNED BY; Schema: api; Owner: -
--

ALTER SEQUENCE api.core_room_id_seq OWNED BY api.core_room.id;


--
-- TOC entry 253 (class 1259 OID 21200)
-- Name: core_sensor; Type: TABLE; Schema: api; Owner: -
--

CREATE TABLE api.core_sensor (
    id integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    modified_at timestamp with time zone NOT NULL,
    sensor_id character varying(8),
    name character varying(35),
    type character varying(2),
    is_fixed boolean,
    is_active boolean,
    is_at_service boolean,
    temp_min_val double precision,
    temp_max_val double precision,
    allowed_temp_min_violation_time integer,
    allowed_temp_max_violation_time integer,
    hum_min_val double precision,
    hum_max_val double precision,
    allowed_hum_min_violation_time integer,
    allowed_hum_max_violation_time integer,
    room_id integer,
    latitude double precision,
    longitude double precision,
    sensor_serial character varying(8),
    number_plate character varying(20),
    CONSTRAINT core_sensor_allowed_hum_max_violation_time_check CHECK ((allowed_hum_max_violation_time >= 0)),
    CONSTRAINT core_sensor_allowed_hum_min_violation_time_check CHECK ((allowed_hum_min_violation_time >= 0)),
    CONSTRAINT core_sensor_allowed_temp_max_violation_time_check CHECK ((allowed_temp_max_violation_time >= 0)),
    CONSTRAINT core_sensor_allowed_temp_min_violation_time_check CHECK ((allowed_temp_min_violation_time >= 0))
);


--
-- TOC entry 252 (class 1259 OID 21198)
-- Name: core_sensor_id_seq; Type: SEQUENCE; Schema: api; Owner: -
--

CREATE SEQUENCE api.core_sensor_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 7619 (class 0 OID 0)
-- Dependencies: 252
-- Name: core_sensor_id_seq; Type: SEQUENCE OWNED BY; Schema: api; Owner: -
--

ALTER SEQUENCE api.core_sensor_id_seq OWNED BY api.core_sensor.id;


--
-- TOC entry 249 (class 1259 OID 21174)
-- Name: core_university; Type: TABLE; Schema: api; Owner: -
--

CREATE TABLE api.core_university (
    id integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    modified_at timestamp with time zone NOT NULL,
    name character varying(150),
    province_id integer
);


--
-- TOC entry 248 (class 1259 OID 21172)
-- Name: core_university_id_seq; Type: SEQUENCE; Schema: api; Owner: -
--

CREATE SEQUENCE api.core_university_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 7620 (class 0 OID 0)
-- Dependencies: 248
-- Name: core_university_id_seq; Type: SEQUENCE OWNED BY; Schema: api; Owner: -
--

ALTER SEQUENCE api.core_university_id_seq OWNED BY api.core_university.id;


--
-- TOC entry 247 (class 1259 OID 21166)
-- Name: core_warehouse; Type: TABLE; Schema: api; Owner: -
--

CREATE TABLE api.core_warehouse (
    id integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    modified_at timestamp with time zone NOT NULL,
    warehouse_id character varying(8),
    name character varying(75),
    clerk_name character varying(100),
    clerk_phone_number character varying(11),
    center_id integer
);


--
-- TOC entry 246 (class 1259 OID 21164)
-- Name: core_warehouse_id_seq; Type: SEQUENCE; Schema: api; Owner: -
--

CREATE SEQUENCE api.core_warehouse_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 7621 (class 0 OID 0)
-- Dependencies: 246
-- Name: core_warehouse_id_seq; Type: SEQUENCE OWNED BY; Schema: api; Owner: -
--

ALTER SEQUENCE api.core_warehouse_id_seq OWNED BY api.core_warehouse.id;


--
-- TOC entry 281 (class 1259 OID 21588)
-- Name: django_admin_log; Type: TABLE; Schema: api; Owner: -
--

CREATE TABLE api.django_admin_log (
    id integer NOT NULL,
    action_time timestamp with time zone NOT NULL,
    object_id text,
    object_repr character varying(200) NOT NULL,
    action_flag smallint NOT NULL,
    change_message text NOT NULL,
    content_type_id integer,
    user_id integer NOT NULL,
    CONSTRAINT django_admin_log_action_flag_check CHECK ((action_flag >= 0))
);


--
-- TOC entry 280 (class 1259 OID 21586)
-- Name: django_admin_log_id_seq; Type: SEQUENCE; Schema: api; Owner: -
--

CREATE SEQUENCE api.django_admin_log_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 7622 (class 0 OID 0)
-- Dependencies: 280
-- Name: django_admin_log_id_seq; Type: SEQUENCE OWNED BY; Schema: api; Owner: -
--

ALTER SEQUENCE api.django_admin_log_id_seq OWNED BY api.django_admin_log.id;


--
-- TOC entry 255 (class 1259 OID 21243)
-- Name: django_content_type; Type: TABLE; Schema: api; Owner: -
--

CREATE TABLE api.django_content_type (
    id integer NOT NULL,
    app_label character varying(100) NOT NULL,
    model character varying(100) NOT NULL
);


--
-- TOC entry 254 (class 1259 OID 21241)
-- Name: django_content_type_id_seq; Type: SEQUENCE; Schema: api; Owner: -
--

CREATE SEQUENCE api.django_content_type_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 7623 (class 0 OID 0)
-- Dependencies: 254
-- Name: django_content_type_id_seq; Type: SEQUENCE OWNED BY; Schema: api; Owner: -
--

ALTER SEQUENCE api.django_content_type_id_seq OWNED BY api.django_content_type.id;


--
-- TOC entry 239 (class 1259 OID 21129)
-- Name: django_migrations; Type: TABLE; Schema: api; Owner: -
--

CREATE TABLE api.django_migrations (
    id integer NOT NULL,
    app character varying(255) NOT NULL,
    name character varying(255) NOT NULL,
    applied timestamp with time zone NOT NULL
);


--
-- TOC entry 238 (class 1259 OID 21127)
-- Name: django_migrations_id_seq; Type: SEQUENCE; Schema: api; Owner: -
--

CREATE SEQUENCE api.django_migrations_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 7624 (class 0 OID 0)
-- Dependencies: 238
-- Name: django_migrations_id_seq; Type: SEQUENCE OWNED BY; Schema: api; Owner: -
--

ALTER SEQUENCE api.django_migrations_id_seq OWNED BY api.django_migrations.id;


--
-- TOC entry 283 (class 1259 OID 21652)
-- Name: django_session; Type: TABLE; Schema: api; Owner: -
--

CREATE TABLE api.django_session (
    session_key character varying(40) NOT NULL,
    session_data text NOT NULL,
    expire_date timestamp with time zone NOT NULL
);


--
-- TOC entry 284 (class 1259 OID 21760)
-- Name: received_data; Type: TABLE; Schema: data; Owner: -
--

CREATE TABLE data.received_data (
    id bigint NOT NULL,
    branch_id character(8),
    room_id character(8),
    sensor_id character(8),
    sensor_type character(2),
    log_date_time timestamp without time zone,
    latitude double precision,
    longitude double precision,
    temperature double precision,
    humidity double precision
);


--
-- TOC entry 285 (class 1259 OID 21763)
-- Name: received_data_id_seq; Type: SEQUENCE; Schema: data; Owner: -
--

CREATE SEQUENCE data.received_data_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 7625 (class 0 OID 0)
-- Dependencies: 285
-- Name: received_data_id_seq; Type: SEQUENCE OWNED BY; Schema: data; Owner: -
--

ALTER SEQUENCE data.received_data_id_seq OWNED BY data.received_data.id;


--
-- TOC entry 286 (class 1259 OID 21765)
-- Name: sensor_data; Type: TABLE; Schema: data; Owner: -
--

CREATE TABLE data.sensor_data (
    id bigint NOT NULL,
    branch_id character(8),
    room_id character(8),
    sensor_id character(8),
    sensor_type character(2),
    log_date_time timestamp without time zone,
    latitude double precision,
    longitude double precision,
    temperature double precision,
    humidity double precision,
    temperature_max double precision,
    temperature_min double precision,
    humidity_max double precision,
    humidity_min double precision
);


--
-- TOC entry 288 (class 1259 OID 22014)
-- Name: sensor_data_id_seq; Type: SEQUENCE; Schema: data; Owner: -
--

CREATE SEQUENCE data.sensor_data_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 7626 (class 0 OID 0)
-- Dependencies: 288
-- Name: sensor_data_id_seq; Type: SEQUENCE OWNED BY; Schema: data; Owner: -
--

ALTER SEQUENCE data.sensor_data_id_seq OWNED BY data.sensor_data.id;


--
-- TOC entry 293 (class 1259 OID 2145737)
-- Name: sensor_last_data; Type: TABLE; Schema: data; Owner: -
--

CREATE TABLE data.sensor_last_data (
    id bigint NOT NULL,
    sensor_id bigint NOT NULL,
    latitude double precision,
    longitude double precision,
    temperature double precision,
    humidity double precision,
    temperature_max double precision,
    temperature_min double precision,
    humidity_max double precision,
    humidity_min double precision,
    first_log_date_time timestamp without time zone,
    last_log_date_time timestamp without time zone,
    create_date timestamp without time zone,
    last_update timestamp without time zone
);


--
-- TOC entry 292 (class 1259 OID 2145735)
-- Name: sensor_last_data_id_seq; Type: SEQUENCE; Schema: data; Owner: -
--

CREATE SEQUENCE data.sensor_last_data_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 7627 (class 0 OID 0)
-- Dependencies: 292
-- Name: sensor_last_data_id_seq; Type: SEQUENCE OWNED BY; Schema: data; Owner: -
--

ALTER SEQUENCE data.sensor_last_data_id_seq OWNED BY data.sensor_last_data.id;


--
-- TOC entry 289 (class 1259 OID 22021)
-- Name: sensors; Type: VIEW; Schema: data; Owner: -
--

CREATE VIEW data.sensors AS
 SELECT w.warehouse_id,
    r.room_id,
    s.sensor_id,
    c.url
   FROM (((api.core_center c
     LEFT JOIN api.core_warehouse w ON ((w.center_id = c.id)))
     LEFT JOIN api.core_room r ON ((w.id = r.warehouse_id)))
     LEFT JOIN api.core_sensor s ON ((r.id = s.room_id)));


--
-- TOC entry 290 (class 1259 OID 22026)
-- Name: tables; Type: TABLE; Schema: data; Owner: -
--

CREATE TABLE data.tables (
    id integer NOT NULL,
    created date,
    table_name character varying(18)
);


--
-- TOC entry 291 (class 1259 OID 22029)
-- Name: tables_id_seq; Type: SEQUENCE; Schema: data; Owner: -
--

CREATE SEQUENCE data.tables_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 7628 (class 0 OID 0)
-- Dependencies: 291
-- Name: tables_id_seq; Type: SEQUENCE OWNED BY; Schema: data; Owner: -
--

ALTER SEQUENCE data.tables_id_seq OWNED BY data.tables.id;


--
-- TOC entry 6145 (class 2604 OID 21337)
-- Name: account_accesscontrol id; Type: DEFAULT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.account_accesscontrol ALTER COLUMN id SET DEFAULT nextval('api.account_accesscontrol_id_seq'::regclass);


--
-- TOC entry 6146 (class 2604 OID 21347)
-- Name: account_accesscontrol_centers id; Type: DEFAULT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.account_accesscontrol_centers ALTER COLUMN id SET DEFAULT nextval('api.account_accesscontrol_centers_id_seq'::regclass);


--
-- TOC entry 6147 (class 2604 OID 21355)
-- Name: account_accesscontrol_provinces id; Type: DEFAULT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.account_accesscontrol_provinces ALTER COLUMN id SET DEFAULT nextval('api.account_accesscontrol_provinces_id_seq'::regclass);


--
-- TOC entry 6148 (class 2604 OID 21363)
-- Name: account_accesscontrol_rooms id; Type: DEFAULT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.account_accesscontrol_rooms ALTER COLUMN id SET DEFAULT nextval('api.account_accesscontrol_rooms_id_seq'::regclass);


--
-- TOC entry 6149 (class 2604 OID 21371)
-- Name: account_accesscontrol_universities id; Type: DEFAULT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.account_accesscontrol_universities ALTER COLUMN id SET DEFAULT nextval('api.account_accesscontrol_universities_id_seq'::regclass);


--
-- TOC entry 6150 (class 2604 OID 21379)
-- Name: account_accesscontrol_warehouses id; Type: DEFAULT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.account_accesscontrol_warehouses ALTER COLUMN id SET DEFAULT nextval('api.account_accesscontrol_warehouses_id_seq'::regclass);


--
-- TOC entry 6142 (class 2604 OID 21308)
-- Name: account_user id; Type: DEFAULT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.account_user ALTER COLUMN id SET DEFAULT nextval('api.account_user_id_seq'::regclass);


--
-- TOC entry 6143 (class 2604 OID 21321)
-- Name: account_user_groups id; Type: DEFAULT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.account_user_groups ALTER COLUMN id SET DEFAULT nextval('api.account_user_groups_id_seq'::regclass);


--
-- TOC entry 6144 (class 2604 OID 21329)
-- Name: account_user_user_permissions id; Type: DEFAULT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.account_user_user_permissions ALTER COLUMN id SET DEFAULT nextval('api.account_user_user_permissions_id_seq'::regclass);


--
-- TOC entry 6140 (class 2604 OID 21264)
-- Name: auth_group id; Type: DEFAULT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.auth_group ALTER COLUMN id SET DEFAULT nextval('api.auth_group_id_seq'::regclass);


--
-- TOC entry 6141 (class 2604 OID 21274)
-- Name: auth_group_permissions id; Type: DEFAULT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.auth_group_permissions ALTER COLUMN id SET DEFAULT nextval('api.auth_group_permissions_id_seq'::regclass);


--
-- TOC entry 6139 (class 2604 OID 21256)
-- Name: auth_permission id; Type: DEFAULT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.auth_permission ALTER COLUMN id SET DEFAULT nextval('api.auth_permission_id_seq'::regclass);


--
-- TOC entry 6246 (class 2604 OID 2608459)
-- Name: config_mapconfig id; Type: DEFAULT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.config_mapconfig ALTER COLUMN id SET DEFAULT nextval('api.config_mapconfig_id_seq'::regclass);


--
-- TOC entry 6127 (class 2604 OID 21143)
-- Name: core_center id; Type: DEFAULT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.core_center ALTER COLUMN id SET DEFAULT nextval('api.core_center_id_seq'::regclass);


--
-- TOC entry 6128 (class 2604 OID 21151)
-- Name: core_centertype id; Type: DEFAULT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.core_centertype ALTER COLUMN id SET DEFAULT nextval('api.core_centertype_id_seq'::regclass);


--
-- TOC entry 6129 (class 2604 OID 21159)
-- Name: core_province id; Type: DEFAULT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.core_province ALTER COLUMN id SET DEFAULT nextval('api.core_province_id_seq'::regclass);


--
-- TOC entry 6132 (class 2604 OID 21185)
-- Name: core_room id; Type: DEFAULT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.core_room ALTER COLUMN id SET DEFAULT nextval('api.core_room_id_seq'::regclass);


--
-- TOC entry 6133 (class 2604 OID 21203)
-- Name: core_sensor id; Type: DEFAULT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.core_sensor ALTER COLUMN id SET DEFAULT nextval('api.core_sensor_id_seq'::regclass);


--
-- TOC entry 6131 (class 2604 OID 21177)
-- Name: core_university id; Type: DEFAULT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.core_university ALTER COLUMN id SET DEFAULT nextval('api.core_university_id_seq'::regclass);


--
-- TOC entry 6130 (class 2604 OID 21169)
-- Name: core_warehouse id; Type: DEFAULT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.core_warehouse ALTER COLUMN id SET DEFAULT nextval('api.core_warehouse_id_seq'::regclass);


--
-- TOC entry 6151 (class 2604 OID 21591)
-- Name: django_admin_log id; Type: DEFAULT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.django_admin_log ALTER COLUMN id SET DEFAULT nextval('api.django_admin_log_id_seq'::regclass);


--
-- TOC entry 6138 (class 2604 OID 21246)
-- Name: django_content_type id; Type: DEFAULT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.django_content_type ALTER COLUMN id SET DEFAULT nextval('api.django_content_type_id_seq'::regclass);


--
-- TOC entry 6126 (class 2604 OID 21132)
-- Name: django_migrations id; Type: DEFAULT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.django_migrations ALTER COLUMN id SET DEFAULT nextval('api.django_migrations_id_seq'::regclass);


--
-- TOC entry 6153 (class 2604 OID 22184)
-- Name: received_data id; Type: DEFAULT; Schema: data; Owner: -
--

ALTER TABLE ONLY data.received_data ALTER COLUMN id SET DEFAULT nextval('data.received_data_id_seq'::regclass);


--
-- TOC entry 6154 (class 2604 OID 22185)
-- Name: sensor_data id; Type: DEFAULT; Schema: data; Owner: -
--

ALTER TABLE ONLY data.sensor_data ALTER COLUMN id SET DEFAULT nextval('data.sensor_data_id_seq'::regclass);


--
-- TOC entry 6156 (class 2604 OID 2145740)
-- Name: sensor_last_data id; Type: DEFAULT; Schema: data; Owner: -
--

ALTER TABLE ONLY data.sensor_last_data ALTER COLUMN id SET DEFAULT nextval('data.sensor_last_data_id_seq'::regclass);


--
-- TOC entry 6155 (class 2604 OID 22187)
-- Name: tables id; Type: DEFAULT; Schema: data; Owner: -
--

ALTER TABLE ONLY data.tables ALTER COLUMN id SET DEFAULT nextval('data.tables_id_seq'::regclass);


--
-- TOC entry 6518 (class 2606 OID 21417)
-- Name: account_accesscontrol_centers account_accesscontrol_ce_accesscontrol_id_center__362b29d1_uniq; Type: CONSTRAINT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.account_accesscontrol_centers
    ADD CONSTRAINT account_accesscontrol_ce_accesscontrol_id_center__362b29d1_uniq UNIQUE (accesscontrol_id, center_id);


--
-- TOC entry 6522 (class 2606 OID 21349)
-- Name: account_accesscontrol_centers account_accesscontrol_centers_pkey; Type: CONSTRAINT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.account_accesscontrol_centers
    ADD CONSTRAINT account_accesscontrol_centers_pkey PRIMARY KEY (id);


--
-- TOC entry 6514 (class 2606 OID 21339)
-- Name: account_accesscontrol account_accesscontrol_pkey; Type: CONSTRAINT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.account_accesscontrol
    ADD CONSTRAINT account_accesscontrol_pkey PRIMARY KEY (id);


--
-- TOC entry 6524 (class 2606 OID 21431)
-- Name: account_accesscontrol_provinces account_accesscontrol_pr_accesscontrol_id_provinc_0c567da1_uniq; Type: CONSTRAINT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.account_accesscontrol_provinces
    ADD CONSTRAINT account_accesscontrol_pr_accesscontrol_id_provinc_0c567da1_uniq UNIQUE (accesscontrol_id, province_id);


--
-- TOC entry 6527 (class 2606 OID 21357)
-- Name: account_accesscontrol_provinces account_accesscontrol_provinces_pkey; Type: CONSTRAINT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.account_accesscontrol_provinces
    ADD CONSTRAINT account_accesscontrol_provinces_pkey PRIMARY KEY (id);


--
-- TOC entry 6530 (class 2606 OID 21445)
-- Name: account_accesscontrol_rooms account_accesscontrol_ro_accesscontrol_id_room_id_10e09ec4_uniq; Type: CONSTRAINT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.account_accesscontrol_rooms
    ADD CONSTRAINT account_accesscontrol_ro_accesscontrol_id_room_id_10e09ec4_uniq UNIQUE (accesscontrol_id, room_id);


--
-- TOC entry 6533 (class 2606 OID 21365)
-- Name: account_accesscontrol_rooms account_accesscontrol_rooms_pkey; Type: CONSTRAINT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.account_accesscontrol_rooms
    ADD CONSTRAINT account_accesscontrol_rooms_pkey PRIMARY KEY (id);


--
-- TOC entry 6536 (class 2606 OID 21459)
-- Name: account_accesscontrol_universities account_accesscontrol_un_accesscontrol_id_univers_a239311f_uniq; Type: CONSTRAINT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.account_accesscontrol_universities
    ADD CONSTRAINT account_accesscontrol_un_accesscontrol_id_univers_a239311f_uniq UNIQUE (accesscontrol_id, university_id);


--
-- TOC entry 6539 (class 2606 OID 21373)
-- Name: account_accesscontrol_universities account_accesscontrol_universities_pkey; Type: CONSTRAINT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.account_accesscontrol_universities
    ADD CONSTRAINT account_accesscontrol_universities_pkey PRIMARY KEY (id);


--
-- TOC entry 6516 (class 2606 OID 21341)
-- Name: account_accesscontrol account_accesscontrol_user_id_key; Type: CONSTRAINT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.account_accesscontrol
    ADD CONSTRAINT account_accesscontrol_user_id_key UNIQUE (user_id);


--
-- TOC entry 6542 (class 2606 OID 21473)
-- Name: account_accesscontrol_warehouses account_accesscontrol_wa_accesscontrol_id_warehou_12dea6bf_uniq; Type: CONSTRAINT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.account_accesscontrol_warehouses
    ADD CONSTRAINT account_accesscontrol_wa_accesscontrol_id_warehou_12dea6bf_uniq UNIQUE (accesscontrol_id, warehouse_id);


--
-- TOC entry 6545 (class 2606 OID 21381)
-- Name: account_accesscontrol_warehouses account_accesscontrol_warehouses_pkey; Type: CONSTRAINT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.account_accesscontrol_warehouses
    ADD CONSTRAINT account_accesscontrol_warehouses_pkey PRIMARY KEY (id);


--
-- TOC entry 6503 (class 2606 OID 21323)
-- Name: account_user_groups account_user_groups_pkey; Type: CONSTRAINT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.account_user_groups
    ADD CONSTRAINT account_user_groups_pkey PRIMARY KEY (id);


--
-- TOC entry 6506 (class 2606 OID 21384)
-- Name: account_user_groups account_user_groups_user_id_group_id_4d09af3e_uniq; Type: CONSTRAINT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.account_user_groups
    ADD CONSTRAINT account_user_groups_user_id_group_id_4d09af3e_uniq UNIQUE (user_id, group_id);


--
-- TOC entry 6497 (class 2606 OID 21313)
-- Name: account_user account_user_pkey; Type: CONSTRAINT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.account_user
    ADD CONSTRAINT account_user_pkey PRIMARY KEY (id);


--
-- TOC entry 6508 (class 2606 OID 21398)
-- Name: account_user_user_permissions account_user_user_permis_user_id_permission_id_48bdd28b_uniq; Type: CONSTRAINT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.account_user_user_permissions
    ADD CONSTRAINT account_user_user_permis_user_id_permission_id_48bdd28b_uniq UNIQUE (user_id, permission_id);


--
-- TOC entry 6511 (class 2606 OID 21331)
-- Name: account_user_user_permissions account_user_user_permissions_pkey; Type: CONSTRAINT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.account_user_user_permissions
    ADD CONSTRAINT account_user_user_permissions_pkey PRIMARY KEY (id);


--
-- TOC entry 6500 (class 2606 OID 21315)
-- Name: account_user account_user_username_key; Type: CONSTRAINT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.account_user
    ADD CONSTRAINT account_user_username_key UNIQUE (username);


--
-- TOC entry 6487 (class 2606 OID 21301)
-- Name: auth_group auth_group_name_key; Type: CONSTRAINT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.auth_group
    ADD CONSTRAINT auth_group_name_key UNIQUE (name);


--
-- TOC entry 6492 (class 2606 OID 21287)
-- Name: auth_group_permissions auth_group_permissions_group_id_permission_id_0cd325b0_uniq; Type: CONSTRAINT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.auth_group_permissions
    ADD CONSTRAINT auth_group_permissions_group_id_permission_id_0cd325b0_uniq UNIQUE (group_id, permission_id);


--
-- TOC entry 6495 (class 2606 OID 21276)
-- Name: auth_group_permissions auth_group_permissions_pkey; Type: CONSTRAINT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.auth_group_permissions
    ADD CONSTRAINT auth_group_permissions_pkey PRIMARY KEY (id);


--
-- TOC entry 6489 (class 2606 OID 21266)
-- Name: auth_group auth_group_pkey; Type: CONSTRAINT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.auth_group
    ADD CONSTRAINT auth_group_pkey PRIMARY KEY (id);


--
-- TOC entry 6482 (class 2606 OID 21278)
-- Name: auth_permission auth_permission_content_type_id_codename_01ab375a_uniq; Type: CONSTRAINT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.auth_permission
    ADD CONSTRAINT auth_permission_content_type_id_codename_01ab375a_uniq UNIQUE (content_type_id, codename);


--
-- TOC entry 6484 (class 2606 OID 21258)
-- Name: auth_permission auth_permission_pkey; Type: CONSTRAINT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.auth_permission
    ADD CONSTRAINT auth_permission_pkey PRIMARY KEY (id);


--
-- TOC entry 6553 (class 2606 OID 21614)
-- Name: authtoken_token authtoken_token_pkey; Type: CONSTRAINT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.authtoken_token
    ADD CONSTRAINT authtoken_token_pkey PRIMARY KEY (key);


--
-- TOC entry 6555 (class 2606 OID 21616)
-- Name: authtoken_token authtoken_token_user_id_key; Type: CONSTRAINT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.authtoken_token
    ADD CONSTRAINT authtoken_token_user_id_key UNIQUE (user_id);


--
-- TOC entry 6750 (class 2606 OID 2608462)
-- Name: config_mapconfig config_mapconfig_pkey; Type: CONSTRAINT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.config_mapconfig
    ADD CONSTRAINT config_mapconfig_pkey PRIMARY KEY (id);


--
-- TOC entry 6450 (class 2606 OID 21145)
-- Name: core_center core_center_pkey; Type: CONSTRAINT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.core_center
    ADD CONSTRAINT core_center_pkey PRIMARY KEY (id);


--
-- TOC entry 6454 (class 2606 OID 21153)
-- Name: core_centertype core_centertype_pkey; Type: CONSTRAINT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.core_centertype
    ADD CONSTRAINT core_centertype_pkey PRIMARY KEY (id);


--
-- TOC entry 6457 (class 2606 OID 21163)
-- Name: core_province core_province_name_key; Type: CONSTRAINT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.core_province
    ADD CONSTRAINT core_province_name_key UNIQUE (name);


--
-- TOC entry 6459 (class 2606 OID 21161)
-- Name: core_province core_province_pkey; Type: CONSTRAINT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.core_province
    ADD CONSTRAINT core_province_pkey PRIMARY KEY (id);


--
-- TOC entry 6467 (class 2606 OID 21187)
-- Name: core_room core_room_pkey; Type: CONSTRAINT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.core_room
    ADD CONSTRAINT core_room_pkey PRIMARY KEY (id);


--
-- TOC entry 6469 (class 2606 OID 21224)
-- Name: core_room core_room_room_id_warehouse_id_6354b4bd_uniq; Type: CONSTRAINT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.core_room
    ADD CONSTRAINT core_room_room_id_warehouse_id_6354b4bd_uniq UNIQUE (room_id, warehouse_id);


--
-- TOC entry 6472 (class 2606 OID 21209)
-- Name: core_sensor core_sensor_pkey; Type: CONSTRAINT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.core_sensor
    ADD CONSTRAINT core_sensor_pkey PRIMARY KEY (id);


--
-- TOC entry 6475 (class 2606 OID 21234)
-- Name: core_sensor core_sensor_sensor_id_room_id_fd423472_uniq; Type: CONSTRAINT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.core_sensor
    ADD CONSTRAINT core_sensor_sensor_id_room_id_fd423472_uniq UNIQUE (sensor_id, room_id);


--
-- TOC entry 6464 (class 2606 OID 21179)
-- Name: core_university core_university_pkey; Type: CONSTRAINT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.core_university
    ADD CONSTRAINT core_university_pkey PRIMARY KEY (id);


--
-- TOC entry 6462 (class 2606 OID 21171)
-- Name: core_warehouse core_warehouse_pkey; Type: CONSTRAINT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.core_warehouse
    ADD CONSTRAINT core_warehouse_pkey PRIMARY KEY (id);


--
-- TOC entry 6549 (class 2606 OID 21597)
-- Name: django_admin_log django_admin_log_pkey; Type: CONSTRAINT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.django_admin_log
    ADD CONSTRAINT django_admin_log_pkey PRIMARY KEY (id);


--
-- TOC entry 6477 (class 2606 OID 21250)
-- Name: django_content_type django_content_type_app_label_model_76bd3d3b_uniq; Type: CONSTRAINT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.django_content_type
    ADD CONSTRAINT django_content_type_app_label_model_76bd3d3b_uniq UNIQUE (app_label, model);


--
-- TOC entry 6479 (class 2606 OID 21248)
-- Name: django_content_type django_content_type_pkey; Type: CONSTRAINT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.django_content_type
    ADD CONSTRAINT django_content_type_pkey PRIMARY KEY (id);


--
-- TOC entry 6448 (class 2606 OID 21137)
-- Name: django_migrations django_migrations_pkey; Type: CONSTRAINT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.django_migrations
    ADD CONSTRAINT django_migrations_pkey PRIMARY KEY (id);


--
-- TOC entry 6558 (class 2606 OID 21659)
-- Name: django_session django_session_pkey; Type: CONSTRAINT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.django_session
    ADD CONSTRAINT django_session_pkey PRIMARY KEY (session_key);


--
-- TOC entry 6561 (class 2606 OID 22036)
-- Name: received_data received_data_pkey; Type: CONSTRAINT; Schema: data; Owner: -
--

ALTER TABLE ONLY data.received_data
    ADD CONSTRAINT received_data_pkey PRIMARY KEY (id);

--
-- TOC entry 6563 (class 2606 OID 22120)
-- Name: sensor_data sensor_data_branch_id_room_id_sensor_id_log_date_time_key; Type: CONSTRAINT; Schema: data; Owner: -
--

ALTER TABLE ONLY data.sensor_data
    ADD CONSTRAINT sensor_data_branch_id_room_id_sensor_id_log_date_time_key UNIQUE (branch_id, room_id, sensor_id, log_date_time);


--
-- TOC entry 6565 (class 2606 OID 22122)
-- Name: sensor_data sensor_data_pkey; Type: CONSTRAINT; Schema: data; Owner: -
--

ALTER TABLE ONLY data.sensor_data
    ADD CONSTRAINT sensor_data_pkey PRIMARY KEY (id);


--
-- TOC entry 6569 (class 2606 OID 2145742)
-- Name: sensor_last_data sensor_last_data_pkey; Type: CONSTRAINT; Schema: data; Owner: -
--

ALTER TABLE ONLY data.sensor_last_data
    ADD CONSTRAINT sensor_last_data_pkey PRIMARY KEY (id);


--
-- TOC entry 6567 (class 2606 OID 22126)
-- Name: tables tables_pkey; Type: CONSTRAINT; Schema: data; Owner: -
--

ALTER TABLE ONLY data.tables
    ADD CONSTRAINT tables_pkey PRIMARY KEY (id);


--
-- TOC entry 6519 (class 1259 OID 21428)
-- Name: account_accesscontrol_centers_accesscontrol_id_7976ad55; Type: INDEX; Schema: api; Owner: -
--

CREATE INDEX account_accesscontrol_centers_accesscontrol_id_7976ad55 ON api.account_accesscontrol_centers USING btree (accesscontrol_id);


--
-- TOC entry 6520 (class 1259 OID 21429)
-- Name: account_accesscontrol_centers_center_id_ea302d08; Type: INDEX; Schema: api; Owner: -
--

CREATE INDEX account_accesscontrol_centers_center_id_ea302d08 ON api.account_accesscontrol_centers USING btree (center_id);


--
-- TOC entry 6525 (class 1259 OID 21442)
-- Name: account_accesscontrol_provinces_accesscontrol_id_026b0beb; Type: INDEX; Schema: api; Owner: -
--

CREATE INDEX account_accesscontrol_provinces_accesscontrol_id_026b0beb ON api.account_accesscontrol_provinces USING btree (accesscontrol_id);


--
-- TOC entry 6528 (class 1259 OID 21443)
-- Name: account_accesscontrol_provinces_province_id_f80cc937; Type: INDEX; Schema: api; Owner: -
--

CREATE INDEX account_accesscontrol_provinces_province_id_f80cc937 ON api.account_accesscontrol_provinces USING btree (province_id);


--
-- TOC entry 6531 (class 1259 OID 21456)
-- Name: account_accesscontrol_rooms_accesscontrol_id_2325bdf1; Type: INDEX; Schema: api; Owner: -
--

CREATE INDEX account_accesscontrol_rooms_accesscontrol_id_2325bdf1 ON api.account_accesscontrol_rooms USING btree (accesscontrol_id);


--
-- TOC entry 6534 (class 1259 OID 21457)
-- Name: account_accesscontrol_rooms_room_id_6b721e90; Type: INDEX; Schema: api; Owner: -
--

CREATE INDEX account_accesscontrol_rooms_room_id_6b721e90 ON api.account_accesscontrol_rooms USING btree (room_id);


--
-- TOC entry 6537 (class 1259 OID 21470)
-- Name: account_accesscontrol_universities_accesscontrol_id_35d18f80; Type: INDEX; Schema: api; Owner: -
--

CREATE INDEX account_accesscontrol_universities_accesscontrol_id_35d18f80 ON api.account_accesscontrol_universities USING btree (accesscontrol_id);


--
-- TOC entry 6540 (class 1259 OID 21471)
-- Name: account_accesscontrol_universities_university_id_ff725435; Type: INDEX; Schema: api; Owner: -
--

CREATE INDEX account_accesscontrol_universities_university_id_ff725435 ON api.account_accesscontrol_universities USING btree (university_id);


--
-- TOC entry 6543 (class 1259 OID 21484)
-- Name: account_accesscontrol_warehouses_accesscontrol_id_cb137c69; Type: INDEX; Schema: api; Owner: -
--

CREATE INDEX account_accesscontrol_warehouses_accesscontrol_id_cb137c69 ON api.account_accesscontrol_warehouses USING btree (accesscontrol_id);


--
-- TOC entry 6546 (class 1259 OID 21485)
-- Name: account_accesscontrol_warehouses_warehouse_id_5f3a5c15; Type: INDEX; Schema: api; Owner: -
--

CREATE INDEX account_accesscontrol_warehouses_warehouse_id_5f3a5c15 ON api.account_accesscontrol_warehouses USING btree (warehouse_id);


--
-- TOC entry 6501 (class 1259 OID 21396)
-- Name: account_user_groups_group_id_6c71f749; Type: INDEX; Schema: api; Owner: -
--

CREATE INDEX account_user_groups_group_id_6c71f749 ON api.account_user_groups USING btree (group_id);


--
-- TOC entry 6504 (class 1259 OID 21395)
-- Name: account_user_groups_user_id_14345e7b; Type: INDEX; Schema: api; Owner: -
--

CREATE INDEX account_user_groups_user_id_14345e7b ON api.account_user_groups USING btree (user_id);


--
-- TOC entry 6509 (class 1259 OID 21410)
-- Name: account_user_user_permissions_permission_id_66c44191; Type: INDEX; Schema: api; Owner: -
--

CREATE INDEX account_user_user_permissions_permission_id_66c44191 ON api.account_user_user_permissions USING btree (permission_id);


--
-- TOC entry 6512 (class 1259 OID 21409)
-- Name: account_user_user_permissions_user_id_cc42d270; Type: INDEX; Schema: api; Owner: -
--

CREATE INDEX account_user_user_permissions_user_id_cc42d270 ON api.account_user_user_permissions USING btree (user_id);


--
-- TOC entry 6498 (class 1259 OID 21382)
-- Name: account_user_username_d393f583_like; Type: INDEX; Schema: api; Owner: -
--

CREATE INDEX account_user_username_d393f583_like ON api.account_user USING btree (username varchar_pattern_ops);


--
-- TOC entry 6485 (class 1259 OID 21302)
-- Name: auth_group_name_a6ea08ec_like; Type: INDEX; Schema: api; Owner: -
--

CREATE INDEX auth_group_name_a6ea08ec_like ON api.auth_group USING btree (name varchar_pattern_ops);


--
-- TOC entry 6490 (class 1259 OID 21298)
-- Name: auth_group_permissions_group_id_b120cbf9; Type: INDEX; Schema: api; Owner: -
--

CREATE INDEX auth_group_permissions_group_id_b120cbf9 ON api.auth_group_permissions USING btree (group_id);


--
-- TOC entry 6493 (class 1259 OID 21299)
-- Name: auth_group_permissions_permission_id_84c5c92e; Type: INDEX; Schema: api; Owner: -
--

CREATE INDEX auth_group_permissions_permission_id_84c5c92e ON api.auth_group_permissions USING btree (permission_id);


--
-- TOC entry 6480 (class 1259 OID 21284)
-- Name: auth_permission_content_type_id_2f476e4b; Type: INDEX; Schema: api; Owner: -
--

CREATE INDEX auth_permission_content_type_id_2f476e4b ON api.auth_permission USING btree (content_type_id);


--
-- TOC entry 6551 (class 1259 OID 21622)
-- Name: authtoken_token_key_10f0b77e_like; Type: INDEX; Schema: api; Owner: -
--

CREATE INDEX authtoken_token_key_10f0b77e_like ON api.authtoken_token USING btree (key varchar_pattern_ops);


--
-- TOC entry 6451 (class 1259 OID 21231)
-- Name: core_center_type_id_0a2ddb96; Type: INDEX; Schema: api; Owner: -
--

CREATE INDEX core_center_type_id_0a2ddb96 ON api.core_center USING btree (type_id);


--
-- TOC entry 6452 (class 1259 OID 21232)
-- Name: core_center_university_id_8e2d3747; Type: INDEX; Schema: api; Owner: -
--

CREATE INDEX core_center_university_id_8e2d3747 ON api.core_center USING btree (university_id);


--
-- TOC entry 6455 (class 1259 OID 21210)
-- Name: core_province_name_b2da7ae5_like; Type: INDEX; Schema: api; Owner: -
--

CREATE INDEX core_province_name_b2da7ae5_like ON api.core_province USING btree (name varchar_pattern_ops);


--
-- TOC entry 6470 (class 1259 OID 21230)
-- Name: core_room_warehouse_id_6a6f5de2; Type: INDEX; Schema: api; Owner: -
--

CREATE INDEX core_room_warehouse_id_6a6f5de2 ON api.core_room USING btree (warehouse_id);


--
-- TOC entry 6473 (class 1259 OID 21240)
-- Name: core_sensor_room_id_9aa5274e; Type: INDEX; Schema: api; Owner: -
--

CREATE INDEX core_sensor_room_id_9aa5274e ON api.core_sensor USING btree (room_id);


--
-- TOC entry 6465 (class 1259 OID 21222)
-- Name: core_university_province_id_0f2599d5; Type: INDEX; Schema: api; Owner: -
--

CREATE INDEX core_university_province_id_0f2599d5 ON api.core_university USING btree (province_id);


--
-- TOC entry 6460 (class 1259 OID 21216)
-- Name: core_warehouse_center_id_3afa136c; Type: INDEX; Schema: api; Owner: -
--

CREATE INDEX core_warehouse_center_id_3afa136c ON api.core_warehouse USING btree (center_id);


--
-- TOC entry 6547 (class 1259 OID 21608)
-- Name: django_admin_log_content_type_id_c4bce8eb; Type: INDEX; Schema: api; Owner: -
--

CREATE INDEX django_admin_log_content_type_id_c4bce8eb ON api.django_admin_log USING btree (content_type_id);


--
-- TOC entry 6550 (class 1259 OID 21609)
-- Name: django_admin_log_user_id_c564eba6; Type: INDEX; Schema: api; Owner: -
--

CREATE INDEX django_admin_log_user_id_c564eba6 ON api.django_admin_log USING btree (user_id);


--
-- TOC entry 6556 (class 1259 OID 21661)
-- Name: django_session_expire_date_a5c62663; Type: INDEX; Schema: api; Owner: -
--

CREATE INDEX django_session_expire_date_a5c62663 ON api.django_session USING btree (expire_date);


--
-- TOC entry 6559 (class 1259 OID 21660)
-- Name: django_session_session_key_c0390e0f_like; Type: INDEX; Schema: api; Owner: -
--

CREATE INDEX django_session_session_key_c0390e0f_like ON api.django_session USING btree (session_key varchar_pattern_ops);


--
-- TOC entry 6570 (class 1259 OID 2145743)
-- Name: sensor_last_data_sensor_id_idx; Type: INDEX; Schema: data; Owner: -
--

CREATE INDEX sensor_last_data_sensor_id_idx ON data.sensor_last_data USING btree (sensor_id);


--
-- TOC entry 7166 (class 2606 OID 21581)
-- Name: account_accesscontrol_provinces account_accesscontro_accesscontrol_id_026b0beb_fk_account_a; Type: FK CONSTRAINT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.account_accesscontrol_provinces
    ADD CONSTRAINT account_accesscontro_accesscontrol_id_026b0beb_fk_account_a FOREIGN KEY (accesscontrol_id) REFERENCES api.account_accesscontrol(id) DEFERRABLE INITIALLY DEFERRED;


--
-- TOC entry 7168 (class 2606 OID 21551)
-- Name: account_accesscontrol_rooms account_accesscontro_accesscontrol_id_2325bdf1_fk_account_a; Type: FK CONSTRAINT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.account_accesscontrol_rooms
    ADD CONSTRAINT account_accesscontro_accesscontrol_id_2325bdf1_fk_account_a FOREIGN KEY (accesscontrol_id) REFERENCES api.account_accesscontrol(id) DEFERRABLE INITIALLY DEFERRED;


--
-- TOC entry 7170 (class 2606 OID 21561)
-- Name: account_accesscontrol_universities account_accesscontro_accesscontrol_id_35d18f80_fk_account_a; Type: FK CONSTRAINT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.account_accesscontrol_universities
    ADD CONSTRAINT account_accesscontro_accesscontrol_id_35d18f80_fk_account_a FOREIGN KEY (accesscontrol_id) REFERENCES api.account_accesscontrol(id) DEFERRABLE INITIALLY DEFERRED;


--
-- TOC entry 7164 (class 2606 OID 21541)
-- Name: account_accesscontrol_centers account_accesscontro_accesscontrol_id_7976ad55_fk_account_a; Type: FK CONSTRAINT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.account_accesscontrol_centers
    ADD CONSTRAINT account_accesscontro_accesscontrol_id_7976ad55_fk_account_a FOREIGN KEY (accesscontrol_id) REFERENCES api.account_accesscontrol(id) DEFERRABLE INITIALLY DEFERRED;


--
-- TOC entry 7172 (class 2606 OID 21571)
-- Name: account_accesscontrol_warehouses account_accesscontro_accesscontrol_id_cb137c69_fk_account_a; Type: FK CONSTRAINT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.account_accesscontrol_warehouses
    ADD CONSTRAINT account_accesscontro_accesscontrol_id_cb137c69_fk_account_a FOREIGN KEY (accesscontrol_id) REFERENCES api.account_accesscontrol(id) DEFERRABLE INITIALLY DEFERRED;


--
-- TOC entry 7163 (class 2606 OID 21536)
-- Name: account_accesscontrol_centers account_accesscontro_center_id_ea302d08_fk_core_cent; Type: FK CONSTRAINT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.account_accesscontrol_centers
    ADD CONSTRAINT account_accesscontro_center_id_ea302d08_fk_core_cent FOREIGN KEY (center_id) REFERENCES api.core_center(id) DEFERRABLE INITIALLY DEFERRED;


--
-- TOC entry 7165 (class 2606 OID 21576)
-- Name: account_accesscontrol_provinces account_accesscontro_province_id_f80cc937_fk_core_prov; Type: FK CONSTRAINT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.account_accesscontrol_provinces
    ADD CONSTRAINT account_accesscontro_province_id_f80cc937_fk_core_prov FOREIGN KEY (province_id) REFERENCES api.core_province(id) DEFERRABLE INITIALLY DEFERRED;


--
-- TOC entry 7169 (class 2606 OID 21556)
-- Name: account_accesscontrol_universities account_accesscontro_university_id_ff725435_fk_core_univ; Type: FK CONSTRAINT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.account_accesscontrol_universities
    ADD CONSTRAINT account_accesscontro_university_id_ff725435_fk_core_univ FOREIGN KEY (university_id) REFERENCES api.core_university(id) DEFERRABLE INITIALLY DEFERRED;


--
-- TOC entry 7171 (class 2606 OID 21566)
-- Name: account_accesscontrol_warehouses account_accesscontro_warehouse_id_5f3a5c15_fk_core_ware; Type: FK CONSTRAINT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.account_accesscontrol_warehouses
    ADD CONSTRAINT account_accesscontro_warehouse_id_5f3a5c15_fk_core_ware FOREIGN KEY (warehouse_id) REFERENCES api.core_warehouse(id) DEFERRABLE INITIALLY DEFERRED;


--
-- TOC entry 7167 (class 2606 OID 21546)
-- Name: account_accesscontrol_rooms account_accesscontrol_rooms_room_id_6b721e90_fk_core_room_id; Type: FK CONSTRAINT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.account_accesscontrol_rooms
    ADD CONSTRAINT account_accesscontrol_rooms_room_id_6b721e90_fk_core_room_id FOREIGN KEY (room_id) REFERENCES api.core_room(id) DEFERRABLE INITIALLY DEFERRED;


--
-- TOC entry 7162 (class 2606 OID 21411)
-- Name: account_accesscontrol account_accesscontrol_user_id_7030ddc2_fk_account_user_id; Type: FK CONSTRAINT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.account_accesscontrol
    ADD CONSTRAINT account_accesscontrol_user_id_7030ddc2_fk_account_user_id FOREIGN KEY (user_id) REFERENCES api.account_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- TOC entry 7159 (class 2606 OID 21390)
-- Name: account_user_groups account_user_groups_group_id_6c71f749_fk_auth_group_id; Type: FK CONSTRAINT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.account_user_groups
    ADD CONSTRAINT account_user_groups_group_id_6c71f749_fk_auth_group_id FOREIGN KEY (group_id) REFERENCES api.auth_group(id) DEFERRABLE INITIALLY DEFERRED;


--
-- TOC entry 7158 (class 2606 OID 21385)
-- Name: account_user_groups account_user_groups_user_id_14345e7b_fk_account_user_id; Type: FK CONSTRAINT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.account_user_groups
    ADD CONSTRAINT account_user_groups_user_id_14345e7b_fk_account_user_id FOREIGN KEY (user_id) REFERENCES api.account_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- TOC entry 7161 (class 2606 OID 21404)
-- Name: account_user_user_permissions account_user_user_pe_permission_id_66c44191_fk_auth_perm; Type: FK CONSTRAINT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.account_user_user_permissions
    ADD CONSTRAINT account_user_user_pe_permission_id_66c44191_fk_auth_perm FOREIGN KEY (permission_id) REFERENCES api.auth_permission(id) DEFERRABLE INITIALLY DEFERRED;


--
-- TOC entry 7160 (class 2606 OID 21399)
-- Name: account_user_user_permissions account_user_user_pe_user_id_cc42d270_fk_account_u; Type: FK CONSTRAINT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.account_user_user_permissions
    ADD CONSTRAINT account_user_user_pe_user_id_cc42d270_fk_account_u FOREIGN KEY (user_id) REFERENCES api.account_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- TOC entry 7157 (class 2606 OID 21293)
-- Name: auth_group_permissions auth_group_permissio_permission_id_84c5c92e_fk_auth_perm; Type: FK CONSTRAINT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.auth_group_permissions
    ADD CONSTRAINT auth_group_permissio_permission_id_84c5c92e_fk_auth_perm FOREIGN KEY (permission_id) REFERENCES api.auth_permission(id) DEFERRABLE INITIALLY DEFERRED;


--
-- TOC entry 7156 (class 2606 OID 21288)
-- Name: auth_group_permissions auth_group_permissions_group_id_b120cbf9_fk_auth_group_id; Type: FK CONSTRAINT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.auth_group_permissions
    ADD CONSTRAINT auth_group_permissions_group_id_b120cbf9_fk_auth_group_id FOREIGN KEY (group_id) REFERENCES api.auth_group(id) DEFERRABLE INITIALLY DEFERRED;


--
-- TOC entry 7155 (class 2606 OID 21279)
-- Name: auth_permission auth_permission_content_type_id_2f476e4b_fk_django_co; Type: FK CONSTRAINT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.auth_permission
    ADD CONSTRAINT auth_permission_content_type_id_2f476e4b_fk_django_co FOREIGN KEY (content_type_id) REFERENCES api.django_content_type(id) DEFERRABLE INITIALLY DEFERRED;


--
-- TOC entry 7175 (class 2606 OID 21623)
-- Name: authtoken_token authtoken_token_user_id_35299eff_fk_account_user_id; Type: FK CONSTRAINT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.authtoken_token
    ADD CONSTRAINT authtoken_token_user_id_35299eff_fk_account_user_id FOREIGN KEY (user_id) REFERENCES api.account_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- TOC entry 7149 (class 2606 OID 21188)
-- Name: core_center core_center_type_id_0a2ddb96_fk_core_centertype_id; Type: FK CONSTRAINT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.core_center
    ADD CONSTRAINT core_center_type_id_0a2ddb96_fk_core_centertype_id FOREIGN KEY (type_id) REFERENCES api.core_centertype(id) DEFERRABLE INITIALLY DEFERRED;


--
-- TOC entry 7150 (class 2606 OID 21193)
-- Name: core_center core_center_university_id_8e2d3747_fk_core_university_id; Type: FK CONSTRAINT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.core_center
    ADD CONSTRAINT core_center_university_id_8e2d3747_fk_core_university_id FOREIGN KEY (university_id) REFERENCES api.core_university(id) DEFERRABLE INITIALLY DEFERRED;


--
-- TOC entry 7153 (class 2606 OID 21225)
-- Name: core_room core_room_warehouse_id_6a6f5de2_fk_core_warehouse_id; Type: FK CONSTRAINT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.core_room
    ADD CONSTRAINT core_room_warehouse_id_6a6f5de2_fk_core_warehouse_id FOREIGN KEY (warehouse_id) REFERENCES api.core_warehouse(id) DEFERRABLE INITIALLY DEFERRED;


--
-- TOC entry 7154 (class 2606 OID 21235)
-- Name: core_sensor core_sensor_room_id_9aa5274e_fk_core_room_id; Type: FK CONSTRAINT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.core_sensor
    ADD CONSTRAINT core_sensor_room_id_9aa5274e_fk_core_room_id FOREIGN KEY (room_id) REFERENCES api.core_room(id) DEFERRABLE INITIALLY DEFERRED;


--
-- TOC entry 7152 (class 2606 OID 21217)
-- Name: core_university core_university_province_id_0f2599d5_fk_core_province_id; Type: FK CONSTRAINT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.core_university
    ADD CONSTRAINT core_university_province_id_0f2599d5_fk_core_province_id FOREIGN KEY (province_id) REFERENCES api.core_province(id) DEFERRABLE INITIALLY DEFERRED;


--
-- TOC entry 7151 (class 2606 OID 21211)
-- Name: core_warehouse core_warehouse_center_id_3afa136c_fk_core_center_id; Type: FK CONSTRAINT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.core_warehouse
    ADD CONSTRAINT core_warehouse_center_id_3afa136c_fk_core_center_id FOREIGN KEY (center_id) REFERENCES api.core_center(id) DEFERRABLE INITIALLY DEFERRED;


--
-- TOC entry 7173 (class 2606 OID 21598)
-- Name: django_admin_log django_admin_log_content_type_id_c4bce8eb_fk_django_co; Type: FK CONSTRAINT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.django_admin_log
    ADD CONSTRAINT django_admin_log_content_type_id_c4bce8eb_fk_django_co FOREIGN KEY (content_type_id) REFERENCES api.django_content_type(id) DEFERRABLE INITIALLY DEFERRED;


--
-- TOC entry 7174 (class 2606 OID 21603)
-- Name: django_admin_log django_admin_log_user_id_c564eba6_fk_account_user_id; Type: FK CONSTRAINT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.django_admin_log
    ADD CONSTRAINT django_admin_log_user_id_c564eba6_fk_account_user_id FOREIGN KEY (user_id) REFERENCES api.account_user(id) DEFERRABLE INITIALLY DEFERRED;


-- Completed on 2021-04-29 12:16:36 +0430

--
-- PostgreSQL database dump complete
--


