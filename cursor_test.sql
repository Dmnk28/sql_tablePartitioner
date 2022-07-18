/* Cursor Testarea */
BEGIN TRANSACTION ProzTransaction

/* CHECK FOR CONSTRAINT */
SELECT  *             -- constraint_name 
FROM    sys.foreign_keys            
WHERE   referenced_object_id = 21575115

SELECT  "name" AS constraint_name,
        FKC.*
INTO    #tableFKeys
FROM    sys.foreign_keys AS FK                      -- Sys Tabelle mit Foreign Keys         
JOIN    sys.foreign_key_columns AS FKC              -- Sys Tabelle mit Foreign Key Columns
ON      FK.object_id = FKC.constraint_object_id         
WHERE   FK.referenced_object_id = 21575115          -- later to be modified with @table - Param and object id

/* drop table #tableFKeys

SELECT  *             -- constraint_name 
FROM    #tableFKeys    */         


/* Drop all Foreign Keys  */
DECLARE c_dropForeignKeys CURSOR for	SELECT constraint_name
								        FROM #tableFKeys            

DECLARE @cons_name	    varchar(200),
		@tbl_name	    varchar(200),
		@drop_statement	nvarchar(600);

OPEN c_dropForeignKeys;

FETCH NEXT FROM c_dropForeignKeys INTO @cons_name;    -- Bewegen des Zeigers in Trefferauswahl von c_dropForeignKeys

WHILE @@fetch_status=0
BEGIN
	SET @tbl_name   =   (   SELECT  name
                            FROM    sys.objects
                            WHERE   object_id = (   SELECT  parent_object_id
                                                    FROM    #tableFKeys            
								                    WHERE   constraint_name = @cons_name
                                                ) 
                        );
							
	SET @drop_statement     =   concat('ALTER TABLE "', @tbl_name, '"',         -- '"' Granting correct usage of Tablenames with spaces, hyphens, etc.  
                                'DROP CONSTRAINT ',  @cons_name, ';');
							
	EXEC sp_executesql @drop_statement; 

	FETCH NEXT FROM c_dropForeignKeys INTO @cons_name;
END;
																	
CLOSE c_dropForeignKeys;              --Schlie�en des Cursors
																	
DEALLOCATE c_dropForeignKeys;         --Speicherbereich freigeben

/* Checking Deletiion of Keys */
select *  
from sys.foreign_keys            -- Sys Tabelle mit Foreign Keys         
where referenced_object_id = 21575115

/* Adding Foreign Keys again to the tables affected */
DECLARE c_restoreForeignKeys CURSOR for	SELECT constraint_name             -- constraint_name 
								        FROM #tableFKeys            

DECLARE @addCons_name	    varchar(200),
		@addTbl_name	    varchar(200),
		@cons_col	        varchar(200),
		@ref_col	        varchar(200),
		@add_statement	    nvarchar(600);

OPEN c_restoreForeignKeys;

FETCH NEXT FROM c_restoreForeignKeys INTO @cons_name;    -- Bewegen des Zeigers in Trefferauswahl von c_restoreForeignKeys

WHILE @@fetch_status=0
BEGIN
	SET @addTbl_name   =   (   SELECT  name
                            FROM    sys.objects
                            WHERE   object_id = (   SELECT  parent_object_id
                                                    FROM    #tableFKeys            
                                                    WHERE   constraint_name = @addCons_name
                                                ) 
                        )
    SET @cons_col   =   (   SELECT  "name"
                            FROM    sys.columns
                            WHERE   object_id = (   SELECT  parent_column_id
                                                    FROM    #tableFKeys            
                                                    WHERE   constraint_name = @addCons_name
                                                )
                            AND     column_id = (   SELECT  parent_column_id
                                                    FROM    #tableFKeys
                                                    WHERE   constraint_name = @addCons_name
                                                )
                        )
    SET @ref_col    =   (   SELECT  "name"
                            FROM    sys.columns
                            WHERE   object_id = 21575115                                -- NUmber => Orders has to be modified for Procedure
                            AND     column_id = (   SELECT  referenced_column_id
                                                    FROM    #tableFKeys
                                                    WHERE   constraint_name = @addCons_name
                                                )
                        )


	SET @add_statement     =    concat( 'ALTER TABLE "', @addTbl_name, '" ',         
                                        'ADD CONSTRAINT [',  @addCons_name, '] FOREIGN KEY (',  @cons_col, ') REFERENCES [Orders','] (', @ref_col,');');       -- orders has to be replaced by the @table-parameter of the procedure later
							
	EXEC sp_executesql @add_statement; 

	FETCH NEXT FROM c_restoreForeignKeys INTO @addCons_name;
END;
																	
CLOSE c_restoreForeignKeys;              --Schlie�en des Cursors
																	
DEALLOCATE c_restoreForeignKeys;         --Speicherbereich freigeben

DROP TABLE #tableFKeys;


/* Checking Restorment of Keys */
select *  
from sys.foreign_keys            -- Sys Tabelle mit Foreign Keys         
where referenced_object_id = 21575115

ROLLBACK TRANSACTION ProzTransaction;
--COMMIT TRANSACTION ProzTransaction
