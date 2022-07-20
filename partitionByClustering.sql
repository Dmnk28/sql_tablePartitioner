CREATE PROCEDURE partitionClusteredTable 
@table          NVARCHAR(250)   =   null,
@filegroup      NVARCHAR(250)   =   null,
@columnstore    BINARY
AS
BEGIN

    IF  @table IS NULL OR @filegroup IS NULL
        RETURN

    

    BEGIN TRANSACTION ProzTransaction
        /**********************************************************************/
        /*  Creating an Temporary Table of Existing Foreign Key Constraints   */
        /**********************************************************************/
        SELECT  "name" AS constraint_name,
                (   SELECT "name"
                    FROM    sys.objects
                    WHERE   object_id = FKC.parent_object_id
                ) as parent_table_name,
                (   SELECT "name"
                    FROM    sys.columns
                    WHERE   object_id = FKC.parent_object_id
                    AND     sys.columns.column_id = FKC.parent_column_id
                ) as parent_table_column_name,
                (   SELECT "name"
                    FROM    sys.objects
                    WHERE   object_id = FKC.referenced_object_id
                ) as referenced_table_name,
                (   SELECT "name"
                    FROM    sys.columns
                    WHERE   object_id = FKC.referenced_object_id
                    AND     sys.columns.column_id = FKC.referenced_column_id
                ) as referenced_column_name
        INTO    #tableFKeys
        FROM    sys.foreign_keys AS FK                                  -- System table with Foreign Keys         
        JOIN    sys.foreign_key_columns AS FKC                          -- System table with Foreign Key Columns
        ON      FK.object_id = FKC.constraint_object_id         
        WHERE   FK.referenced_object_id =   (   SELECT  object_id
                                                FROM    sys.objects
                                                WHERE   "name" = @table   )

        /* Check whether there are constraints in the temporary table */
        SELECT  *
        FROM    #tableFKeys
    
        /*****************************/
        /*  Drop all Foreign Keys    */
        /*****************************/
        DECLARE c_dropForeignKeys CURSOR for	SELECT constraint_name, parent_table_name
        								        FROM #tableFKeys            
        DECLARE @cons_name	    varchar(200),
        		@tbl_name	    varchar(200),
        		@drop_statement	nvarchar(600);
    
        OPEN c_dropForeignKeys;
        FETCH NEXT FROM c_dropForeignKeys INTO @cons_name, @tbl_name;   
        
        WHILE @@fetch_status=0
        BEGIN        
        	SET @drop_statement     =   concat('ALTER TABLE "', @tbl_name, '"',         -- '"' Granting correct usage of Tablenames with spaces, hyphens, etc.  
                                        'DROP CONSTRAINT "',  @cons_name, '";');
        
        	EXEC sp_executesql @drop_statement; 
    
        	FETCH NEXT FROM c_dropForeignKeys INTO @cons_name,  @tbl_name;
        END;
        
        CLOSE c_dropForeignKeys;
        DEALLOCATE c_dropForeignKeys;

        /* Checking Deletiion of Keys */
        select *  
        from sys.foreign_keys            -- Sys Tabelle mit Foreign Keys         
        where referenced_object_id = 21575115


        /******************************************/
        /*  Let the Clustered Index do its Magic  */
        /******************************************/
        DECLARE @primaryKey_name        NVARCHAR(200),
                @primaryKey_column      NVARCHAR(200),
                @executableStatement    NVARCHAR(800);

        SET @primaryKey_name =  (   SELECT  "name"  
                                    FROM    sys.key_constraints  
                                    WHERE   type = 'PK' AND OBJECT_NAME(parent_object_id) = @table  )

/* 
        ALTER TABLE @table
        DROP CONSTRAINT @primaryKey

        
        CREATE CLUSTERED INDEX CIX+@primaryKey_name ON @table(@primaryKey_column) ?? FILEGROUP

        ALTER TABLE @table
        ADD CONSTRAINT @primaryKey_name PRIMARY KEY CLUSTERED (@primaryKey_column)

 */


        /****************************************************/
        /* Adding Foreign Keys again to the tables affected */
        /****************************************************/
        DECLARE c_restoreForeignKeys CURSOR for	SELECT constraint_name, parent_table_name, parent_table_column_name, referenced_table_name, referenced_column_name
        								        FROM #tableFKeys            
        DECLARE @addCons_name	    varchar(200),
        		@addTbl_name	    varchar(200),
        		@cons_col	        varchar(200),
                @ref_tbl            varchar(200),
        		@ref_col	        varchar(200),
        		@add_statement	    nvarchar(600);

        OPEN c_restoreForeignKeys;
        FETCH NEXT FROM c_restoreForeignKeys INTO @addCons_name, @addTbl_name, @cons_col, @ref_tbl, @ref_col;    

        WHILE @@fetch_status=0
        BEGIN
        	SET @add_statement     =    concat( 'ALTER TABLE "', @addTbl_name, '" ',         
                                                'ADD CONSTRAINT [',  @addCons_name, '] FOREIGN KEY (',  @cons_col, ') REFERENCES [Orders','] (', @ref_col,');');       -- orders has to be replaced by the @table-parameter of the procedure later

        	EXEC sp_executesql @add_statement; 

        	FETCH NEXT FROM c_restoreForeignKeys INTO @addCons_name, @addTbl_name, @cons_col, @ref_tbl, @ref_col;
        END;

        CLOSE c_restoreForeignKeys;              --Schlie�en des Cursors
        DEALLOCATE c_restoreForeignKeys;         --Speicherbereich freigeben

        /*********************************************/
        /*  Drop Temporary Table for Foreign Keys    */
        /*********************************************/
        DROP TABLE #tableFKeys;

        /* Checking Restorment of Keys */
        select *  
        from sys.foreign_keys            -- Sys Tabelle mit Foreign Keys         
        where referenced_object_id = 21575115
    ROLLBACK TRANSACTION ProzTransaction;
END




--COMMIT TRANSACTION ProzTransaction
