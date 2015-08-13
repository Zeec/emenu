--
IF OBJECT_ID(N'em_ExportItemList', 'P') IS NOT NULL 
  DROP PROCEDURE dbo.em_ExportItemList
GO

CREATE PROCEDURE dbo.em_ExportItemList (
  @nttp_ID          UNIQUEIDENTIFIER,
  @ItemListPath     NVARCHAR(MAX),
  @ModifierListPath NVARCHAR(MAX),
  @SubcategoryPath  NVARCHAR(MAX),
  @CategoryPath     NVARCHAR(MAX),
  @MenuPath         NVARCHAR(MAX),
  @dev_ID			UNIQUEIDENTIFIER)
  
AS
DECLARE @Date DATETIME
declare @fn nvarchar(255)
declare @xmlt nvarchar(max)
declare @ImagePath nvarchar(max) = ''

SET @Date = GETDATE()

-- Таблицы для выгружаеммых элементов
IF OBJECT_ID('tempdb..#ItemList') IS NOT NULL DROP TABLE #ItemList

CREATE TABLE #ItemList (
  item_ID UNIQUEIDENTIFIER,
  sub_ID UNIQUEIDENTIFIER, 
  cat_ID UNIQUEIDENTIFIER,
  item_Name NVARCHAR(MAX),
  item_Description NVARCHAR(MAX),
  item_Price NVARCHAR(50),
  item_Photo VARBINARY(MAX),
  item_Path NVARCHAR(255),
  item_IsActive NVARCHAR(5),
  item_IsDeleted NVARCHAR(5),
  item_Order INT,
  item_PrepatarionTime NVARCHAR(MAX),
  item_Calory NUMERIC(18,6))

IF OBJECT_ID('tempdb..#ModifierList') IS NOT NULL DROP TABLE #ModifierList

CREATE TABLE #ModifierList (
  mod_ID UNIQUEIDENTIFIER,
  mod_Name NVARCHAR(MAX),
  mod_Description NVARCHAR(MAX),
  mod_Price NVARCHAR(50),
  mod_IsActive NVARCHAR(5),
  mod_IsDeleted NVARCHAR(5))
  
IF OBJECT_ID('tempdb..#Subcategory') IS NOT NULL DROP TABLE #Subcategory

CREATE TABLE #Subcategory (
  sub_ID UNIQUEIDENTIFIER,
  sub_Name NVARCHAR(MAX),
  sub_Photo VARBINARY(MAX),
  sub_Path NVARCHAR(255))

IF OBJECT_ID('tempdb..#Category') IS NOT NULL DROP TABLE #Category

CREATE TABLE #Category (
  cat_ID UNIQUEIDENTIFIER,
  cat_Name NVARCHAR(MAX),
  cat_Photo VARBINARY(MAX),
  cat_Path NVARCHAR(255))
  
