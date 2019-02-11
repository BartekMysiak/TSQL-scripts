--Blokady na sql

SELECT session_id AS [SESSION], start_time AS [START], wait_time/1000/60 as [MINUTES], status AS [STATUS], command AS [COMMAND], d.name AS [Database], blocking_session_id AS [BLOCKING ID], wait_type AS [WAIT TYPE], transaction_id AS [TRAN ID] from sys.dm_exec_requests as er inner join sys.databases as d on er.database_id=d.database_id order by blocking_session_id DESC

select resource_type, resource_subtype, resource_database_id, request_mode, request_type, request_status, request_session_id from sys.dm_tran_locks

SELECT  resource_type AS [Resource Type], resource_subtype AS [Resource Subtype], resource_database_id AS [DatabaseID], D.name AS [Database Name], request_mode AS [Mode], ES.login_name AS [User], ES.program_name AS [Aplication], ES.host_name AS [Host]
FROM sys.dm_tran_locks AS TL  INNER JOIN sys.databases AS D ON TL.resource_database_id=D.database_id 
INNER JOIN sys.dm_exec_sessions AS ES ON TL.request_session_id=ES.session_id
--WHERE resource_database_id = 35


--Backup history

SELECT 
CONVERT(CHAR(100), SERVERPROPERTY('Servername')) AS Server, 
msdb.dbo.backupset.database_name,
msdb.dbo.backupmediafamily.physical_device_name,
msdb.dbo.backupset.user_name, 
CASE msdb..backupset.type 
WHEN 'D' THEN 'Database' 
WHEN 'L' THEN 'Log' 
END AS backup_type,
msdb.dbo.backupset.backup_start_date, 
msdb.dbo.backupset.backup_finish_date  
FROM msdb.dbo.backupmediafamily 
INNER JOIN msdb.dbo.backupset ON msdb.dbo.backupmediafamily.media_set_id = msdb.dbo.backupset.media_set_id 
WHERE (CONVERT(datetime, msdb.dbo.backupset.backup_start_date, 102) >= GETDATE() - 7)  AND database_name like 'T%'
ORDER BY 
msdb.dbo.backupset.database_name, 
msdb.dbo.backupset.backup_finish_date 


--Restore history
WITH LastRestores AS
(
SELECT
    DatabaseName = [d].[name] ,
    [d].[create_date] ,
    [d].[compatibility_level] ,
    [d].[collation_name] ,
    r.*,
    RowNum = ROW_NUMBER() OVER (PARTITION BY d.Name ORDER BY r.[restore_date] DESC)
FROM master.sys.databases d
LEFT OUTER JOIN msdb.dbo.[restorehistory] r ON r.[destination_database_name] = d.Name
)
SELECT *
FROM [LastRestores]
WHERE [RowNum] = 1 


--Backup/Restore progress

SELECT session_id as SPID, command, a.text AS Query, start_time, percent_complete, dateadd(second,estimated_completion_time/1000, getdate()) as estimated_completion_time
FROM sys.dm_exec_requests r CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) a
WHERE r.command in ('BACKUP DATABASE','RESTORE DATABASE') 


--Lista plikow fizycznych 

SELECT
    db.name AS DBName,
    type_desc AS FileType,
    Physical_Name AS Location
FROM
    sys.master_files mf
INNER JOIN 
    sys.databases db ON db.database_id = mf.database_id


--Wielkosc tabel

SELECT 
    t.NAME AS TableName,
    s.Name AS SchemaName,
    p.rows AS RowCounts,
    SUM(a.total_pages) * 8 AS TotalSpaceKB, 
    CAST(ROUND(((SUM(a.total_pages) * 8) / 1024.00), 2) AS NUMERIC(36, 2)) AS TotalSpaceMB,
    SUM(a.used_pages) * 8 AS UsedSpaceKB, 
    CAST(ROUND(((SUM(a.used_pages) * 8) / 1024.00), 2) AS NUMERIC(36, 2)) AS UsedSpaceMB, 
    (SUM(a.total_pages) - SUM(a.used_pages)) * 8 AS UnusedSpaceKB,
    CAST(ROUND(((SUM(a.total_pages) - SUM(a.used_pages)) * 8) / 1024.00, 2) AS NUMERIC(36, 2)) AS UnusedSpaceMB
FROM 
    sys.tables t
INNER JOIN      
    sys.indexes i ON t.OBJECT_ID = i.object_id
INNER JOIN 
    sys.partitions p ON i.object_id = p.OBJECT_ID AND i.index_id = p.index_id
INNER JOIN 
    sys.allocation_units a ON p.partition_id = a.container_id
LEFT OUTER JOIN 
    sys.schemas s ON t.schema_id = s.schema_id
WHERE 
    t.NAME NOT LIKE 'dt%' 
    AND t.is_ms_shipped = 0
    AND i.OBJECT_ID > 255 
GROUP BY 
    t.Name, s.Name, p.Rows
ORDER BY 
    t.Name
