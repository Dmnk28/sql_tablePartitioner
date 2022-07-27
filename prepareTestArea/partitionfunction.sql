ALTER DATABASE NWOesterle 
ADD FILEGROUP userData

/* Modify for Filegroup */
ALTER DATABASE NWOesterle 
ADD FILE 
(
    NAME = testUserData1,
    FILENAME = 'C:\Program Files\Microsoft SQL Server\MSSQL10_50.MSSQLSERVER\MSSQL\DATA\t1dat3.ndf',
    SIZE = 5MB,
    MAXSIZE = 100MB,
    FILEGROWTH = 5MB
),
(
    NAME = testUserData1,
    FILENAME = 'C:\Program Files\Microsoft SQL Server\MSSQL10_50.MSSQLSERVER\MSSQL\DATA\t1dat4.ndf',
    SIZE = 5MB,
    MAXSIZE = 100MB,
    FILEGROWTH = 5MB
)



CREATE PARTITION FUNCTION partitionLeftByDate ( datetime )
AS RANGE LEFT
FOR VALUES ('2009-01-01 00:00:00.0')

DROP PARTITION FUNCTION partitionLeftByDate;

CREATE PARTITION FUNCTION partitionRightByDate ( datetime )
AS RANGE RIGHT
FOR VALUES ('2009-01-01 00:00:00.0')

DROP PARTITION FUNCTION partitionRightByDate;

CREATE PARTITION SCHEME partitionByDate
AS PARTITION partitionRightByDate
ALL TO ( UserData )

Select * from ORDERs