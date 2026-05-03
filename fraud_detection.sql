-- ============================================================
--  FRAUD DETECTION SYSTEM
--  Introduction to Database Systems
--  Microsoft SQL Server Management Studio (SSMS)
-- ============================================================
--  EXECUTION ORDER:
--  1. Run this entire script in one go, OR section by section
--     in the order they appear below.
-- ============================================================

-- ============================================================
-- SECTION 0: DATABASE CREATION
-- ============================================================

USE master;
GO

IF EXISTS (SELECT name FROM sys.databases WHERE name = 'FraudDetection')
BEGIN
    ALTER DATABASE FraudDetection SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE FraudDetection;
END
GO

CREATE DATABASE FraudDetection;
GO

USE FraudDetection;
GO

-- ============================================================
-- SECTION 1: TABLE CREATION (DDL)
-- ============================================================

-- 1.1 Customers Table
CREATE TABLE Customers (
    CustomerID      INT PRIMARY KEY IDENTITY(1,1),
    FullName        VARCHAR(100) NOT NULL,
    Email           VARCHAR(100) UNIQUE NOT NULL,
    PhoneNumber     VARCHAR(20),
    NationalID      VARCHAR(30) UNIQUE NOT NULL,
    DateOfBirth     DATE,
    Address         VARCHAR(255),
    CreatedAt       DATETIME DEFAULT GETDATE(),
    IsActive        BIT DEFAULT 1
);
GO

-- 1.2 Accounts Table
CREATE TABLE Accounts (
    AccountID       INT PRIMARY KEY IDENTITY(1,1),
    CustomerID      INT NOT NULL,
    AccountNumber   VARCHAR(20) UNIQUE NOT NULL,
    AccountType     VARCHAR(20) CHECK (AccountType IN ('Savings', 'Checking', 'Business')) NOT NULL,
    Balance         DECIMAL(15, 2) DEFAULT 0.00,
    Currency        VARCHAR(5) DEFAULT 'USD',
    OpenedDate      DATE DEFAULT GETDATE(),
    Status          VARCHAR(20) CHECK (Status IN ('Active', 'Suspended', 'Closed')) DEFAULT 'Active',
    CONSTRAINT FK_Accounts_Customers FOREIGN KEY (CustomerID) REFERENCES Customers(CustomerID)
);
GO

-- 1.3 FraudRules Table
CREATE TABLE FraudRules (
    RuleID          INT PRIMARY KEY IDENTITY(1,1),
    RuleName        VARCHAR(100) NOT NULL,
    Description     VARCHAR(500),
    Threshold       DECIMAL(15, 2),
    IsActive        BIT DEFAULT 1,
    CreatedAt       DATETIME DEFAULT GETDATE()
);
GO

-- 1.4 Transactions Table
CREATE TABLE Transactions (
    TransactionID   INT PRIMARY KEY IDENTITY(1,1),
    AccountID       INT NOT NULL,
    TransactionType VARCHAR(30) CHECK (TransactionType IN ('Deposit', 'Withdrawal', 'Transfer', 'Payment')) NOT NULL,
    Amount          DECIMAL(15, 2) NOT NULL CHECK (Amount > 0),
    Currency        VARCHAR(5) DEFAULT 'USD',
    Timestamp       DATETIME DEFAULT GETDATE(),
    MerchantName    VARCHAR(100),
    Location        VARCHAR(100),
    IPAddress       VARCHAR(50),
    DeviceID        VARCHAR(100),
    Status          VARCHAR(20) CHECK (Status IN ('Pending', 'Completed', 'Flagged', 'Blocked')) DEFAULT 'Pending',
    Description     VARCHAR(255),
    CONSTRAINT FK_Transactions_Accounts FOREIGN KEY (AccountID) REFERENCES Accounts(AccountID)
);
GO

-- 1.5 Blacklist Table
CREATE TABLE Blacklist (
    BlacklistID     INT PRIMARY KEY IDENTITY(1,1),
    EntityType      VARCHAR(30) CHECK (EntityType IN ('Account', 'IPAddress', 'DeviceID', 'MerchantName')) NOT NULL,
    EntityValue     VARCHAR(200) NOT NULL,
    Reason          VARCHAR(500),
    AddedBy         VARCHAR(100),
    AddedAt         DATETIME DEFAULT GETDATE(),
    IsActive        BIT DEFAULT 1
);
GO

