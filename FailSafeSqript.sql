USE master;
GO
IF EXISTS (SELECT * FROM sys.databases WHERE name = 'FailSafeDB')
BEGIN
    ALTER DATABASE FailSafeDB SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE FailSafeDB;
END
GO
CREATE DATABASE FailSafeDB;
GO
USE FailSafeDB;
GO

CREATE TABLE CustomerCompany (
    Id INT PRIMARY KEY IDENTITY(1,1),
    CompanyName NVARCHAR(100) NOT NULL,
    OrgNr VARCHAR(12) NOT NULL UNIQUE,
    Email NVARCHAR(100) NOT NULL,
    Phone VARCHAR(20) NOT NULL
);

CREATE TABLE Specialty (
    Id INT PRIMARY KEY IDENTITY(1,1),
    SpecialtyDesc NVARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE Consultant (
    Id INT PRIMARY KEY IDENTITY(1,1),
    [Name] NVARCHAR(100) NOT NULL,
    PersonalNumber VARCHAR(12) NOT NULL UNIQUE,
    HourlyRate DECIMAL(10,2) NOT NULL,
    SpecialtyId INT NOT NULL,
    CONSTRAINT FK_Consultant_Specialty FOREIGN KEY (SpecialtyId) REFERENCES Specialty(Id),
    CONSTRAINT CK_Consultant_HourlyRate CHECK (HourlyRate > 0)
);

CREATE TABLE Assignment (
    Id INT PRIMARY KEY IDENTITY(1,1),
    ConsultantId INT NOT NULL,
    CustomerCompanyId INT NOT NULL,
    RoleDescription NVARCHAR(200) NOT NULL,
    StartDate DATE NOT NULL,
    EndDate DATE NOT NULL,
    CONSTRAINT FK_Assignment_Consultant FOREIGN KEY (ConsultantId) REFERENCES Consultant(Id),
    CONSTRAINT FK_Assignment_CustomerCompany FOREIGN KEY (CustomerCompanyId) REFERENCES CustomerCompany(Id),
    CONSTRAINT CK_Assignment_Dates CHECK (EndDate >= StartDate)
);


-- 1. Specialiteter (först, eftersom Consultant pekar hit)
INSERT INTO Specialty (SpecialtyDesc)
VALUES
    ('Cybersecurity'),
    ('DevOps'),
    ('C# Developer'),
    ('Cloud Architect');

-- 2. Kunder
INSERT INTO CustomerCompany (CompanyName, OrgNr, Email, Phone)
VALUES
    ('Nordbank AB',          '556123-4567', 'it@nordbank.example.se',     '08-123 456 70'),
    ('Fjällhandel Sverige AB','556234-5678', 'kontakt@fjallhandel.example.se', '031-765 43 21'),
    ('MedTech Lund AB',      '556345-6789', 'info@medtechlund.example.se', '046-222 33 44');

-- 3. Konsulter (SpecialtyId: 1 = Cybersecurity, 2 = DevOps, 3 = C# Developer, 4 = Cloud Architect)
INSERT INTO Consultant ([Name], PersonalNumber, HourlyRate, SpecialtyId)
VALUES
    ('Anna Lindqvist',  '198503121234', 1250.00, 1),
    ('Erik Johansson',  '199007234321', 1100.00, 2),
    ('Sara Nilsson',    '199211055678', 950.00,  3),
    ('Mohammed Karimi', '198801308765', 1400.00, 4);

-- 4. Uppdrag (sist, eftersom det pekar på både Consultant och CustomerCompany)
INSERT INTO Assignment (ConsultantId, CustomerCompanyId, RoleDescription, StartDate, EndDate)
VALUES
    (1, 1, 'Säkerhetsgranskning av API-miljö',              '2026-01-12', '2026-03-31'),
    (2, 1, 'Uppsättning av CI/CD-pipeline i Azure DevOps',  '2026-02-01', '2026-06-30'),
    (3, 2, 'Vidareutveckling av webbshop i ASP.NET Core',   '2026-03-02', '2026-08-28'),
    (4, 3, 'Migrering av journalsystem till molnet',        '2026-04-06', '2026-12-18'),
    (1, 3, 'Penetrationstest av patientportal',             '2026-09-01', '2026-10-15'),
    (3, 1, 'Felsökning och optimering av internt C#-system','2026-10-05', '2026-11-27');
GO

INSERT INTO CustomerCompany (CompanyName, OrgNr, Email, Phone)
VALUES ('Tom Kund AB', '556999-0000', 'info@tomkund.example.se', '08-000 00 00');

--Fråga A: Lista namn och timpris på alla konsulter som har ett timpris högre än 1200 kr, sorterat efter pris (högst först).
Select [Name], HourlyRate FROM Consultant Where HourlyRate > 1200 ORDER BY HourlyRate DESC;

--Fråga B: Visa en sammanställning över alla uppdrag.
--Listan måste innehålla kundens företagsnamn, konsultens namn, samt start- och slutdatum för uppdraget.
Select c.CompanyName, cs.[Name], a.StartDate, a.EndDate
From Assignment a
Join CustomerCompany c on a.CustomerCompanyId = c.Id
Join Consultant cs on a.ConsultantId = cs.Id

--Fråga C: Visa en lista på alla kunder och hur många uppdrag respektive kund har aktiva i systemet totalt (Tips: Använd COUNT och GROUP BY).
SELECT c.CompanyName, c.OrgNr,Count(a.Id) as Antal
FROM CustomerCompany c
LEFT Join Assignment a on a.CustomerCompanyId = c.Id
Group By c.OrgNr, c.CompanyName
ORDER BY Antal DESC;


--AKTIVA
SELECT c.CompanyName, c.OrgNr, COUNT(a.Id) AS Antal
FROM CustomerCompany c
LEFT JOIN Assignment a
    ON a.CustomerCompanyId = c.Id
   AND a.StartDate <= CAST(GETDATE() AS DATE)
   AND a.EndDate   >= CAST(GETDATE() AS DATE)
GROUP BY c.OrgNr, c.CompanyName
ORDER BY Antal DESC;

--Fråga D: Uppdatera timpriset för en specifik konsult genom en UPDATE-fråga.
SELECT [Name], HourlyRate FROM Consultant WHERE Id = 1;   -- Före: 1250.00

UPDATE Consultant SET HourlyRate = 1000
WHERE Id = 1;

SELECT [Name], HourlyRate FROM Consultant WHERE Id = 1;   -- Efter: 1000.00

--Fråga E: Skriv en DELETE-fråga som tar bort en kund (förutsatt att kunden inte har några aktiva uppdrag kopplade till sig). 
-- Den främmande nyckeln FK_Assignment_CustomerCompany har ingen ON DELETE-regel, alltså NO ACTION.
-- SQL Server stoppar därför borttagning av en kund som har uppdrag, även avslutade.
-- NOT EXISTS gör att frågan inte gör något i stället för att ge ett fel.
SELECT * FROM CustomerCompany WHERE OrgNr = '556999-0000';   -- Före: 1 rad

DELETE FROM CustomerCompany
WHERE OrgNr = '556999-0000'
  AND NOT EXISTS (SELECT 1 FROM Assignment a WHERE a.CustomerCompanyId = CustomerCompany.Id);

SELECT * FROM CustomerCompany WHERE OrgNr = '556999-0000';   -- Efter: 0 rader

  -- Variant 2: tar bort kunden om den inte har pågående eller kommande uppdrag.
-- Avslutade uppdrag måste tas bort först, eftersom den främmande nyckeln annars stoppar borttagningen.

DECLARE @CustomerId INT = (SELECT Id FROM CustomerCompany WHERE OrgNr = '556234-5678');

SELECT * FROM CustomerCompany WHERE OrgNr = '556234-5678';
SELECT * FROM Assignment WHERE CustomerCompanyId = @CustomerId;

IF NOT EXISTS (SELECT 1 FROM Assignment
               WHERE CustomerCompanyId = @CustomerId
                 AND EndDate >= CAST(GETDATE() AS DATE))
BEGIN
    BEGIN TRANSACTION;
        DELETE FROM Assignment      WHERE CustomerCompanyId = @CustomerId;
        DELETE FROM CustomerCompany WHERE Id = @CustomerId;
    COMMIT;
END
ELSE
    PRINT 'Kunden har aktiva eller kommande uppdrag och kan inte tas bort.';
SELECT * FROM CustomerCompany WHERE OrgNr = '556234-5678';
SELECT * FROM Assignment WHERE CustomerCompanyId = @CustomerId;


SELECT * FROM CustomerCompany;
SELECT * FROM Assignment;
SELECT * FROM Consultant