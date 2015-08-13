IF OBJECT_ID('em_ExportOrder', 'P') IS NOT NULL 
  DROP PROCEDURE dbo.em_ExportOrder
GO

CREATE PROCEDURE dbo.em_ExportOrder (
  @gest_ID UNIQUEIDENTIFIER,
  @ReceiveOrderPath SYSNAME,
  @ReceiveOrderLogPath SYSNAME)
AS
DECLARE 
  @xml XML,
  @xmlt NVARCHAR(MAX),
  @fn SYSNAME,
  @fnlog SYSNAME,
  @Date DATETIME

-- Скорее всего придется делать выгрузку во временные таблицы в TM
-- EXEC tpsrv_logon
-- Триггеры которые запускают tu_emenu_tp_Guests, ti_emenu_tp_Orders, tiu_emenu_tp_Orders

SET @Date = CURRENT_TIMESTAMP

-- Запрос 
SET @xml = (
  SELECT
    '' AS 'VERSION', (
      SELECT 
        ROOM_NO AS [ROOM_NO],
        TABLE_NO AS [TABLE_NO],
        0 AS [COVER],
        '' AS [WAITER_ID],
        -- FORMAT(@Date,N'dd-MM-yyyy HH:mm:ss') AS [TIME],
		CONVERT(varchar,@Date,104)+' '+CONVERT(varchar,@Date,108) AS [TIME], 
  -- ISNULL(ORDER_ID, '') AS [ORDER_ID],
  '' AS [ORDER_ID],
  -- ISNULL(KOT_ID, '') AS [KOT_ID],
  '' AS [KOT_ID], (
--ISNULL(ORDER_ID, '') AS [ORDER_ID],
--ISNULL(KOT_ID, '') AS [KOT_ID], (
		  SELECT 
            '' AS 'KOT_TRANSACTION_ID',
            l1.orit_Count AS 'QTY',
            '' AS 'REMARKS', (
              SELECT 
                orit_mitm_ID AS [ITEM_ID],
	            '' AS [ITEM_NAME],
	            '' AS [ITEM_NOTE],
	            -- !!!!!!!!!!!!!!!!!!!!!!
				(select l3.orit_mitm_ID AS [MODIFIER_ID], '' AS [MODIFIER_NAME]
from tp_OrderItems l3 
where l3.orit_master_id = l2.orit_ID
FOR XML Path(''), Type)
				--'' AS [MODIFIER_ID],
	            --'' AS [MODIFIER_NAME]
              FROM tp_OrderItems l2 
              WHERE l2.orit_ID = l1.orit_ID AND orit_master_id is null
              FOR XML Path('ITEM'), Type )
          FROM tp_Orders o1
          join tp_OrderItems l1 on l1.orit_ordr_ID = o1.ordr_ID
          -- WHERE o.ordr_gest_ID = e.GEST_ID
          WHERE o1.ordr_gest_ID = G.gest_ID
          FOR XML Path('KOT_TRANSACTION'), Type )
      -- FROM em_Orders E
--FROM tp_Orders    O
--WHERE gest_ID = @gest_ID
	  --FROM tp_Orders O
      --LEFT JOIN em_Orders E ON e.ORDR_ID = O.ordr_ID
	  FROM tp_guests G
JOIN (SELECT DISTINCT gest_ID, ROOM_NO, TABLE_NO FROM em_Orders) E ON E.gest_ID = G.gest_ID
WHERE  G.gest_ID = @gest_ID
      --  WHERE  ordr_gest_ID = @gest_ID
      FOR XML Path('KOT'), Type)
  FOR XML Path('TREEROOT'), Type)

-- EXEC tpsrv_logoff

-- SET @fn = @ReceiveOrderPath + 'Order-' + FORMAT(@Date ,N'ddMMyyyy-HHmmss')+'.xml'
SET @fn = @ReceiveOrderPath + 'Order-' +  REPLACE(CONVERT(varchar,@Date,104), '.', '')+' '+REPLACE(CONVERT(varchar,@Date,108), ':', '')+'.xml'
SET @xmlt = CONVERT(NVARCHAR(MAX), @xml)
EXEC dbo.em_SaveToFile @fn, @xmlt -- , 'windows-1251'


-- запись лог-файла
-- SET @fnlog = @ReceiveOrderLogPath + 'POS Log ' + FORMAT(@Date ,N'ddMMyyyy')+'.xml'
SET @fnlog = @ReceiveOrderLogPath + 'POS Log ' + REPLACE(CONVERT(varchar,GETDATE(),104), '.', '')+'.xml'
SET @xmlt = 
  -- FORMAT(@Date ,N'<!--dd.MM.yyyy HH:mm:ss-->')
  N'<!-'+CONVERT(varchar,@Date,104)+' '+CONVERT(varchar,@Date,108)+'-->'
  +char(13)+char(10)
  +'<!-- FilePath:'+@fn+' -->'
  +char(13)+char(10)
  +@xmlt 
EXEC em_SaveToLog @fnlog, @xmlt
GO
