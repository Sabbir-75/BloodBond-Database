-- ============================================================
-- BloodBond - Step 1 Database - SIMPLE v2.1
-- FILE: 05_verify.sql - VERSION: v2.1 - DATE: 2026-11-11
-- Fingerprint check: first 3 lines must say
--   BloodBond - Step 1 Database - SIMPLE v2.1
--   05_verify.sql / v2.1
-- Run AFTER 01, 02, 03, 04 (v2.1). Sudhu pore, kichu bodlay na.
-- PASS hole sob number milbe:
--   Tables = 5 | Users = 5 | Donors = 3 | BloodStock = 8
--   BloodRequests = 1 | Donations = 1
--   Views = 3 | ScalarFunctions = 2 | TableFunctions = 2
--   Procedures = 9
--   Roles: Admin 1, Donor 3, Acceptor 1
--   Rahim eligible = 1 | Nusrat eligible = 0
--   A+ donor Dhaka-te = 1 (Rahim) | Total A+ stock = 10
-- Na mille screenshot dao - Step 2-e jaba na.
-- ============================================================

USE BloodBond;
GO

-- 1. Tables
SELECT 'Tables' AS CheckName, COUNT(*) AS Actual, 5 AS Expected
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'dbo' AND TABLE_TYPE = 'BASE TABLE';
GO

-- 2. Row counts
SELECT 'Users' AS TableName, COUNT(*) AS Actual, 5 AS Expected FROM dbo.Users
UNION ALL SELECT 'Donors', COUNT(*), 3 FROM dbo.Donors
UNION ALL SELECT 'BloodStock', COUNT(*), 8 FROM dbo.BloodStock
UNION ALL SELECT 'BloodRequests', COUNT(*), 1 FROM dbo.BloodRequests
UNION ALL SELECT 'Donations', COUNT(*), 1 FROM dbo.Donations;
GO

-- 3. Roles - sudhu 3 ta role thakte hobe
SELECT Role, COUNT(*) AS TotalUsers FROM dbo.Users GROUP BY Role ORDER BY Role;
GO

-- 4. Views / Functions / Procedures
SELECT 'Views' AS CheckName, COUNT(*) AS Actual, 3 AS Expected
FROM INFORMATION_SCHEMA.VIEWS WHERE TABLE_SCHEMA = 'dbo';
GO

SELECT 'ScalarFunctions' AS CheckName, COUNT(*) AS Actual, 2 AS Expected
FROM INFORMATION_SCHEMA.ROUTINES WHERE ROUTINE_SCHEMA = 'dbo' AND ROUTINE_TYPE = 'FUNCTION' AND ROUTINE_NAME LIKE 'fn_%';
GO

SELECT 'TableFunctions' AS CheckName, COUNT(*) AS Actual, 2 AS Expected
FROM INFORMATION_SCHEMA.ROUTINES WHERE ROUTINE_SCHEMA = 'dbo' AND ROUTINE_TYPE = 'FUNCTION' AND ROUTINE_NAME LIKE 'tf_%';
GO

SELECT 'Procedures' AS CheckName, COUNT(*) AS Actual, 9 AS Expected
FROM INFORMATION_SCHEMA.ROUTINES WHERE ROUTINE_SCHEMA = 'dbo' AND ROUTINE_TYPE = 'PROCEDURE';
GO

-- 5. Eligibility: Rahim = 1, Nusrat = 0
SELECT u.FullName, d.BloodGroup, d.AvailabilityStatus, d.LastDonationDate,
       dbo.fn_GetNextEligibleDate(d.DonorID) AS NextEligibleDate,
       dbo.fn_IsDonorEligible(d.DonorID) AS IsEligible
FROM dbo.Donors d JOIN dbo.Users u ON u.UserID = d.DonorID
ORDER BY u.FullName;
GO

-- 6. Search: A+ Dhaka Dhaka - expect 1 row (Rahim)
SELECT * FROM dbo.tf_SearchDonors(N'A+', N'Dhaka', N'Dhaka', NULL);
GO

-- 7. Compatible donors for A+ - expect Rahim (A+) + Karim (O-)
SELECT * FROM dbo.tf_GetCompatibleDonors(N'A+');
GO

-- 8. Stock: A+ = 10
SELECT * FROM dbo.vw_BloodStockByGroup ORDER BY BloodGroup;
GO

-- End of 05_verify.sql v2.1
