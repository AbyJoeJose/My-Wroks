--- populating customer dimension in staging
INSERT INTO Customer_Dimension(CustomerID, CustomerName, CustomerZip)
SELECT c.customerid,c.customername, c.customerzip
FROM josea_zagimore.customer as c


---populating store dimension in staging
INSERT INTO Store_Dimension(StoreID, StoreZip,RegionID, RegionName )
SELECT s.storeid, s.storezip, s.regionid, r.regionname
FROM josea_zagimore.store as s, josea_zagimore.region as r
WHERE s.regionid = r.regionid

--- populating product dimension in staging 
INSERT INTO Product_Dimension(ProductID, ProductName, ProductSalesPrice, VendorID, VendorName, CategoryID,CategoryName, ProductType )
SELECT p.productid, p.productname, p.productprice, v.vendorid,v.vendorname, c.categoryid, c.categoryname, 'Sales'
FROM josea_zagimore.product as p, josea_zagimore.vendor as v, josea_zagimore.category as c
WHERE c.categoryid = p.categoryid  and p.vendorid = v.vendorid

INSERT INTO Product_Dimension (ProductId, Productname, ProductDailyRentalPrice, ProductWeeklyRentalPrice, VendorId, Vendorname, categoryID, Categoryname, ProductType)
SELECT p.productid, p.productname , p.productpricedaily, p.productpriceweekly, v.vendorid, v.vendorname ,c.categoryid, c.categoryname , 'Rental'
FROM  josea_zagimore.rentalProducts as p , josea_zagimore.category as c, josea_zagimore.vendor as v 
WHERE c.categoryid = p.categoryid and p.vendorid = v.vendorid

--Creating an intermediate fact and populating with rental transaction

---Extracting fact in datastaging and creating a temprory table - weekly
DROP TABLE IntermedeiateFact;
CREATE TABLE IntermediateFact AS
SELECT 0 as UnitSold, r.productpriceweekly* rv.duration as RevenueGenerated, 'RentalWeekly' as RevenueType, rv.tid TID,
r.productid as ProductId, c.customerid as CustomerId, s.storeid as StoreId, rt.tdate as FullDate
FROM josea_zagimore.rentalProducts as r, josea_zagimore.rentvia rv, josea_zagimore.customer as c, josea_zagimore.store as s, josea_zagimore.rentaltransaction as rt
WHERE rv.productid=r.productid AND rv.tid = rt.tid
AND rt.customerid = c.customerid
AND s.storeid = rt.storeid
AND rv.rentaltype = 'W'

--- Extracting into fact - daily
INSERT INTO IntermediateFact (UnitSold, RevenueGenerated, RevenueType, TID,ProductId, CustomerId, StoreId, FullDate)
SELECT 0 , r.productpriceweekly* rv.duration , 'RentalDaily' , rv.tid TID,
r.productid , c.customerid , s.storeid , rt.tdate 
FROM josea_zagimore.rentalProducts as r, josea_zagimore.rentvia rv, josea_zagimore.customer as c, josea_zagimore.store as s, josea_zagimore.rentaltransaction as rt
WHERE rv.productid=r.productid AND rv.tid = rt.tid
AND rt.customerid = c.customerid
AND s.storeid = rt.storeid
AND rv.rentaltype = 'D'


---Populating the revenue fact table using the Intermediate Fact table 
INSERT INTO Revenue (UnitsSold, RevenueGenerated,RevenueType, TID, CustomerKey,StoreKey, ProductKey, CalendarKey )
SELECT i.UnitSold , i.RevenueGenerated , i.RevenueType, i.TID, cd.CustomerKey , sd.StoreKey , pd.ProductKey , cad.CalendarKey
FROM IntermediateFact as i , Customer_Dimension as cd, Store_Dimension as sd, Product_Dimension as pd, Calendar_Dimension as cad
WHERE i.CustomerId = cd.CustomerId
AND sd.StoreId = i.StoreId
AND pd.ProductId = i.ProductId 
AND pd.ProductType = 'Rental'
AND cad.FullDate = i.FullDate



-- for not rental (product)
--- Extracting fact to datastaging and creating a temprory table
CREATE IntermedeiateFact AS
SELECT sv.noofitems as UnitSold, p.productprice*sv.noofitems as RevenueGenerated, 'Sales' as RevenueType, sv.tid TID,
p.productid as ProductId, c.customerid as CustomerId, s.storeid as StoreId, st.tdate as FullDate
FROM josea_zagimore.product as p, josea_zagimore.soldvia sv, josea_zagimore.customer as c, josea_zagimore.store as s, josea_zagimore.salestransaction as st
WHERE sv.productid=p.productid AND sv.tid = st.tid
AND st.customerid = c.customerid
AND s.storeid = st.storeid


