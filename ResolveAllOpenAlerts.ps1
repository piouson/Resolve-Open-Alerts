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
        $queryResults = Invoke-WebRequest -Uri $Uri -Headers (Get-ApiHeader) -Method $Method -UseBasicParsing
    } catch {
        Write-Host "Error reading API" $_.InvocationInfo.PositionMessage
        Write-Error -Message $_ -ErrorAction Stop
    }
    return (ConvertFrom-Json $queryResults)
}

function Get-OpenAlerts ([string]$Uri) {
	$alerts = (Invoke-RMMApi -Uri $Uri).alerts
    return $alerts
}

function Resolve-OpenAlert ([string]$AlertUid) {
    $resolvePath = "alert/{0}/resolve" -f $AlertUid
							
    $alertUri = "{0}{1}" -f (Get-ApiV2Uri), $resolvePath

    Invoke-RMMApi -Uri $alertUri -Method "POST"
}

function Start-RMMComponent {
    Write-Host "`n=============================="
    Write-Host " Resolve All Open Alerts v1.1"
    Write-Host "=============================="
    Write-Host "Target: "$Env:Target
	if ($Env:Target -eq "site") {
		Write-Host "SiteID: "$Env:SiteID
	}
    Write-Host "Priority: "$Env:Priority

    Write-Host "Searching API Token in System Variable..."
    if(-not (Assert-ApiKey)) {
        Write-Host "API Token NOT found!"
        Write-Host "Please save API Token on device with command below before rerunning component..."
        Write-Host "[Environment]::SetEnvironmentVariable('RMMAPIKey','enter-api-token-here','Machine')"
        Write-Host "RMM APIv2 Doc: https://help.aem.autotask.net/en/Content/2SETUP/APIv2.htm"
        Write-Error "Exiting..." -ErrorAction Stop
    }
    Write-Host "API Token found."

    Write-Host "Verifying RMM Platform..."
    if((-not (Assert-RMMPlatform)) -or ((Get-RMMPlatform).length -eq 0)) {
        Write-Host "Could not determine RMM Platform!"
        Write-Error "Exiting..." -ErrorAction Stop
    }
    Write-Host "RMM Platform: "(Get-RMMPlatform)

    Write-Host "Reading Open Alerts..."
    $openAlerts = Get-OpenAlerts -Uri (Get-AlertApiUri)
    if (-not $openAlerts) {
        Write-Host "No Open Alerts found!"
        Write-Error "Exiting..." -ErrorAction Stop
    }

    if ($Env:Priority -ne 'All') {
        $openAlerts = $openAlerts | Where-Object {$_.Priority -eq $Env:Priority}
    }
    
	# Rate Limit: Requests to the RMM API are limited to 600 requests per minute
	# Rate Limit: RMM API introduces a 1 sec delay to responses after 540 requests
	$request = 1
	$rateLimit = 500
    ForEach ($alert in $openAlerts) {
		if ($request%$rateLimit -eq 0) {
			Start-Sleep -Seconds 60
		}
        Write-Host "Resolving Alert: "$alert.alertUid
        Resolve-OpenAlert -AlertUid $alert.alertUid
		$request++
    }
}

Start-RMMComponent