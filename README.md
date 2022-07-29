# TSQL Partitioning and Restructuring Procedures
> :warning: __Work in Progress !__ 

These Procedures are made to move tables with already existing data to different filegroups/files in a convenient way. The core idea is to move the table logicaly and (depenending on your filegroup physicaly as well) by creating an clustered index for the table. For this Idea I thank my SQL-Teacher Mr. Frank Mewes from the iad GmbH. To make this trick even more usefull for already existing datatables which may already have (clustered) primary keys or foreign keys referncing them, I implemented the cursor logic you'll find in the procedures. 
Feel free to adjust and optimize the procedures before creating them.

> :warning: !Please mind that correlating to the size of your table you want to move the procedure could hold xlocks for a pretty long time!

## moveToDatagroupByClustering Procedure
This procedure allows to move your table and data to a filegroup of your choice.
Therefore it first disables foreign and existing (clustered) primary keys and uses ```create clustered index ... on @filegroup``` to move the table and its content.

Please pass it the following parameters:
-   @table          = The table you want to move
-   @filegroup      = The Filegroup you have prepared already (mind to add at least one file to the filegroup before executing the procedure)
-   @columnstore    = This is optional. If you would like to use an columstore index in the long run
 


## ToDos
-   [ ] Columnstore Option mit if (@columnstore) else einbinden
-   [ ] Partitionierungsprocedur schreiben
-   [ ] README Schreiben