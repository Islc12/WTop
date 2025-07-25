
# WTop – Windows Top Processes Monitor

**Path:**  
`C:\Path\To\WTop\wtop.ps1`

## Synopsis

**WTop** is a PowerShell-based script used to monitor and display the top processes and their resource usage on a Windows machine.

---

## Syntax

```powershell
wtop.ps1 [[-WaitTime] <Single>] [[-PriorityStat] <String>] [[-NumberProcesses] <Int32>] [[-BackgroundColor] <String>] [[-TextColor] <String>] [<CommonParameters>]
```

---

## Description

This is a prototype version of a process monitoring tool built in PowerShell. It allows system administrators to observe important system processes and their associated resource usage such as:

- PID
- Process Name
- CPU %
- Memory usage
- NPM
- Start Time

**Best Usage:**  
Run using `Invoke-Command` on a remote machine to avoid installing additional software on endpoints — useful for space-restricted systems.

> **Note:**  
> Functionality is currently limited and includes some bugs. Future updates will enhance usability and expand features.

---

## Parameters

### `-WaitTime <Single>`
Specifies the interval (in seconds) between updates.  
**Default:** `5`

---

### `-PriorityStat <String>`
Specifies the sorting priority.  
**Options:** `CPU`, `Memory`, `NPM`  
**Default:** `CPU`

---

### `-NumberProcesses <Int32>`
Number of top processes to display.  
**Default:** Max number that fits current PowerShell window size

---

### `-BackgroundColor <String>`
Sets background color for display.  
**Default:** System selected.

> **Note:**  
> In **Windows Console Host**, setting background to black has no visual effect. This option is primarily intended for **Windows Terminal**.

**Available Colors:**  
`Black`, `DarkBlue`, `DarkGreen`, `DarkCyan`, `DarkRed`, `DarkMagenta`, `DarkYellow`, `Gray`, `DarkGray`, `Blue`, `Green`, `Cyan`, `Red`, `Magenta`, `Yellow`, `White`

---

### `-TextColor <String>`
Sets text (foreground) color for display.  
**Default:** System selected.

**Available Colors:**  
_Same list as `BackgroundColor`_

---

### `<CommonParameters>`
Supports all standard PowerShell common parameters like:
- `Verbose`
- `Debug`
- `ErrorAction`
- `ErrorVariable`
- `WarningAction`
- `WarningVariable`
- `OutBuffer`
- `PipelineVariable`
- `OutVariable`

More info: [about_CommonParameters](https://go.microsoft.com/fwlink/?LinkID=113216)

---

## Examples

### Example 1
```powershell
.\wtop.ps1
```
Runs the script with all default parameters.

---

### Example 2
```powershell
.\wtop.ps1 -WaitTime 2
```
Sets update interval to 2 seconds.

---

### Example 3
```powershell
.\wtop.ps1 -PriorityStat Memory
```
Sorts processes by **Memory usage**.

---

### Example 4
```powershell
.\wtop.ps1 -NumberProcesses 10
```
Displays the **top 10 processes** by CPU usage (default priority).

---

### Example 5
```powershell
.\wtop.ps1 -BackgroundColor DarkGray
```
Runs the script with a **DarkGray** background.

---

### Example 6
```powershell
.\wtop.ps1 -TextColor Black
```
Runs the script with **black** text.

---

### Example 7
```powershell
.\wtop.ps1 -WaitTime 10 -PriorityStat Memory -NumberProcesses 15
```
Runs the script with:
- 10-second update interval
- Memory usage sorting
- Top 15 processes shown

---

### Example 8
```powershell
$args = @(
    "-WaitTime", 3,
    "-PriorityStat", "Memory",
    "-BackgroundColor", "DarkCyan"
)
$path = "C:\Path\To\wtop.ps1"
Invoke-Command -ComputerName "RemoteServer" -FilePath $path -ArgumentList $args
```
Runs the script remotely with:
- 3-second update interval
- Memory usage sorting
- DarkCyan background
