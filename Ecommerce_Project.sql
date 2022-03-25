select *
from[dbo].[shipping_dimen]
select *
from[dbo].[orders_dimen]

---------------------------------------------------------------------------------------------------------------------
--1. Join all the tables and create a new table called combined_table. (market_fact, cust_dimen, orders_dimen, prod_dimen, shipping_dimen)


select a.*, c.*, d.*,e.*, b.Sales,b.Discount,b.Order_Quantity,b.Product_Base_Margin
into combined_table
from [dbo].[cust_dimen] a
join [dbo].[market_fact] b
on a.cust_id=b.cust_id 
join [dbo].[orders_dimen] c
on c.Ord_id=b.Ord_id
join [dbo].[prod_dimen] d
on  d.Prod_id=b.Prod_id
join [dbo].[shipping_dimen] e
on e.Ship_id=b.Ship_id

select *
from combined_table
----------------------------------------------------------------------------------------------------------------------
--2. Find the top 3 customers who have the maximum count of orders.
select *
from combined_table

--From combined table

select TOP 3 cust_id, count(Order_ID) number_Order
from combined_table
group by cust_id
order by number_Order desc

--from the original table

select   top 3 customer_Name, count(Order_ID) number_Order
from shipping_dimen a,market_fact b, cust_dimen c
where a.Ship_id=b.Ship_id and c.Cust_id=b.Cust_id
group by  customer_Name
order by number_Order desc

----------------------------------------------------------------------------------------------------------------------
--3.Create a new column at combined_table as DaysTakenForDelivery that contains the date difference of Order_Date and Ship_Date.
--Use "ALTER TABLE", "UPDATE" etc.

ALTER TABLE combined_table
ADD 
  [DaysTakenForDelivery] AS DATEDIFF (DAY,Order_Date,Ship_Date) 

select *
from combined_table

-----------------------------------------------------------------------------------------------------------------------
--4. Find the customer whose order took the maximum time to get delivered.
--Use "MAX" or "TOP"

--with top function
select top 1 DaysTakenForDelivery, cust_id, Customer_Name, Order_date, Ship_Date
from combined_table
order by DaysTakenForDelivery desc

--with max function
select top 1 max(DaysTakenForDelivery) diff_time, Customer_Name,Cust_id,Order_Date,Ship_Date
from combined_table
group by Customer_Name,Cust_id,Order_Date,Ship_Date
order by diff_time desc

---with first_value ****

select top 1 FIRST_VALUE(daystakenfordelivery) over (partition by customer_name order by daystakenfordelivery desc),Customer_Name, Order_Date,Ship_Date
from combined_table
order by DaysTakenForDelivery desc

-------------------------------------------------------------------------------------------------------------------------
--5. Count the total number of unique customers in January and how many of them came back every month over the entire year in 2011
--You can use date functions and subqueries

select MONTH(Order_Date) as Month, DATENAME(month, Order_Date) [Month_Name], 
	   count(distinct cust_id) cnt_of_customers
from combined_table a
where exists (select distinct Cust_id
			from combined_table b
			where Year(Order_Date)=2011 and month(Order_Date)=1 and a.cust_id=b.cust_id)
and year(order_date)=2011
group by MONTH(Order_Date), DATENAME(month, Order_Date)
order by Month

-------------------------------------------------------------------------------------------------------------------------
--6. write a query to return for each user according to the time elapsed between the first purchasing and the third purchasing, 
--in ascending order by Customer ID
--Use "MIN" with Window Functions

--with view table
create view tblnum_first as 
						(select cust_id, customer_name, Order_Date, 
						dense_rank() over (partition by customer_name order by order_date)[row_num]
						from combined_table)

create view tblnum_third as
					(select cust_id, customer_name, Order_Date, 
					dense_rank() over (partition by customer_name order by order_date)[row_num]
					from combined_table)
select *
from tblnum_first
select *
from tblnum_third

select  A.Customer_Name,A.Cust_id, DATEDIFF(day, A.Order_date, B.Order_Date) time_diff
from tblnum_first A, tblnum_third B
where A.Cust_id=B.Cust_id and (A.row_num=1 and B.row_num=3)
order by time_diff desc

--------------------------------------------------------------------------------------------------------------------------------------

--7. Write a query that returns customers who purchased both product 11 and product 14, 
--as well as the ratio of these products to the total number of products purchased by all customers.
--Use CASE Expression, CTE, CAST and/or Aggregate Functions

