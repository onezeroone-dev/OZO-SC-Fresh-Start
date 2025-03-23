#Requires -Modules OZO,OZOLogger

<#PSScriptInfo
    .VERSION 1.2.0
    .GUID b51c39e8-469a-4881-bbf7-c60081ccc8aa
    .AUTHOR Andrew Lievertz <alievertz@onezeroone.dev>
    .COMPANYNAME One Zero One
    .COPYRIGHT (c) 2024 Andrew Lievertz
    .LICENSEURI https://raw.githubusercontent.com/onezeroone-dev/ozo-sc-fresh-start/main/LICENSE
#>

<#
    .SYNOPSIS
    See description.
    .DESCRIPTION
    Wipes the Star Citizen "USER" and "shaders" folders before invoking the launcher, while preserving and restoring any user preferences and custom controls mapping files.
    .PARAMETER InstallLocation
    The path to the RSI Launcher directory. If omitted, the script will attempt to obtain the path from the Windows registry.
    .EXAMPLE
    ozo-sc-fresh-start -InstallLocation "C:\Program Files\Roberts Space Industries\RSI Launcher"
    .LINK
    https://github.com/onezeroone-dev/ozo-sc-fresh-start
#>

[CmdLetBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $false,HelpMessage="[Optional] absolute path to the RSI Launcher directory.")][String]$InstallLocation = (Get-ItemProperty -Path "HKLM:SOFTWARE\81bfc699-f883-50c7-b674-2483b6baae23").InstallLocation
)

Class CustomFile {
    # PROPERTIES: Strings, Xml
    [String] $File64 = $null
    [String] $Path   = $null
    [String] $Type   = $null
    [Xml]    $XML    = $null
    # PROPERTIES: Lists
    [System.Collections.Generic.List[String]] $Messages = @()
    # METHODS
    # Contructor method
    CustomFile($filePath,$fileType) {
        # Set properties
        $this.Path = $filePath
        $this.Type = $fileType.ToLower()
        # Read the XML
        $this.ReadFile()
    }
    # Read data method
    Hidden [Void] ReadFile()  {
        # Switch on Type
        Switch($this.Type) {
            "character" {
                $this.File64 = (Get-OZOFileToBase64 -Path $this.Path)
            }
            "controls" {
                $this.XML = (Get-Content -Path $this.Path)
            }
            default {
                $this.Messages.Add("Unhandled file type.")
            }
        } 
    }
    # Write data method
    Hidden [Void] WriteFile() {
        # Switch on Type
        Switch($this.Type) {
            "character" {
                Set-OZOBase64ToFile -Base64 $this.File64 -Path $this.Path
            }
            "controls" {
                $this.XML.Save($this.Path)
            }
            default {
                $this.Messages.Add("Unhandled file type.")
            }
        } 
    }
}

