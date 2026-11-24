-- ============================================================
-- BloodBond - Step 1 Database - SIMPLE v2.1
-- FILE: 03_stored_procedures.sql - VERSION: v2.1 - DATE: 2026-11-11
-- Fingerprint check: first 3 lines must say
--   BloodBond - Step 1 Database - SIMPLE v2.1
--   03_stored_procedures.sql / v2.1
-- Run AFTER 01 and 02 (v2.1). Safe to run again.
-- Sudhu 8 ta procedure. Prottek-tar upore comment ache,
--   ki kore ta lekha ache, jeno pore bujhte paro.
-- TRANSACTION (taka-r jonno NA): sp_RecordDonation ar
--   sp_IssueBloodFromStock-e bebohar hoyeche. Transaction
--   mane: ek sathe koyekta bodol - sob hole commit, ekta
--   vul hole sob rollback, ordhek bodol hobe na.
-- Success looks like: "Commands completed successfully."
-- ============================================================

USE BloodBond;
GO

-- ------------------------------------------------------------
-- sp_RegisterUser - notun user (Donor / Acceptor / Admin) banay.
-- Donor hole Donors table-eo ekta row banay, alada
-- procedure lagbe na. Tai Donor-er BloodGroup dite hobe.
-- Acceptor / Admin-er BloodGroup lage na.
-- Backend (Step 2) @PasswordHash-e bcrypt hash pathabe.
-- Notun UserID @NewUserID-te ferot dey.
-- ------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.sp_RegisterUser
    @FullName     NVARCHAR(100),
    @Email        NVARCHAR(150),
    @PasswordHash NVARCHAR(255),
    @Phone        NVARCHAR(20) = NULL,
    @Role         NVARCHAR(20),
    @Occupation   NVARCHAR(50) = NULL,
    @Division     NVARCHAR(50) = NULL,
    @District     NVARCHAR(100) = NULL,
    @Upazila      NVARCHAR(100) = NULL,
    @BloodGroup   NVARCHAR(3) = NULL,
    @NewUserID    INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    IF @Role = N'Donor' AND @BloodGroup IS NULL
    BEGIN
        RAISERROR(N'Donor must have a BloodGroup.', 16, 1);
        RETURN;
    END

    IF EXISTS (SELECT 1 FROM dbo.Users WHERE Email = @Email)
    BEGIN
        RAISERROR(N'Email already registered.', 16, 1);
        RETURN;
    END

    INSERT INTO dbo.Users
        (FullName, Email, PasswordHash, Phone, Role, Occupation, Division, District, Upazila, Status)
    VALUES
        (@FullName, @Email, @PasswordHash, @Phone, @Role, @Occupation, @Division, @District, @Upazila, N'Pending');

    SET @NewUserID = SCOPE_IDENTITY();

    IF @Role = N'Donor'
    BEGIN
        INSERT INTO dbo.Donors (DonorID, BloodGroup, AvailabilityStatus)
        VALUES (@NewUserID, @BloodGroup, N'Yes');
    END
END
GO

-- ------------------------------------------------------------
-- sp_CreateBloodRequest - Acceptor blood-er request dey.
-- UnitsNeeded = koy bag lagbe (1, 2, 3 ...).
-- Notun RequestID @NewRequestID-te ferot dey.
-- ------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.sp_CreateBloodRequest
    @AcceptorID   INT,
    @BloodGroup   NVARCHAR(3),
    @UnitsNeeded  INT,
    @Urgency      NVARCHAR(20) = N'Medium',
    @Division     NVARCHAR(50) = NULL,
    @District     NVARCHAR(100) = NULL,
    @Upazila      NVARCHAR(100) = NULL,
    @HospitalName NVARCHAR(150) = NULL,
    @NeededByDate DATE = NULL,
    @NewRequestID INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.Users WHERE UserID = @AcceptorID AND Role = N'Acceptor')
    BEGIN
        RAISERROR(N'Acceptor not found.', 16, 1);
        RETURN;
    END

    IF @UnitsNeeded <= 0
    BEGIN
        RAISERROR(N'UnitsNeeded must be greater than 0.', 16, 1);
        RETURN;
    END

    INSERT INTO dbo.BloodRequests
        (AcceptorID, BloodGroup, UnitsNeeded, Urgency, Division, District, Upazila, HospitalName, NeededByDate, Status)
    VALUES
        (@AcceptorID, @BloodGroup, @UnitsNeeded, @Urgency, @Division, @District, @Upazila, @HospitalName, @NeededByDate, N'Pending');

    SET @NewRequestID = SCOPE_IDENTITY();
