rem Обновление eMenu
set server_name=nb-spb-tpad03
set database_name=DBZee_9_4_4
set user_name=sa
set user_password=sasa

sqlcmd -S %server_name% -d %database_name% -U %user_name% -P %user_password% -i em_ExportItemList.sql 
sqlcmd -S %server_name% -d %database_name% -U %user_name% -P %user_password% -i em_ExportOrders.sql 