Class SCMain {
    # PROPERTIES: Booleans, Strings
    [Boolean] $Validates      = $true
    [String]  $rsiLauncherDir = $null
    [String]  $rsiDir         = $null
    [String]  $userDir        = $null
    [String]  $mappingsDir    = $null
    [String]  $charactersDir  = $null
    [String]  $shadersDir     = $null
    # PROPERTIES: PSCustomObjects
    [PSCustomObject] $ozoLogger = (New-OZOLogger)
    # PROPERTIES: Lists
    [System.Collections.Generic.List[PSCustomObject]] $customFiles   = @()
    # METHODS
    # Constructor method
    SCMain($InstallLocation) {
        # Set properties
        $this.rsiLauncherDir = $InstallLocation
        $this.rsiDir         = (Split-Path $this.rsiLauncherDir -Parent)
        $this.userDir        = (Join-Path -Path $this.rsiDir -ChildPath "StarCitizen\LIVE\user")
        $this.mappingsDir    = (Join-Path -Path $this.userDir -ChildPath "client\0\Controls\Mappings")
        $this.charactersDir  = (Join-Path -Path $this.userDir -ChildPath "client\0\CustomCharacters")
        $this.shadersDir     = (Join-Path -Path (Get-ChildItem -Path Env:LOCALAPPDATA).Value -ChildPath "Star Citizen")
        # Declare ourselves to the world
        $this.ozoLogger.Write("Starting process.","Information")
        # Validate the configuration and environment
        If (($this.ValidateConfiguration() -And $this.ValidateEnvironment()) -eq $true) {
            # Configuration and environment validate; call fresh start
            $this.FreshStart()
        }
        # Report
        $this.ozoLogger.Write("Process complete.","Information")
    }
    # Validate configuration method
    Hidden [Boolean] ValidateConfiguration() {
        # Control variable
        [Boolean] $Return = $true
        # Determine if rsiLauncherDir is null or empty
        If ([String]::IsNullOrEmpty($this.rsiLauncherDir) -eq $true) {
            # rsiLauncherDir is null or empty
            $this.ozoLogger.Write("Unable to obtain value for RSI Launcher directory.","Error")
            $Return = $false
        }
        # Return
        return $Return
    }
    # Validate environment method
    Hidden [Boolean] ValidateEnvironment() {
        # Control variable
        [Boolean] $Return = $true
        # Iterate through the paths
        ForEach ($Path in $this.rsiLauncherDir,$this.rsiDir,$this.userDir,$this.mappingsDir,$this.charactersDir,$this.shadersDir) {
            # Determine if the path is readable
            If ((Test-OZOPath -Path $Path) -eq $false) {
                $this.ozoLogger.Write(("Path not found: " + $Path),"Error")
                $Return = $false
            }
        }
        # Return
        return $Return
    }
    # Fresh start method
    Hidden [Void] FreshStart() {
        # Properties
        [Boolean] $Wait = $true
        # Report
        Write-Host ("RSI Directory          : " + $this.rsiDir)
        Write-Host ("RSI Launcher Directory : " + $this.rsiRSILauncherDir)
        Write-Host ("USER Dir               : " + $this.userDir)
        Write-Host ("Control mappings Dir   : " + $this.mappingsDir)
        Write-Host ("Custom Characters Dir  : " + $this.charactersDir)
        Write-Host ("Shaders Directory      : " + $this.shadersDir)
        # Iterate through the custom characters chf files
        ForEach ($childItem in Get-ChildItem -Filter "*.chf" -Path $this.charactersDir) {
            $this.customFiles.Add(([CustomFile]::new($childItem.FullName,"Character")))
        }
        # Iterate through the control mapping xml files
        ForEach ($childItem in Get-ChildItem -Filter "*.xml" -Path $this.mappingsDir) {
            $this.customFiles.Add(([CustomFile]::new($childItem.FullName,"Controls")))
        }
        # Wipe the USER folder
        If (Test-Path $this.userDir) {
            Get-Item -Path $this.userDir | Remove-Item -Recurse -Force
        }
        # Wipe the shaders folder
        If (Test-Path $this.shadersDir) {
            Get-ChildItem -Path $this.shadersDir -Recurse | Remove-Item -Recurse -Force
        }
        # Start Star Citizen Launcher
        Start-Process -File "RSI Launcher.exe" -WorkingDirectory $this.rsiRSILauncherDir
        # Wait until user starts Star Citizen
        While ($Wait -eq $true) {
            Try {
                Get-Process -Name "StarCitizen" -ErrorAction Stop
                $Wait = $false
            } Catch {
                $Wait = $true
                Write-Host ("Waiting for user to Launch Game.")
                Start-Sleep -Seconds 3
            }
        }
        # Wait for the game to re-create the mappingsDir
        While (-Not(Test-Path -Path $this.mappingsDir)) {
            Start-Sleep -Seconds 1
        }
        # Write out the custom files
        ForEach ($customFile in $this.customFiles) {
            $customFile.WriteFile()
        }
    }
    
}

[SCMain]::new($InstallLocation) | Out-Null
