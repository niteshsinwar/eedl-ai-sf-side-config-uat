param(
    [string]$OrgAlias = "ISB-UAT-New"
)

$ErrorActionPreference = "Stop"

$ApiVersion = "v67.0"
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$RunStamp = Get-Date -Format "yyyyMMdd_HHmmss"
$OutputRoot = Join-Path $ScriptRoot "output\uat_eedl_edge_cases_$RunStamp"
$FileRoot = Join-Path $OutputRoot "files"

New-Item -ItemType Directory -Force -Path $FileRoot | Out-Null

$orgDisplay = sf org display --target-org $OrgAlias --json | ConvertFrom-Json
if ($orgDisplay.status -ne 0) {
    throw "Could not read org auth for $OrgAlias"
}

$instanceUrl = $orgDisplay.result.instanceUrl
$headers = @{
    Authorization = "Bearer $($orgDisplay.result.accessToken)"
    "Content-Type" = "application/json"
}

function Invoke-SfRest {
    param(
        [Parameter(Mandatory = $true)][string]$Method,
        [Parameter(Mandatory = $true)][string]$Path,
        [object]$Body = $null
    )

    $uri = "$instanceUrl/services/data/$ApiVersion/$Path"
    if ($null -eq $Body) {
        return Invoke-RestMethod -Method $Method -Uri $uri -Headers $headers
    }

    $json = $Body | ConvertTo-Json -Depth 20
    return Invoke-RestMethod -Method $Method -Uri $uri -Headers $headers -Body $json
}

function Invoke-SfQuery {
    param([Parameter(Mandatory = $true)][string]$Soql)
    $encoded = [System.Uri]::EscapeDataString($Soql)
    return Invoke-SfRest -Method "Get" -Path "query?q=$encoded"
}

function New-TestImage {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string[]]$Lines
    )

    Add-Type -AssemblyName System.Drawing
    $bitmap = New-Object System.Drawing.Bitmap 1800, 1200
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.Clear([System.Drawing.Color]::White)
    $graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit

    $titleFont = New-Object System.Drawing.Font("Arial", 38, [System.Drawing.FontStyle]::Bold)
    $bodyFont = New-Object System.Drawing.Font("Arial", 30, [System.Drawing.FontStyle]::Regular)
    $smallFont = New-Object System.Drawing.Font("Arial", 22, [System.Drawing.FontStyle]::Regular)
    $brush = [System.Drawing.Brushes]::Black

    try {
        $y = 55
        for ($i = 0; $i -lt $Lines.Count; $i++) {
            $font = if ($i -eq 0) { $titleFont } elseif ($Lines[$i].Length -gt 80) { $smallFont } else { $bodyFont }
            $graphics.DrawString($Lines[$i], $font, $brush, 70, $y)
            $y += if ($i -eq 0) { 62 } elseif ($Lines[$i].Length -gt 80) { 38 } else { 50 }
        }
        $bitmap.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
    }
    finally {
        $graphics.Dispose()
        $bitmap.Dispose()
        $titleFont.Dispose()
        $bodyFont.Dispose()
        $smallFont.Dispose()
    }
}

function New-CorruptPdf {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Label
    )

    $content = @"
%PDF-1.4
% UAT EEDL intentionally corrupt test file
1 0 obj
<< /Type /Catalog /Pages 2 0 R >>
endobj
$Label
%%EOF
"@
    [System.IO.File]::WriteAllText($Path, $content)
}

function Upload-ContentVersion {
    param(
        [Parameter(Mandatory = $true)][string]$OpportunityId,
        [Parameter(Mandatory = $true)][string]$Title,
        [Parameter(Mandatory = $true)][string]$FilePath
    )

    $bytes = [System.IO.File]::ReadAllBytes($FilePath)
    $body = @{
        Title = $Title
        PathOnClient = [System.IO.Path]::GetFileName($FilePath)
        VersionData = [System.Convert]::ToBase64String($bytes)
        FirstPublishLocationId = $OpportunityId
    }

    $created = Invoke-SfRest -Method "Post" -Path "sobjects/ContentVersion" -Body $body
    $version = Invoke-SfRest -Method "Get" -Path "sobjects/ContentVersion/$($created.id)?fields=Id,ContentDocumentId,Title,FileExtension,FirstPublishLocationId"
    return $version
}

