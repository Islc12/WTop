# This is a prototype version for a PowerShell version of the Linux program Top, currently this has a varied number of bugs and almost no functionality.
# However, it does still work, even if on the most basic of levels and will provide the user with a baseline of information such as PID, Process Name, 
# CPU%, Memory usage, NPM, and start time. As time goes on I will continue to work on this script, hopefully building on it in such a manner that it can
# be adequately used across servers through use of cmdlets such as Invoke-Command.

[Console]::CursorVisible = $false
$rawUI = $Host.UI.RawUI
$initialBufferSize = $rawUI.BufferSize
$rawUI.BufferSize = @{ Width = $initialBufferSize.Width; Height = 1000 }

try {
    while ($true) {
        $cpuStats = Get-Counter '\Process(*)\% Processor Time'
        $totalMemory = (Get-CimInstance -ClassName Win32_ComputerSystem).TotalPhysicalMemory

        $procInfo = @{}
        Get-Process | ForEach-Object {
            $procInfo[$_.Name.ToLower()] = $_
        }

        $stats = $cpuStats.CounterSamples |
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

                $nameFixed = if ($rawName.Length -gt 45) {
                    $rawName.Substring(0, 45)
                } else {
                    $rawName.PadRight(45)
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

        $output = $stats | Format-Table -Property @{Label="ID";Expression={$_.ID};Width=6},
                                                @{Label="Name";Expression={$_.Name};Width=45},
                                                @{Label="CPU%";Expression={$_.CPUPercent};Width=7},
                                                @{Label="Memory(MB)";Expression={$_.MemoryMB};Width=10},
                                                @{Label="Mem%";Expression={$_.MemPercent};Width=4},
                                                @{Label="NPM(KB)";Expression={$_.NPM};Width=7},
                                                @{Label="Start Time";Expression={$_.StartTime};Width=15} | Out-String

        Write-Output $output

        Start-Sleep -Seconds 5
    }
}

finally {
    [Console]::CursorVisible = $true

}