create view  prod11and14 as
	(select Cust_id, 
			SUM( case when Prod_id='Prod_11' then Order_Quantity else 0 end) P_11,
			SUM( case when Prod_id='Prod_14' then Order_Quantity else 0 end) P_14,
			SUM(order_quantity) total
		from combined_table
		group by Cust_id
	)

select Cust_id, P_11, cast (P_11/total as numeric(5,3)) prod11_ratio, P_14, cast(P_14/total as numeric(5,3)) prod14_ratio
from prod11and14
where P_11 != 0 and P_14 != 0
order by cust_id
select *
from combined_table

------------------------------------------------------------------------------------------------------------------------------------------------

--CUSTOMER SEGMENTATION

--1. Create a view that keeps visit logs of customers on a monthly basis. (For each log, three field is kept: Cust_id, Year, Month)
--Use such date functions. Don't forget to call up columns you might need later.

create view visit_log 
as
(
select distinct Cust_id, MONTH(order_date) [month], YEAR(order_date)[year]
from combined_table order by cust_id
)
select *
from visit_log

--2.Create a “view” that keeps the number of monthly visits by users. (Show separately all months from the beginning  business)
--Don't forget to call up columns you might need later.
---eski
create view visit_monthly as
(
	select MONTH(Order_Date) [month], count(cust_id) visit
	from combined_table
	group by MONTH(Order_Date)
	
)

select *
from visit_monthly

-----------------------------------------------------------------------------------------------------------------------------------------------

--3. For each visit of customers, create the next month of the visit as a separate column.
--You can order the months using "DENSE_RANK" function.
--then create a new column for each month showing the next month using the order you have made above. (use "LEAD" function.)
--Don't forget to call up columns you might need later.


create view dens_table1 as
		(select cust_id, customer_name, MONTH(order_date) mon, order_date,
		DENSE_RANK () over (partition by customer_name order by customer_name, MONTH(order_date)) dens
		from combined_table order by cust_id)


select t1.cust_id, first_month_visit, second_month_visit
from
	(select distinct cust_id, mon as first_month_visit
	from dens_table1
	where dens=1) as t1
join 
	(select distinct cust_id, mon as second_month_visit
	from dens_table1
	where dens=2) as t2
on t1.cust_id=t2.cust_id
order by t1.cust_id

						
------------------------------------------------------------------------------------------------------------------------------------------
--4. Calculate the monthly time gap between two consecutive visits by each customer.
--Don't forget to call up columns you might need later.
create view dens_table1 as
		(select cust_id, customer_name,month(order_date) mon, order_date,
		DENSE_RANK () over (partition by customer_name order by customer_name, MONTH(order_date)) dens
		from combined_table order by cust_id)

select distinct t1.cust_id, datediff(month,second_visit,first_visit)
from
	(select distinct cust_id, order_date first_visit
	from dens_table1
	where dens=1) as t1
join 
	(select cust_id, order_date second_visit
	from dens_table1
	where dens=2) as t2
on t1.cust_id=t2.cust_id
order by t1.cust_id

-MONTH-WISE RETENTÝON RATE


--Find month-by-month customer retention rate  since the start of the business.


--1. Find the number of customers retained month-wise. (You can use time gaps)
--Use Time Gaps

create view visit_month_year2 as
(
	select YEAR(order_date) [year], MONTH(Order_Date) [month], count(distinct cust_id) visit
	from combined_table
	group by YEAR(order_date), MONTH(Order_Date)
	
)

select [year],[month], visit,
	round(cume_dist() over (partition by year order by visit),2) retention_rate
from visit_month_year2
order by year, month
		

--//////////////////////


--2. Calculate the month-wise retention rate.

--Basic formula: o	Month-Wise Retention Rate = 1.0 * Number of Customers Retained in The Current Month / Total Number of Customers in the Current Month

--It is easier to divide the operations into parts rather than in a single ad-hoc query. It is recommended to use View. 
--You can also use CTE or Subquery if you want.

--You should pay attention to the join type and join columns between your views or tables.
create view visit_month_year2 as
(
	select YEAR(order_date) [year], MONTH(Order_Date) [month], count(distinct cust_id) visit
	from combined_table
	group by YEAR(order_date), MONTH(Order_Date)
	
)

select [year],[month], visit,
	round(cume_dist() over (partition by year order by visit),2) retention_rate
from visit_month_year2
order by year, month






---///////////////////////////////////
--Good luck!