-- ============================================================
-- BloodBond - Step 1 Database - SIMPLE v2.1
-- FILE: 04_seed_demo.sql - VERSION: v2.1 - DATE: 2026-11-11
-- Fingerprint check: first 3 lines must say
--   BloodBond - Step 1 Database - SIMPLE v2.1
--   04_seed_demo.sql / v2.1
-- Run AFTER 01, 02, 03 (v2.1). Safe to run again - prottek
-- INSERT-er age IF NOT EXISTS check ache, tai duplicate hobe na.
-- Demo data sudhu - kono asol manush-er data na.
-- PasswordHash DEMO placeholder, asol hash na. Asol bcrypt
-- hash Step 2-e register API banabe. Ei demo user diye
-- ekhono login korar chesta koro na.
-- Expected: Users = 5, Donors = 3, BloodStock = 8,
-- BloodRequests = 1, Donations = 1.
-- ============================================================

USE BloodBond;
GO

-- ---------- Users (5): 1 Admin, 3 Donor, 1 Acceptor ----------
IF NOT EXISTS (SELECT 1 FROM dbo.Users WHERE Email = N'admin@bloodbond.test')
    INSERT INTO dbo.Users (FullName, Email, PasswordHash, Phone, Role, Occupation, Division, District, Upazila, Status)
    VALUES (N'Admin User', N'admin@bloodbond.test', N'DEMO_HASH_CHANGE_IN_STEP2', N'01700000001', N'Admin', NULL, NULL, NULL, NULL, N'Approved');

IF NOT EXISTS (SELECT 1 FROM dbo.Users WHERE Email = N'rahim@bloodbond.test')
    INSERT INTO dbo.Users (FullName, Email, PasswordHash, Phone, Role, Occupation, Division, District, Upazila, Status)
    VALUES (N'Rahim Uddin', N'rahim@bloodbond.test', N'DEMO_HASH_CHANGE_IN_STEP2', N'01700000002', N'Donor', N'Student', N'Dhaka', N'Dhaka', N'Dhanmondi', N'Approved');

IF NOT EXISTS (SELECT 1 FROM dbo.Users WHERE Email = N'karim@bloodbond.test')
    INSERT INTO dbo.Users (FullName, Email, PasswordHash, Phone, Role, Occupation, Division, District, Upazila, Status)
    VALUES (N'Karim Hossain', N'karim@bloodbond.test', N'DEMO_HASH_CHANGE_IN_STEP2', N'01700000003', N'Donor', N'Job', N'Chattogram', N'Chattogram', N'Chandgaon', N'Approved');

IF NOT EXISTS (SELECT 1 FROM dbo.Users WHERE Email = N'nusrat@bloodbond.test')
    INSERT INTO dbo.Users (FullName, Email, PasswordHash, Phone, Role, Occupation, Division, District, Upazila, Status)
    VALUES (N'Nusrat Jahan', N'nusrat@bloodbond.test', N'DEMO_HASH_CHANGE_IN_STEP2', N'01700000004', N'Donor', N'Job', N'Dhaka', N'Dhaka', N'Mirpur', N'Approved');

IF NOT EXISTS (SELECT 1 FROM dbo.Users WHERE Email = N'tanvir@bloodbond.test')
    INSERT INTO dbo.Users (FullName, Email, PasswordHash, Phone, Role, Occupation, Division, District, Upazila, Status)
    VALUES (N'Tanvir Ahmed', N'tanvir@bloodbond.test', N'DEMO_HASH_CHANGE_IN_STEP2', N'01700000005', N'Acceptor', N'Student', N'Dhaka', N'Dhaka', N'Uttara', N'Approved');
GO

-- ---------- Donors (3) ----------
-- Rahim: A+, status Yes, last 2026-08-01 -> eligible
-- Karim: O-, status Yes, kokhono dey nai -> eligible
-- Nusrat: B+, status No, last 2026-10-20 -> eligible NA (2027-01-18 porjonto na)
IF NOT EXISTS (SELECT 1 FROM dbo.Donors WHERE DonorID = (SELECT UserID FROM dbo.Users WHERE Email = N'rahim@bloodbond.test'))
    INSERT INTO dbo.Donors (DonorID, BloodGroup, LastDonationDate, AvailabilityStatus)
    SELECT UserID, N'A+', '2026-08-01', N'Yes'
    FROM dbo.Users WHERE Email = N'rahim@bloodbond.test';

