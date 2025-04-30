----------------------------------------------Handling Null values-------------------------------------------------------------
select * from deliveries
where delivery_status = 'Cancelled'

update deliveries
set delivery_time = '00:00:00'
where delivery_status = 'Cancelled'

update deliveries
set delivery_time = DATEADD(SECOND,
    (select AVG(CAST(DATEDIFF(SECOND, '00:00:00', delivery_time) AS FLOAT))
     from deliveries
     where delivery_time IS NOT NULL),
    '00:00:00')
where delivery_time IS NULL;
----------------------------------------------Data Analysis-------------------------------------------------------------
-- select the top 5 dishes for 'Mechelle Stoneman' customer
with cte as
(
	select c.customer_id, c.customer_name, o.order_item as dishes, count(*) as total_orders
	from customers c
	inner join 
	orders o 
	on c.customer_id = o.customer_id
	where c.customer_name = 'Mechelle Stoneman'
	group by c.customer_id, c.customer_name, o.order_item
)
,
cte2 as
(
	select * ,
		 DENSE_RANK() over (order by total_orders desc) rn
	from cte
)
select * from cte2
where rn <= 5
------------------------------------------------------------
--identify the time slots during which the most orders are placed based on 2H intervals
with cte as
	(
	select case 
		when datepart(hour,order_time) between 0 and 1 then '00:00 - 02:00'
		when datepart(hour,order_time) between 2 and 3 then '02:00 - 04:00'
		when datepart(hour,order_time) between 4 and 5 then '04:00 - 06:00'
		when datepart(hour,order_time) between 6 and 7 then '06:00 - 08:00'
		when datepart(hour,order_time) between 8 and 9 then '08:00 - 10:00'
		when datepart(hour,order_time) between 10 and 11 then '10:00 - 12:00'
		when datepart(hour,order_time) between 12 and 13 then '12:00 - 14:00'
		when datepart(hour,order_time) between 14 and 15 then '14:00 - 16:00'
		when datepart(hour,order_time) between 16 and 17 then '16:00 - 18:00'
		when datepart(hour,order_time) between 18 and 19 then '18:00 - 20:00'
		when datepart(hour,order_time) between 20 and 21 then '20:00 - 22:00'
		when datepart(hour,order_time) between 22 and 23 then '22:00 - 00:00'
		end as time_slot,
		order_id
		from orders
	)
select time_slot, count(order_id) as orders_count
from cte
group by time_slot
order by count(order_id)

--OR

with cte as
(
	select (CAST(DATEPART(HOUR, order_time) AS FLOAT) / 2) * 2 as start_time,
		   (CAST(DATEPART(HOUR, order_time) AS FLOAT) / 2) * 2 + 2 as end_time,
		   order_id
	from orders
)
select start_time, end_time, count(order_id) as orders_count
from cte
group by start_time, end_time
order by orders_count desc
------------------------------------------------------------
--find the AVG order value per customer who has placed more than 300 orders
select c.customer_name, avg(o.total_amount)  as AOV
from customers c 
inner join orders o
on c.customer_id = o.customer_id
group by c.customer_name
having count(o.order_id) > 300
------------------------------------------------------------
--find the customers who spent more than 55K in total of the food orders
select c.customer_name, sum(o.total_amount)  as total_amount
from customers c 
inner join orders o
on c.customer_id = o.customer_id
group by c.customer_name
having sum(o.total_amount) > 55000
------------------------------------------------------------
--find orders that placed but not delivered	(restuarant name , num. of not delivered orders)
select r.resturant_name, count(o.order_id) as cnt_not_delivered_orders
from orders as o
left join resturants r
on r.resturant_id = o.resturant_id
left join deliveries d
on d.order_id = o.order_id
where d.delivery_id is null
group by r.resturant_name
order by cnt_not_delivered_orders desc
------------------------------------------------------------
--rank the resturants by their total revenue from te last year (resturant name , total revenue , rank within their city)
with cte as 
(	
	select r.resturant_name, r.city, sum(o.total_amount) as total_revenue,
		   rank() over(partition by city order by sum(o.total_amount)) as RN
	from orders o
	inner join resturants r
	on r.resturant_id = o.resturant_id
	group by r.resturant_name, r.city
)
select * from cte where RN = 1 
------------------------------------------------------------
--most popular dish in each city
with cte as
(   select r.city, o.order_item, count(o.order_id) as num_of_orders,
			 row_number() over(partition by r.city order by count(o.order_id) desc) as RN
	from resturants r
	inner join orders o
	on o.resturant_id = r.resturant_id
	group by r.city, o.order_item
)
select * from cte where rn = 1
order by num_of_orders desc
------------------------------------------------------------
--find customers who order in march and not in april
select c.customer_id, c.customer_name
from customers c
inner join orders o
on c.customer_id = o.customer_id
where month(o.order_date) = 3
except
select c.customer_id, c.customer_name
from customers c 
inner join orders o
on c.customer_id = o.customer_id
where month(o.order_date) = 4
------------------------------------------------------------
--calculate and compare the cancellation rate for every restaurant between march and april
WITH cancel_data_march AS (
    SELECT o.resturant_id,
           COUNT(o.order_id) AS total_orders,
           COUNT(CASE WHEN d.delivery_id IS NULL THEN 1 END) AS not_delivered
    FROM orders o 
    LEFT JOIN deliveries d ON o.order_id = d.order_id
    WHERE MONTH(o.order_date) = 3
    GROUP BY o.resturant_id
),
cancel_data_april AS (
    SELECT o.resturant_id,
           COUNT(o.order_id) AS total_orders,
           COUNT(CASE WHEN d.delivery_id IS NULL THEN 1 END) AS not_delivered
    FROM orders o 
    LEFT JOIN deliveries d ON o.order_id = d.order_id
    WHERE MONTH(o.order_date) = 4
    GROUP BY o.resturant_id
),
cancel_ratio_march AS (
    SELECT resturant_id, total_orders, not_delivered,
           ROUND((CAST(not_delivered AS FLOAT) / NULLIF(total_orders, 0)) * 100, 2) AS cancel_ratio
    FROM cancel_data_march
),
cancel_ratio_april AS (
    SELECT resturant_id, total_orders, not_delivered,
           ROUND((CAST(not_delivered AS FLOAT) / NULLIF(total_orders, 0)) * 100, 2) AS cancel_ratio
    FROM cancel_data_april
)
SELECT c.resturant_id AS resturant_id,
       c.cancel_ratio AS april_cancel_ratio,
       l.cancel_ratio AS march_cancel_ratio