-- 1.6 FraudAlerts Table
CREATE TABLE FraudAlerts (
    AlertID         INT PRIMARY KEY IDENTITY(1,1),
    TransactionID   INT NOT NULL,
    RuleID          INT,
    AlertType       VARCHAR(50) NOT NULL,
    Severity        VARCHAR(20) CHECK (Severity IN ('Low', 'Medium', 'High', 'Critical')) NOT NULL,
    AlertMessage    VARCHAR(500),
    IsResolved      BIT DEFAULT 0,
    ResolvedBy      VARCHAR(100),
    ResolvedAt      DATETIME,
    CreatedAt       DATETIME DEFAULT GETDATE(),
    CONSTRAINT FK_FraudAlerts_Transactions FOREIGN KEY (TransactionID) REFERENCES Transactions(TransactionID),
    CONSTRAINT FK_FraudAlerts_Rules FOREIGN KEY (RuleID) REFERENCES FraudRules(RuleID)
);
GO

-- 1.7 AuditLog Table (used by triggers)
CREATE TABLE AuditLog (
    LogID           INT PRIMARY KEY IDENTITY(1,1),
    TableName       VARCHAR(50),
    OperationType   VARCHAR(10) CHECK (OperationType IN ('INSERT', 'UPDATE', 'DELETE')),
    RecordID        INT,
    OldValue        VARCHAR(MAX),
    NewValue        VARCHAR(MAX),
    ChangedBy       VARCHAR(100) DEFAULT SYSTEM_USER,
    ChangedAt       DATETIME DEFAULT GETDATE()
);
GO

-- ============================================================
-- SECTION 2: INSERT SAMPLE DATA (DML)
-- ============================================================

-- 2.1 Insert Customers
INSERT INTO Customers (FullName, Email, PhoneNumber, NationalID, DateOfBirth, Address)
VALUES
    ('Ahmed Raza',       'ahmed.raza@mail.com',    '+92-300-1234567', 'NID-001', '1988-03-12', 'Karachi, Pakistan'),
    ('Sara Khan',        'sara.khan@mail.com',      '+92-321-7654321', 'NID-002', '1993-07-25', 'Lahore, Pakistan'),
    ('John Matthews',    'john.m@mail.com',          '+1-212-5550101',  'NID-003', '1979-11-05', 'New York, USA'),
    ('Fatima Malik',     'fatima.m@mail.com',        '+92-333-9988776', 'NID-004', '1995-01-19', 'Islamabad, Pakistan'),
    ('Carlos Ruiz',      'carlos.r@mail.com',        '+52-55-12345678', 'NID-005', '1985-06-30', 'Mexico City, Mexico'),
    ('Zainab Hussain',   'zainab.h@mail.com',        '+92-312-4455667', 'NID-006', '1991-09-14', 'Faisalabad, Pakistan'),
    ('Michael Turner',   'mike.t@mail.com',          '+44-20-71234567', 'NID-007', '1980-02-28', 'London, UK'),
    ('Nadia Sheikh',     'nadia.s@mail.com',         '+92-345-6677889', 'NID-008', '1997-12-03', 'Multan, Pakistan'),
    ('David Chen',       'david.c@mail.com',         '+86-10-12345678', 'NID-009', '1983-04-17', 'Beijing, China'),
    ('Amna Farooq',      'amna.f@mail.com',          '+92-300-9988112', 'NID-010', '1990-08-22', 'Rawalpindi, Pakistan');
GO

-- 2.2 Insert Accounts
INSERT INTO Accounts (CustomerID, AccountNumber, AccountType, Balance, Currency, Status)
VALUES
    (1,  'ACC-1001', 'Savings',  45000.00,  'USD', 'Active'),
    (1,  'ACC-1002', 'Checking', 12000.00,  'USD', 'Active'),
    (2,  'ACC-1003', 'Savings',  88000.00,  'PKR', 'Active'),
    (3,  'ACC-1004', 'Business', 250000.00, 'USD', 'Active'),
    (4,  'ACC-1005', 'Savings',  32000.00,  'PKR', 'Active'),
    (5,  'ACC-1006', 'Checking', 15000.00,  'USD', 'Suspended'),
    (6,  'ACC-1007', 'Savings',  67000.00,  'PKR', 'Active'),
    (7,  'ACC-1008', 'Business', 120000.00, 'GBP', 'Active'),
    (8,  'ACC-1009', 'Savings',  9000.00,   'PKR', 'Active'),
    (9,  'ACC-1010', 'Checking', 53000.00,  'USD', 'Active'),
    (10, 'ACC-1011', 'Savings',  21000.00,  'PKR', 'Active');
GO

-- 2.3 Insert Fraud Rules
INSERT INTO FraudRules (RuleName, Description, Threshold, IsActive)
VALUES
    ('Large Transaction',         'Single transaction exceeds threshold amount',                 10000.00, 1),
    ('Rapid Transactions',        'More than 5 transactions within 10 minutes',                  5.00,     1),
    ('Blacklist Match',           'Transaction matches a blacklisted IP, device, or merchant',   0.00,     1),
    ('Dormant Account Activity',  'Transaction on an account inactive for 6+ months',            0.00,     1),
    ('Round Number Pattern',      'Repeated transactions of identical round amounts',             1000.00,  1),
    ('Cross-Border High Value',   'International transaction above threshold',                   5000.00,  1),
    ('Suspended Account Use',     'Any transaction attempted on a suspended account',            0.00,     1);