---Populating the revenue fact table using the Intermediate Fact table and joining the dimension
INSERT INTO Revenue (UnitSolds, RevenueGenerated,RevenueType, TID, CustomerKey,StoreKey, ProductKey, CalendarKey )
SELECT i.UnitSold , i.RevenueGenerated , i.RevenueType, i.TID, cd.CustomerKey , sd.StoreKey , pd.ProductKey , cad.Calendar_Key
FROM IntermedeiateFact as i , Customer_Dimension as cd, Store_Dimension as sd, Product_Dimension as pd, Calendar_Dimension as cad
WHERE i.CustomerId = cd.CustomerId
AND sd.StoreId = i.StoreId
AND pd.ProductId = i.ProductId 
AND pd.ProductType = 'Sales'
AND cad.FullDate = i.FullDate



---Loading of Warehouse data from data staging.
INSERT INTO josea_zagimore_dw.Customer_Dimension(CustomerKey, CustomerName, CustomerID, CustomerZip)
SELECT CustomerKey, CustomerName, CustomerID, CustomerZip
FROM Customer_Dimension

INSERT INTO josea_zagimore_dw.Product_Dimension(ProductKey,	ProductID,ProductName,ProductType,VendorID,VendorName,CategoryID,CategoryName,ProductSalesPrice,ProductDailyRentalPrice,ProductWeeklyRentalPrice	)
SELECT 	ProductKey,ProductID,ProductName,ProductType,VendorID,VendorName,CategoryID,CategoryName,ProductSalesPrice,ProductDailyRentalPrice,ProductWeeklyRentalPrice	
FROM Product_Dimension

INSERT INTO josea_zagimore_dw.Store_Dimension(StoreKey,	StoreID,	StoreZip,	RegionID,	RegionName)
SELECT StoreKey,	StoreID,	StoreZip,	RegionID,	RegionName	
FROM Store_Dimension

INSERT INTO josea_zagimore_dw.Calendar_Dimension(CalendarKey,	FullDate,	MonthYear,	Year)
SELECT CalendarKey,	FullDate,	MonthYear,	Year
FROM Calendar_Dimension

INSERT INTO josea_zagimore_dw.Calendar_Dimension(CalendarKey,	FullDate,	MonthYear,	Year)
SELECT CalendarKey,	FullDate,	MonthYear,	Year
FROM Calendar_Dimension

INSERT INTO josea_zagimore_dw.Revenue(RevenueGenerated,	UnitsSold,	TID,	RevenueType,	ProductKey,	CustomerKey,	StoreKey,	CalendarKey	)
SELECT 	RevenueGenerated,	UnitsSold,	TID,	RevenueType,	ProductKey,	CustomerKey,	StoreKey,	CalendarKey	
FROM Revenue


--- One way Aggregate by product category
CREATE TABLE product_cat_dimension AS
SELECT DISTINCT p.CategoryID, p.CategoryName
FROM Product_Dimension as p

ALTER TABLE Product_cat_dimension 
ADD COLUMN Product_Cat_Key INT AUTO_INCREMENT Primary Key


CREATE TABLE OneWayRevenueAggregateByProductCategory AS
SELECT sum(r.UnitsSold) AS TotalUnitSold, SUM(r.RevenueGenerated) AS TotalRevenueGenerated, 
r.CalendarKey, r.CustomerKey, r.StoreKey, pcd.Product_Cat_Key
FROM Revenue AS r, product_cat_dimension AS pcd, Product_Dimension AS pd
WHERE r.ProductKey = pd.ProductKey
AND
pcd.categoryID = pd.categoryID
GROUP BY r.CalendarKey, r.CustomerKey, r.StoreKey, pcd.Product_Cat_Key

ALTER TABLE OneWayRevenueAggregateByProductCategory
ADD PRIMARY KEY(CalendarKey, CustomerKey, StoreKey, Product_Cat_Key)

-- loading one way aggregate to DW
CREATE TABLE josea_zagimore_dw.product_cat_dimension AS 
SELECT * 
FROM product_cat_dimension

ALTER TABLE product_cat_dimension ADD PRIMARY KEY(Product_Cat_Key);

CREATE TABLE josea_zagimore_dw.OneWayRevenueAggregateByProductCategory AS
SELECT*
FROM OneWayRevenueAggregateByProductCategory

ALTER TABLE OneWayRevenueAggregateByProductCategory 
ADD PRIMARY KEY(CalendarKey, CustomerKey, StoreKey, Product_Cat_Key);

--- Creating connection in DW of the one wat aggregate
ALTER TABLE josea_zagimore_dw.OneWayRevenueAggregateByProductCategory
ADD Foreign Key (CalendarKey) REFERENCES 
josea_zagimore_dw.Calendar_Dimension(CalendarKey);

