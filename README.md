# FailSafe IT - Databas

Relationsdatabas för konsultbolaget FailSafe IT som hanterar kunder, konsulter och uppdrag.
Byggd för Microsoft SQL Server.

## Innehåll
- `FailSafeDB.sql` - skapar databasen, tabellerna, testdata och frågorna A-E
- `ER DIAGRAM.png` - ER-diagram skapat i Lucidchart

## ER-diagram
![ER-diagram](ER%20DIAGRAM.png)

**Relationer (1:M):**
- En specialitet kan ha många konsulter (`Specialty` -> `Consultant`)
- En konsult kan ha många uppdrag (`Consultant` -> `Assignment`)
- En kund kan ha många uppdrag (`CustomerCompany` -> `Assignment`)

Sambandet M:N mellan kunder och konsulter är upplöst genom tabellen `Assignment`.
Den har ett eget `Id`, eftersom samma konsult kan ha flera uppdrag hos samma kund vid olika tidpunkter,
och eftersom varje uppdrag har egna uppgifter (rollbeskrivning, startdatum och slutdatum).

## Normalisering (3NF)

**1NF:** Varje kolumn innehåller ett enda värde, till exempel ett telefonnummer per kund.
Det finns inga upprepade kolumner som `Specialty1` och `Specialty2`, och varje tabell har en primärnyckel.

**2NF:** Alla tabeller har en primärnyckel med bara en kolumn (`Id`).
Därför kan ingen kolumn bero på bara en del av nyckeln, och 2NF uppfylls automatiskt.

**3NF:** Inga kolumner beror på andra kolumner som inte är nycklar.
Varje kolumn beskriver bara sin egen tabells nyckel. Specialiteten ligger i en egen tabell
`Specialty` i stället för som text i `Consultant`. Annars hade specialitetens namn berott på
specialiteten och inte på konsulten, ett så kallat transitivt beroende, och samma namn hade
upprepats och kunnat stavas olika. På samma sätt lagrar `Assignment` bara främmande nycklar
till kund och konsult, inte deras namn. Namnen hämtas med `JOIN`.

## DevSecOps-reflektion

**Sec - SQL injection:**
Applikationen ska alltid använda parametriserade frågor, till exempel `SqlParameter` eller
Entity Framework, i stället för att bygga SQL-strängar av användarens inmatning.
Då behandlas inmatningen som data och aldrig som kod. Dessutom ska applikationens
databasanvändare bara ha de rättigheter den behöver (principen om minsta behörighet),
så att den till exempel inte kan köra `DROP TABLE` även om en attack skulle lyckas.

**Ops - Prestanda vid stora datamängder:**
Index bör läggas på de kolumner som ofta används för sökningar och JOINs. `OrgNr` har redan
ett unikt index, eftersom SQL Server skapar ett automatiskt för `UNIQUE`-regeln. Därför går
sökningar på organisationsnummer snabbt även med miljontals rader, utan att hela tabellen
behöver läsas igenom. Främmande nycklar som `Assignment.CustomerCompanyId` och
`Assignment.ConsultantId` får inget index automatiskt och bör indexeras manuellt.