GO

-- 2.4 Insert Transactions
INSERT INTO Transactions (AccountID, TransactionType, Amount, Currency, Timestamp, MerchantName, Location, IPAddress, DeviceID, Status, Description)
VALUES
    (1,  'Withdrawal', 500.00,    'USD', '2025-03-01 09:10:00', 'ATM-Downtown',     'New York',    '192.168.1.1',   'DEV-001', 'Completed', 'ATM Withdrawal'),
    (1,  'Transfer',   15000.00,  'USD', '2025-03-01 09:15:00', NULL,               'Online',      '192.168.1.1',   'DEV-001', 'Flagged',   'Large Transfer'),
    (2,  'Payment',    1000.00,   'USD', '2025-03-02 11:00:00', 'Amazon',           'Online',      '10.0.0.5',      'DEV-002', 'Completed', 'Online Purchase'),
    (3,  'Deposit',    5000.00,   'PKR', '2025-03-03 14:30:00', NULL,               'Lahore',      '172.16.0.3',    'DEV-003', 'Completed', 'Cash Deposit'),
    (4,  'Transfer',   50000.00,  'USD', '2025-03-04 16:00:00', NULL,               'Online',      '198.51.100.22', 'DEV-004', 'Flagged',   'International Transfer'),
    (5,  'Withdrawal', 3000.00,   'PKR', '2025-03-05 08:45:00', 'ATM-City',         'Islamabad',   '203.0.113.10',  'DEV-005', 'Completed', 'ATM Withdrawal'),
    (6,  'Payment',    800.00,    'USD', '2025-03-05 10:00:00', 'SuspectMerchant',  'Mexico City', '192.0.2.55',    'DEV-BAD', 'Blocked',   'Suspicious Payment'),
    (7,  'Deposit',    20000.00,  'PKR', '2025-03-06 12:00:00', NULL,               'Faisalabad',  '10.1.1.1',      'DEV-006', 'Completed', 'Salary Deposit'),
    (8,  'Transfer',   75000.00,  'GBP', '2025-03-07 09:30:00', NULL,               'London',      '185.0.0.10',    'DEV-007', 'Flagged',   'High-Value Transfer'),
    (9,  'Payment',    1000.00,   'PKR', '2025-03-07 13:00:00', 'Online Shop',      'Multan',      '10.2.2.2',      'DEV-008', 'Completed', 'Online Payment'),
    (10, 'Withdrawal', 1000.00,   'USD', '2025-03-08 10:00:00', 'ATM-Beijing',      'Beijing',     '202.96.0.1',    'DEV-009', 'Completed', 'ATM Withdrawal'),
    (10, 'Withdrawal', 1000.00,   'USD', '2025-03-08 10:03:00', 'ATM-Beijing',      'Beijing',     '202.96.0.1',    'DEV-009', 'Flagged',   'Rapid Repeat'),
    (10, 'Withdrawal', 1000.00,   'USD', '2025-03-08 10:06:00', 'ATM-Beijing',      'Beijing',     '202.96.0.1',    'DEV-009', 'Flagged',   'Rapid Repeat'),
    (1,  'Payment',    250.00,    'USD', '2025-03-09 15:00:00', 'Netflix',          'Online',      '192.168.1.1',   'DEV-001', 'Completed', 'Subscription'),
    (4,  'Transfer',   12000.00,  'USD', '2025-03-10 11:00:00', NULL,               'Online',      '198.51.100.22', 'DEV-004', 'Flagged',   'Large Transfer'),
    (11, 'Deposit',    45000.00,  'PKR', '2025-03-11 09:00:00', NULL,               'Rawalpindi',  '10.3.3.3',      'DEV-010', 'Completed', 'Business Income'),
    (2,  'Payment',    5500.00,   'USD', '2025-03-12 14:00:00', 'SuspectMerchant',  'Online',      '192.0.2.55',    'DEV-BAD', 'Blocked',   'Blacklisted Merchant'),
    (3,  'Withdrawal', 2000.00,   'PKR', '2025-03-13 16:30:00', 'ATM-Lahore',       'Lahore',      '172.16.0.3',    'DEV-003', 'Completed', 'ATM Withdrawal'),
    (7,  'Payment',    3500.00,   'PKR', '2025-03-14 11:15:00', 'AliExpress',       'Online',      '10.1.1.1',      'DEV-006', 'Completed', 'Online Purchase'),
    (8,  'Transfer',   8000.00,   'GBP', '2025-03-15 09:45:00', NULL,               'Online',      '185.0.0.10',    'DEV-007', 'Completed', 'Inter-bank Transfer');
