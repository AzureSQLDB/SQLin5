# Getting started with AI in SQL Server 2025 on Windows

This tutorial helps you get started using the new AI features of SQL Server 2025 on Windows/Windows Server.

## Prerequisites

- SQL Server 2025 Public Preview
- A database created with the adventureworks2025.bak backup file
- [SSMS](https://learn.microsoft.com/en-us/ssms/install/install) installed or VS Code with the MSSQL Extension
- Windows environment or Hyper-V Windows VM (Windows or [Windows Server](https://www.microsoft.com/evalcenter/download-windows-server-2025))
- Connection to the internet for software and utility downloads

## Set up your environment

The following section guides you through setting up the environment and installing the necessary software and utilities.

### Install Ollama

There are two ways to install Ollama.

#### Winget and PowerShell

Open up a PowerShell terminal

Enter the following command:

```text
winget install Ollama.Ollama
```

#### Direct Download

Download the executable file from the GitHub repository using the following link: [OllamaSetup.exe](https://github.com/ollama/ollama/releases/download/v0.5.13/OllamaSetup.exe)

Then double-click the `OllamaSetup.exe` file to install Ollama.

Once Ollama is installed, quit or stop it from either the task manager or in the system tray, right select Ollama and select **Quit Ollama**.

### Install nginx

To install **nginx**, use the following link to download it: [Download Nginx](https://nginx.org/en/download.html)

Under the heading **Stable version**, select `nginx/Windows-1.28.0` (the version on as of May 19, 2025) to start the download.

Copy the `nginx-1.28.0.zip` file to the `C:\` drive

Unzip the `nginx-1.28.0.zip` file here. In Windows, use the **Extract All...** option when right selecting on the file.

In the Extract Compressed File dialog, set the extraction directory to be `C:\`. If you leave the default, it will extract the files into a nested folder resulting in `C:\nginx-1.28.0\nginx-1.28.0`.

### Set up SSL for Ollama and nginx

The next step will create self-signed certificates that will be used for SSL in **nginx**.

To start, open a PowerShell terminal and create a certs directory with the following command:

```powershell
mkdir C:\certs
```

Next, using Notepad, copy the following text and save the file as createCert.ps1 in the C:\certs directory.

createCert.ps1

```powershell
param
(
    [parameter(Mandatory=$true)]
    [string]
    $DnsName,

    [parameter(Mandatory=$true)]
    [string]
    $Password,

    [parameter(Mandatory=$true)]
    [string]
    $FilePath
)

# Create a new self-signed certificate
$cert = New-SelfSignedCertificate -Subject $DnsName -DnsName $DnsName -FriendlyName "SQL Development"

# Export the certificate to a file
Export-PfxCertificate -Cert $cert -FilePath $FilePath -Password (ConvertTo-SecureString -String $Password -Force -AsPlainText)

# Import the certificate as trusted
Import-PfxCertificate -Certstorelocation Cert:\LocalMachine\Root -FilePath $FilePath -Password (ConvertTo-SecureString -String $Password -Force -AsPlainText)
```

Close Notepad after saving the file and go back to the PowerShell terminal.

Change the directory to the C:\certs directory

```powershell
cd C:\certs
```

Next, run the createCert.ps1 script with the following command:

```powershell
./createCert.ps1
```

Use the following values for the variables when running the createCert.ps1 script:

- For DnsName, use `localhost`
- For password, use a strong password that you have written down.
- For FilePath, use `C:\certs\cert.pfx`

The certificate is now created.

#### Install OpenSSL

OpenSSL needs to be installed next.

While in the PowerShell terminal, run the following command:

```powershell
winget install ShiningLight.OpenSSL.Light
```

#### Add OpenSSL to the PATH

Once installed, openssl needs to be added to the PATH environment variable.

##### Via PowerShell

Run the following command in the PowerShell terminal:

```powershell
$oldPath = [Environment]::GetEnvironmentVariable("Path", "User")
$newPath = $oldPath + ";C:\Program Files\OpenSSL-Win64\bin"
[Environment]::SetEnvironmentVariable("Path", $newPath, "User")
```

##### Via the Environment Variables modal window

Start by running the following command in the PowerShell terminal:

```powershell
rundll32 sysdm.cpl,EditEnvironmentVariables
```

In the **Environment Variables** modal window, look at the lower section named **System variables**.

Select the **Path** variable and then select the **Edit** button.

In the **Edit environment variable** modal window, start by selecting the **New** button.

Under the last line, you can enter text for the next variable. Use the following text:

```output
C:\Program Files\OpenSSL-Win64\bin
```

Then press the **OK** button to set the variable and close the modal window. Then, select **OK** to close the **Environment Variables** modal window.

#### Create the signed .crt and .key files for nginx

To use the new Path, run the following command in the PowerShell terminal:

```powershell
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
```

Ensure the directory is still set to C:\certs. Run the following command if unsure:

```powershell
cd C:\certs
```

Next, run the following command:

```powershell
openssl pkcs12 -in cert.pfx -nocerts -out cert.key -nodes
```

When asked to **"Enter Import Password"**, enter the strong password you wrote down previously. Then press the enter/return key.

Now, run the following command:

```powershell
openssl pkcs12 -in cert.pfx -clcerts -nokeys -out cert.crt
```

When asked to **"Enter Import Password"**, enter the strong password you wrote down previously. Then press the enter/return key.

#### Edit the nginx.conf file

Again in the PowerShell terminal, run the following command:

> [!NOTE]  
> The version number installed might be different than the one in this tutorial.

```powershell
cd C:\nginx-1.28.0\conf
```

Now, edit this file by opening it in Notepad using the following command in PowerShell:

```powershell
notepad nginx.conf
```

Replace **ALL** the text in the nginx.conf with the following:

```text
worker_processes auto;

events {
    worker_connections 1024;
}

http {

    upstream ollama {
        server localhost:11434;
    }

    server {
        listen 11435 ssl;
        server_name localhost;

  ssl_certificate      C:\certs\cert.crt;
        ssl_certificate_key  C:\certs\cert.key;
        ssl_protocols       TLSv1 TLSv1.1 TLSv1.2;
        ssl_ciphers         HIGH:!aNULL:!MD5;

location / {
            proxy_pass http://localhost:11434;
            proxy_http_version 1.1;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_set_header Origin '';
            proxy_set_header Referer '';
        }
    }
}
```

**Save the file**

After you have **Saved the nginx.conf file**, change the directory in PowerShell using the following command:

```powershell
cd C:\Windows\System32\drivers\etc
```

Edit the hosts file with Notepad using the following command:

```powershell
notepad hosts
```

After the last line in the file, add the following text:

```text
127.0.0.1 localhost
```

**Save the file**

After you have **Saved the hosts file**, it's time to start up the services.

### Start up the services

#### Ollama

Start by going to the top level of the C: Drive with the following command in PowerShell:

```powershell
Set-Location -Path "C:\"
```

Back in PowerShell, Ollama needs an embedding model locally. Use the following command to download that model:

```powershell
ollama pull nomic-embed-text
```

Pulling the model also start Ollama up. We want to stop it so we can start it in PowerShell to monitor the requests. Again stop Ollama from either the task manager or in the system tray, right-click Ollama and select **Quit Ollama**.

Once Ollama as stopped, start Ollama with the following command so that we can monitor it in PowerShell:

```powershell
ollama serve
```

#### Nginx

Open a new PowerShell terminal by **clicking the Plus Sign** on the PowerShell terminal tab area.

Change the directory to the nginx home directory using the following command in PowerShell:

> [!NOTE]  
> The version number installed might be different than the one in this tutorial.

```powershell
cd C:\nginx-1.28.0
```

To start nginx, run the following command in PowerShell:

```powershell
start nginx
```

### Test the Ollama embeddings endpoint

To test the endpoint, run the following command in PowerShell:

```powershell
Invoke-WebRequest -Uri "https://localhost:11435/api/embeddings" -ContentType "application/json" -Method POST -Body '{ "model":"nomic-embed-text", "prompt":"test text"}'
```

And the result should be similar to the following:

```output
StatusCode        : 200
StatusDescription : OK
Content           : {"model":"nomic-embed-text","embeddings":[0.021354584,-0.026753489,-0.16089542,-0.026369257,0.0828
                    7482,-0.03691292,0.022429287,-0.008543771,0.012165211,-0.02446957,-0.01350472,0.072527215,0.0365559
                    64...
RawContent        : HTTP/1.1 200 OK
                    Transfer-Encoding: chunked
                    Connection: keep-alive
                    Content-Type: application/json; charset=utf-8
                    Date: Fri, 07 Mar 2025 17:12:36 GMT
                    Server: nginx/1.28.0

                    {"model":"nomic-embed-t...
Forms             : {}
Headers           : {[Transfer-Encoding, chunked], [Connection, keep-alive], [Content-Type, application/json;
                    charset=utf-8], [Date, Fri, 07 Mar 2025 17:12:36 GMT]...}
Images            : {}
InputFields       : {}
Links             : {}
ParsedHtml        : System.__ComObject
RawContentLength  : 9634
```

If you look at the Ollama PowerShell tab, you see a line similar to the following:

```output
[GIN] 2025/03/07 - 09:12:36 | 200 |     27.8195ms |       127.0.0.1 | POST     "/api/embeddings"
```

## Set up the database

The following section guides you through using the embeddings model to create vector arrays on relation data and use the new vector similarity search functionality in SQL Server 2025.

### Create the EXTERNAL MODEL in the database

Using SSMS, login to the database using Windows credentials

Open a new query sheet using the **AdventureWorksLT2025 database**

Next, run the following SQL to enable REST communication from within the database:

```sql
-- Turn External REST Endpoint Invocation ON in the database
EXECUTE sp_configure 'external rest endpoint enabled', 1;
GO

RECONFIGURE WITH OVERRIDE;
GO
```

Now, run the following SQL to create an EXTERNAL MODEL that points to the Ollama embedding model that was downloaded:

```sql
CREATE EXTERNAL MODEL ollama
WITH (
      LOCATION = 'https://localhost:11435/api/embed',
      API_FORMAT = 'Ollama',
      MODEL_TYPE = EMBEDDINGS,
      MODEL = 'nomic-embed-text'
);
```

### Test the EXTERNAL MODEL

To test the embeddings endpoint, run the following SQL:

```sql
select AI_GENERATE_EMBEDDINGS(N'test text' MODEL ollama);
```

You should see a JSON vector array returned similar to the following:

```JSON-nocopy
[0.1529204398393631,0.4368368685245514,-3.6136839389801025,-0.7697131633758545...
```

Watch Ollama in the PowerShell terminal where you started it to see any errors or successes.

### Embed Product Data

This next section of the tutorial will alter the Adventure Works product table to add a new vector data type column.

Run the following SQL to add the columns to the Product table:

```sql
ALTER TABLE [SalesLT].[Product]
    ADD embeddings VECTOR (768),
        chunk NVARCHAR (2000);
```

Next, we are going to use the EXTERNAL MODEL and AI_GENERATE_EMBEDDINGS to create embeddings for text we supply as an input.

Run the following code to create the embeddings:

```sql
-- create the embeddings
SET NOCOUNT ON;

DROP TABLE IF EXISTS #MYTEMP;

DECLARE @ProductID int
DECLARE @text NVARCHAR (MAX);

SELECT * INTO #MYTEMP FROM [SalesLT].Product WHERE embeddings IS NULL;

SELECT @ProductID = ProductID FROM #MYTEMP;

SELECT TOP(1) @ProductID = ProductID FROM #MYTEMP;

WHILE @@ROWCOUNT <> 0
BEGIN
    SET @text = (
        SELECT p.Name + ' ' + ISNULL(p.Color, 'No Color') + ' ' + c.Name + ' ' + m.Name + ' ' + ISNULL(d.Description, '')
        FROM [SalesLT].[ProductCategory] c,
             [SalesLT].[ProductModel] m,
             [SalesLT].[Product] p
        LEFT OUTER JOIN [SalesLT].[vProductAndDescription] d
             ON p.ProductID = d.ProductID
             AND d.Culture = 'en'
        WHERE p.ProductCategoryID = c.ProductCategoryID
        AND p.ProductModelID = m.ProductModelID
        AND p.ProductID = @ProductID
    );
    UPDATE [SalesLT].[Product] SET [embeddings] = AI_GENERATE_EMBEDDINGS(@text MODEL ollama), [chunk] = @text WHERE ProductID = @ProductID;

    DELETE FROM #MYTEMP WHERE ProductID = @ProductID;

    SELECT TOP(1) @ProductID = ProductID FROM #MYTEMP;
END
```

Use the following query to see if any embeddings were missed:

```sql
SELECT *
FROM SalesLT.Product
WHERE embeddings IS NULL;
```

And use this query to see a sample of the new columns and the data within:

```sql
SELECT TOP 10 chunk,
              embeddings
FROM SalesLT.Product;
```

## Use VECTOR_DISTANCE and VECTOR_SEARCH

Vector similarity searching is a technique used to find and retrieve data points that are similar to a given query, based on their vector representations. The similarity between two vectors is measured using a distance metric, such as cosine similarity or Euclidean distance. These metrics quantify the similarity between two vectors by calculating the angle between them or the distance between their coordinates in the vector space.

Vector similarity searching has numerous applications, such as recommendation systems, search engines, image and video retrieval, and natural language processing tasks. It allows for efficient and accurate retrieval of similar items, enabling users to find relevant information or discover related items quickly and effectively.

This section of the tutorial will be using the new functions VECTOR_DISTANCE and VECTOR_SEARCH. It will also be creating a new DiskANN Vector Index for the VECTOR_SEARCH ANN similarity searches.

### VECTOR_DISTANCE

Uses K-Nearest Neighbors or KNN

Use the following SQL to run similarity searches using VECTOR_DISTANCE.

```sql
declare @search_text nvarchar(max) = 'I am looking for a red bike and I dont want to spend a lot'
declare @search_vector vector(768) = AI_GENERATE_EMBEDDINGS(@search_text MODEL ollama);
SELECT TOP(4)
p.ProductID, p.Name , p.chunk,
vector_distance('cosine', @search_vector, p.embeddings) AS distance
FROM [SalesLT].[Product] p
ORDER BY distance;
```

```sql
declare @search_text nvarchar(max) = 'I am looking for a safe helmet that does not weigh much'
declare @search_vector vector(768) = AI_GENERATE_EMBEDDINGS(@search_text MODEL ollama);
SELECT TOP(4)
p.ProductID, p.Name , p.chunk,
vector_distance('cosine', @search_vector, p.embeddings) AS distance
FROM [SalesLT].[Product] p
ORDER BY distance;
```

```sql
declare @search_text nvarchar(max) = 'Do you sell any padded seats that are good on trails?'
declare @search_vector vector(768) = AI_GENERATE_EMBEDDINGS(@search_text MODEL ollama);
SELECT TOP(4)
p.ProductID, p.Name , p.chunk,
vector_distance('cosine', @search_vector, p.embeddings) AS distance
FROM [SalesLT].[Product] p
ORDER BY distance;
```

### VECTOR_SEARCH

Uses Approximate Nearest Neighbors or ANN

Use the following SQL to run similarity searches using VECTOR_SEARCH and the DiskANN Vector Index.

First, run the following SQL to prepare the database to use the new features:

```sql
-- Enable trace flags for vector features
DBCC TRACEON (466, 474, 13981, -1);
GO
```

```sql
-- Check trace flags status
DBCC TRACESTATUS;
GO
```

Now, create the DiskANN indexes on the embeddings column in the Product table.

```sql
CREATE VECTOR INDEX vec_idx ON [SalesLT].[Product]([embeddings])
WITH (METRIC = 'cosine', TYPE = 'diskann', MAXDOP = 8);
GO

SELECT * FROM sys.indexes WHERE type = 8;
GO
```

Use the following SQL to run the similarity search using both VECTOR_SEARCH and the DiskANN Index:

```sql
-- ANN Search
DECLARE @search_text NVARCHAR (MAX) = 'Do you sell any padded seats that are good on trails?';
DECLARE @search_vector VECTOR (768) = AI_GENERATE_EMBEDDINGS(@search_text MODEL ollama);
SELECT t.chunk,
       s.distance
FROM vector_search(
        table = [SalesLT].[Product] as t,
        column = [embeddings],
        similar_to = @search_vector,
        metric = 'cosine',
        top_n = 10
    ) as s
ORDER BY s.distance;
GO
```

## Chunk with embeddings

This section uses the `AI_GENERATE_CHUNKS` function with `AI_GENERATE_EMBEDDINGS` to simulate breaking a large section of text into smaller set sized chunks to be embedded.

First, create a table to hold the text:

```sql
CREATE TABLE textchunk
(
    text_id INT IDENTITY (1, 1) PRIMARY KEY,
    text_to_chunk NVARCHAR (MAX)
);
GO
```

Next, insert the text into the table:

```sql
INSERT INTO textchunk (text_to_chunk)
VALUES ('All day long we seemed to dawdle through a country which was full of beauty of every kind. Sometimes we saw little towns or castles on the top of steep hills such as we see in old missals; sometimes we ran by rivers and streams which seemed from the wide stony margin on each side of them to be subject to great floods.'),
       ('My Friend, Welcome to the Carpathians. I am anxiously expecting you. Sleep well to-night. At three to-morrow the diligence will start for Bukovina; a place on it is kept for you. At the Borgo Pass my carriage will await you and will bring you to me. I trust that your journey from London has been a happy one, and that you will enjoy your stay in my beautiful land. Your friend, DRACULA');
GO
```

Finally, create chunks of text to be embedded using both functions:

```sql
SELECT c.*, AI_GENERATE_EMBEDDINGS(c.chunk MODEL model_name)
FROM textchunk t
CROSS APPLY
   AI_GENERATE_CHUNKS(source = text_to_chunk, chunk_type = N'FIXED', chunk_size = 50, overlap = 10) c
```

## XEvents for embeddings and REST

The following SQL creates an XEvent session for debugging REST calls from the database

```sql
CREATE EVENT SESSION [rest] ON SERVER
ADD EVENT sqlserver.external_rest_endpoint_summary,
ADD EVENT sqlserver.ai_generate_embeddings_summary
WITH
(
    MAX_MEMORY = 4096 KB,
    EVENT_RETENTION_MODE = ALLOW_SINGLE_EVENT_LOSS,
    MAX_DISPATCH_LATENCY = 30 SECONDS,
    MAX_EVENT_SIZE = 0 KB,
    MEMORY_PARTITION_MODE = NONE,
    TRACK_CAUSALITY = OFF,
    STARTUP_STATE = OFF
);
GO
```

