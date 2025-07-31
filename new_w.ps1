#Requires -Version 7 -PSEdition Core

# Parameters
[CmdLetBinding()]
Param(
    [ValidateRange(1,60)]
    [Int]$WaitTime=5,

    [ValidateSet("CPU","MEM(MB)","MEM%", "NPM(KB)", "PID", "StartTime")]
    [String]$PriorityStat="CPU",

    [ValidateRange(1,20)]
    [Int]$NumberProcesses=20,

    [ValidateSet("Black", "DarkBlue", "DarkGreen", "DarkCyan", "DarkRed", "DarkMagenta", "DarkYellow", "Gray", "DarkGray", "Blue", "Green", "Cyan", "Red", "Magenta", "Yellow", "White")]
    [String]$BackgroundColor=[Console]::BackgroundColor,

    [ValidateSet("Black", "DarkBlue", "DarkGreen", "DarkCyan", "DarkRed", "DarkMagenta", "DarkYellow", "Gray", "DarkGray", "Blue", "Green", "Cyan", "Red", "Magenta", "Yellow", "White")]
    [String]$TextColor=[Console]::ForegroundColor,

    [Switch]$ErrorLog
)

# Functions

Function Format-Text
{
    # Parameters
    Param(
        [Parameter(Mandatory=$True)]
        [String]$Text,

        [Switch]$Centered
    )

    # Variables
    $ConsoleWidth = [Console]::WindowWidth

    # Begins formatting based on the selected switch
    if ($Centered)
    {
        $LeftPadding = [math]::Floor(($ConsoleWidth - $Text.Length) / 2)
        $RightPadding = $ConsoleWidth - $Text.Length - $LeftPadding
        $Text = (' ' * $LeftPadding) + $Text + (' ' * $RightPadding)
    }
    elseif ($Text) { } # Any other boolean switch you'd like to add

    Return $Text
}

Function Write-ProgramHeader
{
    Param(
        [Parameter(Mandatory=$True)]
        [Int]$WaitTime,

        [Parameter(Mandatory=$True)]
        [String]$TextColor,

        [Parameter(Mandatory=$True)]
        [String]$BackgroundColor,

        [Parameter(Mandatory=$True)]
        [String]$NumberProcesses

    )

    # Spelling formatter for correct grammar usage
    if ($WaitTime -gt 1)
    {
        $Spelling = "seconds"
    }
    else
    { 
        $Spelling = "second"
    }
    
    # Variables
    $Header = Format-Text -Text "Wtop - PowerShell Terminal Process Viewer" -Centered
    $Description = Format-Text -Text "Displays top $NumberProcesses of $PriorityStat consuming processes, updated every $WaitTime $Spelling." -Centered
    $Instructions = Format-Text -Text "Press Ctrl+C to exit" -Centered
    $ConsoleWidth = [Console]::WindowWidth
    $LineSeparator = '-' * $ConsoleWidth

    # Create and display program header + instruction
    Write-Host $Header -BackgroundColor $BackgroundColor -ForegroundColor $TextColor
    Write-Host $Instructions -BackgroundColor $BackgroundColor -ForegroundColor $TextColor
    Write-Host $Description -BackgroundColor $BackgroundColor -ForegroundColor $TextColor
    Write-Host $LineSeparator -BackgroundColor $BackgroundColor -ForegroundColor $TextColor
}

Function Set-WindowTitle
{
    Param(
        [Parameter(Mandatory=$True)]
        [String]$Text
    )

    [Console]::Title = $Text
}

Function Get-TopFormatProcess
{
    $Processess = Get-CimInstance -Query "SELECT * FROM Win32_Process"
    $PhysicalMemoryCapacity = ((Get-CimInstance -Query "SELECT * FROM Win32_PhysicalMemory") | Measure-Object -Property Capacity -Sum).Sum

    $ObjectArray = @()

    ForEach ($Process in $Processess)
    {
        $PowerShellProcess = Get-Process -Id $Process.ProcessId | Select -First 1
        
        $Object = [PSCustomObject]@{
        "PID" = $Process.ProcessId
        "NAME" = $PowerShellProcess.Name
        "DESCRIPTION" = $Process.Description
        "CPU" = if ($PowerShellProcess.CPU) {[Math]::Round($PowerShellProcess.CPU,1)} else {0.0}
        "MEM(MB)" = if ($PowerShellProcess.WorkingSet64) {[Math]::Round($PowerShellProcess.WorkingSet64 / 1MB, 1)} else {0.0}
        "MEM%" = [Math]::Round(($PowerShellProcess.WorkingSet64 / $PhysicalMemoryCapacity) * 100, 1)
        "NPM(KB)" = if ($PowerShellProcess.NonpagedSystemMemorySize64) {[Math]::Round(($PowerShellProcess.NonpagedSystemMemorySize64 / 1KB),1)} else {0.0}
        "StartTime" = if ($PowerShellProcess.StartTime) {(Get-Date ($PowerShellProcess.StartTime) -Format "ddMMMyy H:m").ToUpper()} else {'-'}
        }

        $ObjectArray += $Object
    }

    $ObjectArray
}