$cases = @(
    @{
        caseKey = "EC01_AADHAAR_MATCH_BACHELOR"
        opportunityId = "006fs000001Tv5iAAC"
        educationId = "a09fs000000yQR4AAM"
        opportunity = @{ Name = "UAT EC01 Anika Rao"; APP_Citizeship__c = "India" }
        education = @{ Degree_Type__c = "Bachelors"; Degree_Level__c = "Bachelor's Degree"; University_Name__c = "Northstar University"; GPA__c = 8.6; From__c = "2018-07-01"; To__c = "2022-05-31" }
        files = @(
            @{ kind = "png"; title = "EC01_Aadhaar_card_match"; name = "EC01_Aadhaar_card_match.png"; lines = @("AADHAAR CARD", "Name: UAT EC01 Anika Rao", "Citizenship: India", "Nationality: Indian", "Aadhaar Number: 1111 2222 3333", "Date of Birth: 01 Jan 1999") },
            @{ kind = "png"; title = "EC01_bachelor_degree_certificate_match"; name = "EC01_bachelor_degree_certificate_match.png"; lines = @("BACHELOR DEGREE CERTIFICATE", "Student Name: UAT EC01 Anika Rao", "University: Northstar University", "Degree: Bachelors", "GPA: 8.6", "From: 2018-07-01", "To: 2022-05-31") }
        )
    },
    @{
        caseKey = "EC02_AADHAAR_BLANK_CITIZENSHIP"
        opportunityId = "006Ip000004Ad1IIAS"
        educationId = "a09Ip000001BpUTIA0"
        opportunity = @{ Name = "UAT EC02 Bharat Mehta"; APP_Citizeship__c = $null }
        education = @{ Degree_Type__c = "Bachelors"; Degree_Level__c = "Bachelor's Degree"; University_Name__c = "Deccan Institute"; GPA__c = 7.9; From__c = "2017-08-01"; To__c = "2021-05-30" }
        files = @(
            @{ kind = "png"; title = "EC02_Aadhaar_card_citizenship_missing_on_record"; name = "EC02_Aadhaar_card_citizenship_missing_on_record.png"; lines = @("AADHAAR CARD", "Name: UAT EC02 Bharat Mehta", "Citizenship: India", "Nationality: Indian", "Aadhaar Number: 2222 3333 4444", "Date of Birth: 12 Feb 1998") },
            @{ kind = "png"; title = "EC02_bachelor_degree_certificate_match"; name = "EC02_bachelor_degree_certificate_match.png"; lines = @("BACHELOR DEGREE CERTIFICATE", "Student Name: UAT EC02 Bharat Mehta", "University: Deccan Institute", "Degree: Bachelors", "GPA: 7.9", "From: 2017-08-01", "To: 2021-05-30") }
        )
    },
    @{
        caseKey = "EC03_AADHAAR_CITIZENSHIP_MISMATCH"
        opportunityId = "006fs000001VYo2AAG"
        educationId = "a09fs000001CRiLAAW"
        opportunity = @{ Name = "UAT EC03 Chitra Nair"; APP_Citizeship__c = "Outside India" }
        education = @{ Degree_Type__c = "Bachelors"; Degree_Level__c = "Bachelor's Degree"; University_Name__c = "Coastal Technical University"; GPA__c = 8.1; From__c = "2016-07-01"; To__c = "2020-05-31" }
        files = @(
            @{ kind = "png"; title = "EC03_Aadhaar_card_india_record_outside"; name = "EC03_Aadhaar_card_india_record_outside.png"; lines = @("AADHAAR CARD", "Name: UAT EC03 Chitra Nair", "Citizenship: India", "Nationality: Indian", "Aadhaar Number: 3333 4444 5555", "Date of Birth: 23 Mar 1997") },
            @{ kind = "png"; title = "EC03_bachelor_degree_certificate_match"; name = "EC03_bachelor_degree_certificate_match.png"; lines = @("BACHELOR DEGREE CERTIFICATE", "Student Name: UAT EC03 Chitra Nair", "University: Coastal Technical University", "Degree: Bachelors", "GPA: 8.1", "From: 2016-07-01", "To: 2020-05-31") }
        )
    },
    @{
        caseKey = "EC04_PASSPORT_OUTSIDE_INDIA_MATCH"
        opportunityId = "006Ip000004AdcJIAS"
        educationId = "a09fs000000BBxtAAG"
        opportunity = @{ Name = "UAT EC04 Daniel Smith"; APP_Citizeship__c = "Outside India" }
        education = @{ Degree_Type__c = "Masters"; Degree_Level__c = "Master's Degree"; University_Name__c = "Maple School of Business"; GPA__c = 3.7; From__c = "2019-09-01"; To__c = "2021-06-15" }
        files = @(
            @{ kind = "png"; title = "EC04_passport_outside_india_match"; name = "EC04_passport_outside_india_match.png"; lines = @("PASSPORT", "Name: UAT EC04 Daniel Smith", "Nationality: Canadian", "Citizenship: Canada", "Passport Number: C1234567", "Date of Birth: 04 Apr 1996") },
            @{ kind = "png"; title = "EC04_master_degree_certificate_match"; name = "EC04_master_degree_certificate_match.png"; lines = @("MASTER DEGREE CERTIFICATE", "Student Name: UAT EC04 Daniel Smith", "University: Maple School of Business", "Degree: Masters", "GPA: 3.7", "From: 2019-09-01", "To: 2021-06-15") }
        )
    },
    @{
        caseKey = "EC05_PASSPORT_INDIA_EDU_GPA_MISMATCH"
        opportunityId = "006fs000000Vbw9AAC"
        educationId = "a09fs0000006C3UAAU"
        opportunity = @{ Name = "UAT EC05 Esha Iyer"; APP_Citizeship__c = "India" }
        education = @{ Degree_Type__c = "Masters"; Degree_Level__c = "Master's Degree"; University_Name__c = "Riverbend University"; GPA__c = 8.8; From__c = "2020-08-01"; To__c = "2022-05-31" }
        files = @(
            @{ kind = "png"; title = "EC05_passport_india_match"; name = "EC05_passport_india_match.png"; lines = @("PASSPORT", "Name: UAT EC05 Esha Iyer", "Nationality: Indian", "Citizenship: India", "Passport Number: Z7654321", "Date of Birth: 15 May 1995") },
            @{ kind = "png"; title = "EC05_master_degree_certificate_gpa_mismatch"; name = "EC05_master_degree_certificate_gpa_mismatch.png"; lines = @("MASTER DEGREE CERTIFICATE", "Student Name: UAT EC05 Esha Iyer", "University: Riverbend University", "Degree: Masters", "GPA: 6.1", "From: 2020-08-01", "To: 2022-05-31") }
        )
    },
    @{
        caseKey = "EC06_INVALID_ID_DOCUMENT_TEXT"
        opportunityId = "006fs000000ifPFAAY"
        educationId = "a09fs000000C0kDAAS"
        opportunity = @{ Name = "UAT EC06 Farhan Ali"; APP_Citizeship__c = "India" }
        education = @{ Degree_Type__c = "Bachelors"; Degree_Level__c = "Bachelor's Degree"; University_Name__c = "Hillview College"; GPA__c = 7.4; From__c = "2015-07-01"; To__c = "2019-05-30" }
        files = @(
            @{ kind = "png"; title = "EC06_Aadhaar_card_invalid_notice"; name = "EC06_Aadhaar_card_invalid_notice.png"; lines = @("UPLOAD ERROR SCREENSHOT", "The selected file could not be previewed.", "No identity card, Aadhaar number, passport number, name, nationality, or date of birth appears on this document.", "This is intentionally not a valid identity document.") },
            @{ kind = "png"; title = "EC06_bachelor_degree_certificate_match"; name = "EC06_bachelor_degree_certificate_match.png"; lines = @("BACHELOR DEGREE CERTIFICATE", "Student Name: UAT EC06 Farhan Ali", "University: Hillview College", "Degree: Bachelors", "GPA: 7.4", "From: 2015-07-01", "To: 2019-05-30") }
        )
    },
    @{
        caseKey = "EC07_ID_NAME_MISMATCH"
        opportunityId = "006fs000000w7fSAAQ"
        educationId = "a09fs000000ByNZAA0"
        opportunity = @{ Name = "UAT EC07 Gita Menon"; APP_Citizeship__c = "India" }
        education = @{ Degree_Type__c = "Bachelors"; Degree_Level__c = "Bachelor's Degree"; University_Name__c = "Eastern Arts University"; GPA__c = 8.2; From__c = "2018-06-01"; To__c = "2022-04-30" }
        files = @(
            @{ kind = "png"; title = "EC07_Aadhaar_card_name_mismatch"; name = "EC07_Aadhaar_card_name_mismatch.png"; lines = @("AADHAAR CARD", "Name: UAT EC07 Wrong Person", "Citizenship: India", "Nationality: Indian", "Aadhaar Number: 7777 8888 9999", "Date of Birth: 07 Jul 1999") },
            @{ kind = "png"; title = "EC07_bachelor_degree_certificate_match"; name = "EC07_bachelor_degree_certificate_match.png"; lines = @("BACHELOR DEGREE CERTIFICATE", "Student Name: UAT EC07 Gita Menon", "University: Eastern Arts University", "Degree: Bachelors", "GPA: 8.2", "From: 2018-06-01", "To: 2022-04-30") }
        )
    },
    @{
        caseKey = "EC08_EDUCATION_FILE_NOT_MATCHED"
        opportunityId = "006fs000000jU1yAAE"
        educationId = "a09fs000000BgLhAAK"
        opportunity = @{ Name = "UAT EC08 Harish Rao"; APP_Citizeship__c = "India" }
        education = @{ Degree_Type__c = "Masters"; Degree_Level__c = "Master's Degree"; University_Name__c = "Western Management School"; GPA__c = 8.0; From__c = "2021-08-01"; To__c = "2023-05-31" }
        files = @(
            @{ kind = "png"; title = "EC08_Aadhaar_card_match"; name = "EC08_Aadhaar_card_match.png"; lines = @("AADHAAR CARD", "Name: UAT EC08 Harish Rao", "Citizenship: India", "Nationality: Indian", "Aadhaar Number: 8888 9999 0000", "Date of Birth: 08 Aug 1998") },
            @{ kind = "png"; title = "EC08_bachelor_certificate_wrong_keyword"; name = "EC08_bachelor_certificate_wrong_keyword.png"; lines = @("BACHELOR DEGREE CERTIFICATE", "Student Name: UAT EC08 Harish Rao", "University: Western Management School", "Degree: Masters", "GPA: 8.0", "From: 2021-08-01", "To: 2023-05-31", "Filename intentionally uses bachelor keyword while record degree is Masters.") }
        )
    },
    @{
        caseKey = "EC09_CORRUPT_ID_PDF"
        opportunityId = "006fs000001P018AAC"
        educationId = "a09Ip000001BpH5IAK"
        opportunity = @{ Name = "UAT EC09 Ira Kapoor"; APP_Citizeship__c = "India" }
        education = @{ Degree_Type__c = "Bachelors"; Degree_Level__c = "Bachelor's Degree"; University_Name__c = "Sunrise Engineering College"; GPA__c = 7.8; From__c = "2017-07-01"; To__c = "2021-05-31" }
        files = @(
            @{ kind = "corruptPdf"; title = "EC09_Aadhaar_card_corrupt_pdf"; name = "EC09_Aadhaar_card_corrupt_pdf.pdf"; label = "Corrupt Aadhaar PDF for extraction failure edge case." },
            @{ kind = "png"; title = "EC09_bachelor_degree_certificate_match"; name = "EC09_bachelor_degree_certificate_match.png"; lines = @("BACHELOR DEGREE CERTIFICATE", "Student Name: UAT EC09 Ira Kapoor", "University: Sunrise Engineering College", "Degree: Bachelors", "GPA: 7.8", "From: 2017-07-01", "To: 2021-05-31") }
        )
    },
    @{
        caseKey = "EC10_CORRUPT_EDUCATION_PDF"
        opportunityId = "006fs0000010NgpAAE"
        educationId = "a09Ip000001BHsfIAG"
        opportunity = @{ Name = "UAT EC10 Jai Sen"; APP_Citizeship__c = "India" }
        education = @{ Degree_Type__c = "Bachelors"; Degree_Level__c = "Bachelor's Degree"; University_Name__c = "Central Science College"; GPA__c = 8.4; From__c = "2018-07-01"; To__c = "2022-05-31" }
        files = @(
            @{ kind = "png"; title = "EC10_Aadhaar_card_match"; name = "EC10_Aadhaar_card_match.png"; lines = @("AADHAAR CARD", "Name: UAT EC10 Jai Sen", "Citizenship: India", "Nationality: Indian", "Aadhaar Number: 1010 2020 3030", "Date of Birth: 10 Oct 1999") },
            @{ kind = "corruptPdf"; title = "EC10_bachelor_degree_corrupt_pdf"; name = "EC10_bachelor_degree_corrupt_pdf.pdf"; label = "Corrupt bachelor education PDF for extraction failure edge case." }
        )
    }
)

