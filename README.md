# OZO PowerShell Script Template
## Description
Wipes the Star Citizen _USER_ and _shaders_ folders before invoking the launcher, while preserving and restoring any user preferences and custom controls mapping files.

## Installation
This script is published to [PowerShell Gallery](https://learn.microsoft.com/en-us/powershell/scripting/gallery/overview?view=powershell-5.1). Ensure your system is configured for this repository then execute the following in an _Administrator_ PowerShell:

```powershell
Install-Script ozo-sc-fresh-start
```

## Usage
Run this script in an _Administrator_ PowerShell.

```powershell
ozo-sc-fresh-start
    -InstallLocation <String>
```

## Parameters
|Parameter|Description|
|---------|-----------|
|`InstallLocation`|The path to the RSI Launcher directory. If omitted, the script will attempt to obtain the path from the Windows registry.|

## Acknowledgements
Special thanks to my employer, [Sonic Healthcare USA](https://sonichealthcareusa.com), who supports the growth of my PowerShell skillset and enables me to contribute portions of my work product to the PowerShell community.
