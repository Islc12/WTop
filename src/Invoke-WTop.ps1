# Invoke-WTop - wrapper script to run WTop on a remote machine
# Copyright (C) 2025 Richard Smith (Islc12)
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <https://www.gnu.org/licenses/>.

###########################################################################################################################################################
<# 
.SYNOPSIS
    Invoke-WTop is a script used to gather a collection of the top processes and their resource usage on a remote machine. It is designed to be run from a local machine and connect to a remote machine using PowerShell remoting. The script will then spawn a new console host window on the local machine that will display the top processes and their resource usage on the remote machine in real-time. 

.DESCRIPTION
    The script uses the Invoke-Command cmdlet to execute the WTop script on the remote machine using a series of predetermined WTop parameters. The WTop script is a custom script that gathers the top processes and their resource usage on the remote machine and outputs it in a format that can be displayed in the console host window. The script also allows for some customization of the output, such as the wait time between updates, the priority stat to sort by, and the number of processes to display.

.PARAMETER ComputerName
    Specifies the name or IP address of the remote computer to connect to. This parameter is optional. If not provided, the script will spawn a new console host window on the local machine and run WTop locally.

.EXAMPLE
    Invoke-WTop.ps1

    Runs Invoke-Wtop and connects to the local machine. A new console host window will open on the local machine displaying the top processes and their resource usage on the local machine in real-time.

.EXAMPLE
    Invoke-WTop.ps1 -ComputerName "RemotePC"

    Runs Invoke-Wtop and connects to the remote computer named "RemotePC". A new console host window will open on the local machine displaying the top processes and their resource usage on the remote machine in real-time.

.NOTES
    Version: 0.1 (Prototype)
    Author: Rich Smith (Islc12)
    Date: 4MAR2026
    License: GNU General Public License v3.0

    See Get-Help WTop for more information on the WTop script and its parameters.
#>

#Requires -Version 7

# Set the basic parameters for the script. If this is run locally, the script will be able to use the same parameters as WTop,
# but if it is run remotely, the parameters will be used to invoke WTop on the remote machine with the default parameters used for WTop.
# The only exception is that remote sessions will have a random background color for better visibility and contrast with the text color.
[CmdletBinding()]
param (
    [string]$ComputerName=$null,
    [switch]$Spawned,
    [single]$WaitTime=3,
    [string]$PriorityStat="CPU",
    [string]$BackgroundColor=$Host.UI.RawUI.BackgroundColor,
    [string]$TextColor=$Host.UI.RawUI.ForegroundColor,
    $ErrorLog="False" # Accept any type (bool, string, etc.). Proper validation occurs in Get-ValidBoolInput function.
    )

Function Get-ValidBoolInput {
    if ($ErrorLog -isnot [bool]) {
        switch -Regex ($ErrorLog) {
            '^(?i:true|1)$' { $ErrorLog = $true; break }
            '^(?i:false|0)$' { $ErrorLog = $false; break }
            default {
                Write-Warning "ErrorLog value '$ErrorLog' is not a valid boolean. Value must be true/false, `$true/`$false, or 1/0."
                exit 1
            }
        }
    }
}

# Path to WTop
$filePath = "$PSScriptRoot\wtop.ps1"

# # Temporary file to store credentials for remote session. Used to applying credentials to the newly spawned console host session.
# $CredFile = "$env:TEMP\wtop_cred.xml"

Function Invoke-WTopLocal {
     # Ensure we are running inside classic Console Host (conhost.exe)
    if (-not $Spawned) {
        $pwsh = "$env:ProgramFiles\PowerShell\7\pwsh.exe"
        $cmd = @(
                '-NoExit'
                '-ExecutionPolicy', 'Bypass'
                '-Command',
                "& '$filePath' -WaitTime $WaitTime -PriorityStat '$PriorityStat' -BackgroundColor '$BackgroundColor' -TextColor '$TextColor' -ErrorLog:$ErrorLog"
                ) -join ' '
        Start-Process -FilePath "$env:SystemRoot\System32\conhost.exe"  -ArgumentList "$pwsh $cmd"
        exit
    }
}

