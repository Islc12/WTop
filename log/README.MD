Desipte this log file directory being empty by default, this is where log files are intended to be dumped by the program
in the event that an error were to occur. Since, at the moment, WTop is still in development, I've decided to keep the 
log files with the program rather than somewhere like %ProgramData%\WTop\Logs. From a practical standpoint this allows
me to keep errors consolidated within the WTop environment, while simulatenously ensuring that errors are logged within
the repository. Upon completion of the development of WTop, log files will be handled in the most Windows-Native
approach, which is with Windows Event Log, accessed through Event Viewer.
