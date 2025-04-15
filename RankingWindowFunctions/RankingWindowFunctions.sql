
-- table create

CREATE TABLE FrequentFlyers (  
    PassengerID INT IDENTITY(1,1) PRIMARY KEY,  
    PassengerName VARCHAR(100) NOT NULL,  
    MembershipTier VARCHAR(10) NOT NULL,  
    TotalMilesFlown INT NOT NULL,  
    FlightsTaken INT NOT NULL  
);
 
-- table data

INSERT INTO FrequentFlyers (PassengerName, MembershipTier, TotalMilesFlown, FlightsTaken)  
VALUES  
    ('Alice',   'Silver',   35000, 15),  
    ('Bob',     'Silver',   42000, 17),  
    ('Carol',   'Silver',   18000, 10),
    ('Johnny',   'Silver',   18000, 12), 
    ('Mary',    'Gold',     75000, 32),  
    ('John',    'Gold',     90000, 40),  
    ('Susan',   'Gold',     62000, 25),
    ('Will', 'Platinum', 120000, 45),  
    ('Jen', 'Platinum', 150000, 66),  
    ('Charles', 'Platinum', 150000, 60),  
    ('David',   'Platinum', 170000, 65);

-- Ranking Window Functions

-- ROW_NUMBER

SELECT  
    PassengerID,  
    PassengerName,  
    MembershipTier,  
    TotalMilesFlown,  
    ROW_NUMBER() OVER (ORDER BY TotalMilesFlown DESC) AS RowNum  
FROM FrequentFlyers;

-- RANK

SELECT  
    PassengerID,  
    PassengerName,  
    MembershipTier,  
    TotalMilesFlown,  
    RANK() OVER (  
        PARTITION BY MembershipTier  
        ORDER BY TotalMilesFlown DESC  
    ) AS TierRank  
FROM FrequentFlyers;

-- DENSE_RANK

SELECT  
    PassengerID,  
    PassengerName,  
    MembershipTier,  
    TotalMilesFlown,  
    DENSE_RANK() OVER (  
        PARTITION BY MembershipTier  
        ORDER BY TotalMilesFlown DESC  
    ) AS DenseTierRank  
FROM FrequentFlyers;  

-- tie breaker

SELECT  
    PassengerID,  
    PassengerName,  
    MembershipTier,
	FlightsTaken, 
    TotalMilesFlown,  
    DENSE_RANK() OVER (  
        PARTITION BY MembershipTier  
        ORDER BY TotalMilesFlown DESC, FlightsTaken desc
    ) AS DenseTierRank  
FROM FrequentFlyers; 

-- NTILE

SELECT  
    PassengerID,  
    PassengerName,  
    MembershipTier,  
    TotalMilesFlown,  
    NTILE(4) OVER (ORDER BY TotalMilesFlown DESC) AS Quartile  
FROM FrequentFlyers;  

-- Extra Credit: ROW_NUMBER with a CTE

WITH RankedFlyers AS (  
    SELECT  
        PassengerID,  
        PassengerName,  
        MembershipTier,  
        TotalMilesFlown,  
        FlightsTaken,  
        ROW_NUMBER() OVER (  
            PARTITION BY MembershipTier  
            ORDER BY TotalMilesFlown DESC  
        ) AS RowNumWithinTier  
    FROM FrequentFlyers  
)  
SELECT *  
FROM RankedFlyers  
WHERE RowNumWithinTier <= 3;
