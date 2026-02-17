IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = N'protheus')
BEGIN
    CREATE DATABASE protheus COLLATE latin1_general_bin;
END;