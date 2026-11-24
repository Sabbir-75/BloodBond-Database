-- ============================================================
-- BloodBond - Step 1 Database - SIMPLE v2.1
-- FILE: 02_views_functions.sql - VERSION: v2.1 - DATE: 2026-11-11
-- Fingerprint check: first 3 lines must say
--   BloodBond - Step 1 Database - SIMPLE v2.1
--   02_views_functions.sql / v2.1
-- Run AFTER 01_schema.sql v2.1. Safe to run again.
-- Order matters: scalar functions FIRST, then views and
-- table-valued functions that use them.
-- Success looks like: "Commands completed successfully."
-- ============================================================

USE BloodBond;
GO

-- ============================================================
-- SCALAR FUNCTIONS - ektai man ferot dey.
-- Niyom: last donation-er 90 din (3 mash) por abar dite parbe.
-- Kono donation na thakle ekhon-i dite parbe.
-- ============================================================

-- Donor abar kobe dite parbe, sei date-ta dey.
CREATE OR ALTER FUNCTION dbo.fn_GetNextEligibleDate
(
    @DonorID INT
)
RETURNS DATE
AS
BEGIN
    DECLARE @LastDate DATE;
    DECLARE @Result DATE;

    SELECT @LastDate = LastDonationDate
    FROM dbo.Donors
    WHERE DonorID = @DonorID;

    IF @LastDate IS NULL
        SET @Result = CAST(GETDATE() AS DATE);
    ELSE
        SET @Result = DATEADD(DAY, 90, @LastDate);

    RETURN @Result;
END
GO

-- Donor ekhon dite parbe kina: 1 = parbe, 0 = parbe na.
-- Parbe sudhu jodi: status Yes HOY, ar 90 din par hoye jay.
CREATE OR ALTER FUNCTION dbo.fn_IsDonorEligible
(
    @DonorID INT
)
RETURNS BIT
AS
BEGIN
    DECLARE @Status NVARCHAR(20);
    DECLARE @LastDate DATE;

    SELECT @Status = AvailabilityStatus, @LastDate = LastDonationDate
    FROM dbo.Donors
    WHERE DonorID = @DonorID;

    IF @Status IS NULL OR @Status <> N'Yes'
        RETURN 0;

    IF @LastDate IS NULL
        RETURN 1;

    IF DATEADD(DAY, 90, @LastDate) <= CAST(GETDATE() AS DATE)
        RETURN 1;

    RETURN 0;
END
GO

-- ============================================================
-- VIEWS - sudhu 3 ta, toiri kora data, porar jonno.
-- ============================================================

-- Kon Donor ke dekhano jabe, tar status + next date shoho.
-- No status-er Donor ekhane asbe na. NotSure asbe, kintu
-- tar pashe likha thakbe "Call kore confirm koro".
CREATE OR ALTER VIEW dbo.vw_AvailableDonors AS
SELECT
    d.DonorID,
    u.FullName,
    u.Phone,
    u.Email,
    u.Occupation,
    u.Division,
    u.District,
    u.Upazila,
    d.BloodGroup,
    d.AvailabilityStatus,
    d.LastDonationDate,
    dbo.fn_GetNextEligibleDate(d.DonorID) AS NextEligibleDate,
    dbo.fn_IsDonorEligible(d.DonorID) AS IsEligible
FROM dbo.Donors d
JOIN dbo.Users u ON u.UserID = d.DonorID
WHERE d.AvailabilityStatus IN (N'Yes', N'NotSure')
  AND u.Status = N'Approved';
GO

-- Proti group-e koy unit stock ache
CREATE OR ALTER VIEW dbo.vw_BloodStockByGroup AS
SELECT BloodGroup, UnitsAvailable
FROM dbo.BloodStock;
GO

