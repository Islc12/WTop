# WTop - a process and resource usage script for PowerShell
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
    WTop is a script used to gather a collection of the top processes and their resource usage on a Windows machine.

.DESCRIPTION
    This is a prototype version of a process resource usage monitor written explicitly for PowerShell. The intended purpose is for a system administrator, or other relevant individual, to be able to monitor important system processes and the resources that they utilize though a PowerShell interface. The best way to run this is to simply Invoke-Command on a remote device. This allows the user to keep the script itself local and not have to add a separate program to n number of devices. Something that be especially important for space restricted remote systems. Currently this has a varied number of bugs and almost no functionality outside of the bare basics. However, it does still work, even if on the most basic of levels and will provide the user with a baseline of information such as PID, Process Name, CPU%, Memory usage, NPM, and start time. As time goes on I will continue to work on this script, hopefully building on it in such a manner that it can be adequately used across servers and other remote systems.

.PARAMETER WaitTime
    Specifies the wait time between updates in seconds. Defaults to 5 seconds.

.PARAMETER PriorityStat
    Specifies the priority statistic to sort by. Options are "CPU", "Memory", or "NPM". Defaults to "CPU".

.PARAMETER NumberProcesses
    Specifies the number of processes to display. Defaults to the maximum number of processes allowable by the current PowerShell window size.

.PARAMETER BackgroundColor
    Specifies the display background color. Default is system selection.

    *****NOTE*****
    In Windows Console Host the default background color is black. Even if you modify the background color through properties there won't actually be a color change to a black background.
    This color option is left in for users who, despite being advised against, choose to use Windows Terminal.

.PARAMETER TextColor
    Specifies the display text color. Default is system selection.

.PARAMETER ErrorLog
    Specifies whether to store errors in a log file in addition to displaying errors to standard output. Default during development and testing is $true, afterwards the default will be set to $false.

.EXAMPLE
    .\wtop.ps1

    Runs the script with default parameters.
.EXAMPLE
    .\wtop.ps1 -WaitTime 2

    Runs the script with a 2-second update interval.

.EXAMPLE
    .\wtop.ps1 -PriorityStat Memory

    Runs the script prioritizing the memory usage statistic.

.EXAMPLE
    .\wtop.ps1 -NumberProcesses 10

    Runs the script displaying the top 10 processes in order of priority (default priority is CPU usage).

.EXAMPLE
    .\wtop.ps1 -BackgroundColor DarkGray

    Runs the script with a dark gray background.
    Applicable colors are: Black, DarkBlue, DarkGreen, DarkCyan, DarkRed, DarkMagenta, DarkYellow, Gray, DarkGray, Blue, Green, Cyan, Red, Magenta, Yellow, White

        *****NOTE*****
    In Windows Console Host the default background color is black. Even if you modify the background color through properties there won't actually be a color change to a black background.
    This color option is left in for users who, despite being advised against, choose to use Windows Terminal.

.EXAMPLE
    .\wtop.ps1 -TextColor Black

    Runs the script with a black text color.
    Applicable colors are: Black, DarkBlue, DarkGreen, DarkCyan, DarkRed, DarkMagenta, DarkYellow, Gray, DarkGray, Blue, Green, Cyan, Red, Magenta, Yellow, White

.EXAMPLE
    .\wtop.ps1 -ErrorLog $false

    Runs the script without storing errors in a log file.

.EXAMPLE
    .\wtop.ps1 -WaitTime 10 -PriorityStat Memory -NumberProcesses 15

    Runs the script with a 10-second update interval, prioritizing memory usage, and displaying the top 15 processes.

.EXAMPLE
    $args = @(
            "-WaitTime", 3,
            "-PriorityStat", "Memory",
            "-BackgroundColor", "DarkCyan"
            )
    $path = "C:\Path\To\wtop.ps1"
    Invoke-Command -ComputerName "RemoteServer" -FilePath $path -ArgumentList $args

    Executes the script on a remote server with a 3-second update interval, prioritizing Memory usage, and using a DarkCyan background color with all other arguments set to their default.

