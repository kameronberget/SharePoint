#Add SP SnapIn
Add-PSSnapin Microsoft.SharePoint.Powershell


#Logging Function
function Log-ToFile {
    param($msg,[switch]$noNewLine, $foregroundColor = "White",$backgroundColor = "Black")

    if ($noNewLine) {

        Write-Host $msg -NoNewline -ForegroundColor $foregroundColor -BackgroundColor $backgroundColor

    } else {

        Write-Host $msg -ForegroundColor $foregroundColor -BackgroundColor $backgroundColor

    }

    $msg | Out-File -FilePath .\Export_OrgChartData_LOG_$logTime.txt -Append
}



###Define Date ###
[DateTime]$Date = [DateTime]::now
$logTime = $Date.ToUniversalTime().toString( "yyyy-MM-dd_hh-mm-ss" )

### Get SP Context ###
$siteUrl = "http://fwdpdesp02.mg.dev.lab"
$spSite = Get-SPSite $siteUrl
$context = [Microsoft.Office.Server.ServerContext]::GetContext($spSite)

### Define export folders ###
$exportPath = "c:\Users\spkm_installdev\Desktop"
$picPath = "c:\Users\spkm_installdev\Desktop\Pictures"
if (!(Test-Path $exportPath)) {Write-Error "Export path does not exist"; break}
if (!(Test-Path $picPath)) {Write-Error "Picture path does not exist"; break}

###Export Picture Settings###
$exportPictures = $true
if ($exportPictures -eq $true) {
    Read-Host "You will be prompted for credentials to download user profile images. Press enter to continue..."
    $creds = Get-Credential
}

### Get User Profile Manager ###
$upm = New-Object Microsoft.Office.Server.UserProfiles.UserProfileManager($context)

### Create empty data array ###
$orgChartData = @()

foreach ($p in $upm.GetEnumerator()) {
    if ($p["Manager"] -ne $null -and $p["Manager"] -ne "") {
            
        log-ToFile -msg "Exporting $($p["FirstName"]) $($p["LastName"])... " -NoNewline
        
        foreach ($m in $upm.GetEnumerator()) {
            if ($m["AccountName"] -eq $p["Manager"]) {
                $manager = $m.DisplayName
            }
        }  

        ### Get Picture URL if needed ###
        $pictureUrl = ""
        if ($p["PictureUrl"] -and $exportPictures -eq $true) {$pictureUrl = $p.AccountName.split("\")[1] + "_MThumb"}

        ### Build org chart data object ###
        $orgChartData += New-Object -TypeName PSObject -Property @{
            Name = $p.DisplayName;
            Reports_to = $manager;
            Title = $p["Title"].ToString();
            Department = $p["Department"].ToString();
            Telephone = $p["WorkPhone"];
            PicId = $pictureUrl;
        }

        log-ToFile "[Complete]" -backgroundColor Green -foregroundColor Black

        ### Export Picture ###
        if ($p["PictureUrl"] -and $exportPictures -eq $true) {
            write-host ""
            log-ToFile "Downloading $($p["PictureUrl"])" -noNewLine
            Start-BitsTransfer $p["PictureUrl"] -Destination $picPath -Credential $creds -Authentication Ntlm
            log-ToFile "[Complete]" -BackgroundColor Green -ForegroundColor Black
        }

    } else {

        log-ToFile "$($p.DisplayName) does not have a manager defined," -NoNewline
        log-ToFile " skipping... " -BackgroundColor Yellow -ForegroundColor Black
              
    }
}
$spSite.Dispose()
log-ToFile "Exporting file to $exportPath\SharePointOrgChart.csv..." -NoNewline
$orgChartData | Export-Csv -Path $exportPath\SharePointOrgChart.csv -NoTypeInformation
log-ToFile "[Complete]" -BackgroundColor Green -ForegroundColor Black
Read-Host "Press Enter to exit..."
