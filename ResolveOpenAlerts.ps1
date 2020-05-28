<#
    Resolve Open Alerts v2
    - Use Invoke-RMMComponent for production
    - Use Invoke-MockComponent for development, controls $script:isDevelopment
    - Development only simulates and Never resolves Alerts
    - You may use Invoke-RMMComponent in development to test actual Alert resoultion
    - isVerboseDetailed $true displays each Alert resolved in output
    - deviceCache is used to speedup device type filtering by skipping cached entries
    - For updates and documentation, see https://github.com/piouson/Resolve-Open-Alerts
    Author: piouson.github.io
#>

$script:version = " Resolve Open Alerts v2.3.9"
$script:apiHits = 0
$script:rateLimitCount = 0
$script:rateBuffer = 200
$script:delay = 30
$script:statusCode = 0
$script:isDevelopment = $false
$script:isVerboseDetailed = $true
$script:deviceCache = @{ }

function Test-ApiToken {
  return Test-Path Env:RMMAPIKey
}

function Test-RMMPlatform {
  return Test-Path Env:CS_WS_ADDRESS
}

function Get-RMMPlatform {
  [string]$platform = ($Env:CS_WS_ADDRESS -split '-')[0]
  return $platform
}

function Get-ApiUri {
  $platform = Get-RMMPlatform
  [string]$apiUri = "https://{0}-api.centrastage.net/api/v2/" -f $platform
  return $apiUri
}

function Get-ApiAlertUri {
  $alertPath = "/alerts/open"

  if ($script:isDevelopment) {
    $alertPath = "/alerts/resolved"
  }

  if ($Env:Target -eq "site") {
    $alertPath = "/{0}{1}" -f $Env:SiteID, $alertPath
  }
  [string]$alertApiUri = "{0}{1}{2}" -f (Get-ApiUri), $Env:Target, $alertPath
  return $alertApiUri
}

function Get-ApiDeviceUri {
  Param([string]$Uid)

  $devicePath = "device/{0}" -f $Uid
  [string]$deviceApiUri = "{0}{1}" -f (Get-ApiUri), $devicePath
  return $deviceApiUri
}

function Get-ApiHeader {
  $token = "Bearer {0}" -f $Env:RMMAPIKey
  return @{Authorization = $token }
}

function Show-ApiStatusError {
  Param([string]$Action)

  $message = switch ($script:statusCode) {
    401 { "[FAIL] Unauthorised Access! Check API token." }
    403 { "[FAIL] Access Denied! Check Security Level..." }
    404 { ("[FAIL] {0} Not Found!" -f $Action) }
    default { "[ERROR] Check Stderr for details..." }
  }
  return $message
}

function Test-RateLimit {
  Param(
    [string]$Hits,
    [string]$Buffer
  )

  return ($Hits -gt 0 -and $Hits % $Buffer -eq 0)
}

function Invoke-RMMApi {
  <#
.Description
RMM API limits requests to 600 per minute. Rate limiting begins at 500 requests.
This function invokes the RMM API ata rate of 200 requests every 30 seconds
#>
  Param(
    [Parameter(Mandatory = $true)]
    [string]$Uri,
    [Parameter(Mandatory = $false)]
    [string]$Method,
    [Parameter(Mandatory = $false)]
    [string]$Action
  )

  if (-not $Method) {
    $Method = "GET"
  }

  if (-not $Action) {
    $Action = "Alert"
  }

  if (Test-RateLimit -Hits $script:apiHits -Buffer $script:rateBuffer) {
    $script:rateLimitCount++
    Write-Verbose ("RateLimit x{0} | API hits: {1} | Sleep: {2}s" -f
      $script:rateLimitCount, $script:apiHits, $script:delay)
    Start-Sleep -Seconds $script:delay
  }

  try {
    $queryResults = Invoke-WebRequest -Uri $Uri -Headers (Get-ApiHeader) `
      -Method $Method -UseBasicParsing -Verbose:$false

    $script:apiHits++
    $script:statusCode = $_.Exception.Response.StatusCode.value__

  }
  catch {
    $script:statusCode = $_.Exception.Response.StatusCode.value__
    if ($script:isVerboseDetailed) {
      Write-Verbose (
        "{0} | {1}" -f (Show-ApiStatusError -Action $Action),
        ($Uri.split("api/")[1])
      )
    }
    if ($Action -eq "Alert") {
      Write-Error $_.Exception -ErrorAction Stop
    }
  }

  if ($queryResults) {
    return (ConvertFrom-Json $queryResults)
  }
  return $queryResults
}

function Get-OpenAlerts {
  Param([string]$Uri)

  return Invoke-RMMApi -Uri $Uri
}

function Get-Device {
  Param([string]$Uid)

  if ($script:deviceCache.Contains($Uid)) {
    return $script:deviceCache[$Uid]
  }
  $uri = Get-ApiDeviceUri -Uid $Uid
  $device = Invoke-RMMApi -Uri $uri -Action "Device"
  $script:deviceCache.Add($Uid, $device)
  return $device
}

function Find-AlertsByOptions {
  Param([PSCustomObject]$Alerts)

  if ($Env:Priority) {
    $Alerts.alerts = @(
      $Alerts.alerts | Where-Object {
        $_.priority -eq $Env:Priority
      }
    )
  }

  if ($Env:MonitorType -and $Alerts.alerts) {
    $Alerts.alerts = @(
      $Alerts.alerts | Where-Object {
        $_.alertContext."@class" -like "$Env:MonitorType*"
      }
    )
  }

  if ($Env:DeviceType -and $Alerts.alerts.alertSourceInfo) {
    $Alerts.alerts = @(
      $Alerts.alerts | Where-Object {(
        Get-Device $_.alertSourceInfo.deviceUid
      ).deviceType.category -like "$Env:DeviceType*"}
    )
  }

  if ($Env:UdfNumber -and $Alerts.alerts.alertSourceInfo) {
    $udf = ("udf{0}" -f $Env:UdfNumber)
    $Alerts.alerts = @(
      $Alerts.alerts | Where-Object {(
        Get-Device $_.alertSourceInfo.deviceUid
      ).udf.$udf -eq "resolvealerts"}
    )
  }

  $Alerts.pageDetails.count = $Alerts.alerts.count
  return $Alerts
}

function Resolve-OpenAlert {
  Param([string]$AlertUid)

  $resolvePath = "alert/{0}/resolve" -f $AlertUid
  $method = "POST"
  if ($script:isDevelopment) {

    $resolvePath = "alert/{0}" -f $AlertUid
    $method = "GET"
  }
  $alertUri = "{0}{1}" -f (Get-ApiUri), $resolvePath

  Invoke-RMMApi -Uri $alertUri -Method $method | Out-Null
}

function Get-FilterOptionsAsString {
  $message = ("[Filter Options]`n Target: {0}" -f
    (Get-Culture).TextInfo.ToTitleCase($Env:Target))
  if ($Env:Priority) {
    $message += ("`n Priority: {0}" -f $Env:Priority)
  }
  if ($Env:MonitorType) {
    $message += ("`n MonitorType: {0}" -f $Env:MonitorType)
  }
  if ($Env:DeviceType) {
    $message += ("`n DeviceType: {0}" -f $Env:DeviceType)
  }
  if ($Env:UdfNumber) {
    $message += ("`n UDF: {0}" -f $Env:UdfNumber)
  }
  return $message
}

