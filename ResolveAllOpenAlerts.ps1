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

function Assert-ApiKey {
    [bool]$isApiKeySaved = Test-Path Env:RMMAPIKey
	return $isApiKeySaved
}

function Assert-RMMPlatform {
    [bool]$isPlatformDetected = Test-Path Env:CS_WS_ADDRESS
    return $isPlatformDetected
}

function Get-RMMPlatform {
    [string]$platform = ($Env:CS_WS_ADDRESS -split '-')[0]
    return $platform
}

function Get-ApiV2Uri {
    $platform = Get-RMMPlatform
    [string]$apiUri = "https://{0}-api.centrastage.net/api/v2/" -f $platform
    return $apiUri
}

function Get-AlertApiUri {
    $alertPath = "/alerts/open"
								   
    if ($Env:Target -eq "site") {
        $alertPath = "/{0}{1}" -f $Env:SiteID, $alertPath
    }
    [string]$alertApiUri = "{0}{1}{2}" -f (Get-ApiV2Uri), $Env:Target, $alertPath
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
        Write-Host "Error reading API, view Stderr for details..."
        Write-Error -Message $_.Exception -ErrorAction Stop
    }
    return (ConvertFrom-Json $queryResults)
}

function Get-OpenAlerts {
    Param([string]$Uri)

	$alerts = (Invoke-RMMApi -Uri $Uri)
    return $alerts
}

function Find-AlertsByPriority {
    Param([PSCustomObject]$Alerts)
    
    if ($Env:Priority -ne 'All') {
        $Alerts.alerts = $Alerts.alerts | Where-Object {$_.priority -eq $Env:Priority}
    }
    return $Alerts
}

function Resolve-OpenAlert {
    Param([string]$AlertUid)

    $resolvePath = "alert/{0}/resolve" -f $AlertUid		
    $alertUri = "{0}{1}" -f (Get-ApiV2Uri), $resolvePath
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
            Write-Host "Moving to next page of alerts..."
    		Start-Sleep -Seconds 30
        }

        $openAlerts = Get-OpenAlerts -Uri $Uri      
        if (-not $openAlerts.alerts) {
            Write-Host "Error reading Alerts, view Stderr for details..."
            Write-Error (New-AlertsNotFoundError) -ErrorAction Stop
        }
		
        $openAlerts = Find-AlertsByPriority -Alerts $openAlerts
        $nextPageUri = $openAlerts.pageDetails.nextPageUrl
        $alertCount = $openAlerts.alerts.count

        if ($alertCount -gt 0) {
            Write-Host ("Resolving {0} Alerts..." -f $alertCount)
            ForEach ($alert in $openAlerts.alerts) {
                Resolve-OpenAlert -AlertUid $alert.alertUid
            }
            $resolvedCount = $resolvedCount + $alertCount
        }
    }
    While($nextPageUri)

    Write-Host "Total Alerts Resolved: "$resolvedCount
}

function Start-RMMComponent {
    Write-Host "`n=============================="
    Write-Host " Resolve All Open Alerts v1.1"
    Write-Host "=============================="
										

    Write-Host "Target: "(Get-Culture).TextInfo.ToTitleCase($Env:Target)
	if ($Env:Target -eq "site") {
		Write-Host "SiteID: "$Env:SiteID
	}
    Write-Host "Priority: "$Env:Priority

    Write-Host "Searching API Token in System Variable..."
    if(-not (Assert-ApiKey)) {
        Write-Host "API Token Error, view Stderr for details..."
        Write-Error -Message (New-APITokenNotFoundError) -ErrorAction Stop
    }
    Write-Host "API Token found."

    Write-Host "Verifying RMM Platform..."
    if((-not (Assert-RMMPlatform)) -or ((Get-RMMPlatform).length -eq 0)) {
        Write-Host "RMM Platform Error, view Stderr for details..."
        Write-Error -Message (New-InvalidPlatformError) -ErrorAction Stop
    }
    Write-Host "RMM Platform: "(Get-RMMPlatform)

    Write-Host ("Reading Open Alerts from {0}..." -f (Get-AlertApiUri))
    Resolve-AllAlerts -Uri (Get-AlertApiUri)
}

Start-RMMComponent
