-- ============================================================
-- BloodBond - Step 1 Database - SIMPLE v2.1
-- FILE: 01_schema.sql - VERSION: v2.1 - DATE: 2026-11-11
-- Fingerprint check: first 3 lines must say
--   BloodBond - Step 1 Database - SIMPLE v2.1
--   01_schema.sql / v2.1
-- If it says v2.0 or v1.0, do NOT run it - old file.
-- Run in SSMS: once. Safe to run again.
-- This file FIRST deletes the old tables (only if you ran
-- v2.0 / v1 before), then creates the simple 5 tables.
-- Demo data only so far - no real data to lose.
-- Success looks like: "Commands completed successfully."
-- Roles are ONLY 3: Donor, Acceptor, Admin.
--   Donor    = je blood dibe
--   Acceptor = je blood nibe (patient ba hospital)
--   Admin    = je system chalabe
-- Address: Division > District (Zila) > Upazila / Thana.
--   Frontend-e Division select korle tar Zila gulo asbe,
--   Zila select korle tar Upazila gulo asbe.
--   Database-e sudhu text hishebe jomabe - kono alada
--   lookup table nai, jeno simple thake.
-- ============================================================

IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = N'BloodBond')
BEGIN
    CREATE DATABASE BloodBond;
END
GO

USE BloodBond;
GO

-- Delete old objects first, so nothing old is left.
DROP PROCEDURE IF EXISTS dbo.sp_SearchDonors;
DROP PROCEDURE IF EXISTS dbo.sp_IssueBloodFromStock;
DROP PROCEDURE IF EXISTS dbo.sp_RecordDonation;
DROP PROCEDURE IF EXISTS dbo.sp_UpdateBloodStock;
DROP PROCEDURE IF EXISTS dbo.sp_RejectRequest;
DROP PROCEDURE IF EXISTS dbo.sp_ApproveRequest;
DROP PROCEDURE IF EXISTS dbo.sp_RejectUser;
DROP PROCEDURE IF EXISTS dbo.sp_ApproveUser;
DROP PROCEDURE IF EXISTS dbo.sp_CreateBloodRequest;
DROP PROCEDURE IF EXISTS dbo.sp_RegisterDonorProfile;
DROP PROCEDURE IF EXISTS dbo.sp_RegisterUser;
GO

DROP FUNCTION IF EXISTS dbo.tf_GetBloodStock;
DROP FUNCTION IF EXISTS dbo.tf_GetCompatibleDonors;
DROP FUNCTION IF EXISTS dbo.tf_SearchDonors;
DROP FUNCTION IF EXISTS dbo.fn_GetTotalStockByGroup;
DROP FUNCTION IF EXISTS dbo.fn_IsDonorEligible;
DROP FUNCTION IF EXISTS dbo.fn_GetNextEligibleDate;
GO

DROP VIEW IF EXISTS dbo.vw_DashboardSummary;
DROP VIEW IF EXISTS dbo.vw_DonationHistory;
DROP VIEW IF EXISTS dbo.vw_PendingRequests;
DROP VIEW IF EXISTS dbo.vw_BloodStockByGroup;
DROP VIEW IF EXISTS dbo.vw_AvailableDonors;
GO

DROP TABLE IF EXISTS dbo.Notifications;
DROP TABLE IF EXISTS dbo.Donations;
DROP TABLE IF EXISTS dbo.BloodStock;
DROP TABLE IF EXISTS dbo.BloodRequests;
DROP TABLE IF EXISTS dbo.Patients;
DROP TABLE IF EXISTS dbo.Donors;
DROP TABLE IF EXISTS dbo.BloodBanks;
DROP TABLE IF EXISTS dbo.Users;
GO

-- ------------------------------------------------------------
-- 1. Users - sobai ekhane login kore.
-- Role: Donor, Acceptor, Admin - sudhu ei 3 ta.
-- Occupation: Student / Job / Business / Doctor / Teacher /
--   Worker / Other. Division/District/Upazila: thikana.
-- Status: Pending (notun), Approved, Rejected
-- ------------------------------------------------------------
CREATE TABLE dbo.Users (
    UserID       INT IDENTITY(1,1) PRIMARY KEY,
    FullName     NVARCHAR(100) NOT NULL,
    Email        NVARCHAR(150) NOT NULL UNIQUE,
    PasswordHash NVARCHAR(255) NOT NULL,
    Phone        NVARCHAR(20) NULL,
    Role         NVARCHAR(20) NOT NULL
                 CHECK (Role IN (N'Donor', N'Acceptor', N'Admin')),
    Occupation   NVARCHAR(50) NULL
                 CHECK (Occupation IN (N'Student', N'Job', N'Business', N'Doctor', N'Teacher', N'Worker', N'Other')),
    Division     NVARCHAR(50) NULL,
    District     NVARCHAR(100) NULL,
    Upazila      NVARCHAR(100) NULL,
    Status       NVARCHAR(20) NOT NULL DEFAULT N'Pending'
                 CHECK (Status IN (N'Pending', N'Approved', N'Rejected')),
    CreatedAt    DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
);
GO

