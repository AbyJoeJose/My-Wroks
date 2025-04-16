---Making Changes
ALTER TABLE Revenue
ADD  ExtractionTimestamp TIMESTAMP, ADD f_loaded BOOLEAN

UPDATE Revenue
SET ExtractionTimestamp = NOW()-INTERVAL 10 DAY

UPDATE Revenue
SET f_loaded = True

---Creating the new transaction
INSERT INTO `salestransaction` (`tid`, `customerid`, `storeid`, `tdate`) 
VALUES ('ABC', '0-1-222', 'S10', '2025-03-25')

INSERT INTO `soldvia`
(`productid`, `tid`, `noofitems`) 
VALUES ('1X2', 'ABC', '2'), ('2X4','ABC','5')

---Creating new sales facts for 27th
INSERT INTO `salestransaction` (`tid`, `customerid`, `storeid`, `tdate`) 
VALUES ('CDE', '6-7-888', 'S4', '2025-04-01');

INSERT INTO `soldvia` (`productid`, `tid`, `noofitems`) 
VALUES ('1X2', 'CDE', '3');
INSERT INTO `soldvia` (`productid`, `tid`, `noofitems`) 
VALUES ('1X3', 'CDE', '6');

INSERT INTO `rentaltransaction` (`tid`, `customerid`, `storeid`, `tdate`) 
VALUES ('FGH', '3-4-555', 'S7', '2025-04-01');

INSERT INTO `rentvia` (`productid`, `tid`, `rentaltype`, `duration`) 
VALUES ('1X1', 'FGH', 'D', '5');
INSERT INTO `rentvia` (`productid`, `tid`, `rentaltype`, `duration`) 
VALUES ('2X2', 'FGH', 'W', '6');

--- Extracting the new transaction into intermediate fact table
--Adding new Sales facts
DROP Table IntermediateFact;

CREATE TABLE IntermediateFact AS
SELECT sv.noofitems as UnitSold, p.productprice*sv.noofitems as RevenueGenerated, 'Sales' as RevenueType, sv.tid as TID,
p.productid as ProductId, st.customerid as CustomerId, st.storeid as StoreId, st.tdate as FullDate
FROM josea_zagimore.product as p, josea_zagimore.soldvia sv, josea_zagimore.salestransaction as st
WHERE sv.productid=p.productid 
AND sv.tid = st.tid
AND st.tdate > (SELECT MAX(DATE(ExtractionTimestamp)) 
FROM Revenue)

ALTER TABLE IntermediateFact
MODIFY RevenueType VARCHAR(25)

--Adding new Daily Rental facts
INSERT INTO IntermediateFact (UnitSold, RevenueGenerated, RevenueType, TID,ProductId, CustomerId, StoreId, FullDate)
SELECT 0 , r.productpriceweekly* rv.duration , 'RentalDaily' , rv.tid TID,
r.productid , c.customerid , s.storeid , rt.tdate 
FROM josea_zagimore.rentalProducts as r, josea_zagimore.rentvia rv, josea_zagimore.customer as c, josea_zagimore.store as s, josea_zagimore.rentaltransaction as rt
WHERE rv.productid=r.productid AND rv.tid = rt.tid
AND rt.customerid = c.customerid
AND s.storeid = rt.storeid
AND rv.rentaltype = 'D'
AND rt.tdate > (SELECT MAX(DATE(ExtractionTimestamp)) 
FROM Revenue)

--Adding new Weekly rental facts
INSERT INTO IntermediateFact (UnitSold, RevenueGenerated, RevenueType, TID,ProductId, CustomerId, StoreId, FullDate)
SELECT 0 as UnitSold, r.productpriceweekly* rv.duration as RevenueGenerated, 'RentalWeekly' as RevenueType, rv.tid TID,
r.productid as ProductId, c.customerid as CustomerId, s.storeid as StoreId, rt.tdate as FullDate
FROM josea_zagimore.rentalProducts as r, josea_zagimore.rentvia rv, josea_zagimore.customer as c, josea_zagimore.store as s, josea_zagimore.rentaltransaction as rt
WHERE rv.productid=r.productid AND rv.tid = rt.tid
AND rt.customerid = c.customerid
AND s.storeid = rt.storeid
AND rv.rentaltype = 'W'
AND rt.tdate > (SELECT MAX(DATE(ExtractionTimestamp)) 
FROM Revenue)

