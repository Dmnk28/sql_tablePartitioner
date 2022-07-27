CREATE PROCEDURE moveToDatagroupByClustering 
@table          NVARCHAR(250)   =   null,
@filegroup      NVARCHAR(250)   =   null,
@columnstore    BINARY          =   0
AS
BEGIN
    DECLARE @errorMessage NVARCHAR(500);
    
    IF  @table IS NULL OR @filegroup IS NULL
        BEGIN
            SET @errorMessage = 'Please pass Arguments for @table and @filegroup.';
            RAISERROR(@errorMessage, 17, 1);
        END
    
    BEGIN TRY
        BEGIN TRANSACTION ProzTransaction
            /**********************************************************************/
            /*  Creating an Temporary Table of Existing Foreign Key Constraints   */
            /**********************************************************************/
            SELECT  "name" AS constraint_name,
                (   SELECT "name"
                    FROM    sys.objects
                    WHERE   object_id = FKC.parent_object_id    ) as parent_table_name,
                (   SELECT "name"
                    FROM    sys.columns
                    WHERE   object_id = FKC.parent_object_id
                    AND     sys.columns.column_id = FKC.parent_column_id    ) as parent_table_column_name,
                (   SELECT "name"
                    FROM    sys.objects
                    WHERE   object_id = FKC.referenced_object_id    ) as referenced_table_name,
                (   SELECT "name"
                    FROM    sys.columns
                    WHERE   object_id = FKC.referenced_object_id
                    AND     sys.columns.column_id = FKC.referenced_column_id    ) as referenced_column_name
            INTO    #foreign_keys_to_moving_table
            FROM    sys.foreign_keys AS FK                                  -- System table with Foreign Keys         
            JOIN    sys.foreign_key_columns AS FKC                          -- System table with Foreign Key Columns
            ON      FK.object_id = FKC.constraint_object_id         
            WHERE   FK.referenced_object_id =   (   SELECT  object_id
                                                    FROM    sys.objects
                                                    WHERE   "name" = @table   )

            /* Check whether there are constraints in the temporary table */
            SELECT  *
            FROM    #foreign_keys_to_moving_table

            /*****************************/
            /*  Drop all Foreign Keys    */
            /*****************************/
            DECLARE c_dropForeignKeys CURSOR for	SELECT constraint_name, parent_table_name
        								            FROM #foreign_keys_to_moving_table            
            DECLARE @cons_name	    varchar(200),
        	    	@tbl_name	    varchar(200),
        	    	@drop_statement	nvarchar(600);
    
            OPEN c_dropForeignKeys;
            FETCH NEXT FROM c_dropForeignKeys INTO @cons_name, @tbl_name;   

            WHILE @@fetch_status=0
            BEGIN        
        	    SET @drop_statement     =   concat('ALTER TABLE "', @tbl_name, '"',         -- '"' Granting correct usage of Tablenames with spaces, hyphens, etc.  
                                            'DROP CONSTRAINT ',  @cons_name, ';');

        	    EXEC sp_executesql @drop_statement; 

        	    FETCH NEXT FROM c_dropForeignKeys INTO @cons_name,  @tbl_name;
            END;

            CLOSE c_dropForeignKeys;
            DEALLOCATE c_dropForeignKeys;

            /* Checking Deletiion of Keys */
            select  *  
            from    sys.foreign_keys            -- Sys Tabelle mit Foreign Keys         
            where "name" = @table;


            /*********************************************************************/
            /*  Store Name & Columname of the Existing Primary Key in Variables  */
            /*********************************************************************/
            DECLARE @primaryKey_name        NVARCHAR(200),
                    @primaryKey_column      NVARCHAR(200),
                    @executableStatement    NVARCHAR(800);

            SET @primaryKey_name =  (   SELECT  "name"  
                                        FROM    sys.key_constraints  
                                        WHERE   type = 'PK' AND parent_object_id = (    SELECT  object_id
                                                                                        FROM    sys.objects
                                                                                        WHERE   "name" = @table )  
                                    );

            SET @primaryKey_column =    (   select  COL."name" as column_name
                                            from    sys.tables TAB
                                                inner join  sys.indexes PK
                                                    on      TAB.object_id = PK.object_id 
                                                    and     PK.is_primary_key = 1
                                                inner join  sys.index_columns IC
                                                    on      IC.object_id = PK.object_id
                                                    and     IC.index_id = PK.index_id
                                                inner join  sys.columns COL
                                                    on      PK.object_id = COL.object_id
                                                    and     COL.column_id = IC.column_id
                                            WHERE   TAB."name" = @table
                                        );

            /***********************************/
            /*  Drop the Existing Primary Key  */
            /***********************************/
            SET @executableStatement =  CONCAT( 'ALTER TABLE ', @table,
                                                ' DROP CONSTRAINT ',@primaryKey_name    );
            EXEC sp_executesql @executableStatement;


            /******************************************/
            /*  Let the Clustered Index do its Magic  */
            /******************************************/
            
            IF @columnstore = 0
                BEGIN
                    SET @executableStatement =  CONCAT( 'CREATE CLUSTERED INDEX CIX_', @primaryKey_name, 
                                                        ' ON "', @table, '"(', @primaryKey_column, ')
                                                         ON ', @filegroup   );
                END
            ELSE
                BEGIN
                    SET @executableStatement =  CONCAT( 'CREATE CLUSTERED COLUMNSTORE INDEX CIX_COL_', @primaryKey_name, 
                                                        ' ON "', @table, '"(', @primaryKey_column, ')
                                                         ON ', @filegroup   );
                END


            EXEC sp_executesql @executableStatement; 
            
            SET @executableStatement =  CONCAT( 'ALTER TABLE "', @table, '" 
                                                 ADD CONSTRAINT "', @primaryKey_name, '" PRIMARY KEY NONCLUSTERED (', @primaryKey_column, ')'   );
            EXEC sp_executesql @executableStatement; 


            /****************************************************/
            /* Adding Foreign Keys again to the tables affected */
            /****************************************************/
            DECLARE c_restoreForeignKeys CURSOR for	SELECT  constraint_name, parent_table_name, parent_table_column_name, referenced_table_name, referenced_column_name
        								            FROM    #foreign_keys_to_moving_table            
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
                                                'ADD CONSTRAINT "',  @addCons_name, '" FOREIGN KEY (',  @cons_col, ') REFERENCES "', @table,'" (', @ref_col,');');       

        	EXEC sp_executesql @add_statement; 

        	FETCH NEXT FROM c_restoreForeignKeys INTO @addCons_name, @addTbl_name, @cons_col, @ref_tbl, @ref_col;
            END;

            CLOSE c_restoreForeignKeys;
            DEALLOCATE c_restoreForeignKeys;

            /*********************************************/
            /*  Drop Temporary Table for Foreign Keys    */
            /*********************************************/
            DROP TABLE #foreign_keys_to_moving_table;

            /* Checking Restorment of Keys */
            select *  
            from sys.foreign_keys            -- Sys Tabelle mit Foreign Keys         
            where "name" = @table;

        COMMIT TRANSACTION ProzTransaction;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION ProzTransaction;
        SET @errorMessage = CONCAT( 'The error with error number ', ERROR_NUMBER(), ' ocurred in Line ', ERROR_LINE(), '. Please note the following Message: ', ERROR_MESSAGE());
        RAISERROR(@errorMessage, 17, 1);    
    END CATCH; 
END