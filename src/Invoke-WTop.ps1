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
    Specifies the name or IP address of the remote computer to connect to. This parameter is required for the script to run.

.EXAMPLE
    Invoke-WTop.ps1 -ComputerName "RemotePC"

    Runs Invoke-Wtop and connects to the remote computer named "RemotePC". A new console host window will open on the local machine displaying the top processes and their resource usage on the remote machine in real-time.

.NOTES
    Version: 0.1 (Prototype)
    Author: Rich Smith (Islc12)
    Date: 4MAR2026
    License: GNU General Public License v3.0
#>

# ------------------------------------------------------------------
# Establish the required parameters
# ------------------------------------------------------------------
[CmdletBinding()]
param (
       [string]$ComputerName=$null,
       [switch]$Spawned
      )

# At this time this script is designed to only work with a remote computer name or IP address. 
# Localhost is not supported because the script utilizes the Invoke-Command cmdlet to execute WTop on the remote machine.
# Without the user taking special WinRM configuration steps into account, the script will not able to properly execute.
# This will not be addressed in future updates, as the main purpose of this script is to provide a way to run WTop on a remote machine, not locally.
# For local use, simply run WTop directly in a PowerShell console host window.
if (-not $ComputerName) {
    Write-Warning "No remote device provided. Please provide a computer name or IP address to connect to. Example: Invoke-WTop -ComputerName 'RemotePC'"
    exit 1
}
elseif ($ComputerName -like "localhost" -or $ComputerName -like "127*") {
    Write-Warning "Local host is not supported. Please provide a remote computer name or IP address to connect to. Example: Invoke-WTop -ComputerName 'RemotePC'"
    exit 1
}
  
# Temporary file to store credentials for remote session. Used to applying credentials to the newly spawned console host session.
$CredFile = "$env:TEMP\wtop_cred.xml"
# Path to WTop
$filePath = "$PSScriptRoot\wtop.ps1"

# ------------------------------------------------------------------
# Ensure we are running inside classic Console Host (conhost.exe)
# ------------------------------------------------------------------
if (-not $Spawned) {
    $Credential = Get-Credential
    $Credential | Export-Clixml -Path $CredFile
    $pwsh = "$env:ProgramFiles\PowerShell\7\pwsh.exe"
    $cmd = @(
             '-NoExit'
             '-ExecutionPolicy', 'Bypass'
             '-Command',
             "& '$PSCommandPath' -ComputerName '$ComputerName' -Spawned"
            ) -join ' '
  
    Start-Process -FilePath "$env:SystemRoot\System32\conhost.exe"  -ArgumentList "$pwsh $cmd" 
   
    exit
}

# ------------------------------------------------------------------
# Main Code - Running inside Console Host
# ------------------------------------------------------------------
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
              WaitTime        = 3 # 3 second wait time helps to reduce polling and allows for the user to read stats without it being too fast.
              PriorityStat    = "CPU"
              NumberProcesses = $Host.UI.RawUI.WindowSize.Height - 11
              BackgroundColor = $BackgroundANSI16
              TextColor       = "White" # Set to white for better contrast with random background color
              ErrorLog        = $False # Keep in mind that if you set this to $True, the log file will be created on the remote machine, not locally
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

Invoke-Command @invokeParams

# Cleanup credentials file
Remove-Item -Path $CredFile -ErrorAction SilentlyContinue