---Populating the new facts into the revenue fact table
INSERT INTO Revenue (UnitsSold, RevenueGenerated,RevenueType, TID, CustomerKey,StoreKey, ProductKey, CalendarKey,ExtractionTimestamp,f_loaded )
SELECT i.UnitSold , i.RevenueGenerated , i.RevenueType, i.TID, cd.CustomerKey , sd.StoreKey , pd.ProductKey , cad.CalendarKey, NOW(), FALSE
FROM IntermediateFact as i , Customer_Dimension as cd, Store_Dimension as sd, Product_Dimension as pd, Calendar_Dimension as cad
WHERE i.CustomerId = cd.CustomerId
AND sd.StoreId = i.StoreId
AND pd.ProductId = i.ProductId 
AND pd.ProductType = 'Sales'
AND cad.FullDate = i.FullDate


--as we are pretending to be tomorrow we use this code with small change now()+ INTERVAL 1 DAY
INSERT INTO Revenue (UnitsSold, RevenueGenerated,RevenueType, TID, CustomerKey,StoreKey, ProductKey, CalendarKey,ExtractionTimestamp,f_loaded )
SELECT i.UnitSold , i.RevenueGenerated , i.RevenueType, i.TID, cd.CustomerKey , sd.StoreKey , pd.ProductKey , cad.CalendarKey, NOW()+INTERVAL 1 DAY, FALSE
FROM IntermediateFact as i , Customer_Dimension as cd, Store_Dimension as sd, Product_Dimension as pd, Calendar_Dimension as cad
WHERE i.CustomerId = cd.CustomerId
AND sd.StoreId = i.StoreId
AND pd.ProductId = i.ProductId 
AND pd.ProductType = 'Sales'
AND cad.FullDate = i.FullDate
-- AND LEFT(pd.ProductType,1) = LEFT(i.RevenueType,1); worked without this

--- Insert into the new transaction of sales into DW
INSERT INTO josea_zagimore_dw.Revenue(RevenueGenerated,	UnitsSold,	TID,	RevenueType,	ProductKey,	CustomerKey,	StoreKey,	CalendarKey)
SELECT 	RevenueGenerated,	UnitsSold,	TID,	RevenueType,	ProductKey,	CustomerKey,	StoreKey,	CalendarKey	
FROM Revenue
WHERE f_loaded = 0

---Now setting the f_loaded = False to True after loading into WH
UPDATE Revenue
SET f_loaded = TRUE
WHERE f_loaded = FALSE


---New facts for creating a code to run as whole
INSERT INTO `salestransaction` (`tid`, `customerid`, `storeid`, `tdate`) 
VALUES ('BBC', '7-8-999', 'S4', '2025-03-27');

INSERT INTO `soldvia` (`productid`, `tid`, `noofitems`) 
VALUES ('1X2', 'BBC', '3');
INSERT INTO `soldvia` (`productid`, `tid`, `noofitems`) 
VALUES ('1X3', 'BBC', '6');

INSERT INTO `rentaltransaction` (`tid`, `customerid`, `storeid`, `tdate`) 
VALUES ('BBB', '3-4-555', 'S7', '2025-03-27');

INSERT INTO `rentvia` (`productid`, `tid`, `rentaltype`, `duration`) 
VALUES ('1X1', 'BBB', 'D', '5');
INSERT INTO `rentvia` (`productid`, `tid`, `rentaltype`, `duration`) 
VALUES ('2X2', 'BBB', 'W', '6');


CREATE PROCEDURE Daily_Regular_Fact_Refresh()
BEGIN 

