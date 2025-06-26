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

# This is a prototype version for the PowerShell version of the Linux program Top, currently this has a varied number of bugs and almost no functionality.
# However, it does still work, even if on the most basic of levels and will provide the user with a baseline of information such as PID, Process Name, 
# CPU%, Memory usage, NPM, and start time. As time goes on I will continue to work on this script, hopefully building on it in such a manner that it can
# be adequately used across servers through use of cmdlets such as Invoke-Command.

###########################################################################################################################################################

# Author: Rich Smith (Islc12)
# Date Started: 26JUN2025

###########################################################################################################################################################

# Used to provide a more seamless enviroment, keeps the program from starting where ever it wants to on the shell
[Console]::CursorVisible = $false
$rawUI = $Host.UI.RawUI
$initialBufferSize = $rawUI.BufferSize
$rawUI.BufferSize = @{ Width = $initialBufferSize.Width; Height = 1000 }

# Used to clear the terminal screen, avoiding any unintentional overlap in screen output
Clear-Host
Write-Host "Terminal Task Manager" -BackgroundColor DarkGrey -ForegroundColor Yellow

try {
    while ($true) {
        $cpuStats = Get-Counter '\Process(*)\% Processor Time'
        $totalMemory = (Get-CimInstance -ClassName Win32_ComputerSystem).TotalPhysicalMemory
        $validSamples = $cpuStats.CounterSamples | Where-Object { $_.Status -eq 0 }

        $procInfo = @{}
        Get-Process | ForEach-Object {
            $procInfo[$_.Name.ToLower()] = $_
        }

        $stats = $validSamples |
            Where-Object { $_.InstanceName -notmatch 'Idle|_Total|System' } |
            Group-Object InstanceName |
            ForEach-Object {
                $rawName = $_.Name
                $cleanName = $rawName -replace '#\d+$', ''

                $cpuPercent = ($_.Group | Measure-Object CookedValue -Sum).Sum

                $logicalCpuCount = [Environment]::ProcessorCount
                $normalizedCpu = [math]::Round($cpuPercent / $logicalCpuCount, 2)

                $proc = $procInfo[$cleanName.ToLower()]
                $workingSet = if ($proc) { $proc.WorkingSet64 } else { 0 }
                $npm = if ($proc) { $proc.NonpagedSystemMemorySize64 } else { 0 }
                $startTime = if ($proc -and $proc.StartTime) {
                                try {
                                    $proc.StartTime.ToString("ddMMMyy HH:mm").ToUpper().PadRight(15)
                                } 
                                catch { "-".PadRight(15) }
                            } else { "-".PadRight(15) }

                $memPercent = if ($totalMemory -and $workingSet -gt 0) {
                    [System.Math]::Round(($workingSet / $totalMemory) * 100, 2)
                } else { "-" }

                $nameFixed = if ($rawName.Length -gt 40) {
                    $rawName.Substring(0, 40)
                } else {
                    $rawName.PadRight(40)
                }

                [PSCustomObject]@{
                    Name        = $nameFixed
                    ID          = if ($proc) { $proc.Id } else { "-" }
                    CPUPercent  = [System.Math]::Round($normalizedCpu, 2)
                    MemoryMB    = if ($proc) { [System.Math]::Round($workingSet / 1MB, 2) } else { "-" }
                    MemPercent  = $memPercent
                    NPM = [System.Math]::Round($npm / 1KB, 2)
                    StartTime = $startTime
                }
            } |
            Sort-Object CPUPercent -Descending |
            Select-Object -First 25

        # Move cursor to top-left without clearing screen
        $rawUI.CursorPosition = @{X=0;Y=0}

        $output = $stats | Format-Table -Property @{Label="ID    ";Expression={$_.ID};Width=8;Alignment='Left'},
                                                @{Label="Name                    ";Expression={$_.Name};Width=40},
                                                @{Label="CPU%";Expression={$_.CPUPercent};Width=9},
                                                @{Label="Memory(MB)";Expression={$_.MemoryMB};Width=12},
                                                @{Label="Mem%";Expression={$_.MemPercent};Width=6},
                                                @{Label="NPM(KB)";Expression={$_.NPM};Width=9},
                                                @{Label="Start Time     ";Expression={$_.StartTime};Width=15;Alignment='Right'} | Out-String

        Write-Host $output -BackgroundColor DarkGray -ForegroundColor Yellow

        Start-Sleep -Seconds 5
    }
}

finally {
    [Console]::CursorVisible = $true
}