-- ------------------------------------------------------------
-- 2. Donors - Donor hole ei table-e ekta row thakbe.
-- DonorID = Users.UserID (ek-i manush, dui table).
-- AvailabilityStatus: Yes = dite parbe, No = parbe na,
--   NotSure = phone/email kore confirm korte hobe.
-- LastDonationDate: 90 din na gele auto eligible hobe na.
-- ------------------------------------------------------------
CREATE TABLE dbo.Donors (
    DonorID            INT PRIMARY KEY,
    BloodGroup         NVARCHAR(3) NOT NULL
                       CHECK (BloodGroup IN (N'A+', N'A-', N'B+', N'B-', N'O+', N'O-', N'AB+', N'AB-')),
    LastDonationDate   DATE NULL,
    AvailabilityStatus NVARCHAR(20) NOT NULL DEFAULT N'Yes'
                       CHECK (AvailabilityStatus IN (N'Yes', N'No', N'NotSure')),
    CONSTRAINT FK_Donors_User
        FOREIGN KEY (DonorID) REFERENCES dbo.Users (UserID)
);
GO

-- ------------------------------------------------------------
-- 3. BloodRequests - Acceptor blood chaile ekhane request dey.
-- AcceptorID = je Acceptor request dilo (Users.UserID).
-- UnitsNeeded = koy bag lagbe (1, 2, 3 ...).
-- ------------------------------------------------------------
CREATE TABLE dbo.BloodRequests (
    RequestID    INT IDENTITY(1,1) PRIMARY KEY,
    AcceptorID   INT NOT NULL,
    BloodGroup   NVARCHAR(3) NOT NULL
                 CHECK (BloodGroup IN (N'A+', N'A-', N'B+', N'B-', N'O+', N'O-', N'AB+', N'AB-')),
    UnitsNeeded  INT NOT NULL CHECK (UnitsNeeded > 0),
    Urgency      NVARCHAR(20) NOT NULL DEFAULT N'Medium'
                 CHECK (Urgency IN (N'Low', N'Medium', N'High', N'Critical')),
    Division     NVARCHAR(50) NULL,
    District     NVARCHAR(100) NULL,
    Upazila      NVARCHAR(100) NULL,
    HospitalName NVARCHAR(150) NULL,
    NeededByDate DATE NULL,
    Status       NVARCHAR(20) NOT NULL DEFAULT N'Pending'
                 CHECK (Status IN (N'Pending', N'Approved', N'Fulfilled', N'Rejected', N'Cancelled')),
    CreatedAt    DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    FulfilledAt  DATETIME2 NULL,
    CONSTRAINT FK_BloodRequests_Acceptor
        FOREIGN KEY (AcceptorID) REFERENCES dbo.Users (UserID)
);
GO

-- ------------------------------------------------------------
-- 4. Donations - ke, kobe, koy unit dilo.
-- ------------------------------------------------------------
CREATE TABLE dbo.Donations (
    DonationID   INT IDENTITY(1,1) PRIMARY KEY,
    DonorID      INT NOT NULL,
    RequestID    INT NULL,
    DonationDate DATE NOT NULL DEFAULT CAST(GETDATE() AS DATE),
    Units        INT NOT NULL DEFAULT 1 CHECK (Units > 0),
    Status       NVARCHAR(20) NOT NULL DEFAULT N'Completed'
                 CHECK (Status IN (N'Completed', N'Cancelled')),
    CONSTRAINT FK_Donations_Donor
        FOREIGN KEY (DonorID) REFERENCES dbo.Donors (DonorID),
    CONSTRAINT FK_Donations_Request
        FOREIGN KEY (RequestID) REFERENCES dbo.BloodRequests (RequestID)
);
GO

-- ------------------------------------------------------------
-- 5. BloodStock - proti blood group-e koy unit ache.
-- BloodGroup-i PRIMARY KEY, tai proti group-er sudhu 1 row.
-- Kono bank table nai - Admin-i ei stock chalabe.
-- ------------------------------------------------------------
CREATE TABLE dbo.BloodStock (
    BloodGroup     NVARCHAR(3) PRIMARY KEY
                   CHECK (BloodGroup IN (N'A+', N'A-', N'B+', N'B-', N'O+', N'O-', N'AB+', N'AB-')),
    UnitsAvailable INT NOT NULL DEFAULT 0 CHECK (UnitsAvailable >= 0),
    LastUpdated    DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
);
GO

-- ------------------------------------------------------------
-- Index - blood group + district diye khujte jeno fast hoy.
-- ------------------------------------------------------------
CREATE INDEX IX_Donors_Search ON dbo.Donors (BloodGroup);
GO

CREATE INDEX IX_Users_Address ON dbo.Users (Division, District, Upazila);
GO

CREATE INDEX IX_BloodRequests_Search ON dbo.BloodRequests (BloodGroup, District, Status);
GO

-- End of 01_schema.sql v2.1 - next file: 02_views_functions.sql v2.1