DROP Table IF EXISTS IntermediateFact;
CREATE TABLE IntermediateFact AS
SELECT sv.noofitems as UnitSold, p.productprice*sv.noofitems as RevenueGenerated, 'Sales' as RevenueType, sv.tid as TID,
p.productid as ProductId, st.customerid as CustomerId, st.storeid as StoreId, st.tdate as FullDate
FROM josea_zagimore.product as p, josea_zagimore.soldvia sv, josea_zagimore.salestransaction as st
WHERE sv.productid=p.productid 
AND sv.tid = st.tid
AND st.tdate > (SELECT MAX(DATE(ExtractionTimestamp)) 
FROM Revenue);

ALTER TABLE IntermediateFact
MODIFY RevenueType VARCHAR(25);


INSERT INTO IntermediateFact (UnitSold, RevenueGenerated, RevenueType, TID,ProductId, CustomerId, StoreId, FullDate)
SELECT 0 , r.productpriceweekly* rv.duration , 'RentalDaily' , rv.tid TID,
r.productid , c.customerid , s.storeid , rt.tdate 
FROM josea_zagimore.rentalProducts as r, josea_zagimore.rentvia rv, josea_zagimore.customer as c, josea_zagimore.store as s, josea_zagimore.rentaltransaction as rt
WHERE rv.productid=r.productid AND rv.tid = rt.tid
AND rt.customerid = c.customerid
AND s.storeid = rt.storeid
AND rv.rentaltype = 'D'
AND rt.tdate > (SELECT MAX(DATE(ExtractionTimestamp)) 
FROM Revenue);


INSERT INTO IntermediateFact (UnitSold, RevenueGenerated, RevenueType, TID,ProductId, CustomerId, StoreId, FullDate)
SELECT 0 as UnitSold, r.productpriceweekly* rv.duration as RevenueGenerated, 'RentalWeekly' as RevenueType, rv.tid TID,
r.productid as ProductId, c.customerid as CustomerId, s.storeid as StoreId, rt.tdate as FullDate
FROM josea_zagimore.rentalProducts as r, josea_zagimore.rentvia rv, josea_zagimore.customer as c, josea_zagimore.store as s, josea_zagimore.rentaltransaction as rt
WHERE rv.productid=r.productid AND rv.tid = rt.tid
AND rt.customerid = c.customerid
AND s.storeid = rt.storeid
AND rv.rentaltype = 'W'
AND rt.tdate > (SELECT MAX(DATE(ExtractionTimestamp)) 
FROM Revenue);


INSERT INTO Revenue (UnitsSold, RevenueGenerated,RevenueType, TID, CustomerKey,StoreKey, ProductKey, CalendarKey,ExtractionTimestamp,f_loaded )
SELECT i.UnitSold , i.RevenueGenerated , i.RevenueType, i.TID, cd.CustomerKey , sd.StoreKey , pd.ProductKey , cad.CalendarKey, NOW(), FALSE
FROM IntermediateFact as i , Customer_Dimension as cd, Store_Dimension as sd, Product_Dimension as pd, Calendar_Dimension as cad
WHERE i.CustomerId = cd.CustomerId
AND sd.StoreId = i.StoreId
AND pd.ProductId = i.ProductId 
AND pd.ProductType = 'Sales'
AND cad.FullDate = i.FullDate;


INSERT INTO josea_zagimore_dw.Revenue(RevenueGenerated,	UnitsSold,	TID,	RevenueType,	ProductKey,	CustomerKey,	StoreKey,	CalendarKey)
SELECT 	RevenueGenerated,	UnitsSold,	TID,	RevenueType,	ProductKey,	CustomerKey,	StoreKey,	CalendarKey	
FROM Revenue
WHERE f_loaded = 0;


UPDATE Revenue
SET f_loaded = TRUE
WHERE f_loaded = FALSE;

END



---New Values for 29 Match

INSERT INTO `salestransaction` (`tid`, `customerid`, `storeid`, `tdate`) 
VALUES ('AAA', '7-8-999', 'S4', '2025-03-29');

