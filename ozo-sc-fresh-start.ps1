<#PSScriptInfo
    .VERSION 1.0.1
    .GUID b51c39e8-469a-4881-bbf7-c60081ccc8aa
    .AUTHOR Andrew Lievertz <alievertz@onezeroone.dev>
    .COMPANYNAME One Zero One
    .COPYRIGHT (c) 2024 Andrew Lievertz
    .LICENSEURI https://raw.githubusercontent.com/onezeroone-dev/ozo-sc-fresh-start/main/LICENSE
#>

<#
    .SYNOPSIS
    Wipes the Star Citizen "USER" and/or "shaders" folders before invoking the launcher, while preserving and restoring any custom controls mapping files.
    .DESCRIPTION
    See synopsis.
    .PARAMETER InstallLocation
    Optional. The absolute path to the RSI Launcher directory. If omitted, the script will attempt to obtain the path from the Windows registry.
    .EXAMPLE
    PS> ozo-sc-fresh-start.ps1 -InstallLocation "C:\Program Files\Roberts Space Industries\RSI Launcher"
    .LINK
    https://github.com/onezeroone-dev/ozo-sc-fresh-start
#>

[CmdLetBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $false,HelpMessage="[Optional] absolute path to the RSI Launcher directory.")][string]$InstallLocation = (Get-ItemProperty -Path "HKLM:SOFTWARE\81bfc699-f883-50c7-b674-2483b6baae23").InstallLocation
)

class ControlMapping {
    $Path = $null
    $XML = $null
}

# Paths
[string]$rsiRSILauncherDir = $InstallLocation
[string]$rsiDir = Split-Path $rsiRSILauncherDir -Parent
[string]$userDir = Join-Path -Path $rsiDir -ChildPath "StarCitizen\LIVE\USER"
[string]$mappingsDir = Join-Path -Path $userDir -ChildPath "Client\0\Controls\Mappings"
[string]$shadersDir = Join-Path -Path (Get-ChildItem -Path Env:\LOCALAPPDATA).Value -ChildPath "Star Citizen"

# Array for holding control mapping information
[array]$mappings = $null

# Report directories
Write-Host ("RSI Directory          : " + $rsiDir)
Write-Host ("RSI Launcher Directory : " + $rsiRSILauncherDir)
Write-Host ("USER Dir               : " + $userDir)
Write-Host ("Control mappings Dir   : " + $mappingsDir)
Write-Host ("Shaders Directory      : " + $shadersDir)    

# Iterate through the control mapping xml files
ForEach ($item in Get-ChildItem -Filter "*.xml" -Path $mappingsDir) {
    # Create an instance of the ControlMapping class
    $mapping = [ControlMapping]::new()
    # Store the file path
    $mapping.Path = Join-Path -Path $mappingsDir -ChildPath $item.Name
    # Store the xml
    [xml]$mapping.XML = Get-Content -Path $mapping.Path
    # Add this object to the mappings array
    $mappings += $mapping
}

# Wipe the USER folder
If (Test-Path $userDir) {
    Get-Item -Path $userDir | Remove-Item -Recurse -Force
}

# Wipe the shaders folder
If (Test-Path $shadersDir) {
    Get-ChildItem -Path $shadersDir -Recurse | Remove-Item -Recurse -Force
}

# Start Star Citizen Launcher
Start-Process -File "RSI Launcher.exe" -WorkingDirectory $rsiRSILauncherDir

# Wait until user starts Star Citizen
[bool]$wait = $true
While ($wait -eq $true) {
    Try {
        Get-Process -Name "StarCitizen" -ErrorAction Stop
        $wait = $false
    } Catch {
        $wait = $true
        Write-Host ("Waiting for user to start Star Citizen.")
        Start-Sleep -Seconds 2
    }
}

# Wait for the game to re-create the mappingsDir
While (-Not(Test-Path -Path $mappingsDir)) {
    Start-Sleep -Seconds 1
}

# Write out the control mappings
ForEach ($mapping in $mappings) {
    $mapping.XML.Save($mapping.Path)
}