$opportunityIds = ($cases | ForEach-Object { "'$($_.opportunityId)'" }) -join ","
$educationIds = ($cases | ForEach-Object { "'$($_.educationId)'" }) -join ","

$originalOpportunities = Invoke-SfQuery -Soql "SELECT Id, Name, StageName, RecordType.DeveloperName, ContactId, APP_Contact__c, APP_Citizeship__c, LastModifiedDate FROM Opportunity WHERE Id IN ($opportunityIds)"
$originalEducations = Invoke-SfQuery -Soql "SELECT Id, Name, Contact__c, Degree_Type__c, Degree_Level__c, Degree__c, University_Name__c, Name_of_the_University__c, GPA__c, From__c, To__c, LastModifiedDate FROM Education__c WHERE Id IN ($educationIds)"
$existingFiles = Invoke-SfQuery -Soql "SELECT LinkedEntityId, ContentDocumentId, ContentDocument.Title, ContentDocument.FileExtension, ContentDocument.LatestPublishedVersionId, SystemModstamp FROM ContentDocumentLink WHERE LinkedEntityId IN ($opportunityIds) ORDER BY LinkedEntityId, SystemModstamp DESC"

$uploadedFiles = @()

foreach ($case in $cases) {
    Write-Host "Seeding $($case.caseKey) on Opportunity $($case.opportunityId)"

    Invoke-SfRest -Method "Patch" -Path "sobjects/Opportunity/$($case.opportunityId)" -Body $case.opportunity | Out-Null
    Invoke-SfRest -Method "Patch" -Path "sobjects/Education__c/$($case.educationId)" -Body $case.education | Out-Null

    foreach ($file in $case.files) {
        $filePath = Join-Path $FileRoot $file.name

        if ($file.kind -eq "png") {
            New-TestImage -Path $filePath -Lines $file.lines
        }
        elseif ($file.kind -eq "corruptPdf") {
            New-CorruptPdf -Path $filePath -Label $file.label
        }
        else {
            throw "Unknown file kind $($file.kind)"
        }

        $uploaded = Upload-ContentVersion -OpportunityId $case.opportunityId -Title $file.title -FilePath $filePath
        $uploadedFiles += [pscustomobject]@{
            caseKey = $case.caseKey
            opportunityId = $case.opportunityId
            title = $uploaded.Title
            fileExtension = $uploaded.FileExtension
            contentVersionId = $uploaded.Id
            contentDocumentId = $uploaded.ContentDocumentId
            localPath = $filePath
        }
    }
}

