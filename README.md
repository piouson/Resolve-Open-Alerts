# Resolve Open Alerts

A Datto RMM Component to resolve Open Alerts via the RMM API.

> This Component compliments existing Alert Resolution options in RMM, offering more flexibility and control over Alert Resolution, especially for 100s and 1000s of Open Alerts.

![License: GPL-3](https://img.shields.io/github/license/piouson/Resolve-Open-Alerts) ![Powershell: Version 4, 5 and 6](https://img.shields.io/badge/powershell-4.0%20%7C%205.1%20%7C%206.2-blue) ![Platforms: Windows, macOS, Linux](https://img.shields.io/badge/platform-windows%20%7C%20macos%20%7C%20linux-brightgreen)  
![Releave: Version 2](https://img.shields.io/github/v/release/piouson/Resolve-Open-Alerts?sort=semver) ![Release Date](https://img.shields.io/github/release-date/piouson/Resolve-Open-Alerts) ![Downloads](https://img.shields.io/github/downloads/piouson/Resolve-Open-Alerts/total) ![Open Issues](https://img.shields.io/github/issues-raw/piouson/Resolve-Open-Alerts)

> ![Resolve Open Alerts sample image](./sample-480.png)

## Prerequisites

- Valid RMM API token, saved on target device as `$Env:RMMAPIKey`, see [RMM API docs](https://help.aem.autotask.net/en/Content/2SETUP/APIv2.htm)
- Preconfigured [Environment Variables](#environment-variables)

## Deployment

### Import component in RMM

- Download [`resolve-open-alerts-v2.cpt`](https://github.com/piouson/Resolve-Open-Alerts/releases)
- [Import component in RMM](https://help.aem.autotask.net/en/Content/4WEBPORTAL/Components/ManageComponents.htm#Import_a_component), select `resolve-open-alerts-v2.cpt` and save

### Save RMM API token on target device

- In RMM, [Activate the API](https://help.aem.autotask.net/en/Content/2SETUP/APIv2.htm#Activate_the_API)
- Save the `API Key`, `API Secret Key` and `API URL` in a text file
- Download [RMM API example files](https://help.aem.autotask.net/en/Content/2SETUP/APIv2.htm#Downloadable_example_code) and extract `powershell_token.ps1`
- Open `Powershell ISE` as **`Administrator`** and open script `powershell_token.ps1`
- Scroll to the bottom of `powershell_token.ps1`, add code below and run script

> For options outside Powershell, use `curl_token.bat` or `csharp_token.cs`

```powershell
# Define parameters
$params = @{
  apiUrl        = '[API URL]'
  apiKey        = '[API Key]'
  apiSecretKey  = '[API Secret Key]'
}

# Call New-AemApiAccessToken function using defined parameters 
$key = New-AemApiAccessToken @params

# Save API Token as System Variable
[Environment]::SetEnvironmentVariable('RMMAPIKey',$key,'Machine')
```

> Requires process refresh for changes, close and reopen `Powershell ISE`, then run below command to confirm token saved as **System** variable

```powershell
[Environment]::GetEnvironmentVariable('RMMAPIKey', 'Machine')
```

> If token is not displayed, try saving again by rerunning `Powershell ISE` as **Administrator**
>
> **RMM API token** is not suitable as [RMM Site Variable](https://help.aem.autotask.net/en/Content/4WEBPORTAL/Sites/SiteSettings.htm#Variables) due to its character length exceeding limit.

### Run component on target device

- Use a [Quick Job](https://help.aem.autotask.net/en/Content/4WEBPORTAL/Jobs/Quick_Jobs.htm) or [Job Scheduler](https://help.aem.autotask.net/en/Content/4WEBPORTAL/Jobs/Job_Scheduler.htm) and select the target device

## Environment Variables

If running in production (e.g. from RMM), you only need to configure `$Env:RMMAPIKey` at **System** level, see [Deployment](#deployment).

Other variables required at deployment time, must be set manually in [`Invoke-MockComponent`](https://github.com/piouson/Resolve-Open-Alerts/blob/71b99a72c550e37e3bc72e8a6fd06ce743bd4083/ResolveAllOpenAlerts.ps1#L292) for local development and mock testing.

- `$Env:CS_WS_ADDRESS` - preconfigured in RMM {`merlot-centrastage.net` | `concord-centrastage.net` | etc}
- `$Env:Target` {`site` | `account`}, default is site of device running component
- `$Env:SiteID`, set here if `$Env:Target` = `"site"`
- `$Env:Priority` {`All` | `Information` | `Low` | `Moderate` | `High` | `Critical`}
- `$Env:MonitorType`, use Monitor Class names
- `$Env:DeviceType` {`Desktop` | `Laptop` | `Server` | `ESXI Host` | `Printer` | `Network Device`}
- `$Env:UdfNumber` {`1-30`}, UDF must be set to `"resolvealerts"` in RMM, see image below

> ![Sample UDF value](./udf-example.png)

See [variables in Powershell](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_environment_variables) and [variables in RMM](https://help.aem.autotask.net/en/Content/2SETUP/AccountSettings/AccountSettings.htm#Variables).

## Running Directly in Powershell

The quickest way to try out this component is by running in Powershell.

- [Clone or Download source code](https://github.com/piouson/Resolve-Open-Alerts)
- Unzip to a suitable path
- Open `ResolveOpenAlerts.ps1` in [Visual Studio Code](https://code.visualstudio.com/), Powershell ISE or your favourite Powershell IDE.
- Define [environment variables](#environment-variables) in [`Invoke-MockComponent`](https://github.com/piouson/Resolve-Open-Alerts/blob/71b99a72c550e37e3bc72e8a6fd06ce743bd4083/ResolveAllOpenAlerts.ps1#L292) for testing or just above `Invoke-RMMComponent` for production/live
- For testing, switch to development mode, see [Running Tests](#running-tests)
- Run script

> The default RMM script timeout of 1 hour should resolve max 30,000 Alerts.

## Running Tests

> Requires [environment variables](#environment-variables).

Unit Tests have not been written for any functions yet, but [`Invoke-MockComponent`](https://github.com/piouson/Resolve-Open-Alerts/blob/71b99a72c550e37e3bc72e8a6fd06ce743bd4083/ResolveAllOpenAlerts.ps1#L292) can be used for local development, Integration Testing and/or Stress Testing. Just uncomment invocation at bottom of file, see snippet below.

> ### Production/Live mode

```powershell
#Invoke-MockComponent
Invoke-RMMComponent
```

> ### Development mode

```powershell
Invoke-MockComponent
#Invoke-RMMComponent
```

> When using [`Invoke-MockComponent`](https://github.com/piouson/Resolve-Open-Alerts/blob/71b99a72c550e37e3bc72e8a6fd06ce743bd4083/ResolveAllOpenAlerts.ps1#L292), Alerts are **never resolved**. Alert Resolution is simulated by using already Resolved Alerts as mock data.

For actual Alert Resolution in local development, use [`Invoke-RMMComponent`](https://github.com/piouson/Resolve-Open-Alerts/blob/71b99a72c550e37e3bc72e8a6fd06ce743bd4083/ResolveAllOpenAlerts.ps1#L261) directly with [environment variables](#environment-variables).

## Contributing

Anyone can contribute.

- Open a [new issue](https://github.com/piouson/Resolve-Open-Alerts/issues) to request bug fixes, features or a simple question
- Create a [pull request](https://github.com/piouson/Resolve-Open-Alerts/pulls) to submit your own fixes, unit tests, features, or for typos and document updates
- Submit test cases

## License

[![License: GPL-3](https://img.shields.io/github/license/piouson/Resolve-Open-Alerts)](https://github.com/piouson/Resolve-Open-Alerts/blob/master/LICENSE)