GO

-- 2.5 Insert Blacklist Entries
INSERT INTO Blacklist (EntityType, EntityValue, Reason, AddedBy, IsActive)
VALUES
    ('IPAddress',    '192.0.2.55',      'Associated with phishing campaigns',         'SecurityTeam', 1),
    ('DeviceID',     'DEV-BAD',         'Device linked to multiple fraud attempts',   'SecurityTeam', 1),
    ('MerchantName', 'SuspectMerchant', 'Merchant involved in money laundering',      'ComplianceTeam', 1),
    ('Account',      'ACC-1006',        'Account holder under fraud investigation',   'LegalTeam', 1),
    ('IPAddress',    '198.51.100.22',   'Known proxy/VPN used for fraud',             'SecurityTeam', 1);
GO

-- 2.6 Insert Fraud Alerts
INSERT INTO FraudAlerts (TransactionID, RuleID, AlertType, Severity, AlertMessage, IsResolved)
VALUES
    (2,  1, 'Large Transaction',        'High',     'Transfer of $15,000 exceeds threshold of $10,000',          0),
    (5,  6, 'Cross-Border High Value',  'Critical', 'International transfer of $50,000 flagged',                 0),
    (7,  3, 'Blacklist Match',          'Critical', 'Transaction involves blacklisted device DEV-BAD',           1),
    (9,  6, 'Cross-Border High Value',  'High',     'Transfer of GBP 75,000 exceeds international threshold',    0),
    (12, 2, 'Rapid Transactions',       'Medium',   '3 identical withdrawals in 6 minutes from same ATM',        0),
    (13, 2, 'Rapid Transactions',       'Medium',   'Continuation of rapid withdrawal pattern',                  0),
    (15, 1, 'Large Transaction',        'High',     'Transfer of $12,000 exceeds threshold of $10,000',          0),
    (17, 3, 'Blacklist Match',          'Critical', 'Payment to blacklisted merchant SuspectMerchant',           1);
GO

-- ============================================================
-- SECTION 3: VIEWS
-- ============================================================

-- View 1: All active fraud alerts with customer details
CREATE VIEW vw_ActiveFraudAlerts AS
SELECT
    fa.AlertID,
    fa.AlertType,
    fa.Severity,
    fa.AlertMessage,
    fa.CreatedAt AS AlertCreatedAt,
    t.TransactionID,
    t.Amount,
    t.TransactionType,
    t.Timestamp AS TransactionTime,
    t.Location,
    t.IPAddress,
    a.AccountNumber,
    c.FullName AS CustomerName,
    c.Email AS CustomerEmail
FROM FraudAlerts fa
JOIN Transactions t ON fa.TransactionID = t.TransactionID
JOIN Accounts     a ON t.AccountID      = a.AccountID
JOIN Customers    c ON a.CustomerID     = c.CustomerID
WHERE fa.IsResolved = 0;
GO

-- View 2: Customer transaction summary
CREATE VIEW vw_CustomerTransactionSummary AS
SELECT
    c.CustomerID,
    c.FullName,
    c.Email,
    a.AccountNumber,
    a.AccountType,
    COUNT(t.TransactionID)      AS TotalTransactions,
    SUM(t.Amount)               AS TotalAmount,
    AVG(t.Amount)               AS AvgTransactionAmount,
    MAX(t.Amount)               AS MaxTransaction,
    SUM(CASE WHEN t.Status = 'Flagged' THEN 1 ELSE 0 END) AS FlaggedCount
FROM Customers c
JOIN Accounts     a ON c.CustomerID = a.CustomerID
LEFT JOIN Transactions t ON a.AccountID = t.AccountID
GROUP BY c.CustomerID, c.FullName, c.Email, a.AccountNumber, a.AccountType;
GO

-- View 3: Blacklisted transactions
CREATE VIEW vw_BlacklistedTransactions AS
SELECT
    t.TransactionID,
    t.Amount,
    t.TransactionType,
    t.Timestamp,
    t.IPAddress,
    t.DeviceID,
    t.MerchantName,
    b.EntityType AS BlacklistType,
    b.EntityValue AS BlacklistedValue,
    b.Reason AS BlacklistReason,
    c.FullName AS CustomerName,
    a.AccountNumber
FROM Transactions t
JOIN Accounts  a ON t.AccountID   = a.AccountID
JOIN Customers c ON a.CustomerID  = c.CustomerID
JOIN Blacklist b ON (
    (b.EntityType = 'IPAddress'    AND b.EntityValue = t.IPAddress)   OR
    (b.EntityType = 'DeviceID'     AND b.EntityValue = t.DeviceID)    OR
    (b.EntityType = 'MerchantName' AND b.EntityValue = t.MerchantName)
)
WHERE b.IsActive = 1;
GO

