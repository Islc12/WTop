# TODO

### Priority = High
1. Currently there is an issue with output when a window is shrunk while the program is running. This causes some really off putting formatting errors where lines are crossing over other lines causing the entire table to be printed again in a new location, however even the table looks bad. Adding -AutoSize to the Format-Table action helps with this formatting error, as it initiates text wrapping where appropriate and automatically shrinking the data available as well. Which if a user wants to not see as much that is their own dealing. However, this also causes issues with the relocation of the cursor after the script exits. 

### Priority = Medium - ***RESOLVED***
2. Introduce some text wrapping for warning messages. Currently warning messages such as that for -BackgroundColor and -TextColor don't wrap. This leaves users unable to see the full message, which for these parameters in particular means they can't see acceptable choices.

### Priority = Low
3. At the moment there isn't a clear indicator of which resource statistic is the priority, every column is shown to be the same priority. This can be fixed by contrasting the background/foreground color for that particular column or even by simply moving that one the furtherest to the left. 

### Priority = Low
4. Currently the check and modification for the screen size occurs before any checks occur for valid parameters. While this doesn't change the script running or whether errors are displayed it should be adjusted so that the screen size doesn't modify until after the script checks for valid parameters. However, I was having issues with this earlier, if I ran the screen size modifier inside the try block (even if before the parameter check) it would still execute the finally block causing the new cursor position to jump around. So it seems that this check will need to still occur outside the try block, but also move the parameter check outside the try block, BUT still keep how it handles the parameter check inside the try block.