.NOTES
Version: 0.1 (Prototype)
Author: Rich Smith (Islc12)
Date: 26JUN2025
License: GNU General Public License v3.0

Exit Codes:
    0    - Successful execution and exit
    1    - WaitTime MIN user input error (e.g., WaitTime less than 1 second)
    2    - WaitTime MAX user input error (e.g., WaitTime greater than 60 seconds)
    4    - PriorityStat user input error (e.g., Invalid PriorityStat value)
    8    - NumberProcesses MAX user input error (e.g., NumberProcesses exceeds maximum allowed)
    16   - NumberProcesses MIN user input error (e.g., NumberProcesses exceeds minimum allowed)
    32   - User input error (e.g., Unsupported color choice for shell background)
    64   - User input error (e.g., Unsupported color choice for shell text)
    128  - Unexpected error occurred during execution
    254  - Failed attempt to run on an application other than Windows Console Host
    255  - Failed atempt to run on a non-Windows operating system

    Exit codes different than this are the result of multiple exit codes added together, meaning there were multiple errors which caused WTop to stop early. For example, an exit code of 9 would be exit code 1 + exit code 8, would mean that there was a WaitTime MIN user input error (Exit 1) and NumberProcesses MAX user input error (Exit 8).
#>

###########################################################################################################################################################

# Default parameters
# 5 second interval between process updates
# CPU is the primary statistic display
# Total number of processes displayed is based on the users current PowerShell window height
# Sets the default values for background and text color to the current shell default
param(
    # Allows for a refresh rate of no less than 1.401298E-45 seconds. This however isn't going to be possible on probably anything other than a quantom computer.
    [single]$WaitTime=5,
    [string]$PriorityStat="CPU",
    [int]$NumberProcesses=$Host.UI.RawUI.WindowSize.Height - 10,
    [string]$BackgroundColor=$Host.UI.RawUI.BackgroundColor,
    [string]$TextColor=$Host.UI.RawUI.ForegroundColor,
    [bool]$ErrorLog=$True #Default value of $True will change to $False after development and testing
)

## Variables
$rawUI = $Host.UI.RawUI
$PID_LEN = 8
$NAME_LEN = 15
$DESC_LEN = 35
$CPU_LEN = 5
$MEMMB_LEN = 10
$MEMPERC_LEN = 5
$NPM_LEN = 7
$STARTTIME_LEN = 13
$DEAD_SPACE = 8
$windowWidth = $PID_LEN + $NAME_LEN + $DESC_LEN + $CPU_LEN + $MEMMB_LEN + $MEMPERC_LEN + $NPM_LEN + $STARTTIME_LEN + $DEAD_SPACE
if ($rawUI.WindowSize.Width -lt $windowWidth) { [Console]::WindowWidth = $windowWidth }
$initialCursorPosition = $rawUI.CursorPosition 
$initialWindowTitle = $rawUI.WindowTitle
$windowHeight = $rawUI.WindowSize.Height
$validNumProcessInput = $windowHeight - 10
$exitCode = $null
$restartLine = $null
$ANSI16 = "Black", "DarkBlue", "DarkGreen", "DarkCyan", "DarkRed", "DarkMagenta", "DarkYellow", "Gray", "DarkGray", "Blue", "Green", "Cyan", "Red", "Magenta", "Yellow", "White"

## Functions
# Checks for valid use interfaces of both Windows OS and Windows Console Host
function Get-ValidInterfaces {
    # This is a Windows only PowerShell script and so this prevents it from being run on another type operating system
    if ((Get-CimInstance Win32_OperatingSystem) -notmatch "Microsoft Windows") {
        Write-Warning "WTop can only be run on a Microsoft Windows Operating System."
        exit 255
    }

    # Enforces that this program should only be run using Windows Console Host and that any other terminal enviroment will either not work OR require 
    # that the user modifies the source code to make it run.
    if ($env:WT_SESSION) {
        Write-Warning "WTop is designed to be run with Windows Console Host`nModifications may be made to the source code to alter this. However, there is no gurantee on the reliablity of the program if altered."
        exit 254
    }
}