-- View 4: Daily fraud statistics
CREATE VIEW vw_DailyFraudStats AS
SELECT
    CAST(t.Timestamp AS DATE)                                  AS TransactionDate,
    COUNT(t.TransactionID)                                     AS TotalTransactions,
    SUM(CASE WHEN t.Status = 'Flagged' THEN 1 ELSE 0 END)     AS FlaggedTransactions,
    SUM(CASE WHEN t.Status = 'Blocked' THEN 1 ELSE 0 END)     AS BlockedTransactions,
    SUM(t.Amount)                                              AS TotalAmount,
    SUM(CASE WHEN t.Status IN ('Flagged','Blocked') THEN t.Amount ELSE 0 END) AS SuspiciousAmount
FROM Transactions t
GROUP BY CAST(t.Timestamp AS DATE);
GO

-- ============================================================
-- SECTION 4: STORED PROCEDURES
-- ============================================================

-- Procedure 1: Get all transactions for a specific customer
CREATE PROCEDURE sp_GetCustomerTransactions
    @CustomerID INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        c.FullName,
        a.AccountNumber,
        t.TransactionID,
        t.TransactionType,
        t.Amount,
        t.Currency,
        t.Timestamp,
        t.MerchantName,
        t.Location,
        t.Status
    FROM Customers c
    JOIN Accounts     a ON c.CustomerID = a.CustomerID
    JOIN Transactions t ON a.AccountID  = t.AccountID
    WHERE c.CustomerID = @CustomerID
    ORDER BY t.Timestamp DESC;
END;
GO

-- Procedure 2: Flag a transaction manually
CREATE PROCEDURE sp_FlagTransaction
    @TransactionID INT,
    @Reason        VARCHAR(500),
    @FlaggedBy     VARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE Transactions
    SET Status = 'Flagged'
    WHERE TransactionID = @TransactionID;

    INSERT INTO FraudAlerts (TransactionID, AlertType, Severity, AlertMessage)
    VALUES (@TransactionID, 'Manual Flag', 'Medium', @Reason);

    INSERT INTO AuditLog (TableName, OperationType, RecordID, NewValue, ChangedBy)
    VALUES ('Transactions', 'UPDATE', @TransactionID,
            CONCAT('Status changed to Flagged. Reason: ', @Reason), @FlaggedBy);

    PRINT 'Transaction flagged and alert created successfully.';
END;
GO

-- Procedure 3: Resolve a fraud alert
CREATE PROCEDURE sp_ResolveFraudAlert
    @AlertID    INT,
    @ResolvedBy VARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE FraudAlerts
    SET IsResolved = 1,
        ResolvedBy = @ResolvedBy,
        ResolvedAt = GETDATE()
    WHERE AlertID = @AlertID;

    PRINT CONCAT('Alert ', @AlertID, ' resolved by ', @ResolvedBy);
END;
GO

-- Procedure 4: Add an entry to the blacklist
CREATE PROCEDURE sp_AddToBlacklist
    @EntityType  VARCHAR(30),
    @EntityValue VARCHAR(200),
    @Reason      VARCHAR(500),
    @AddedBy     VARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (
        SELECT 1 FROM Blacklist
        WHERE EntityType = @EntityType AND EntityValue = @EntityValue AND IsActive = 1
    )
    BEGIN
        PRINT 'Entry already exists in blacklist.';
        RETURN;
    END

    INSERT INTO Blacklist (EntityType, EntityValue, Reason, AddedBy)
    VALUES (@EntityType, @EntityValue, @Reason, @AddedBy);

    PRINT CONCAT(@EntityType, ' [', @EntityValue, '] added to blacklist.');
END;
GO

-- Procedure 5: Search transactions with multiple filters
CREATE PROCEDURE sp_SearchTransactions
    @MinAmount      DECIMAL(15,2) = NULL,
    @MaxAmount      DECIMAL(15,2) = NULL,
    @Status         VARCHAR(20)   = NULL,
    @StartDate      DATETIME      = NULL,
    @EndDate        DATETIME      = NULL,
    @Location       VARCHAR(100)  = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        t.TransactionID,
        c.FullName AS CustomerName,
        a.AccountNumber,
        t.TransactionType,
        t.Amount,
        t.Currency,
        t.Timestamp,
        t.Location,
        t.MerchantName,
        t.Status
    FROM Transactions t
    JOIN Accounts  a ON t.AccountID  = a.AccountID
    JOIN Customers c ON a.CustomerID = c.CustomerID
    WHERE
        (@MinAmount  IS NULL OR t.Amount    >= @MinAmount)
    AND (@MaxAmount  IS NULL OR t.Amount    <= @MaxAmount)
    AND (@Status     IS NULL OR t.Status     = @Status)
    AND (@StartDate  IS NULL OR t.Timestamp >= @StartDate)
    AND (@EndDate    IS NULL OR t.Timestamp <= @EndDate)
    AND (@Location   IS NULL OR t.Location LIKE '%' + @Location + '%')
    ORDER BY t.Timestamp DESC;
