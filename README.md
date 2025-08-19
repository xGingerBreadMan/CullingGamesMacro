# Roblox Auto-Queue Macro Setup Guide

## Required Files
You need to place 3 image files in the same folder as the script:
1. `disconnect_button.png` - Screenshot of the disconnect button that appears after a game
2. `matchmaking_screen.png` - Screenshot of the matchmaking screen 
3. `queue_confirm.png` - Screenshot of the image that appears when you need to confirm queue

## How to Capture Images
1. Use Windows Snipping Tool or any screenshot tool
2. Capture ONLY the button/element you want to detect (not the entire screen)
3. Save as PNG format with the exact names listed above
4. Place in the same folder as RobloxAutoQueue.ahk

## Coordinate Configuration
Open RobloxAutoQueue.ahk in a text editor and modify these coordinates at the top:

```autohotkey
; Set your coordinates here
INITIAL_CLICK_X := 960  ; Initial click coordinate X
INITIAL_CLICK_Y := 540  ; Initial click coordinate Y

QUEUE_BUTTON_X := 960   ; Queue button coordinate X after escape sequence
QUEUE_BUTTON_Y := 540   ; Queue button coordinate Y after escape sequence

FINAL_COORD1_X := 960   ; First coordinate after timeout
FINAL_COORD1_Y := 400   ; First coordinate after timeout

FINAL_COORD2_X := 960   ; Second coordinate after 5 second wait
FINAL_COORD2_Y := 500   ; Second coordinate after 5 second wait

FINAL_COORD3_X := 960   ; Third coordinate after another 5 second wait
FINAL_COORD3_Y := 600   ; Third coordinate after another 5 second wait

MIDDLE_SCREEN_X := 960  ; Middle of screen X for periodic clicks
MIDDLE_SCREEN_Y := 540  ; Middle of screen Y for periodic clicks
```

## How to Find Coordinates
1. Download a coordinate finder tool or use this PowerShell command:
   ```powershell
   Add-Type -AssemblyName System.Windows.Forms
   [System.Windows.Forms.Cursor]::Position
   ```
2. Position your mouse where you want to click and run the command
3. Replace the coordinates in the script

## Controls
- **F1**: Start/Stop the macro
- **F2**: Exit the macro completely

## How It Works
1. **Initial State**: Clicks the initial coordinate to start queue
2. **Waiting for Disconnect**: Scans for disconnect button, clicks middle screen every 2 minutes
3. **Escape Sequence**: When disconnect found, sends Escape → L → Enter
4. **Queue Confirmation**: Looks for queue confirm image, clicks queue button if found
5. **Timeout Handling**: If no queue confirm after 2 minutes, clicks the 3 backup coordinates
6. **Return to Matchmaking**: Waits for matchmaking screen, then restarts cycle

## Features
- Mouse jittering (±2 pixels) for better button detection
- 2-minute periodic clicks to prevent AFK
- 2-minute timeout system
- State-based operation for reliability
- Visual feedback with tooltips

## Troubleshooting
- Make sure AutoHotkey is installed
- Ensure image files are in the correct location
- Test coordinates by temporarily adding clicks to see if they work
- Images should be clear and not too large (just the button/element)
- Run Roblox in windowed mode for better detection