# Used to center text within a given width
function Format-CenteredText {
    param (
        [string]$Text,
        [int]$Width
    )
    $padLeft = [math]::Max(0, [math]::Floor(($Width - $Text.Length) / 2))
    $padRight = [math]::Max(0, $Width - $Text.Length - $padLeft)
    return (' ' * $padLeft) + $Text + (' ' * $padRight)
}

# Used for program header text
function Set-ProgramHeader {
    # Spelling formatter for correct grammar usage
    $spelling = if ($WaitTime -eq 1) { "second" } else { "seconds" }
    $formatWidth = $windowWidth - 1 # -1 to account for the blank space at right edge of the console window 

    # Create and display program header + instruction
    $header = Format-CenteredText -Text "Wtop - PowerShell Terminal Process Viewer" -Width $formatWidth
    $instructions = Format-CenteredText -Text "Press Ctrl+C to exit" -Width $formatWidth
    $details = Format-CenteredText -Text "Displays top $NumberProcesses of $PriorityStat consuming processes, updated every $waitTime $spelling." -Width $formatWidth
    $separator = '-' * $formatWidth
    Write-Host $header -BackgroundColor $BackgroundColor -ForegroundColor $TextColor
    Write-Host $instructions -BackgroundColor $BackgroundColor -ForegroundColor $TextColor
    Write-Host $details -BackgroundColor $BackgroundColor -ForegroundColor $TextColor
    Write-Host $separator -BackgroundColor $BackgroundColor -ForegroundColor $TextColor
}

# Used to validate user input parameters
function Get-ValidInputs {
    # Manual validation for WaitTime parameter with custom exit codes
    if ($WaitTime -le 0) {
        Write-Warning "WaitTime must be greater than 0 seconds."
        $exitCode = $exitcode + 1
        $restartLine = $restartLine + 1
    } elseif ($WaitTime -gt 60) {
        Write-Warning "WaitTime greater than 60 seconds is not recommended."
        $exitCode = $exitcode + 2
        $restartLine = $restartLine + 1
    }

    # Manual validation for PriorityStat parameter with custom exit code
    if ($PriorityStat -notin @("CPU","Memory","NPM")) {
        Write-Warning "PriorityStat must be 'CPU', 'Memory', or 'NPM'."
        $exitCode = 4
        $restartLine = $restartLine + 1
    }
    # Warning and exit if the user inputs too many processes to display, as this causes display issues.
    ### Eventually I will try to add scrolling functionality to allow for more processes to be displayed, but for now this is a hard limit.
    if ($NumberProcesses -gt $validNumProcessInput) {
        $warningText = "NumberProcesses greater than $validNumProcessInput causes display issues. `n`tEnlarge window, reduce number of processes, or use the default value."
        Write-Warning $warningText
        $exitCode = $exitcode + 8
        $restartLine = $restartLine + 2
    } elseif ($NumberProcesses -le 0) {
        Write-Warning "Invalid number of processes entered, enter an amount greater than 0."
        $exitcode = $exitcode + 16
        $restartLine = $restartLine + 1
    }

    # Warning and exit due to invalid user input for BackgroundColor, and then gives the user a list of colors they can use
    if ($BackgroundColor -notin ($ANSI16)) {
        Write-Warning "BackgroundColor of $BackgroundColor is not a supported ANSI standard-16 color.`n`tAvailable choices are: $ANSI16"
        $exitCode = $exitcode + 32
        $restartLine = $restartLine + 3
    }

    # Warning and exit due to invalid user input for TextColor, and then gives the user a list of colors they can use
    if ($TextColor -notin ($ANSI16)) {
        Write-Warning "TextColor of $TextColor is not a supported ANSI standard-16 color.`n`tAvailable choices are: $ANSI16"
        $exitCode = $exitcode + 64
        $restartLine = $restartLine + 3
    }

    # If an exit code is produced this will stop the program, we're using this so a user can reference exit codes formulated by any errors
    if ($exitCode) {
        Exit $exitCode
    }
}