-- Pending request gulo, ke chailo tar nam shoho
CREATE OR ALTER VIEW dbo.vw_PendingRequests AS
SELECT
    r.RequestID,
    u.FullName AS AcceptorName,
    r.BloodGroup,
    r.UnitsNeeded,
    r.Urgency,
    r.Division,
    r.District,
    r.Upazila,
    r.HospitalName,
    r.NeededByDate,
    r.CreatedAt
FROM dbo.BloodRequests r
JOIN dbo.Users u ON u.UserID = r.AcceptorID
WHERE r.Status = N'Pending';
GO

-- ============================================================
-- TABLE-VALUED FUNCTIONS - parameter dile table ferot dey.
-- ============================================================

-- Blood group + Division + District + Upazila diye Donor khujo.
-- Kono ekta khali rakhle oi ta diye filter hobe na.
CREATE OR ALTER FUNCTION dbo.tf_SearchDonors
(
    @BloodGroup NVARCHAR(3),
    @Division   NVARCHAR(50),
    @District   NVARCHAR(100),
    @Upazila    NVARCHAR(100)
)
RETURNS TABLE
AS
RETURN
(
    SELECT
        d.DonorID,
        u.FullName,
        u.Phone,
        u.Email,
        u.Occupation,
        u.Division,
        u.District,
        u.Upazila,
        d.BloodGroup,
        d.AvailabilityStatus,
        dbo.fn_GetNextEligibleDate(d.DonorID) AS NextEligibleDate,
        dbo.fn_IsDonorEligible(d.DonorID) AS IsEligible
    FROM dbo.Donors d
    JOIN dbo.Users u ON u.UserID = d.DonorID
    WHERE u.Status = N'Approved'
      AND (@BloodGroup IS NULL OR @BloodGroup = N'' OR d.BloodGroup = @BloodGroup)
      AND (@Division IS NULL OR @Division = N'' OR u.Division = @Division)
      AND (@District IS NULL OR @District = N'' OR u.District = @District)
      AND (@Upazila IS NULL OR @Upazila = N'' OR u.Upazila = @Upazila)
);
GO

-- @NeededGroup-ke ke blood dite parbe.
-- A+ <- A+, A-, O+, O- | A- <- A-, O- | B+ <- B+, B-, O+, O-
-- B- <- B-, O- | O+ <- O+, O- | O- <- O- | AB+ <- sobai | AB- <- AB-, A-, B-, O-
CREATE OR ALTER FUNCTION dbo.tf_GetCompatibleDonors
(
    @NeededGroup NVARCHAR(3)
)
RETURNS TABLE
AS
RETURN
(
    SELECT
        d.DonorID,
        u.FullName,
        u.Phone,
        u.Division,
        u.District,
        u.Upazila,
        d.BloodGroup,
        d.AvailabilityStatus,
        dbo.fn_IsDonorEligible(d.DonorID) AS IsEligible
    FROM dbo.Donors d
    JOIN dbo.Users u ON u.UserID = d.DonorID
    WHERE u.Status = N'Approved'
      AND d.AvailabilityStatus IN (N'Yes', N'NotSure')
      AND (
            @NeededGroup = N'AB+'
            OR (@NeededGroup = N'A+'  AND d.BloodGroup IN (N'A+', N'A-', N'O+', N'O-'))
            OR (@NeededGroup = N'A-'  AND d.BloodGroup IN (N'A-', N'O-'))
            OR (@NeededGroup = N'B+'  AND d.BloodGroup IN (N'B+', N'B-', N'O+', N'O-'))
            OR (@NeededGroup = N'B-'  AND d.BloodGroup IN (N'B-', N'O-'))
            OR (@NeededGroup = N'O+'  AND d.BloodGroup IN (N'O+', N'O-'))
            OR (@NeededGroup = N'O-'  AND d.BloodGroup IN (N'O-'))
            OR (@NeededGroup = N'AB-' AND d.BloodGroup IN (N'AB-', N'A-', N'B-', N'O-'))
          )
);
GO

-- End of 02_views_functions.sql v2.1 - next file: 03_stored_procedures.sql v2.1