INSERT INTO `soldvia` (`productid`, `tid`, `noofitems`) 
VALUES ('1X2', 'AAA', '3');
INSERT INTO `soldvia` (`productid`, `tid`, `noofitems`) 
VALUES ('1X3', 'AAA', '6');

INSERT INTO `rentaltransaction` (`tid`, `customerid`, `storeid`, `tdate`) 
VALUES ('AAB', '3-4-555', 'S7', '2025-03-29');

INSERT INTO `rentvia` (`productid`, `tid`, `rentaltype`, `duration`) 
VALUES ('1X1', 'AAB', 'D', '5');
INSERT INTO `rentvia` (`productid`, `tid`, `rentaltype`, `duration`) 
VALUES ('2X2', 'AAB', 'W', '6');

--- Daily refresh of Product Dimension

ALTER TABLE Product_Dimension
ADD ExtractionTimestamp TIMESTAMP
ADD PDLoaded BOOLEAN

UPDATE Product_Dimension
SET ExtractionTimestamp = NOW() - INTERVAL 20 DAY;

UPDATE Product_Dimension
SET PDLoaded = TRUE;

INSERT INTO Product_Dimension(ProductID, ProductName, ProductSalesPrice, VendorID, VendorName, CategoryID,CategoryName, ProductType, ExtractionTimestamp, PDLoaded )
SELECT p.productid, p.productname, p.productprice, v.vendorid,v.vendorname, c.categoryid, c.categoryname, 'Sales', NOW(), FALSE
FROM josea_zagimore.product as p, josea_zagimore.vendor as v, josea_zagimore.category as c
WHERE c.categoryid = p.categoryid  
and p.vendorid = v.vendorid
AND p.productid NOT IN (Select productid FROM Product_Dimension WHERE ProductType = 'Sales')

INSERT INTO josea_zagimore_dw.Product_Dimension(ProductKey, ProductID, ProductName, ProductSalesPrice, VendorID, VendorName, CategoryID,CategoryName, ProductType)
SELECT ProductKey, ProductID, ProductName, ProductSalesPrice, VendorID, VendorName, CategoryID,CategoryName, ProductType
FROM Product_Dimension
WHERE PDLoaded = False

UPDATE Product_Dimension
SET PDLoaded = TRUE

--- Do the same for rental product
INSERT INTO `rentalProducts` (`productid`, `productname`, `vendorid`, `categoryid`, `productpricedaily`, `productpriceweekly`) 
VALUES ('1R1', 'Car', 'WL', 'CY', '200', '1000');

INSERT INTO Product_Dimension (ProductId, Productname, ProductDailyRentalPrice, ProductWeeklyRentalPrice, VendorId, Vendorname, categoryID, Categoryname, ProductType, ExtractionTimestamp, PDLoaded)
SELECT p.productid, p.productname , p.productpricedaily, p.productpriceweekly, v.vendorid, v.vendorname ,c.categoryid, c.categoryname , 'Rental', NOW(), FALSE
FROM  josea_zagimore.rentalProducts as p , josea_zagimore.category as c, josea_zagimore.vendor as v 
WHERE c.categoryid = p.categoryid and p.vendorid = v.vendorid
AND p.vendorid = v.vendorid
AND p.productid NOT IN (Select productid FROM Product_Dimension WHERE ProductType = 'Rental')

INSERT INTO josea_zagimore_dw.Product_Dimension(ProductKey, ProductID, ProductName, ProductSalesPrice,ProductDailyRentalPrice, ProductWeeklyRentalPrice, VendorID, VendorName, CategoryID,CategoryName, ProductType)
SELECT ProductKey, ProductID, ProductName, ProductSalesPrice,,ProductDailyRentalPrice, ProductWeeklyRentalPrice, VendorID, VendorName, CategoryID,CategoryName, ProductType
FROM Product_Dimension
WHERE PDLoaded = False

UPDATE Product_Dimension
SET PDLoaded = TRUE

---Creating procedure for product dimension

CREATE PROCEDURE Daily_Product_Refresh()
 BEGIN