Function Write-LogFile
{
    Param(
        [Parameter(Mandatory=$True)]
        [Boolean]$IsActive,

        [Parameter(Mandatory=$True)]
        [String]$File,

        [Parameter(Mandatory=$True)]
        [String]$Message,

        [Parameter(Mandatory=$False)]
        [ValidateSet("INFO", "DEBUG", "WARN", "ERR")]
        [String]$LogLevel = "INFO"

    )

    $CurrentTime = Get-Date -UFormat "%m-%d-%y %H:%M:%S"
    $Hostname = $env:COMPUTERNAME
    $Message = "[$Hostname : $CurrentTime : $LogLevel] " + $Message

    if ($IsActive)
    {
        try
        {
            Write-Output -InputObject $Message | Out-File $File -Append
        }
        catch
        {
            Write-Error "Could not write logs to $File"
        }
    }
}

# Variables
$WindowTitle = "Wtop - PowerShell Terminal Process Viewer"
$ClearingSpace = ' ' * (([Console]::WindowWidth) * ([Console]::WindowHeight - 5))
$LogFile = ".\WTop_Logs.txt"

# Pre-process display tasks
Write-LogFile -LogLevel INFO -IsActive $ErrorLog -File $LogFile -Message "Started WTop"

[Console]::CursorVisible = $False
Clear-Host
Write-LogFile -LogLevel INFO -IsActive $ErrorLog -File $LogFile -Message "Cleared host console"

Write-ProgramHeader -WaitTime $WaitTime -TextColor $TextColor -BackgroundColor $BackgroundColor -NumberProcesses $NumberProcesses
Write-LogFile -LogLevel INFO -IsActive $ErrorLog -File $LogFile -Message "Wrote the program header to the user's console"

Set-WindowTitle -Text $WindowTitle
Write-LogFile -LogLevel INFO -IsActive $ErrorLog -File $LogFile -Message "Set the Window title to $WindowTitle"

# Gets the current cursor position for reference
$CursorReferencePoint = $Host.Ui.RawUI.CursorPosition
Write-LogFile -LogLevel INFO -IsActive $ErrorLog -File $LogFile -Message "Obtained current cursor location and saved reference point"

$Counter = 0
while ($True)
{
    $Counter++
    Write-LogFile -LogLevel INFO -IsActive $ErrorLog -File $LogFile -Message "Begining WTop refresh cycle $Counter"

    # Clears the screen from the reference point
    $Host.Ui.RawUI.CursorPosition = $CursorReferencePoint
    Write-LogFile -LogLevel INFO -IsActive $ErrorLog -File $LogFile -Message "Set the user's cursor to reference point location"
    Write-Host "`r$ClearingSpace"
    Write-LogFile -LogLevel INFO -IsActive $ErrorLog -File $LogFile -Message "Cleared the user's console space"

    Write-LogFile -LogLevel INFO -IsActive $ErrorLog -File $LogFile -Message "Set the user's cursor to reference point location"
    $Host.Ui.RawUI.CursorPosition = $CursorReferencePoint

    # Refreshes the system information
    Write-LogFile -LogLevel INFO -IsActive $ErrorLog -File $LogFile -Message "Running Get-TopFormatProcess"
    Get-TopFormatProcess | Sort-Object -Property $PriorityStat -Descending | Select -First $NumberProcesses | Format-Table -AutoSize -Wrap

    Write-LogFile -LogLevel INFO -IsActive $ErrorLog -File $LogFile -Message "Displayed WTop console to user"
    Write-LogFile -LogLevel INFO -IsActive $ErrorLog -File $LogFile -Message "Waiting for refresh in $WaitTime second(s)"

    # Starts the wait time and loops
    Start-Sleep -Seconds $WaitTime
}