FROM cancel_ratio_april c
INNER JOIN cancel_ratio_march l ON c.resturant_id = l.resturant_id;
------------------------------------------------------------
--rider average delivery time
with cte as 
(
	select  o.order_id, d.rider_id, o.order_time, d.delivery_time ,
			abs(datediff(minute,o.order_time,d.delivery_time)) as delivery_duration_minutes
	from deliveries d
	inner join orders o
	on o.order_id = d.order_id
	where d.delivery_status = 'Delivered'
)
select rider_id, count(*) as num_of_orders, avg(delivery_duration_minutes) as avg_time_per_order_mins
from cte
group by rider_id
order by num_of_orders, avg_time_per_order_mins
------------------------------------------------------------
--rider rating analysis
with cte as (
	select o.order_id, o.order_time, d.delivery_time, d.rider_id,
		   abs(DATEDIFF(MINUTE, o.order_time, d.delivery_time)) as delivery_duration_minutes   
	from orders o 
	inner join deliveries d on o.order_id = d.order_id
	where d.delivery_status = 'Delivered'
),
ranked as (
	select *,
		   avg(delivery_duration_minutes) over () as avg_delivery
	from cte
)
select 
	rider_id,
	delivery_duration_minutes,
	case 
		when delivery_duration_minutes < avg_delivery then '5 star'
		when delivery_duration_minutes between avg_delivery and avg_delivery + 58 then '4 star'
		else '3 star'
	end as stars
from ranked
------------------------------------------------------------
--customer segmentation (Gold-Silver)
--if customer total spending > AOV (gold) else (silver) 
declare @AOV float
select @AOV = avg(total_amount) from orders
select customer_id, sum(total_amount) as total_spend, count(order_id) as total_orders,
	   iif(sum(total_amount)>= @AOV, 'Gold', 'Silver')
from orders
group by customer_id
order by total_spend desc, total_orders desc
------------------------------------------------------------
--order frequency by day for each resturant
select * from
(
    select 
        r.resturant_name, 
        format(o.order_date, 'dddd') as _day, 
        count(o.order_id) as total_orders,
        dense_rank() over (
            partition by r.resturant_name 
            order by count(o.order_id) desc
        ) as rn
    from resturants r 
    inner join orders o 
        on o.resturant_id = r.resturant_id
    group by r.resturant_name, format(o.order_date, 'dddd')
) as ranked_orders
where rn = 1
------------------------------------------------------------
--customer lifetime vale CLV
select o.customer_id, c.customer_name, sum(o.total_amount) as CLV 
from customers c 
inner join orders o 
on o.customer_id = c.customer_id
group by o.customer_id, c.customer_name 
order by CLV desc
------------------------------------------------------------
--monthly sales trends
select year(order_date) as _year, month(order_date) as _month, sum(total_amount) as total_sales,
	   lag(sum(total_amount),1) over (order by year(order_date), month(order_date)) as prev_month
from orders
group by year(order_date), month(order_date)