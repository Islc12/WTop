[CmdletBinding()]
param (
       [string]$ComputerName,
       [switch]$Spawned
      )

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

    if ($ComputerName -eq $null) {
        $ComputerName = 'localhost'
    }
           
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
              WaitTime        = 3
              PriorityStat    = "CPU"
              NumberProcesses = $Host.UI.RawUI.WindowSize.Height - 11
              BackgroundColor = $BackgroundANSI16
              TextColor       = "White"
              ErrorLog        = $False
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