function Resolve-AllAlerts {
  Param([string]$Uri)

  $openAlerts = @{ }
  $page = 0
  $resolvedCount = 0

  do {
    $nextPageUri = $openAlerts.pageDetails.nextPageUrl
    if ($nextPageUri) {
      $Uri = $nextPageUri
      $page++
      Write-Verbose ("NextPage: Page {0} | Total Alerts Resolved: {1}" -f
        $page, $resolvedCount)
    }

    $openAlerts = Get-OpenAlerts -Uri $Uri
    if (-not $openAlerts.alerts) {
      Write-Output "[Null] No Open Alerts for Account!"
      Write-Output ("[Stats] Total Alerts Resolved: {0}" -f $resolvedCount)
      return
    }

    $openAlerts = Find-AlertsByOptions -Alerts $openAlerts
    if (-not $openAlerts.alerts) {
      Write-Output "[Null] No Open Alerts matching filter options!"
    }
    else {
      Write-Output ("[New Page] Processing {0} Alert(s)..." -f $openAlerts.alerts.count)
      ForEach ($alert in $openAlerts.alerts) {
        Resolve-OpenAlert -AlertUid $alert.alertUid
        $resolvedCount++
        if ($script:isVerboseDetailed) {
          Write-Verbose ("Resolved Alert: {0} | Device {1}" -f
            $alert.alertUid, $alert.alertSourceInfo.deviceName)
        }
        if ($script:isDevelopment -and $resolvedCount -ge $script:maxSims) {
          Write-Output ("[Test Complete] Simulations: {0}" -f $resolvedCount)
          return
        }
      }
    }
    $nextPageUri = $openAlerts.pageDetails.nextPageUrl
  }
  While ($nextPageUri)

  Write-Output ("[Stats] Total Alerts Resolved: {0}" -f $resolvedCount)
}

function Invoke-RMMComponent {
  Write-Output "`n================================"
  Write-Output $script:version
  Write-Output "================================"

  Write-Output (Get-FilterOptionsAsString)

  if (-not (Test-ApiToken)) {
    Write-Output "[Auth] Token Error, view Stderr for details..."
    Write-Error "API Token Not Found!" -ErrorAction Stop
  }
  Write-Output "[Auth] Token found."

  if ((-not (Test-RMMPlatform)) -or ((Get-RMMPlatform).length -eq 0)) {
    Write-Output "[Platform] Not Found, view Stderr for details..."
    Write-Error "RMM Platform Unknown!" -ErrorAction Stop
  }
  Write-Output ("[Platform] RMM - {0}" -f (Get-RMMPlatform))

  Write-Output "[Fetch] Reading Open Alerts"
  Resolve-AllAlerts -Uri (Get-ApiAlertUri)
}

function Invoke-MockComponent {
  <#
.Description
Mock Run: Uses already Resolved Alerts for simulation
This is useful for Integration Testing and Stress Testing
Set Mock environment variables below
#>
  $Env:CS_WS_ADDRESS = "" # merlot-centrastage | concord-centrastage | etc
  $Env:RMMAPIKey = ""
  $Env:Target = "" # site | account
  $Env:SiteID = "" # set here if Env:Target = "site"
  $Env:Priority = "" # Information | Low | Moderate | High | Critical
  $Env:MonitorType = "" # online_offline | eventlog | custom_snmp | etc
  $Env:DeviceType = "" # Desktop | Laptop | Server | ESXI Host | Printer | etc
  $Env:UdfNumber = "" # UDF1-30, UDF must be set to "resolvealerts" in RMM
  $script:maxSims = 1000 # number of alert resolution to simulate

  $oldPrefs = $VerbosePreference
  $VerbosePreference = "Continue"
  $script:isDevelopment = $true

  Invoke-RMMComponent
  $VerbosePreference = $oldPrefs
}

#Invoke-MockComponent
Invoke-RMMComponent