IF NOT EXISTS (SELECT 1 FROM dbo.Donors WHERE DonorID = (SELECT UserID FROM dbo.Users WHERE Email = N'karim@bloodbond.test'))
    INSERT INTO dbo.Donors (DonorID, BloodGroup, LastDonationDate, AvailabilityStatus)
    SELECT UserID, N'O-', NULL, N'Yes'
    FROM dbo.Users WHERE Email = N'karim@bloodbond.test';

IF NOT EXISTS (SELECT 1 FROM dbo.Donors WHERE DonorID = (SELECT UserID FROM dbo.Users WHERE Email = N'nusrat@bloodbond.test'))
    INSERT INTO dbo.Donors (DonorID, BloodGroup, LastDonationDate, AvailabilityStatus)
    SELECT UserID, N'B+', '2026-10-20', N'No'
    FROM dbo.Users WHERE Email = N'nusrat@bloodbond.test';
GO

-- ---------- BloodStock (8 group) ----------
IF NOT EXISTS (SELECT 1 FROM dbo.BloodStock WHERE BloodGroup = N'A+')
    INSERT INTO dbo.BloodStock (BloodGroup, UnitsAvailable) VALUES (N'A+', 10);
IF NOT EXISTS (SELECT 1 FROM dbo.BloodStock WHERE BloodGroup = N'A-')
    INSERT INTO dbo.BloodStock (BloodGroup, UnitsAvailable) VALUES (N'A-', 5);
IF NOT EXISTS (SELECT 1 FROM dbo.BloodStock WHERE BloodGroup = N'B+')
    INSERT INTO dbo.BloodStock (BloodGroup, UnitsAvailable) VALUES (N'B+', 8);
IF NOT EXISTS (SELECT 1 FROM dbo.BloodStock WHERE BloodGroup = N'B-')
    INSERT INTO dbo.BloodStock (BloodGroup, UnitsAvailable) VALUES (N'B-', 4);
IF NOT EXISTS (SELECT 1 FROM dbo.BloodStock WHERE BloodGroup = N'O+')
    INSERT INTO dbo.BloodStock (BloodGroup, UnitsAvailable) VALUES (N'O+', 12);
IF NOT EXISTS (SELECT 1 FROM dbo.BloodStock WHERE BloodGroup = N'O-')
    INSERT INTO dbo.BloodStock (BloodGroup, UnitsAvailable) VALUES (N'O-', 3);
IF NOT EXISTS (SELECT 1 FROM dbo.BloodStock WHERE BloodGroup = N'AB+')
    INSERT INTO dbo.BloodStock (BloodGroup, UnitsAvailable) VALUES (N'AB+', 6);
IF NOT EXISTS (SELECT 1 FROM dbo.BloodStock WHERE BloodGroup = N'AB-')
    INSERT INTO dbo.BloodStock (BloodGroup, UnitsAvailable) VALUES (N'AB-', 2);
GO

-- ---------- BloodRequests (1 pending, Tanvir Acceptor) ----------
DECLARE @AcceptorID INT;
SELECT @AcceptorID = UserID FROM dbo.Users WHERE Email = N'tanvir@bloodbond.test';

IF NOT EXISTS (SELECT 1 FROM dbo.BloodRequests WHERE AcceptorID = @AcceptorID AND BloodGroup = N'A+' AND Status = N'Pending')
    INSERT INTO dbo.BloodRequests (AcceptorID, BloodGroup, UnitsNeeded, Urgency, Division, District, Upazila, HospitalName, NeededByDate, Status)
    VALUES (@AcceptorID, N'A+', 2, N'High', N'Dhaka', N'Dhaka', N'Uttara', N'City Hospital Dhaka', '2026-11-15', N'Pending');
GO

-- ---------- Donations (1, Rahim 2026-08-01) ----------
DECLARE @RahimID INT;
SELECT @RahimID = UserID FROM dbo.Users WHERE Email = N'rahim@bloodbond.test';

IF NOT EXISTS (SELECT 1 FROM dbo.Donations WHERE DonorID = @RahimID AND DonationDate = '2026-08-01')
    INSERT INTO dbo.Donations (DonorID, RequestID, DonationDate, Units, Status)
    VALUES (@RahimID, NULL, '2026-08-01', 1, N'Completed');
GO

-- End of 04_seed_demo.sql v2.1 - next file: 05_verify.sql v2.1
