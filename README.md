# Resolve-Open-Alerts

A Datto RMM Component to resolve Open Alerts via the RMM API.

> This Component compliments existing Alert Resolution options in RMM, offering more flexibility and control over Alert Resolution, especially for 100s and 1000s of Open Alerts.

![License: GPL-3](https://img.shields.io/github/license/piouson/Resolve-Open-Alerts) ![Powershell: Version 3, 5 and 6](https://img.shields.io/badge/powershell-3.0%20%7C%205.1%20%7C%206.2-blue) ![Platforms: Windows, macOS, Linux](https://img.shields.io/badge/platform-windows%20%7C%20macos%20%7C%20linux-brightgreen)  
![Releave: Version 2](https://img.shields.io/github/v/release/piouson/Resolve-Open-Alerts?sort=semver) ![Release Date](https://img.shields.io/github/release-date/piouson/Resolve-Open-Alerts) ![Downloads](https://img.shields.io/github/downloads/piouson/Resolve-Open-Alerts/total) ![Open Issues](https://img.shields.io/github/issues-raw/piouson/Resolve-Open-Alerts)

> ![Resolve Open Alerts sample image](./sample-480.png)

## Prerequisites

- Valid RMM API token, saved on target device as `$Env:RMMAPIKey`, see [RMM API docs](https://help.aem.autotask.net/en/Content/2SETUP/APIv2.htm)
- Preconfigured [Environment Variables](#environment-variables)

## Getting Started

The quickest way to try out this component is by running in Powershell.

- Unzip `ResolveOpenAlerts.zip`
- Open `ResolveOpenAlerts.ps1` in [Visual Studio Code](https://code.visualstudio.com/), [Powershell ISE](https://docs.microsoft.com/en-us/powershell/scripting/components/ise/introducing-the-windows-powershell-ise) or your favourite IDE.
- Define [environment variables](#environment-variables) in [`Invoke-MockComponent`](https://github.com/piouson/Resolve-Open-Alerts/blob/71b99a72c550e37e3bc72e8a6fd06ce743bd4083/ResolveAllOpenAlerts.ps1#L292)
- Switch to development mode, see [Running Tests](#running-tests)
- Run script

> The default RMM script timeout of 1 hour should resolve max 30,000 Alerts.

## Environment Variables

If running in production (e.g. from RMM), you only need to configure `$Env:RMMAPIKey` at [**System** level](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_environment_variables?view=powershell-7#saving-changes-to-environment-variables) to hold the RMM API token before [deployment](#deployment).

> This is not suitable as [RMM Site Variable](https://help.aem.autotask.net/en/Content/4WEBPORTAL/Sites/SiteSettings.htm#Variables) due to its character length limitation.

```powershell
# run as administrator
[Environment]::SetEnvironmentVariable('RMMAPIKey', 'enter-api-token-here', 'Machine')
```

> Requires process refresh to verify changes or just open a new Powershell terminal

```powershell
[Environment]::GetEnvironmentVariable('RMMAPIKey', 'Machine')
```

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

## Running Tests

> Requires [environment variables](#environment-variables).

Unit Tests have not been written for any functions yet, but [`Invoke-MockComponent`](https://github.com/piouson/Resolve-Open-Alerts/blob/71b99a72c550e37e3bc72e8a6fd06ce743bd4083/ResolveAllOpenAlerts.ps1#L292) can be used for local development, Integration Testing and/or Stress Testing. Just uncomment invocation at bottom of file, see snippet below.

```powershell
Invoke-MockComponent
#Invoke-RMMComponent
```

> When using [`Invoke-MockComponent`](https://github.com/piouson/Resolve-Open-Alerts/blob/71b99a72c550e37e3bc72e8a6fd06ce743bd4083/ResolveAllOpenAlerts.ps1#L292), Alerts are **never resolved**. Alert Resolution is simulated by using already Resolved Alerts as mock data.

For actual Alert Resolution in local development, use [`Invoke-RMMComponent`](https://github.com/piouson/Resolve-Open-Alerts/blob/71b99a72c550e37e3bc72e8a6fd06ce743bd4083/ResolveAllOpenAlerts.ps1#L261) directly with [environment variables](#environment-variables).

## Deployment

- [Import Component](https://help.aem.autotask.net/en/Content/4WEBPORTAL/Components/ManageComponents.htm#Import_a_component) and select `ResolveOpenAlert.cpt`
- Use a [Quick Job](https://help.aem.autotask.net/en/Content/4WEBPORTAL/Jobs/Quick_Jobs.htm) or [Job Scheduler](https://help.aem.autotask.net/en/Content/4WEBPORTAL/Jobs/Job_Scheduler.htm), and specify a single device as target

## Contributing

Anyone can contribute.

- Open a [new issue](https://github.com/piouson/Resolve-Open-Alerts/issues) for bug report, feature request, typos or a simple question
- Create a [pull request](https://github.com/piouson/Resolve-Open-Alerts/pulls) to submit your own fixes, unit tests, improvements, or features
- Submit test cases

## License

[![License: GPL-3](https://img.shields.io/github/license/piouson/Resolve-Open-Alerts)](https://github.com/piouson/Resolve-Open-Alerts/blob/master/LICENSE)

- **[MIT license](https://github.com/piouson/Resolve-Open-Alerts/blob/master/LICENSE)**
