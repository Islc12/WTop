# WTop - a Top like script for PowerShell
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

# This is a prototype version for the PowerShell version of the Linux program Top, except in PowerShell script form. The intended purpose is for a system
# administrator, or other relevant individual, to be able to monitor important system processes and the resources that they utilize though a PowerShell 
# interface. The best way to run this is to simply Invoke-Command on a remote device. This allows the user to keep the script itself local and not have to
# add a separate program to n number of devices. Something that be especially important for space restricted remote systems. Currently this has a varied 
# number of bugs and almost no functionality outside of the bare basics. However, it does still work, even if on the most basic of levels and will provide
# the user with a baseline of information such as PID, Process Name, CPU%, Memory usage, NPM, and start time. As time goes on I will continue to work on
# this script, hopefully building on it in such a manner that it can be adequately used across servers and other remote systems.

###########################################################################################################################################################

# Author: Rich Smith (Islc12)
# Date Started: 26JUN2025

###########################################################################################################################################################

# Allows the user to specify a wait time between updates, defaults to 5 seconds if no value is provided
param(
    [Int32]$WaitTime=5,
    [ValidateSet("CPU","Memory","NPM")][string]$PriorityStat="CPU",
    [Int32]$NumberProcesses=20
    )

# Stops the program before it starts if the user inputs too many processes to display, as this causes display issues.
# Eventually I will add scrolling functionality to allow for more processes to be displayed, but for now this is a hard limit.
if ($NumberProcesses -gt 35) {
    Write-Warning "NumberProcesses greater than 35 causes display issues. TERMINATING PROGRAM."
    break
}

# Used to provide a more seamless enviroment, keeps the program from starting where ever it wants to on the shell
[Console]::CursorVisible = $false
$rawUI = $Host.UI.RawUI
$initialBufferSize = $rawUI.BufferSize
$rawUI.BufferSize = @{ Width = $initialBufferSize.Width; Height = 1000 }

# Used to clear the terminal screen, avoiding any unintentional overlap in screen output
# In the future I will change this to not clear the screen, but rather to start the output at the top of the screen
# This will allow for a user to scroll up and see previous output if needed
Clear-Host

# Function to center text within a given width
function Center-Text {
    param (
        [string]$Text,
        [int]$Width
    )
    $padLeft = [math]::Max(0, [math]::Floor(($Width - $Text.Length) / 2))
    $padRight = [math]::Max(0, $Width - $Text.Length - $padLeft)
    return (' ' * $padLeft) + $Text + (' ' * $padRight)
}

$spelling = if ($WaitTime -eq 1) { "second" } else { "seconds" }
# Create and display program header + instruction
$header = Center-Text -Text "Wtop - PowerShell Terminal Process Viewer" -Width 115
$instructions = Center-Text -Text "Press Ctrl+C to exit" -Width 115
$details = Center-Text -Text "Displays top $NumberProcesses of $PriorityStat consuming processes, updated every $waitTime $spelling." -Width 115
$separator = '-' * 115
Write-Host $header -BackgroundColor DarkGray -ForegroundColor Yellow
Write-Host $instructions -BackgroundColor DarkGray -ForegroundColor Yellow
Write-Host $details -BackgroundColor DarkGray -ForegroundColor Yellow
Write-Host $separator -BackgroundColor DarkGray -ForegroundColor Yellow

try {
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
                $normalizedCpu = [math]::Round($cpuPercent / $logicalCpuCount, 2)

                # Get process details from the hashtable
                $proc = $procInfo[$cleanName.ToLower()]
                $workingSet = if ($proc) { $proc.WorkingSet64 } else { 0 }
                $npm = if ($proc) { $proc.NonpagedSystemMemorySize64 } else { 0 }
                $startTime = if ($proc -and $proc.StartTime) {
                                try {
                                    $proc.StartTime.ToString("ddMMMyy HH:mm").ToUpper().PadRight(15)
                                } 
                                catch { "-".PadRight(15) }
                            } else { "-".PadRight(15) }

                # Calculate memory percentage
                $memPercent = if ($totalMemory -and $workingSet -gt 0) {
                    [System.Math]::Round(($workingSet / $totalMemory) * 100, 2)
                } else { "-" }

                # Ensure name fits within 50 characters
                $nameFixed = if ($rawName.Length -gt 50) {
                    $rawName.Substring(0, 50)
                } else {
                    $rawName.PadRight(50)
                }

                # Create a custom object for output
                [PSCustomObject]@{
                    Name        = $nameFixed
                    ID          = if ($proc) { $proc.Id } else { "-" }
                    CPUPercent  = [System.Math]::Round($normalizedCpu, 2)
                    MemoryMB    = if ($proc) { [System.Math]::Round($workingSet / 1MB, 2) } else { "-" }
                    MemPercent  = $memPercent
                    NPM = [System.Math]::Round($npm / 1KB, 2)
                    StartTime = $startTime
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

        # Move cursor to top-left without clearing screen
        $rawUI.CursorPosition = @{X=0;Y=0}
        # Used blank lines to skip over header and instructions
        Write-Host ""
        Write-Host ""
        Write-Host ""

        # Format and display the stats table
        $output = $stats | Format-Table -Property @{Label="ID    ";                   Expression={$_.ID};Width=8;Alignment='Left'},
                                                  @{Label="Name                    "; Expression={$_.Name};Width=50},
                                                  @{Label="CPU%";                     Expression={$_.CPUPercent};Width=9},
                                                  @{Label="Memory(MB)";               Expression={$_.MemoryMB};Width=12},
                                                  @{Label="Mem%";                     Expression={$_.MemPercent};Width=6},
                                                  @{Label="NPM(KB)";                  Expression={$_.NPM};Width=9},
                                                  @{Label="Start Time     ";          Expression={$_.StartTime};Width=15;Alignment='Right'} | Out-String

        # Used for debugging invalid samples
        Write-Host $output -BackgroundColor DarkGray -ForegroundColor Yellow

        # Wait before the next update - 5 seconds by default
        Start-Sleep -Seconds $WaitTime
    }
}

finally {
    # Restore original buffer size and cursor visibility
    $rawUI.BufferSize = $initialBufferSize
    [Console]::CursorVisible = $true
}