END;
GO

-- ============================================================
-- SECTION 5: USER-DEFINED FUNCTIONS
-- ============================================================

-- Function 1: Get fraud risk score for an account (returns 0-100)
CREATE FUNCTION fn_GetRiskScore (@AccountID INT)
RETURNS INT
AS
BEGIN
    DECLARE @Score INT = 0;
    DECLARE @FlaggedCount INT;
    DECLARE @LargeCount   INT;
    DECLARE @BlacklistHit INT;

    -- Flagged transactions in last 30 days
    SELECT @FlaggedCount = COUNT(*)
    FROM Transactions
    WHERE AccountID = @AccountID
      AND Status IN ('Flagged', 'Blocked')
      AND Timestamp >= DATEADD(DAY, -30, GETDATE());

    -- Large transactions in last 30 days
    SELECT @LargeCount = COUNT(*)
    FROM Transactions
    WHERE AccountID = @AccountID
      AND Amount > 10000
      AND Timestamp >= DATEADD(DAY, -30, GETDATE());

    -- Blacklist hits
    SELECT @BlacklistHit = COUNT(*)
    FROM Transactions t
    JOIN Blacklist b ON (
        (b.EntityType = 'IPAddress'    AND b.EntityValue = t.IPAddress) OR
        (b.EntityType = 'DeviceID'     AND b.EntityValue = t.DeviceID)  OR
        (b.EntityType = 'MerchantName' AND b.EntityValue = t.MerchantName)
    )
    WHERE t.AccountID = @AccountID AND b.IsActive = 1;

    SET @Score = (@FlaggedCount * 20) + (@LargeCount * 15) + (@BlacklistHit * 30);
    IF @Score > 100 SET @Score = 100;

    RETURN @Score;
END;
GO

-- Function 2: Count transactions in a time window (for rapid-transaction detection)
CREATE FUNCTION fn_CountRecentTransactions (
    @AccountID  INT,
    @Minutes    INT
)
RETURNS INT
AS
BEGIN
    DECLARE @Count INT;
    SELECT @Count = COUNT(*)
    FROM Transactions
    WHERE AccountID = @AccountID
      AND Timestamp >= DATEADD(MINUTE, -@Minutes, GETDATE());
    RETURN @Count;
END;
GO

-- Function 3: Get account status label (Inline TVF example)
CREATE FUNCTION fn_GetAccountDetails (@AccountID INT)
RETURNS TABLE
AS
RETURN (
    SELECT
        a.AccountID,
        a.AccountNumber,
        a.AccountType,
        a.Balance,
        a.Status,
        c.FullName,
        c.Email,
        dbo.fn_GetRiskScore(a.AccountID) AS RiskScore
    FROM Accounts  a
    JOIN Customers c ON a.CustomerID = c.CustomerID
    WHERE a.AccountID = @AccountID
);
GO

-- ============================================================
-- SECTION 6: TRIGGERS
-- ============================================================

-- Trigger 1: Auto-flag large transactions on INSERT
CREATE TRIGGER trg_FlagLargeTransaction
ON Transactions
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    -- Check if inserted transaction exceeds $10,000 threshold
    IF EXISTS (SELECT 1 FROM inserted WHERE Amount > 10000)
    BEGIN
        UPDATE Transactions
        SET Status = 'Flagged'
        WHERE TransactionID IN (SELECT TransactionID FROM inserted WHERE Amount > 10000)
          AND Status = 'Pending';

        -- Create alert for each large transaction
        INSERT INTO FraudAlerts (TransactionID, RuleID, AlertType, Severity, AlertMessage)
        SELECT
            i.TransactionID,
            1,  -- RuleID 1 = Large Transaction
            'Large Transaction',
            CASE
                WHEN i.Amount > 50000 THEN 'Critical'
                WHEN i.Amount > 20000 THEN 'High'
                ELSE 'Medium'
            END,
            CONCAT('Transaction amount $', i.Amount, ' exceeds threshold. Account: ',
                   i.AccountID, ' at ', i.Location)
        FROM inserted i
        WHERE i.Amount > 10000;
    END;
END;
GO

