CREATE DATABASE [ProcTestDB]
    CONTAINMENT = NONE
    ON  PRIMARY 
    (   NAME = N'ProcTestDB', 
        FILENAME = N'P:\StandardDBPrimDaten\ProcTestDB.mdf' )               -- PATH to be adjusted
    LOG ON 
    (   NAME = N'ProcTestDB_log', 
        FILENAME = N'L:\StandardDBLogs\ProcTestDB_log.ldf' )               -- PATH to be adjusted 

WITH CATALOG_COLLATION = DATABASE_DEFAULT
GO

IF (1 = FULLTEXTSERVICEPROPERTY('IsFullTextInstalled'))
    begin
        EXEC [ProcTestDB].[dbo].[sp_fulltext_database] @action = 'enable'
    end
GO

USE [master]
GO
ALTER DATABASE  [ProcTestDB] 
ADD FILEGROUP   [TestData]
GO
ALTER DATABASE  [ProcTestDB] 
ADD FILE (  NAME = N'Test_Data1', 
            FILENAME = N'P:\StandardDBPrimDaten\Test_Data1.ndf' )                -- PATH to be adjusted
TO FILEGROUP [TestData]
GO

ALTER DATABASE [ProcTestDB] 
ADD FILE (  NAME = N'Test_Data2', 
            FILENAME = N'P:\StandardDBPrimDaten\Test_Data2.ndf' )               -- PATH to be adjusted 
TO FILEGROUP [TestData]
GO

USE [ProcTestDB]
GO
IF NOT EXISTS ( SELECT  name 
                FROM    sys.filegroups 
                WHERE   is_default=1 AND name = N'TestData' ) 
    BEGIN
        ALTER DATABASE [ProcTestDB] 
        MODIFY FILEGROUP [TestData] DEFAULT
    END
GO