ALTER TABLE josea_zagimore_dw.OneWayRevenueAggregateByProductCategory 
ADD Foreign Key(CustomerKey) REFERENCES 
josea_zagimore_dw.Customer_Dimension(CustomerKey),
ADD Foreign Key(StoreKey) REFERENCES 
josea_zagimore_dw.Store_Dimension(StoreKey), 
ADD Foreign Key(Product_Cat_Key) REFERENCES 
josea_zagimore_dw.Product_cat_dimension(Product_Cat_Key)

--- daily sales snapshot
CREATE TABLE DailyStoreSnapshot As
SELECT sum(r.UnitsSold) AS TotalUnitSold, SUM(r.RevenueGenerated) AS TotalRevenueGenerated, 
COUNT(DISTINCT r.TID) AS TotalNumberOfTransaction, AVG(r.RevenueGenerated) AS AverageRevenueGenerated, r.CalendarKey, r.StoreKey
FROM Revenue AS r
GROUP BY r.CalendarKey, r.StoreKey

ALTER TABLE DailyStoreSnapshot 
MODIFY COLUMN AverageRevenueGenerated DECIMAL(9,2) 

---
CREATE TABLE FootwearRevenue AS
SELECT SUM(r.RevenueGenerated) AS TotalfootwearRevenue,  r.CalendarKey, r.StoreKey
FROM Revenue AS r, Product_Dimension AS pd
WHERE pd.CategoryName = "Footwear"
AND pd.ProductKey = r.ProductKey
GROUP BY r.CalendarKey, r.StoreKey

---Adding a column to the dailystore snapshot
ALTER TABLE DailyStoreSnapshot
ADD COLUMN TotalfootwearRevenue INT DEFAULT 0

---Updating total foootwear Revenue values
UPDATE DailyStoreSnapshot ds, FootwearRevenue fw
SET ds.TotalfootwearRevenue = fw.TotalfootwearRevenue
WHERE ds.CalendarKey = fw.CalendarKey
AND ds.StoreKey = fw.StoreKey

---Adding a column for high value to the daily snapshot
ALTER TABLE DailyStoreSnapshot
ADD COLUMN NumberofHVTransaction INT DEFAULT 0

CREATE TABLE HVTransaction AS
SELECT COUNT(DISTINCT r.TID) as HVTransactionCount,r.CalendarKey,r.StoreKey
FROM Revenue r
WHERE r.RevenueGenerated > 100
GROUP BY r.CalendarKey,r.StoreKey

UPDATE DailyStoreSnapshot ds, HVTransaction hv
SET  ds.NumberofHVTransaction = hv.HVTransactionCount
WHERE ds.CalendarKey = hv.CalendarKey
AND ds.StoreKey = hv.StoreKey

---Adding a column for Local revenue
ALTER TABLE DailyStoreSnapshot
ADD COLUMN TotalLocalRevenue INT DEFAULT 0

CREATE TABLE TotalLocalRevenue AS
SELECT SUM(r.RevenueGenerated) AS TotalLocalRevenue,  r.CalendarKey, r.StoreKey
FROM Revenue AS r, Store_Dimension AS sd, Customer_Dimension AS cd
WHERE  LEFT(sd.StoreZip,2) = LEFT(cd.CustomerZip,2)
AND sd.StoreKey = r.StoreKey
AND cd.CustomerKey = r.CustomerKey
GROUP BY r.CalendarKey, r.StoreKey

UPDATE DailyStoreSnapshot ds, TotalLocalRevenue lr
SET ds.TotalLocalRevenue = lr.TotalLocalRevenue
WHERE ds.CalendarKey = lr.CalendarKey
AND ds.StoreKey = lr.StoreKey

---Dropping Tables
DROP TABLE TotalLocalRevenue, FootwearRevenue
DROP TABLE HVTransaction

---Copying snapshot into DW
CREATE TABLE josea_zagimore_dw.DailyStoreSnapshot AS
SELECT * 
FROM DailyStoreSnapshot

-- Adding Connection
ALTER TABLE josea_zagimore_dw.DailyStoreSnapshot
ADD PRIMARY KEY (CalendarKey, StoreKey)

ALTER TABLE josea_zagimore_dw.DailyStoreSnapshot
ADD FOREIGN KEY (CalendarKey) REFERENCES josea_zagimore_dw.Calendar_Dimension(CalendarKey)

ALTER TABLE josea_zagimore_dw.DailyStoreSnapshot
ADD FOREIGN KEY (StoreKey) REFERENCES josea_zagimore_dw.Store_Dimension(StoreKey)