END
GO

-- ------------------------------------------------------------
-- sp_ApproveUser - Admin notun user-ke approve kore.
-- Approve na hole user login koreo kaj korte parbe na.
-- ------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.sp_ApproveUser
    @UserID INT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.Users SET Status = N'Approved' WHERE UserID = @UserID;
END
GO

-- ------------------------------------------------------------
-- sp_ApproveRequest - Admin request-ke approve kore.
-- ------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.sp_ApproveRequest
    @RequestID INT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.BloodRequests SET Status = N'Approved'
    WHERE RequestID = @RequestID AND Status = N'Pending';
END
GO

-- ------------------------------------------------------------
-- sp_UpdateDonorStatus - Donor nije tar status bodlay.
-- Status: Yes / No / NotSure. Donation dewar por No korbe,
--   ar LastDonationDate dibe. 90 din por auto eligible hobe.
-- ------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.sp_UpdateDonorStatus
    @DonorID           INT,
    @AvailabilityStatus NVARCHAR(20),
    @LastDonationDate  DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE dbo.Donors
    SET AvailabilityStatus = @AvailabilityStatus,
        LastDonationDate = CASE WHEN @LastDonationDate IS NULL THEN LastDonationDate ELSE @LastDonationDate END
    WHERE DonorID = @DonorID;
END
GO

-- ------------------------------------------------------------
-- sp_UpdateBloodStock - stock barao ba komao, Transaction-e.
-- @UnitsChange +5 mane 5 unit jog, -2 mane 2 unit kom.
-- Stock kokhono 0-er niche jabe na - gele sob rollback.
-- Notun total @NewUnits-e ferot dey.
-- ------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.sp_UpdateBloodStock
    @BloodGroup  NVARCHAR(3),
    @UnitsChange INT,
    @NewUnits    INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM dbo.BloodStock WHERE BloodGroup = @BloodGroup)
        BEGIN
            IF @UnitsChange < 0
            BEGIN
                RAISERROR(N'Cannot remove stock that does not exist.', 16, 1);
            END
            INSERT INTO dbo.BloodStock (BloodGroup, UnitsAvailable)
            VALUES (@BloodGroup, @UnitsChange);
        END
        ELSE
        BEGIN
            UPDATE dbo.BloodStock
            SET UnitsAvailable = UnitsAvailable + @UnitsChange,
                LastUpdated = SYSUTCDATETIME()
            WHERE BloodGroup = @BloodGroup;

            IF EXISTS (SELECT 1 FROM dbo.BloodStock
                       WHERE BloodGroup = @BloodGroup AND UnitsAvailable < 0)
            BEGIN
                RAISERROR(N'Stock cannot go below 0.', 16, 1);
            END
        END

        SELECT @NewUnits = UnitsAvailable
        FROM dbo.BloodStock
        WHERE BloodGroup = @BloodGroup;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