INSERT INTO Product_Dimension(ProductID, ProductName, ProductSalesPrice, VendorID, VendorName, CategoryID,CategoryName, ProductType, ExtractionTimestamp, PDLoaded )
SELECT p.productid, p.productname, p.productprice, v.vendorid,v.vendorname, c.categoryid, c.categoryname, 'Sales', NOW(), FALSE
FROM josea_zagimore.product as p, josea_zagimore.vendor as v, josea_zagimore.category as c
WHERE c.categoryid = p.categoryid  
and p.vendorid = v.vendorid
AND p.productid NOT IN (Select productid FROM Product_Dimension WHERE ProductType = 'Sales'
);

INSERT INTO Product_Dimension (ProductId, Productname, ProductDailyRentalPrice, ProductWeeklyRentalPrice, VendorId, Vendorname, categoryID, Categoryname, ProductType, ExtractionTimestamp, PDLoaded)
SELECT p.productid, p.productname , p.productpricedaily, p.productpriceweekly, v.vendorid, v.vendorname ,c.categoryid, c.categoryname , 'Rental', NOW(), FALSE
FROM  josea_zagimore.rentalProducts as p , josea_zagimore.category as c, josea_zagimore.vendor as v 
WHERE c.categoryid = p.categoryid and p.vendorid = v.vendorid
AND p.vendorid = v.vendorid
AND p.productid NOT IN (Select productid FROM Product_Dimension Where ProductType = 'Rental');

INSERT INTO josea_zagimore_dw.Product_Dimension(ProductKey, ProductID, ProductName, ProductSalesPrice, VendorID, VendorName, CategoryID,CategoryName, ProductType)
SELECT ProductKey, ProductID, ProductName, ProductSalesPrice, VendorID, VendorName, CategoryID,CategoryName, ProductType
FROM Product_Dimension
WHERE PDLoaded = False;

UPDATE Product_Dimension
SET PDLoaded = TRUE;

END

INSERT INTO `rentalProducts` (`productid`, `productname`, `vendorid`, `categoryid`, `productpricedaily`, `productpriceweekly`) 
VALUES ('2Z2', 'COFFEE', 'WL', 'CY', '20', '1000');

INSERT INTO `product` (`productid`, `productname`, `productprice`,`vendorid`, `categoryid`) 
VALUES ('2Z2', 'COFFEE',10, 'OA', 'CY');


---Refresh for late arriving facts

INSERT INTO `salestransaction` (`tid`, `customerid`, `storeid`, `tdate`) 
VALUES ('NEW', '7-8-999', 'S4', '2025-03-25');

INSERT INTO `soldvia` (`productid`, `tid`, `noofitems`) 
VALUES ('1X2', 'NEW', '3');
INSERT INTO `soldvia` (`productid`, `tid`, `noofitems`) 
VALUES ('1X3', 'NEW', '6');

INSERT INTO `rentaltransaction` (`tid`, `customerid`, `storeid`, `tdate`) 
VALUES ('NEWD', '3-4-555', 'S7', '2025-03-26');

INSERT INTO `rentvia` (`productid`, `tid`, `rentaltype`, `duration`) 
VALUES ('1X1', 'NEWD', 'D', '5');
INSERT INTO `rentvia` (`productid`, `tid`, `rentaltype`, `duration`) 
VALUES ('2X2', 'NEWD', 'W', '6');

INSERT INTO `salestransaction` (`tid`, `customerid`, `storeid`, `tdate`) 
VALUES ('NEWST', '7-8-999', 'S4', '2025-03-25');

INSERT INTO `soldvia` (`productid`, `tid`, `noofitems`) 
VALUES ('1X2', 'NEWST', '3');


INSERT INTO `rentaltransaction` (`tid`, `customerid`, `storeid`, `tdate`) 
VALUES ('NEWRT', '3-4-555', 'S7', '2025-03-26');

INSERT INTO `rentvia` (`productid`, `tid`, `rentaltype`, `duration`) 
VALUES ('1X1', 'NEWRT', 'D', '5');
INSERT INTO `rentvia` (`productid`, `tid`, `rentaltype`, `duration`) 
VALUES ('2X2', 'NEWRT', 'W', '6');