Get-ValidInterfaces
Get-ValidInputs 
$rawUI.CursorPosition = @{X=0;Y=$($initialCursorPosition.Y + 1)}

try {
    $rawUI.WindowTitle = "WTop - PowerShell Process Viewer"

    try {
        [Console]::CursorVisible = $false
    } catch { # If no console handle available, skip - typically the case for Invoke-Command
    }

    for ($i -eq 0; $i -lt $windowHeight; $i++){
        Write-Host ""
    }

    $rawUI.CursorPosition = @{X=0;Y=$($initialCursorPosition.Y + 1)}
    $newCursorPosition = $rawUI.CursorPosition

    Set-ProgramHeader

    while ($true) {
        # Gather CPU stats for all processes
        $cpuStats = Get-Counter '\Process(*)\% Processor Time' -ErrorAction SilentlyContinue

        # Get total physical memory for memory percentage calculations
        $totalMemory = (Get-CimInstance -ClassName Win32_ComputerSystem).TotalPhysicalMemory
        $validSamples = $cpuStats.CounterSamples | Where-Object { $_.Status -eq 0 }

        # Create a hashtable of process info for quick lookup
        $procInfo = @{}
        Get-Process | ForEach-Object {
            $procInfo[$_.Name.ToLower()] = $_
        }

        # Process and aggregate CPU usage, normalize by logical CPU count
        $stats = $validSamples |
            Where-Object { $_.InstanceName -notmatch 'Idle|_Total|System' } |
            Group-Object InstanceName |
            ForEach-Object {
                $rawName = $_.Name
                $cleanName = $rawName -replace '#\d+$', ''

                # Sum CPU usage for all instances of the process
                $cpuPercent = ($_.Group | Measure-Object CookedValue -Sum).Sum

                # Normalize CPU% by number of logical processors
                $logicalCpuCount = [Environment]::ProcessorCount
                $normalizedCpu = [System.Math]::Round($cpuPercent / $logicalCpuCount, 1)

                # Get process details from the hashtable
                $proc = $procInfo[$cleanName.ToLower()]
                $workingSet = if ($proc) { $proc.WorkingSet64 } else { 0 }
                $npm = if ($proc) { $proc.NonpagedSystemMemorySize64 } else { 0 }
                $convertNPM = [System.Math]::Round($npm / 1KB, 1)
                $startTime = if ($proc -and $proc.StartTime) {
                                try {
                                    $proc.StartTime.ToString("ddMMMyy HH:mm").ToUpper().PadRight(13)
                                } 
                                catch { "      -      " }
                            } else { "      -      " }

                $procDescription = if ($proc -and $proc.Description) {
                                try {
                                    if ($proc.Description.Length -gt $DESC_LEN) {
                                    $proc.Description.Substring(0, [Math]::Min($DESC_LEN, $proc.Description.Length - 1))
                                    } else { $proc.Description }
                                } 
                                catch { "-" }
                            } else { "-" }

                # Calculate memory percentage
                $memPercent = if ($totalMemory -and $workingSet -gt 0) {
                    [System.Math]::Round(($workingSet / $totalMemory) * 100, 1)
                } else { "-" }

                # Ensure name fits within 15 characters
                $nameFixed = if ($rawName.Length -gt $NAME_LEN) {
                    $rawName.Substring(0, $NAME_LEN)
                } else {
                    $rawName.PadRight($NAME_LEN)
                }

                # Create a custom object for output
                [PSCustomObject]@{
                    Name        = $nameFixed
                    PID         = if ($proc) { $proc.Id } else { "-" }
                    CPUPercent  = $normalizedCpu
                    MemoryMB    = if ($proc) { [System.Math]::Round($workingSet / 1MB, 1) } else { 0 }
                    MemPercent  = $memPercent
                    NPM         = $convertNPM
                    StartTime   = $startTime
                    Description = $procDescription
                }
            }

            # Sort by user-specified priority stat - CPU by default
            switch ($PriorityStat) {
                "CPU"       { $stats = $stats | Sort-Object CPUPercent -Descending }
                "Memory"    { $stats = $stats | Sort-Object MemoryMB -Descending }
                "NPM"       { $stats = $stats | Sort-Object NPM -Descending }
                default     { $stats = $stats | Sort-Object CPUPercent -Descending }
            }
            
            # Limit to user-specified number of processes - 20 by default
            $stats = $stats | Select-Object -First $NumberProcesses

        # # Move cursor to top-left without clearing screen
        $rawUI.CursorPosition = $newCursorPosition

        # Used blank lines to skip over header and instructions
        for ($i = 0; $i -lt 3; $i++) {
            Write-Host ""
        }

        # Format and display the stats table
        $output = $stats | Format-Table -Property @{Label="PID     ";                 Expression={$_.PID}; Width=$PID_LEN; Alignment='Left'},
                                                            @{Label="Name           ";          Expression={$_.Name}; Width=$NAME_LEN},
                                                            @{Label="Description             "; Expression={$_.Description}; Width=$DESC_LEN},
                                                            @{Label=" CPU%";                    Expression={ "{0:N1}" -f $_.CPUPercent }; Width=$CPU_LEN; Alignment='Right'},
                                                            @{Label="Memory(MB)";               Expression={ "{0:N1}" -f $_.MemoryMB }; Width=$MEMMB_LEN; Alignment='Right'},
                                                            @{Label=" Mem%";                    Expression={ "{0:N1}" -f $_.MemPercent }; Width=$MEMPERC_LEN; Alignment='Right'},
                                                            @{Label="NPM(KB)";                  Expression={ "{0:N1}" -f $_.NPM }; Width=$NPM_LEN; Alignment='Right'},
                                                            @{Label="   Start Time";            Expression={$_.StartTime}; Width=$STARTTIME_LEN; Alignment='Center'} | Out-String

                                                            # Used to ensure Window Size remains greater than minimum size
        if ($rawUI.WindowSize.Width -lt $windowWidth) {
            [Console]::WindowWidth = $windowWidth
            $rawUI.CursorPosition = @{X=0;Y=$($initialCursorPosition.Y + 1)}
            $newCursorPosition = $rawUI.CursorPosition
        }
        if ($rawUI.WindowSize.Height -lt $windowHeight) {
            [Console]::WindowHeight = $windowHeight
        }

        # Print the results of $output table to the screen
        Write-Host $output -BackgroundColor $BackgroundColor -ForegroundColor $TextColor

        # Wait before the next update - 5 seconds by default
        Start-Sleep -Seconds $WaitTime
    }
}

# Catch block to handle unexpected errors and store them in a log file
catch {
    $errorOutput = $_.Exception.Message
    $DT = Get-Date -UFormat "%d%b%Y %H:%M:%S"
    Write-Warning "ERROR: An unexpected error occurred - $DT."
    Write-Warning $errorOutput
    if ($ErrorLog -eq $true) {
        Add-Content -Path "$PSScriptRoot\wtop_error.log" -Value "${DT}: $errorOutput"
    }
    $exitCode = 128
}

# Finally block to ensure cleanup actions are performed
finally {
    # Restore original Window Title and Buffer Size
    $rawUI.WindowTitle = $initialWindowTitle

    # Move cursor to just below process screen and make it visible again
    try {
        [Console]::CursorVisible = $true
    } catch {
        # Ignore if console handle unavailable - typically the case for Invoke-Command
    }
    # Reposition cursor to the appropriate position and exits with appropriate code
    if ($exitCode) {
        $rawUI.CursorPosition = @{X=0;Y=$initialCursorPosition.Y + $restartLine}
        Exit $exitCode
    } else {
        $rawUI.CursorPosition = @{X=0;Y=$newCursorPosition.Y + $NumberProcesses + 6}
        Exit $exitCode
    }
}