$postOpportunities = Invoke-SfQuery -Soql "SELECT Id, Name, StageName, RecordType.DeveloperName, ContactId, APP_Contact__c, APP_Citizeship__c, LastModifiedDate FROM Opportunity WHERE Id IN ($opportunityIds)"
$postEducations = Invoke-SfQuery -Soql "SELECT Id, Name, Contact__c, Degree_Type__c, Degree_Level__c, Degree__c, University_Name__c, Name_of_the_University__c, GPA__c, From__c, To__c, LastModifiedDate FROM Education__c WHERE Id IN ($educationIds)"

$manifest = [pscustomobject]@{
    runStamp = $RunStamp
    orgAlias = $OrgAlias
    instanceUrl = $instanceUrl
    apiVersion = $ApiVersion
    cases = $cases
    originalOpportunities = $originalOpportunities.records
    originalEducations = $originalEducations.records
    preExistingFiles = $existingFiles.records
    uploadedFiles = $uploadedFiles
    postOpportunities = $postOpportunities.records
    postEducations = $postEducations.records
}

$manifestPath = Join-Path $OutputRoot "manifest.json"
$manifest | ConvertTo-Json -Depth 30 | Set-Content -Path $manifestPath -Encoding UTF8

Write-Host "Seed complete."
Write-Host "Manifest: $manifestPath"
Write-Host "Uploaded files: $($uploadedFiles.Count)"