Function Start-ConHostRemote {
    # Some IDE's may highlight this as a possible security risk. However, when we call 'Get-Credential', Windows already takes care of
    # ensuring the credentials are stored in a safe and secure manner.
    param([string]$CredFile)

    # Ensure we are running inside classic Console Host (conhost.exe)
    if (-not $Spawned) {
        $Credential = Get-Credential
        $Credential | Export-Clixml -Path $CredFile
        $pwsh = "$env:ProgramFiles\PowerShell\7\pwsh.exe"
        $cmd = @(
                '-NoExit'
                '-ExecutionPolicy', 'Bypass'
                '-Command',
                "& '$PSCommandPath' -ComputerName '$ComputerName' -Spawned -WaitTime $WaitTime -PriorityStat '$PriorityStat' -ErrorLog:$ErrorLog"
                ) -join ' '
    
        Start-Process -FilePath "$env:SystemRoot\System32\conhost.exe"  -ArgumentList "$pwsh $cmd" 
        exit
    }
}

Function Invoke-WTopRemote {
    # Some IDE's may highlight this as a possible security risk. However, when we call (Get-Credential), Windows already takes care of
    # ensuring the credentials are stored in a safe and secure manner.
    param([string]$CredFile)
    Start-ConHostRemote -CredFile $CredFile

    # Import credentials
    $Cred = Import-Clixml -Path $CredFile
    # Resize window (WTop depends on this)
    if ($Host.UI.RawUI.WindowSize.Width -ne 109) {
            [Console]::WindowWidth = 109
    }
    if ($Host.UI.RawUI.WindowSize.Height -ne 29) {
            [Console]::WindowHeight = 29
    }

    # Stabilize buffer
    $raw = $Host.UI.RawUI
    $raw.BufferSize = New-Object System.Management.Automation.Host.Size(109, 500)

    # Random background color
    $BackgroundANSI16 = "Black", "DarkBlue", "DarkGreen", "DarkRed", "DarkMagenta", "DarkGray" | Get-Random

    # Arguments for WTop
    $listArgs = @{
                WaitTime        = $WaitTime # Default is 3 seconds, which helps to reduce polling and allows for the user to read stats without it being too fast.
                PriorityStat    = $PriorityStat # Default is CPU, but can be set to any valid WTop stat such as Memory, Disk, Network, etc.
                NumberProcesses = $Host.UI.RawUI.WindowSize.Height - 11
                BackgroundColor = $BackgroundANSI16
                TextColor       = "White" # Set to white for better contrast with random background color
                ErrorLog        = $ErrorLog # Default is $False, but if you set this to $True, the log file will be created on the remote machine, not locally.
    }

    # Invoke-Command parameters
    $invokeParams = @{
        ComputerName = $ComputerName
        FilePath = $filePath
        ArgumentList = @(
                        $listArgs.WaitTime,
                        $listArgs.PriorityStat,
                        $listArgs.NumberProcesses,
                        $listArgs.BackgroundColor,
                        $listArgs.TextColor,
                        $listArgs.ErrorLog
                        )
        Credential = $Cred
    }

    try {
        Invoke-Command @invokeParams
    } finally {
        # always attempt to delete the credentials file, even on interrupt
        Remove-Item -Path $CredFile -ErrorAction SilentlyContinue
    }
}

Function Invoke-Main {
    Get-ValidBoolInput
    # Validate ComputerName parameter and determine whether to run locally or remotely.
    # If ComputerName is not provided or is localhost/127.*.*.*/8, run locally. Otherwise, run remotely.
    if (-not $ComputerName -or $ComputerName -like "localhost" -or $ComputerName -like "127*") {
        Invoke-WTopLocal
        exit 1
    }
    else {
        # Temporary file to store credentials for remote session. Used to applying credentials to the newly spawned console host session.
        # This file is stored as a PSCredential object in XML format, which allows for secure storage of the credentials.
        $CredFile = "$env:TEMP\wtop_cred.xml"
        Invoke-WTopRemote -CredFile $CredFile
        exit 1
    }
}

Invoke-Main