-- Этой строчки быть не должно (
-- Скорее всего придется делать выгрузку во временные таблицы в TM
-- EXEC tpsrv_logon

-- [ISACTIVE], [ISDELETED] перенести в запрос
INSERT INTO #ItemList (item_ID, sub_ID, cat_ID, item_Name, item_Description, item_Price, item_Photo, item_Path, item_IsActive, item_IsDeleted, item_Order, item_PrepatarionTime, item_Calory) 
SELECT distinct -- TOP 1
  I.mitm_ID, 
  I.mitm_mgrp_ID,
  -- Если один уровень - категория = субкатегории
  ISNULL(P.mgrp_mgrp_ID_Parent, I.mitm_mgrp_ID),
  ISNULL(dbo.f_MultiLanguageStringToStringByLanguageGroup(mitm_Name, NULL), 'language_translate_error'), 
  ISNULL(dbo.f_MultiLanguageStringToStringByLanguageGroup(mitm_Description, NULL), 0),
  REPLACE(CONVERT(NVARCHAR(50), mitm_Price), '.', ','),
  ISNULL(mitm_Photo, mpic_Data),
  CASE 
    WHEN mitm_Photo IS NOT NULL THEN @ItemListPath + @ImagePath + CONVERT(NVARCHAR(36), mitm_ID) + '.jpg'
	WHEN mpic_Data IS NOT NULL THEN @ItemListPath + @ImagePath + CONVERT(NVARCHAR(36), mitm_ID) + '.jpg'
	ELSE ''
  END,
  -- IIF((I.mitm_IsDisabled = 0)  AND (misl_ID IS NULL), 'True', 'False'),
  CASE
	WHEN (I.mitm_IsDisabled = 0) AND (misl_ID IS NULL) THEN 'True'
	ELSE 'False'
  END,
  -- IIF(I.mitm_del_ID IS NOT NULL, 'True', 'False')
  CASE 
    WHEN (I.mitm_del_ID IS NOT NULL) THEN 'True'
    ELSE 'False'
  END,
  ISNULL(mitm_Order, 0),
  -- Время приготовления
  ISNULL(mitm_QuickCode, 0),
  -- Калории
  ISNULL(pitm_Calory*mipi_VolumeMenu*mipi_VolumeProduct,0)
FROM      tp_MenuItems  I
     JOIN tp_Notes      N ON N.note_obj_ID = I.mitm_ID AND N.note_nttp_ID = @nttp_ID
LEFT JOIN tp_MenuGroups P ON P.mgrp_ID = I.mitm_mgrp_ID
LEFT JOIN tp_MenuPictures C ON C.mpic_ID = I.mitm_mpic_ID
LEFT JOIN tp_MenuSaleProperties  ON mspr_ID = I.mitm_mspr_ID
LEFT JOIN tp_MenuItemStopList ON misl_mitm_ID = I.mitm_ID  AND misl_dev_ID = @dev_ID
-- Калории
LEFT JOIN tp_MenuItemProductItems ON mipi_mitm_ID = I.mitm_ID 
LEFT JOIN tp_ProductItems ON pitm_ID = mipi_pitm_ID
WHERE ISNULL(mspr_IsModifyer, 0) = 0 AND I.mitm_del_ID IS NULL 
-- AND mitm_ID = 'F94B697D-8E47-2C44-A2A9-11BE1390F818'

INSERT INTO #ModifierList (mod_ID, mod_Name, mod_Description, mod_Price, mod_IsActive, mod_IsDeleted)
SELECT DISTINCT 
  I.mitm_ID, 
  ISNULL(dbo.f_MultiLanguageStringToStringByLanguageGroup(I.mitm_Name, NULL), '<language error>'), 
  ISNULL(dbo.f_MultiLanguageStringToStringByLanguageGroup(I.mitm_Description, NULL), 0),
  REPLACE(CONVERT(NVARCHAR(50), I.mitm_Price), '.', ','),
  -- IIF(I.mitm_IsDisabled = 0, 'True', 'False'),
  CASE 
    WHEN (I.mitm_IsDisabled = 0) THEN 'True'
	ELSE 'False'
  END,
  -- IIF(I.mitm_del_ID IS NOT NULL, 'True', 'False')
  CASE 
    WHEN (I.mitm_del_ID IS NOT NULL) THEN 'True'
	ELSE 'False'
  END
FROM      tp_MenuItems          I
     JOIN tp_Notes              N ON N.note_obj_ID = I.mitm_ID AND N.note_nttp_ID = @nttp_ID
LEFT JOIN tp_MenuSaleProperties P ON P.mspr_ID = I.mitm_mspr_ID
WHERE ISNULL(P.mspr_IsModifyer, 0) = 1 AND I.mitm_del_ID IS NULL 

-- Старая схема
-- '['+ISNULL(dbo.f_MultiLanguageStringToStringByLanguageGroup(T.mitm_Name, NULL), '<language error>')+']\'+ISNULL(dbo.f_MultiLanguageStringToStringByLanguageGroup(M.mitm_Name, NULL), '<language error>'), 
--JOIN tp_MenuModifierItems	ON mmit_mitm_ID = M.mitm_ID
--JOIN tp_MenuModifierGroups	ON mmgr_ID = mmit_mmgr_ID
--JOIN tp_MenuModifiers		ON mmod_ID = mmgr_mmod_ID
--JOIN tp_MenuItems T         ON T.mitm_mmod_ID = mmod_ID
--JOIN #ItemList				ON item_ID = T.mitm_ID

INSERT INTO #Subcategory (sub_ID, sub_Name, sub_Photo, sub_Path) 
SELECT distinct
  G.mgrp_ID, 
  ISNULL(dbo.f_MultiLanguageStringToStringByLanguageGroup(mgrp_Name, NULL), '<language error>'),
  mpic_Data,
  CASE 
    WHEN mpic_Data IS NOT NULL THEN @SubcategoryPath + @ImagePath + CONVERT(NVARCHAR(36), G.mgrp_ID) + '.jpg'
	ELSE ''
  END
FROM tp_MenuGroups G
JOIN #ItemList     I ON I.sub_ID = G.mgrp_ID
LEFT JOIN tp_MenuPictures P ON P.mpic_ID = G.mgrp_mpic_ID
WHERE mgrp_del_ID IS NULL

INSERT INTO #Category (cat_ID, cat_Name, cat_Photo, cat_Path) 
SELECT distinct
  G.mgrp_ID, 
  ISNULL(dbo.f_MultiLanguageStringToStringByLanguageGroup(G.mgrp_Name, NULL), '<language error>'),
  mpic_Data,
  CASE 
    WHEN mpic_Data IS NOT NULL THEN @CategoryPath + @ImagePath + CONVERT(NVARCHAR(36), G.mgrp_ID) + '.jpg'
	ELSE ''
  END
FROM tp_MenuGroups G
JOIN #ItemList     I ON I.cat_ID = G.mgrp_ID
LEFT JOIN tp_MenuPictures P ON P.mpic_ID = G.mgrp_mpic_ID
WHERE G.mgrp_del_ID IS NULL

-- Удаление старых данных
DECLARE @cmd NVARCHAR(255)

SET @cmd = 'DEL /f /q "'+@ItemListPath+'*.*"'
EXEC master..xp_cmdshell @cmd 
SET @cmd = 'DEL /f /q "'+@ModifierListPath+'*.*"'
EXEC master..xp_cmdshell @cmd
SET @cmd = 'DEL /f /q "'+@SubcategoryPath+'*.*"'
EXEC master..xp_cmdshell @cmd
SET @cmd = 'DEL /f /q "'+@CategoryPath+'*.*"'
EXEC master..xp_cmdshell @cmd
SET @cmd = 'DEL /f /q "'+@MenuPath+'*.*"'
EXEC master..xp_cmdshell @cmd

--
declare @xml xml
declare @i_fn varchar(max), @i_photo varchar(max)

-- Фото блюд, категорий и подкатегорий
DECLARE c_Photos CURSOR FOR
  SELECT DISTINCT item_Path, CONVERT(VARCHAR(MAX), item_Photo)
  FROM #ItemList
  WHERE item_Photo IS NOT NULL
  UNION 
  SELECT DISTINCT sub_Path,  CONVERT(VARCHAR(MAX), sub_Photo) 
  FROM #SubCategory
  WHERE sub_Photo IS NOT NULL
  UNION
  SELECT DISTINCT cat_Path,  CONVERT(VARCHAR(MAX), cat_Photo) 
  FROM #Category
  WHERE cat_Photo IS NOT NULL

OPEN c_Photos
FETCH c_Photos INTO @i_fn, @i_photo

WHILE @@FETCH_STATUS = 0 BEGIN
  PRINT @i_fn
  EXEC dbo.em_SaveToFile @i_fn, @i_photo, 'windows-1251'

  FETCH c_Photos INTO @i_fn, @i_photo
END

CLOSE c_Photos
DEALLOCATE c_Photos

-- ЭП
SELECT @XML = 
(SELECT  
  -- FORMAT(CURRENT_TIMESTAMP,N'dd-MM-yyyy HH:mm:ss') AS [TIME],
  CONVERT(varchar,@Date,104)+' '+CONVERT(varchar,@Date,108) AS [TIME], 
  -- ЭП
  (SELECT 
     item_ID 		AS [ITEM_ID],
	 item_Name  	AS [ITEM_NAME],
     item_Description	AS [DESCRIPTION],
	 0 AS [RECIPE],
     -- QUOTENAME(@ImagePath + CONVERT(NVARCHAR(MAX), item_ID) + '.jpg', CHAR(39))  AS [IMAGE_PATH],
     item_Path AS [IMAGE_PATH],
     item_PrepatarionTime AS [PREPARATION_TIME],
     item_Calory AS [CALORIE],
     0 AS [SERVINGS],
     item_IsActive AS [ISACTIVE],
	 item_IsDeleted AS [ISDELETED],
     item_Price AS [PRICE1],
	 0 AS [PRICE2],
	 0 AS [PRICE3],
	 0 AS [PRICE4],
	 0 AS [PRICE5],
     1 AS [DEFAULT_PRICE],
     0 AS [TAX1],
     0 AS [TAX2],
     0 AS [TAX3],
     'False' AS [CALCULATE_TAX2_AFTER_TAX1],
     'False' AS [CALCULATE_TAX3_AFTER_TAX1],
     'False' AS [CALCULATE_TAX3_AFTER_TAX2]
   FROM #ItemList
   ORDER BY item_Order 
   FOR XML PATH('ITEM'), Type) 
FOR XML PATH('POS_ITEM_LIST'), Type)

-- FORMAT(CURRENT_TIMESTAMP ,N'ddMMyyyy-HHmmss')
SET @fn = @ItemListPath + 'ItemList-' + REPLACE(CONVERT(varchar,@Date,104), '.', '')+'-'+REPLACE(CONVERT(varchar,@Date,108), ':', '') + '.xml'
SET @xmlt = CONVERT(NVARCHAR(MAX), @xml)
EXEC dbo.em_SaveToFile @fn, @xmlt 

-- Модификаторы
SELECT @XML = 
(SELECT  
  -- FORMAT(CURRENT_TIMESTAMP,N'dd-MM-yyyy HH:mm:ss') AS [TIME],
  CONVERT(varchar,@Date,104)+' '+CONVERT(varchar,@Date,108) AS [TIME], 
  -- ЭП
  (SELECT 
     mod_ID 		 AS [MODIFIER_ID],
	 mod_Name  	     AS [MODIFIER_NAME],
     mod_Description AS [DESCRIPTION],
     mod_IsActive    AS [ISACTIVE],
	 mod_IsDeleted   AS [ISDELETED],
     mod_price AS [PRICE1],
	 0 AS [PRICE2],
	 0 AS [PRICE3],
	 0 AS [PRICE4],
	 0 AS [PRICE5],
     1 AS [DEFAULT_PRICE],
	 'False' AS [IGNORE_ITEM_PRICE],
     0 AS [TAX1],
     0 AS [TAX2],
     0 AS [TAX3],
     'False' AS [CALCULATE_TAX2_AFTER_TAX1],
     'False' AS [CALCULATE_TAX3_AFTER_TAX1],
     'False' AS [CALCULATE_TAX3_AFTER_TAX2]
   FROM #ModifierList
   FOR XML PATH('MODIFIER'), Type) 
FOR XML PATH('POS_MODIFIER_LIST'), Type)

--  FORMAT(CURRENT_TIMESTAMP ,N'ddMMyyyy-HHmmss')
SET @fn = @ModifierListPath + 'ModifierList-' + REPLACE(CONVERT(varchar,@Date,104), '.', '')+'-'+REPLACE(CONVERT(varchar,@Date,108), ':', '') + '.xml'
SET @xmlt = CONVERT(NVARCHAR(MAX), @xml)
EXEC dbo.em_SaveToFile @fn, @xmlt 


SET @XML =
(SELECT 
  (SELECT DISTINCT -- TOP 3
     sub_ID	  AS [SUBCATEGORY_ID],
	 sub_Name AS [SUBCATEGORY_NAME],
     sub_Path AS [IMAGE_PATH]
   FROM #Subcategory 
   FOR XML PATH('SUBCATEGORY'), Type)
FOR XML Path('POS_SUBCATEGORY_LIST'), Type)

-- FORMAT(CURRENT_TIMESTAMP ,N'ddMMyyyy-HHmmss')
SET @fn = @SubcategoryPath + 'Subcategory-' + REPLACE(CONVERT(varchar,@Date,104), '.', '')+'-'+REPLACE(CONVERT(varchar,@Date,108), ':', '') + '.xml'
SET @xmlt = CONVERT(NVARCHAR(MAX), @xml)
EXEC dbo.em_SaveToFile @fn, @xmlt 

SET @XML =
(SELECT 
  (SELECT DISTINCT -- TOP 3
     cat_ID	  AS [CATEGORY_ID],
	 cat_Name AS [CATEGORY_NAME],
     cat_Path AS [IMAGE_PATH]
   FROM #category 
   FOR XML PATH('CATEGORY'), Type)
FOR XML Path('POS_CATEGORY_LIST'), Type)

-- FORMAT(CURRENT_TIMESTAMP ,N'ddMMyyyy-HHmmss')
SET @fn = @CategoryPath + 'Category-' + REPLACE(CONVERT(varchar,@Date,104), '.', '')+'-'+REPLACE(CONVERT(varchar,@Date,108), ':', '') + '.xml'
SET @xmlt = CONVERT(NVARCHAR(MAX), @xml)
EXEC dbo.em_SaveToFile @fn, @xmlt 

SET @XML = 
(SELECT  
  (SELECT DISTINCT -- TOP 3
     cat_ID AS [CATEGORY_ID],
	 sub_ID AS [SUBCATEGORY_ID]
   FROM #ItemList 
   FOR XML PATH('SUBCATEGORY'), ROOT('SUBCATEGORY_LIST'), Type),
   (SELECT DISTINCT -- TOP 3
     sub_ID  AS [SUBCATEGORY_ID],
	 item_ID AS [ITEM_ID]
   FROM #ItemList 
   FOR XML PATH('ITEM'), ROOT('ITEM_LIST'), Type)
FOR XML Path('MENU'), Type)

-- FORMAT(CURRENT_TIMESTAMP ,N'ddMMyyyy-HHmmss')
SET @fn = @MenuPath + 'Menu-' + REPLACE(CONVERT(varchar,@Date,104), '.', '')+'-'+REPLACE(CONVERT(varchar,@Date,108), ':', '') + '.xml'
SET @xmlt = CONVERT(NVARCHAR(MAX), @xml)
EXEC dbo.em_SaveToFile @fn, @xmlt 


DROP TABLE #Category
DROP TABLE #SubCategory
DROP TABLE #ModifierList
DROP TABLE #ItemList
GO
