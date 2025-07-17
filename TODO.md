# TODO

### Priority = High
1. Currently there is an issue with output when a window is shrunk while the program is running. This causes some really off putting formatting errors where lines are crossing over other lines causing the entire table to be printed again in a new location, however even the table looks bad. Adding -AutoSize to the Format-Table action helps with this formatting error, as it initiates text wrapping where appropriate and automatically shrinking the data available as well. Which if a user wants to not see as much that is their own dealing. However, this also causes issues with the relocation of the cursor after the script exits. 

### Priority = Low
2. At the moment there isn't a clear indicator of which resource statistic is the priority, every column is shown to be the same priority. This can be fixed by contrasting the background/foreground color for that particular column or even by simply moving that one the furtherest to the left. 