-- ------------------------------------------------------------
-- sp_RecordDonation - Donor blood dilo.
-- TRANSACTION bebohar: EK sathe 4 ta kaj -
--   (1) Donation row, (2) Donor-er LastDonationDate = ajke
--   ar AvailabilityStatus = No, (3) Stock-e unit jog,
--   (4) Request thakle Fulfilled. Ekta vul hole sob rollback.
-- Donor eligible na hole kichui bodlabe na.
-- 90 din por fn_IsDonorEligible abar 1 hobe - mane auto Yes.
-- Notun DonationID @NewDonationID-te ferot dey.
-- ------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.sp_RecordDonation
    @DonorID       INT,
    @RequestID     INT = NULL,
    @Units         INT = 1,
    @NewDonationID INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Needed INT = NULL;
    DECLARE @DonorGroup NVARCHAR(3);

    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM dbo.Donors WHERE DonorID = @DonorID)
        BEGIN
            RAISERROR(N'Donor not found.', 16, 1);
        END

        IF dbo.fn_IsDonorEligible(@DonorID) = 0
        BEGIN
            RAISERROR(N'Donor is not eligible to donate yet (90-day rule or status is not Yes).', 16, 1);
        END

        IF @Units <= 0
        BEGIN
            RAISERROR(N'Units must be greater than 0.', 16, 1);
        END

        SELECT @DonorGroup = BloodGroup FROM dbo.Donors WHERE DonorID = @DonorID;

        INSERT INTO dbo.Donations (DonorID, RequestID, DonationDate, Units, Status)
        VALUES (@DonorID, @RequestID, CAST(GETDATE() AS DATE), @Units, N'Completed');

        SET @NewDonationID = SCOPE_IDENTITY();

        UPDATE dbo.Donors
        SET LastDonationDate = CAST(GETDATE() AS DATE),
            AvailabilityStatus = N'No'
        WHERE DonorID = @DonorID;

        IF NOT EXISTS (SELECT 1 FROM dbo.BloodStock WHERE BloodGroup = @DonorGroup)
        BEGIN
            INSERT INTO dbo.BloodStock (BloodGroup, UnitsAvailable)
            VALUES (@DonorGroup, @Units);
        END
        ELSE
        BEGIN
            UPDATE dbo.BloodStock
            SET UnitsAvailable = UnitsAvailable + @Units,
                LastUpdated = SYSUTCDATETIME()
            WHERE BloodGroup = @DonorGroup;
        END

        IF @RequestID IS NOT NULL
        BEGIN
            SELECT @Needed = UnitsNeeded FROM dbo.BloodRequests WHERE RequestID = @RequestID;

            IF @Needed IS NULL
            BEGIN
                RAISERROR(N'Blood request not found.', 16, 1);
            END

            IF @Units >= @Needed
            BEGIN
                UPDATE dbo.BloodRequests
                SET Status = N'Fulfilled', FulfilledAt = SYSUTCDATETIME()
                WHERE RequestID = @RequestID;
            END
            ELSE
            BEGIN
                UPDATE dbo.BloodRequests
                SET Status = N'Approved'
                WHERE RequestID = @RequestID AND Status = N'Pending';
            END
        END

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

-- ------------------------------------------------------------
-- sp_IssueBloodFromStock - Stock theke request-ke blood dao.
-- TRANSACTION bebohar: stock komao + request Fulfilled koro.
-- Stock kom thakle kichui bodlabe na (rollback).
-- ------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.sp_IssueBloodFromStock
    @RequestID INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Group NVARCHAR(3);
    DECLARE @Needed INT;
    DECLARE @Available INT;

    BEGIN TRY
        BEGIN TRANSACTION;

        SELECT @Group = BloodGroup, @Needed = UnitsNeeded
        FROM dbo.BloodRequests
        WHERE RequestID = @RequestID;

        IF @Group IS NULL
        BEGIN
            RAISERROR(N'Blood request not found.', 16, 1);
        END

        SELECT @Available = ISNULL(UnitsAvailable, 0)
        FROM dbo.BloodStock
        WHERE BloodGroup = @Group;

        IF @Available < @Needed
        BEGIN
            RAISERROR(N'Not enough stock for this request.', 16, 1);
        END

        UPDATE dbo.BloodStock
        SET UnitsAvailable = UnitsAvailable - @Needed,
            LastUpdated = SYSUTCDATETIME()
        WHERE BloodGroup = @Group;

        UPDATE dbo.BloodRequests
        SET Status = N'Fulfilled', FulfilledAt = SYSUTCDATETIME()
        WHERE RequestID = @RequestID;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

-- ------------------------------------------------------------
-- sp_SearchDonors - Backend ei procedure call korbe.
-- Khujar niyom ek jaygay ache: tf_SearchDonors.
-- Division / District / Upazila / BloodGroup diye khujbe.
-- ------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.sp_SearchDonors
    @BloodGroup NVARCHAR(3) = NULL,
    @Division   NVARCHAR(50) = NULL,
    @District   NVARCHAR(100) = NULL,
    @Upazila    NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM dbo.tf_SearchDonors(@BloodGroup, @Division, @District, @Upazila);
END
GO

-- End of 03_stored_procedures.sql v2.1
-- Note: procedure ekhon 9 ta (sp_UpdateDonorStatus notun).
-- 05_verify.sql-e Procedures = 9 milte hobe.
