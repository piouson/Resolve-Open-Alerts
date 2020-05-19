function New-APITokenNotFoundError {
    [string]$componentError = "API Token NOT found!`n" +
        "Please save API Token on device with command below " +
        "before rerunning component...`n" +
        "[Environment]::SetEnvironmentVariable('RMMAPIKey'," +
        "'enter-api-token-here','Machine')`n" +
        "RMM APIv2 Doc: https://help.aem.autotask.net/en/Content/2SETUP/APIv2.htm`n" +
        "Exiting..."
    return $componentError
}

function New-InvalidPlatformError {
    [string]$componentError = "Could not determine RMM Platform!`nExiting..."
    return $componentError
}

function New-AlertsNotFoundError {
    [string]$componentError = "No Open Alerts found!`nExiting..."
    return $componentError
}

function Test-ApiToken {
    [bool]$isApiKeySaved = Test-Path Env:RMMAPIKey
	return $isApiKeySaved
}

function Test-RMMPlatform {
    [bool]$isPlatformDetected = Test-Path Env:CS_WS_ADDRESS
    return $isPlatformDetected
}

function Get-RMMPlatform {
    [string]$platform = ($Env:CS_WS_ADDRESS -split '-')[0]
    return $platform
}

function Get-ApiUrl {
    $platform = Get-RMMPlatform
    [string]$apiUri = "https://{0}-api.centrastage.net/api/v2/" -f $platform
    return $apiUri
}

function Get-ApiAlertUrl {
    $alertPath = "/alerts/open"

    if ($Env:Target -eq "site") {
        $alertPath = "/{0}{1}" -f $Env:SiteID, $alertPath
    }
    [string]$alertApiUri = "{0}{1}{2}" -f (Get-ApiUrl), $Env:Target, $alertPath
    return $alertApiUri
}

function Get-ApiHeader {
    $token = "Bearer {0}" -f $Env:RMMAPIKey
    [hashtable]$header = @{Authorization = $token}
    return $header
}

function Invoke-RMMApi {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$Uri,
        [Parameter(Mandatory=$false)]
        [string]$Method
    )

    if ($Method -eq "") {
        $Method = "GET"
    }

    try {
        $queryResults = Invoke-WebRequest -Uri $Uri -Headers (Get-ApiHeader) `
                -Method $Method -UseBasicParsing
    } catch {
        Write-Verbose (" Url: {0}" -f $Uri)
        Write-Error $_.Exception -ErrorAction Stop
    }
    return (ConvertFrom-Json $queryResults)
}

function Get-OpenAlerts {
    Param([string]$Uri)

	$alerts = (Invoke-RMMApi -Uri $Uri)
    return $alerts
}

function Find-AlertsByOptions {
    Param([PSCustomObject]$Alerts)

    if ($Env:Priority -ne 'All') {
        Write-Verbose ("[Filter] Priority - {0}" -f $Env:Priority)
        $Alerts.alerts = $Alerts.alerts | Where-Object {$_.priority -eq $Env:Priority}
    }
    return $Alerts
}

function Resolve-OpenAlert {
    Param([string]$AlertUid)

    $resolvePath = "alert/{0}/resolve" -f $AlertUid
    $alertUri = "{0}{1}" -f (Get-ApiUrl), $resolvePath
    Invoke-RMMApi -Uri $alertUri -Method "POST"
}

function Resolve-AllAlerts {
<#
.Description
RMM API requests are limited to 250 results per request and 600 requests per minute
Resolve-AllAlerts introduces a 30s delay after processing every 250 alerts for Rate Limit
#>
    Param([string]$Uri)

    $openAlerts = @{}
    $resolvedCount = 0

    do {
        $nextPageUri = $openAlerts.pageDetails.nextPageUrl
        if ($nextPageUri) {
            $Uri = $nextPageUri
            Write-Verbose ("NextPage: Page {0} | Alerts Resolved: {1}" -f
                $page, $resolvedCount)
    		Start-Sleep -Seconds 30
        }

        $openAlerts = Get-OpenAlerts -Uri $Uri
        if (-not $openAlerts.alerts) {
            Write-Output "[FAIL] Error reading Alerts, see Stderr..."
            Write-Output (" Total Alerts Resolved: {0}" -f $resolvedCount)
            Write-Error (New-AlertsNotFoundError) -ErrorAction Stop
        }

        $openAlerts = Find-AlertsByOptions -Alerts $openAlerts
        $nextPageUri = $openAlerts.pageDetails.nextPageUrl
        $alertCount = $openAlerts.alerts.count

        if ($alertCount -gt 0) {
            Write-Output ("[Batch] Processing {0} Alert(s)..." -f $alertCount)
            ForEach ($alert in $openAlerts.alerts) {
                Resolve-OpenAlert -AlertUid $alert.alertUid
            }
            $resolvedCount = $resolvedCount + $alertCount
        }
        else {
            Write-Output "[NotFound] No matching open Alerts..."
        }
    }
    While($nextPageUri)

    Write-Verbose (" Total Alerts Resolved: {0}" -f $resolvedCount)
}

function Invoke-RMMComponent {
    Write-Output "`n=============================="
    Write-Output " Resolve All Open Alerts v1.1"
    Write-Output "=============================="


    Write-Output "[Options]"
    Write-Output (" Target: {0}" -f (Get-Culture).TextInfo.ToTitleCase($Env:Target))
    if ($Env:Target -eq "site") {
        Write-Output (" SiteID: {0}" -f $Env:SiteID)
    }
    Write-Output (" Priority: {0}" -f $Env:Priority)

    if(-not (Test-ApiToken)) {
        Write-Output "[Auth] Token Error, view Stderr for details..."
        Write-Error -Message (New-APITokenNotFoundError) -ErrorAction Stop
    }
    Write-Output "[Auth] Token found."

    if((-not (Test-RMMPlatform)) -or ((Get-RMMPlatform).length -eq 0)) {
        Write-Output "[Platform] Not Found, view Stderr for details..."
        Write-Error -Message (New-InvalidPlatformError) -ErrorAction Stop
    }
    Write-Output ("[Platform] RMM - {0}" -f (Get-RMMPlatform))

    Write-Output "[Fetch] Reading Open Alerts"
    Resolve-AllAlerts -Uri (Get-ApiAlertUrl)
}

Invoke-RMMComponent