-- Trigger 2: Block transactions from blacklisted IPs or devices
CREATE TRIGGER trg_BlockBlacklistedTransaction
ON Transactions
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE Transactions
    SET Status = 'Blocked'
    WHERE TransactionID IN (
        SELECT i.TransactionID
        FROM inserted i
        WHERE EXISTS (
            SELECT 1 FROM Blacklist b
            WHERE b.IsActive = 1 AND (
                (b.EntityType = 'IPAddress'    AND b.EntityValue = i.IPAddress)   OR
                (b.EntityType = 'DeviceID'     AND b.EntityValue = i.DeviceID)    OR
                (b.EntityType = 'MerchantName' AND b.EntityValue = i.MerchantName)
            )
        )
    );

    INSERT INTO FraudAlerts (TransactionID, RuleID, AlertType, Severity, AlertMessage)
    SELECT
        i.TransactionID,
        3,  -- RuleID 3 = Blacklist Match
        'Blacklist Match',
        'Critical',
        CONCAT('Transaction blocked: entity matches blacklist. IP: ', i.IPAddress,
               ' | Device: ', i.DeviceID, ' | Merchant: ', ISNULL(i.MerchantName, 'N/A'))
    FROM inserted i
    WHERE EXISTS (
        SELECT 1 FROM Blacklist b
        WHERE b.IsActive = 1 AND (
            (b.EntityType = 'IPAddress'    AND b.EntityValue = i.IPAddress)   OR
            (b.EntityType = 'DeviceID'     AND b.EntityValue = i.DeviceID)    OR
            (b.EntityType = 'MerchantName' AND b.EntityValue = i.MerchantName)
        )
    );
END;
GO

-- Trigger 3: Audit log on Accounts UPDATE
CREATE TRIGGER trg_AuditAccountUpdate
ON Accounts
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO AuditLog (TableName, OperationType, RecordID, OldValue, NewValue)
    SELECT
        'Accounts',
        'UPDATE',
        i.AccountID,
        CONCAT('Balance=', d.Balance, ', Status=', d.Status),
        CONCAT('Balance=', i.Balance, ', Status=', i.Status)
    FROM inserted i
    JOIN deleted  d ON i.AccountID = d.AccountID;
END;
GO

-- Trigger 4: Prevent transactions on suspended/closed accounts
CREATE TRIGGER trg_BlockSuspendedAccount
ON Transactions
INSTEAD OF INSERT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @SuspendedCount INT;

    SELECT @SuspendedCount = COUNT(*)
    FROM inserted i
    JOIN Accounts a ON i.AccountID = a.AccountID
    WHERE a.Status IN ('Suspended', 'Closed');

    IF @SuspendedCount > 0
    BEGIN
        -- Still insert but mark as blocked
        INSERT INTO Transactions
            (AccountID, TransactionType, Amount, Currency, Timestamp,
             MerchantName, Location, IPAddress, DeviceID, Status, Description)
        SELECT
            i.AccountID, i.TransactionType, i.Amount, i.Currency,
            ISNULL(i.Timestamp, GETDATE()), i.MerchantName, i.Location,
            i.IPAddress, i.DeviceID,
            CASE
                WHEN a.Status IN ('Suspended','Closed') THEN 'Blocked'
                ELSE i.Status
            END,
            CONCAT(ISNULL(i.Description,''), ' [BLOCKED: Account is ', a.Status, ']')
        FROM inserted i
        JOIN Accounts a ON i.AccountID = a.AccountID;
    END
    ELSE
    BEGIN
        -- Normal insert path (also fires trg_FlagLargeTransaction & trg_BlockBlacklistedTransaction)
        INSERT INTO Transactions
            (AccountID, TransactionType, Amount, Currency, Timestamp,
             MerchantName, Location, IPAddress, DeviceID, Status, Description)
        SELECT
            AccountID, TransactionType, Amount, Currency,
            ISNULL(Timestamp, GETDATE()), MerchantName, Location,
            IPAddress, DeviceID, ISNULL(Status,'Pending'), Description
        FROM inserted;
    END;
END;
GO

-- ============================================================
-- SECTION 7: ADVANCED QUERIES (for explanation in presentation)
-- ============================================================

-- Query 1: INNER JOIN - Transactions with customer and account info
SELECT
    c.FullName,
    a.AccountNumber,
    a.AccountType,
    t.TransactionType,
    t.Amount,
    t.Status,
    t.Timestamp
FROM Transactions t
INNER JOIN Accounts  a ON t.AccountID  = a.AccountID
INNER JOIN Customers c ON a.CustomerID = c.CustomerID
ORDER BY t.Timestamp DESC;
GO

-- Query 2: LEFT JOIN - All customers including those with no transactions
SELECT
    c.FullName,
    c.Email,
    COUNT(t.TransactionID) AS TransactionCount,
    ISNULL(SUM(t.Amount), 0) AS TotalSpent
FROM Customers c
LEFT JOIN Accounts     a ON c.CustomerID = a.CustomerID
LEFT JOIN Transactions t ON a.AccountID  = t.AccountID
GROUP BY c.CustomerID, c.FullName, c.Email
ORDER BY TotalSpent DESC;
GO

