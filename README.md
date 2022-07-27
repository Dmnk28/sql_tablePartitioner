# TSQL Partitionierungs- und Umstrukturierungsproceduren 
!Please mind that correlating to the size of your table you want to move the procedure could hold xlocks for a pretty long time!

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