CREATE PROCEDURE LateFactRefresh()
BEGIN 

DROP Table IF EXISTS IntermediateFact;
CREATE TABLE IntermediateFact AS
SELECT sv.noofitems as UnitSold, p.productprice*sv.noofitems as RevenueGenerated, 'Sales' as RevenueType, sv.tid as TID,
p.productid as ProductId, st.customerid as CustomerId, st.storeid as StoreId, st.tdate as FullDate
FROM josea_zagimore.product as p, josea_zagimore.soldvia sv, josea_zagimore.salestransaction as st
WHERE sv.productid=p.productid 
AND sv.tid = st.tid
AND st.tid NOT IN (
    SELECT TID FROM Revenue
    WHERE RevenueType = 'Sales'
);

ALTER TABLE IntermediateFact
MODIFY RevenueType VARCHAR(25);


INSERT INTO IntermediateFact (UnitSold, RevenueGenerated, RevenueType, TID,ProductId, CustomerId, StoreId, FullDate)
SELECT 0 , r.productpriceweekly* rv.duration , 'RentalDaily' , rv.tid TID,
r.productid , c.customerid , s.storeid , rt.tdate 
FROM josea_zagimore.rentalProducts as r, josea_zagimore.rentvia rv, josea_zagimore.customer as c, josea_zagimore.store as s, josea_zagimore.rentaltransaction as rt
WHERE rv.productid=r.productid AND rv.tid = rt.tid
AND rt.customerid = c.customerid
AND s.storeid = rt.storeid
AND rv.rentaltype = 'D'
AND rt.tid NOT IN (
    SELECT TID FROM Revenue
    WHERE RevenueType LIKE 'R%'
);


INSERT INTO IntermediateFact (UnitSold, RevenueGenerated, RevenueType, TID,ProductId, CustomerId, StoreId, FullDate)
SELECT 0 as UnitSold, r.productpriceweekly* rv.duration as RevenueGenerated, 'RentalWeekly' as RevenueType, rv.tid TID,
r.productid as ProductId, c.customerid as CustomerId, s.storeid as StoreId, rt.tdate as FullDate
FROM josea_zagimore.rentalProducts as r, josea_zagimore.rentvia rv, josea_zagimore.customer as c, josea_zagimore.store as s, josea_zagimore.rentaltransaction as rt
WHERE rv.productid=r.productid AND rv.tid = rt.tid
AND rt.customerid = c.customerid
AND s.storeid = rt.storeid
AND rv.rentaltype = 'W'
AND rt.tid NOT IN (
    SELECT TID FROM Revenue
    WHERE RevenueType LIKE 'R%'
);


INSERT INTO Revenue (UnitsSold, RevenueGenerated,RevenueType, TID, CustomerKey,StoreKey, ProductKey, CalendarKey,ExtractionTimestamp,f_loaded )
SELECT i.UnitSold , i.RevenueGenerated , i.RevenueType, i.TID, cd.CustomerKey , sd.StoreKey , pd.ProductKey , cad.CalendarKey, NOW(), FALSE
FROM IntermediateFact as i , Customer_Dimension as cd, Store_Dimension as sd, Product_Dimension as pd, Calendar_Dimension as cad
WHERE i.CustomerId = cd.CustomerId
AND sd.StoreId = i.StoreId
AND pd.ProductId = i.ProductId 
AND pd.ProductType = 'Sales'
AND cad.FullDate = i.FullDate;


INSERT INTO josea_zagimore_dw.Revenue(RevenueGenerated,	UnitsSold,	TID,	RevenueType,	ProductKey,	CustomerKey,	StoreKey,	CalendarKey)
SELECT 	RevenueGenerated,	UnitsSold,	TID,	RevenueType,	ProductKey,	CustomerKey,	StoreKey,	CalendarKey	
FROM Revenue
WHERE f_loaded = 0;


UPDATE Revenue
SET f_loaded = TRUE
WHERE f_loaded = FALSE;

END