-- Query 3: Subquery - Customers who have flagged transactions
SELECT FullName, Email
FROM Customers
WHERE CustomerID IN (
    SELECT DISTINCT a.CustomerID
    FROM Accounts a
    WHERE a.AccountID IN (
        SELECT AccountID FROM Transactions WHERE Status IN ('Flagged', 'Blocked')
    )
);
GO

-- Query 4: Subquery - Transactions above average amount
SELECT TransactionID, Amount, Status, Timestamp
FROM Transactions
WHERE Amount > (SELECT AVG(Amount) FROM Transactions)
ORDER BY Amount DESC;
GO

-- Query 5: Risk score for all accounts using function
SELECT
    a.AccountNumber,
    c.FullName,
    a.Balance,
    a.Status,
    dbo.fn_GetRiskScore(a.AccountID) AS RiskScore,
    CASE
        WHEN dbo.fn_GetRiskScore(a.AccountID) >= 70 THEN 'HIGH RISK'
        WHEN dbo.fn_GetRiskScore(a.AccountID) >= 40 THEN 'MEDIUM RISK'
        ELSE 'LOW RISK'
    END AS RiskCategory
FROM Accounts  a
JOIN Customers c ON a.CustomerID = c.CustomerID
ORDER BY RiskScore DESC;
GO

-- Query 6: Fraud alert summary by severity
SELECT
    Severity,
    COUNT(*) AS AlertCount,
    SUM(CASE WHEN IsResolved = 1 THEN 1 ELSE 0 END) AS Resolved,
    SUM(CASE WHEN IsResolved = 0 THEN 1 ELSE 0 END) AS Pending
FROM FraudAlerts
GROUP BY Severity
ORDER BY CASE Severity
    WHEN 'Critical' THEN 1
    WHEN 'High'     THEN 2
    WHEN 'Medium'   THEN 3
    WHEN 'Low'      THEN 4
END;
GO

-- Query 7: Rapid transactions detection (within 10 minutes)
SELECT
    t1.AccountID,
    c.FullName,
    COUNT(*) AS TransactionCount,
    MIN(t1.Timestamp) AS WindowStart,
    MAX(t1.Timestamp) AS WindowEnd
FROM Transactions t1
JOIN Transactions t2 ON t1.AccountID = t2.AccountID
    AND t2.Timestamp BETWEEN t1.Timestamp AND DATEADD(MINUTE, 10, t1.Timestamp)
    AND t1.TransactionID != t2.TransactionID
JOIN Accounts  a ON t1.AccountID  = a.AccountID
JOIN Customers c ON a.CustomerID  = c.CustomerID
GROUP BY t1.AccountID, c.FullName
HAVING COUNT(*) >= 2
ORDER BY TransactionCount DESC;
GO

-- Query 8: SELF JOIN - Accounts belonging to the same customer
SELECT
    c.FullName,
    a1.AccountNumber AS Account1,
    a1.AccountType   AS Type1,
    a2.AccountNumber AS Account2,
    a2.AccountType   AS Type2
FROM Accounts  a1
JOIN Accounts  a2 ON a1.CustomerID = a2.CustomerID AND a1.AccountID < a2.AccountID
JOIN Customers c  ON a1.CustomerID = c.CustomerID;
GO

-- ============================================================
-- SECTION 8: TEST STORED PROCEDURES AND FUNCTIONS
-- ============================================================

-- Test sp_GetCustomerTransactions
EXEC sp_GetCustomerTransactions @CustomerID = 1;

-- Test sp_SearchTransactions (flagged only)
EXEC sp_SearchTransactions @Status = 'Flagged';

-- Test sp_SearchTransactions (large amounts)
EXEC sp_SearchTransactions @MinAmount = 10000;

-- Test sp_ResolveFraudAlert
EXEC sp_ResolveFraudAlert @AlertID = 1, @ResolvedBy = 'Admin';

-- Test sp_AddToBlacklist
EXEC sp_AddToBlacklist
    @EntityType  = 'IPAddress',
    @EntityValue = '10.99.99.99',
    @Reason      = 'Linked to credential stuffing attack',
    @AddedBy     = 'SecurityTeam';

-- Test function
SELECT dbo.fn_GetRiskScore(4) AS RiskScore;
SELECT dbo.fn_CountRecentTransactions(10, 60) AS TxnIn60Mins;
SELECT * FROM dbo.fn_GetAccountDetails(4);

-- Test views
SELECT * FROM vw_ActiveFraudAlerts;
SELECT * FROM vw_CustomerTransactionSummary;
SELECT * FROM vw_BlacklistedTransactions;
SELECT * FROM vw_DailyFraudStats;
GO
