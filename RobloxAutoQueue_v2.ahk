#SingleInstance Force
SendMode("Input")
SetWorkingDir(A_ScriptDir)

; ===== CONFIGURATION =====
; Screen percentage coordinates (based on 1920x1080 reference resolution)
; These percentages will automatically scale to any monitor size

; Reference resolution: 1920x1080
REFERENCE_WIDTH := 1920
REFERENCE_HEIGHT := 1080

; Button coordinates (fixed values - use F4 to update these manually)
QUEUE_BUTTON_X := 1383    ; Queue button coordinate X
QUEUE_BUTTON_Y := 1030    ; Queue button coordinate Y

PLAY_BUTTON_X := 885      ; Play button coordinate X
PLAY_BUTTON_Y := 270      ; Play button coordinate Y

ANY_KEY_BUTTON_X := 960   ; Any key to enter first screen coordinate X
ANY_KEY_BUTTON_Y := 540   ; Any key to enter first screen coordinate Y

MATCHMAKING_BUTTON_X := 200  ; Matchmaking button coordinate X
MATCHMAKING_BUTTON_Y := 500  ; Matchmaking button coordinate Y

SLOT_BUTTON_X := 610      ; Slot selection button coordinate X
SLOT_BUTTON_Y := 550      ; Slot selection button coordinate Y

MIDDLE_SCREEN_X := 960    ; Middle of screen X for periodic clicks to prevent AFK
MIDDLE_SCREEN_Y := 540    ; Middle of screen Y for periodic clicks to prevent AFK

PRE_ESCAPE_CLICK_X := 840 ; Coordinate to click after finding disconnect button but before escape sequence X
PRE_ESCAPE_CLICK_Y := 620 ; Coordinate to click after finding disconnect button but before escape sequence Y

; Image file paths (place images in same folder as script)
DISCONNECT_IMAGE := A_ScriptDir . "\disconnect_button.png"  ; The disconnect/leave button that appears after game
TELEPORT_FAILED_IMAGE := A_ScriptDir . "\teleport_failed.png"  ; The teleport failed message
MATCHMAKING_IMAGE := A_ScriptDir . "\matchmaking_screen.png"  ; The matchmaking lobby screen
PLAY_BUTTON_IMAGE := A_ScriptDir . "\play_button.png"  ; The play button after leaving a game (normal state)
PLAY_BUTTON_HOVERED_IMAGE := A_ScriptDir . "\play_button_hovered.png"  ; The play button after leaving a game (hovered state)
GAME_LOGO_IMAGE := A_ScriptDir . "\game_logo.png"  ; The game logo that appears when game has loaded

; Timing settings
MIDDLE_CLICK_INTERVAL := 120000  ; 2 minutes in milliseconds for AFK prevention
IMAGE_SEARCH_DELAY := 500        ; 0.5 seconds between image searches
PLAY_BUTTON_TIMEOUT := 120000    ; 2 minutes timeout for play button detection
PLAY_BUTTON_CHECK_TIMEOUT := 10000  ; 10 seconds to check for play button after disconnect
GAME_LOGO_TIMEOUT := 60000       ; 1 minute timeout for game logo detection
QUEUE_BUTTON_FAILSAFE_TIMEOUT := 180000  ; 3 minutes timeout to re-press queue button if still in matchmaking
JITTER_AMOUNT_PCT := 0.10        ; Percentage of screen width to jitter mouse (0.10% = ~2 pixels on 1920px width)
JITTER_AMOUNT := Round(1920 * JITTER_AMOUNT_PCT / 100)  ; Calculate actual jitter pixels based on reference width

; ===== GLOBAL VARIABLES =====
isRunning := false
lastMiddleClick := 0
state := "initial"  ; States: initial, waiting_for_disconnect, checking_for_play_button, waiting_for_play_button, waiting_for_game_logo, waiting_for_matchmaking
playButtonSearchStartTime := 0
playButtonCheckStartTime := 0
gameLogoSearchStartTime := 0
lastQueueButtonClick := 0

; ===== HOTKEYS =====
F1:: {
    if (!isRunning) {
        StartMacro()
    } else {
        StopMacro()
    }
}

F2:: {
    StopMacro()
    ExitApp()
}

F3:: {
    CheckAllImages()
}

F4:: {
    ; Interactive coordinate selection menu
    ShowCoordinateMenu()
}

F5:: {
    ; Interactive screenshot replacement menu
    ShowScreenshotMenu()
}

; ===== MAIN FUNCTIONS =====
StartMacro() {
    global
    
    isRunning := true
    lastMiddleClick := A_TickCount
    
    ; Detect current state by checking for various UI elements
    ShowStatusTooltip("Macro Starting - Detecting current state...")
    
    ; Check for play buttons first (highest priority - means we need to click play)
    if (FindAnyPlayButton(&foundX, &foundY)) {
        ShowStatusTooltip("Detected: Play button visible - Starting from play button click")
        state := "waiting_for_play_button"
        playButtonSearchStartTime := A_TickCount
    }
    ; Check for matchmaking screen (means we're in lobby, need to queue)
    else if (FindImage(MATCHMAKING_IMAGE, &foundX, &foundY)) {
        ShowStatusTooltip("Detected: Matchmaking lobby - Starting queue sequence")
        JitterClick(QUEUE_BUTTON_X, QUEUE_BUTTON_Y)
        lastQueueButtonClick := A_TickCount
        state := "waiting_for_disconnect"
    }
    ; Check for disconnect button (means we're in game)
    else if (FindAnyDisconnect(&foundX, &foundY)) {
        ShowStatusTooltip("Detected: In game - Starting from disconnect monitoring")
        state := "waiting_for_disconnect"
    }
    ; Check for game logo (means game is loading/loaded)
    else if (FindImage(GAME_LOGO_IMAGE, &foundX, &foundY)) {
        ShowStatusTooltip("Detected: Game logo - Starting from game sequence")
        state := "waiting_for_game_logo"
        gameLogoSearchStartTime := A_TickCount
    }
    ; Default: assume we're in matchmaking lobby
    else {
        ShowStatusTooltip("No specific state detected - Assuming matchmaking lobby, starting queue")
        JitterClick(QUEUE_BUTTON_X, QUEUE_BUTTON_Y)
        lastQueueButtonClick := A_TickCount
        state := "waiting_for_disconnect"
    }
    
    SetTimer(MainLoop, IMAGE_SEARCH_DELAY)
}

StopMacro() {
    global
    isRunning := false
    SetTimer(MainLoop, 0)
    SetTimer(RemoveToolTip, 0)
    SetTimer(RemoveStatusTooltip, 0)
    ShowStatusTooltip("Macro Stopped")
    SetTimer(RemoveStatusTooltip, 3000)
}

MainLoop() {
    global
    if (!isRunning) {
        return
    }
    
    currentTime := A_TickCount
    
    ; ALWAYS check for disconnect button first, regardless of state
    if (FindAnyDisconnect(&foundX, &foundY)) {
        ; Found disconnect button or teleport failed, click it and check for play button
        ShowStatusTooltip("Found disconnect/teleport failed! Clicking and checking for play button...")
        JitterClick(foundX, foundY)  ; Click the leave button
        Sleep(500)
        
        ; Click coordinate after disconnect
        ShowStatusTooltip("Clicking pre-escape coordinate...")
        JitterClick(PRE_ESCAPE_CLICK_X, PRE_ESCAPE_CLICK_Y)
        Sleep(300)
        
        ; Start checking for play button for 10 seconds
        state := "checking_for_play_button"
        playButtonCheckStartTime := A_TickCount
        return
    }
    
    ; State-specific logic
    if (state = "waiting_for_disconnect") {
        ShowStatusTooltip("Status: In game - Waiting for disconnect button`nNext AFK prevention click: " . Round((MIDDLE_CLICK_INTERVAL - (currentTime - lastMiddleClick)) / 1000) . "s")
        
        ; Check for queue button failsafe - if still seeing matchmaking screen after 3 minutes
        if (lastQueueButtonClick > 0 && (currentTime - lastQueueButtonClick >= QUEUE_BUTTON_FAILSAFE_TIMEOUT)) {
            if (FindImage(MATCHMAKING_IMAGE, &foundX, &foundY)) {
                ; Still in matchmaking after 3 minutes, re-press queue button
                ShowStatusTooltip("Failsafe: Still in matchmaking after 3 minutes! Re-pressing queue button...")
                JitterClick(QUEUE_BUTTON_X, QUEUE_BUTTON_Y)
                lastQueueButtonClick := A_TickCount
                return
            }
        }
        
        ; Periodic middle screen click every 2 minutes to prevent AFK kick
        if (currentTime - lastMiddleClick >= MIDDLE_CLICK_INTERVAL) {
            ShowStatusTooltip("Clicking middle screen to prevent AFK kick...")
            JitterClick(MIDDLE_SCREEN_X, MIDDLE_SCREEN_Y)
            lastMiddleClick := currentTime
        }
    }
    else if (state = "checking_for_play_button") {
        timeLeft := Round((PLAY_BUTTON_CHECK_TIMEOUT - (currentTime - playButtonCheckStartTime)) / 1000)
        ShowStatusTooltip("Status: Checking for play button after disconnect`nTimeout in: " . timeLeft . "s")
        
        ; Look for play button within 10 seconds
        if (FindAnyPlayButton(&foundX, &foundY)) {
            ; Found play button quickly, skip escape sequence and go directly to play button
            ShowStatusTooltip("Found play button! Skipping escape sequence...")
            state := "waiting_for_play_button"
            playButtonSearchStartTime := A_TickCount
            return
        }
        
        ; Check for timeout (10 seconds)
        if (currentTime - playButtonCheckStartTime >= PLAY_BUTTON_CHECK_TIMEOUT) {
            ; Timeout reached, send escape sequence
            ShowStatusTooltip("Play button not found after 10 seconds. Sending escape sequence...")
            Send("{Escape}")
            Sleep(200)
            Send("l")
            Sleep(200)
            Send("{Enter}")
            Sleep(1000)
            
            state := "waiting_for_play_button"
            playButtonSearchStartTime := A_TickCount
            return
        }
    }
    else if (state = "waiting_for_play_button") {
        timeLeft := Round((PLAY_BUTTON_TIMEOUT - (currentTime - playButtonSearchStartTime)) / 1000)
        ShowStatusTooltip("Status: Waiting for play button`nTimeout in: " . timeLeft . "s")
        
        ; Look for play button
        if (FindAnyPlayButton(&foundX, &foundY)) {
            ; Found play button, click it
            ShowStatusTooltip("Found play button! Clicking to enter game...")
            JitterClick(PLAY_BUTTON_X, PLAY_BUTTON_Y)
            
            ; Start waiting for game logo instead of fixed delay
            state := "waiting_for_game_logo"
            gameLogoSearchStartTime := A_TickCount
            return
        }
        
        ; Check for timeout (2 minutes)
        if (currentTime - playButtonSearchStartTime >= PLAY_BUTTON_TIMEOUT) {
            ; Timeout reached, execute backup sequence
            ShowStatusTooltip("Play button timeout! Executing backup sequence...")
            JitterClick(ANY_KEY_BUTTON_X, ANY_KEY_BUTTON_Y)
            Sleep(5000)
            JitterClick(MATCHMAKING_BUTTON_X, MATCHMAKING_BUTTON_Y)
            Sleep(5000)
            JitterClick(SLOT_BUTTON_X, SLOT_BUTTON_Y)
            Sleep(2000)
            
            state := "waiting_for_matchmaking"
            return
        }
    }
    else if (state = "waiting_for_game_logo") {
        timeLeft := Round((GAME_LOGO_TIMEOUT - (currentTime - gameLogoSearchStartTime)) / 1000)
        ShowStatusTooltip("Status: Game loading - Waiting for game logo`nTimeout in: " . timeLeft . "s")
        
        ; Look for game logo
        if (FindImage(GAME_LOGO_IMAGE, &foundX, &foundY)) {
            ; Found game logo, game has loaded, wait 10 seconds then proceed
            ShowStatusTooltip("Game loaded! Waiting 10 seconds before proceeding...")
            Sleep(15000)
            
            ; Press any key to enter first screen
            ShowStatusTooltip("Pressing any key to enter first screen...")
            JitterClick(ANY_KEY_BUTTON_X, ANY_KEY_BUTTON_Y)
            Sleep(2000)
            
            ; Press matchmaking button
            ShowStatusTooltip("Clicking matchmaking button...")
            JitterClick(MATCHMAKING_BUTTON_X, MATCHMAKING_BUTTON_Y)
            Sleep(2000)
            
            ; Press slot selection button
            ShowStatusTooltip("Selecting slot to play...")
            JitterClick(SLOT_BUTTON_X, SLOT_BUTTON_Y)
            Sleep(2000)
            
            state := "waiting_for_matchmaking"
            return
        }
        
        ; Check for timeout (1 minute)
        if (currentTime - gameLogoSearchStartTime >= GAME_LOGO_TIMEOUT) {
            ; Timeout reached, execute backup sequence
            ShowStatusTooltip("Game logo timeout! Executing backup sequence...")
            JitterClick(ANY_KEY_BUTTON_X, ANY_KEY_BUTTON_Y)
            Sleep(5000)
            JitterClick(MATCHMAKING_BUTTON_X, MATCHMAKING_BUTTON_Y)
            Sleep(5000)
            JitterClick(SLOT_BUTTON_X, SLOT_BUTTON_Y)
            Sleep(2000)
            
            state := "waiting_for_matchmaking"
            return
        }
    }
    else if (state = "waiting_for_matchmaking") {
        ShowStatusTooltip("Status: Waiting for matchmaking lobby`nSearching for return to queue...")
        
        ; Look for matchmaking screen to restart the cycle
        if (FindImage(MATCHMAKING_IMAGE, &foundX, &foundY)) {
            ; Back to matchmaking lobby, restart the cycle
            ShowStatusTooltip("Found matchmaking lobby! Restarting queue...")
            JitterClick(QUEUE_BUTTON_X, QUEUE_BUTTON_Y)
            lastQueueButtonClick := A_TickCount
            state := "waiting_for_disconnect"
            lastMiddleClick := A_TickCount
            return
        }
    }
}

; ===== UTILITY FUNCTIONS =====
ShowCoordinateMenu() {
    ; Create a menu for selecting which coordinate to update
    coordinateMenu := Menu()
    
    coordinateMenu.Add("Queue Button", SetQueueButton)
    coordinateMenu.Add("Play Button", SetPlayButton)
    coordinateMenu.Add("Matchmaking Button", SetMatchmakingButton)
    coordinateMenu.Add("Slot Button", SetSlotButton)
    coordinateMenu.Add("Middle Screen (AFK Prevention)", SetMiddleScreen)
    coordinateMenu.Add("Disconnection Click", SetDisconnectionClick)
    coordinateMenu.Add()  ; Separator
    coordinateMenu.Add("Show Current Coordinates", ShowCurrentCoordinates)
    coordinateMenu.Add("Cancel", CancelCoordinateSelection)
    
    ; Show the menu at cursor position
    coordinateMenu.Show()
}

SetQueueButton(*) {
    SetCoordinate("Queue Button", "QUEUE_BUTTON_X", "QUEUE_BUTTON_Y")
}

SetPlayButton(*) {
    SetCoordinate("Play Button", "PLAY_BUTTON_X", "PLAY_BUTTON_Y")
}

SetMatchmakingButton(*) {
    SetCoordinate("Matchmaking Button", "MATCHMAKING_BUTTON_X", "MATCHMAKING_BUTTON_Y")
}

SetSlotButton(*) {
    SetCoordinate("Slot Button", "SLOT_BUTTON_X", "SLOT_BUTTON_Y")
}

SetMiddleScreen(*) {
    SetCoordinate("Middle Screen (AFK Prevention)", "MIDDLE_SCREEN_X", "MIDDLE_SCREEN_Y")
}

SetDisconnectionClick(*) {
    SetCoordinate("Disconnection Click", "PRE_ESCAPE_CLICK_X", "PRE_ESCAPE_CLICK_Y")
}

SetCoordinate(buttonName, xVarName, yVarName) {
    global
    ; Show instruction tooltip
    ShowStatusTooltip("Click anywhere on screen to set " . buttonName . " coordinates.`nPress ESC to cancel.")
    
    ; Wait for mouse click or ESC key
    KeyWait("LButton", "D")
    
    ; Get mouse position when clicked
    MouseGetPos(&newX, &newY)
    
    ; Update the global coordinates using dynamic variable assignment
    %xVarName% := newX
    %yVarName% := newY
    
    ; Show confirmation
    ShowStatusTooltip(buttonName . " coordinates updated to (" . newX . ", " . newY . ")")
    SetTimer(RemoveStatusTooltip, 3000)
}

ShowCurrentCoordinates(*) {
    ; Display all current coordinates
    coordText := "Current Coordinates:`n`n"
    coordText .= "Queue Button: (" . QUEUE_BUTTON_X . ", " . QUEUE_BUTTON_Y . ")`n"
    coordText .= "Play Button: (" . PLAY_BUTTON_X . ", " . PLAY_BUTTON_Y . ")`n"
    coordText .= "Matchmaking Button: (" . MATCHMAKING_BUTTON_X . ", " . MATCHMAKING_BUTTON_Y . ")`n"
    coordText .= "Slot Button: (" . SLOT_BUTTON_X . ", " . SLOT_BUTTON_Y . ")`n"
    coordText .= "Middle Screen: (" . MIDDLE_SCREEN_X . ", " . MIDDLE_SCREEN_Y . ")`n"
    coordText .= "Disconnection Click: (" . PRE_ESCAPE_CLICK_X . ", " . PRE_ESCAPE_CLICK_Y . ")`n"
    
    ToolTip(coordText, 10, 10)
    SetTimer(RemoveToolTip, 8000)
}

CancelCoordinateSelection(*) {
    ShowStatusTooltip("Coordinate selection cancelled.")
    SetTimer(RemoveStatusTooltip, 2000)
}

ShowScreenshotMenu() {
    ; Create a menu for selecting which screenshot to replace
    screenshotMenu := Menu()
    
    screenshotMenu.Add("Disconnect Button", CaptureDisconnectButton)
    screenshotMenu.Add("Teleport Failed Message", CaptureTeleportFailed)
    screenshotMenu.Add("Matchmaking Screen", CaptureMatchmakingScreen)
    screenshotMenu.Add("Play Button (Normal)", CapturePlayButton)
    screenshotMenu.Add("Play Button (Hovered)", CapturePlayButtonHovered)
    screenshotMenu.Add("Game Logo", CaptureGameLogo)
    screenshotMenu.Add()  ; Separator
    screenshotMenu.Add("Cancel", CancelScreenshotSelection)
    
    ; Show the menu at cursor position
    screenshotMenu.Show()
}

CaptureDisconnectButton(*) {
    CaptureScreenshot("Disconnect Button", "disconnect_button.png")
}

CaptureTeleportFailed(*) {
    CaptureScreenshot("Teleport Failed Message", "teleport_failed.png")
}

CaptureMatchmakingScreen(*) {
    CaptureScreenshot("Matchmaking Screen", "matchmaking_screen.png")
}

CapturePlayButton(*) {
    CaptureScreenshot("Play Button (Normal)", "play_button.png")
}

CapturePlayButtonHovered(*) {
    CaptureScreenshot("Play Button (Hovered)", "play_button_hovered.png")
}

CaptureGameLogo(*) {
    CaptureScreenshot("Game Logo", "game_logo.png")
}

CaptureScreenshot(imageName, fileName) {
    ; Show instruction tooltip
    ShowStatusTooltip("Click and drag to select area for " . imageName . " screenshot.`nPress ESC to cancel.")
    
    ; Wait for mouse button down
    KeyWait("LButton", "D")
    
    ; Get starting position
    MouseGetPos(&startX, &startY)
    
    ; Create a simple overlay GUI with just a red border outline
    selectionGui := Gui("+AlwaysOnTop +ToolWindow -Caption +E0x20", "")
    selectionGui.BackColor := "Red"
    selectionGui.MarginX := 0
    selectionGui.MarginY := 0
    
    ; Make it semi-transparent
    WinSetTransparent(100, selectionGui.Hwnd)
    
    ; Initialize with a tiny window first
    selectionGui.Show("x" . startX . " y" . startY . " w1 h1 NA")
    
    ; Wait for mouse button up while tracking movement
    while GetKeyState("LButton", "P") {
        MouseGetPos(&currentX, &currentY)
        
        ; Calculate selection rectangle corners EXACTLY like the working GDI version
        left := Min(startX, currentX)
        top := Min(startY, currentY)
        right := Max(startX, currentX)
        bottom := Max(startY, currentY)
        width := right - left
        height := bottom - top
        
        ; Only update if we have a reasonable size to avoid flicker
        if (width > 1 && height > 1) {
            ; Move and resize the existing GUI instead of recreating it
            WinMove(left, top, width, height, selectionGui.Hwnd)
        }
        
        ; Show selection rectangle info
        ShowStatusTooltip("Selecting: " . width . "x" . height . " at (" . left . ", " . top . ")")
        Sleep(16) ; ~60 FPS update rate for smooth tracking
    }
    
    ; Hide and destroy the selection GUI
    selectionGui.Hide()
    selectionGui.Destroy()
    
    ; Get final position
    MouseGetPos(&endX, &endY)
    
    ; Calculate final selection rectangle using the same method
    left := Min(startX, endX)
    top := Min(startY, endY)
    right := Max(startX, endX)
    bottom := Max(startY, endY)
    width := right - left
    height := bottom - top
    
    ; Only proceed if there's a valid selection
    if (width > 5 && height > 5) {
        ; Take screenshot of selected area
        filePath := A_ScriptDir . "\" . fileName
        
        try {
            ; Use Windows built-in screenshot capability
            psCommand := "Add-Type -AssemblyName System.Windows.Forms; Add-Type -AssemblyName System.Drawing; $bitmap = New-Object System.Drawing.Bitmap(" . width . ", " . height . "); $graphics = [System.Drawing.Graphics]::FromImage($bitmap); $graphics.CopyFromScreen(" . left . ", " . top . ", 0, 0, [System.Drawing.Size]::new(" . width . ", " . height . ")); $bitmap.Save('" . filePath . "', [System.Drawing.Imaging.ImageFormat]::Png); $bitmap.Dispose(); $graphics.Dispose()"
            Run("powershell.exe -Command `"" . psCommand . "`"", , "Hide")
            
            ShowStatusTooltip(imageName . " screenshot saved to " . fileName . "`nSize: " . width . "x" . height . " at (" . left . ", " . top . ")")
            SetTimer(RemoveStatusTooltip, 4000)
        } catch {
            ShowStatusTooltip("Error saving screenshot. Make sure PowerShell is available.")
            SetTimer(RemoveStatusTooltip, 3000)
        }
    } else {
        ShowStatusTooltip("Selection too small. Please drag a larger area.")
        SetTimer(RemoveStatusTooltip, 3000)
    }
}

CancelScreenshotSelection(*) {
    ShowStatusTooltip("Screenshot selection cancelled.")
    SetTimer(RemoveStatusTooltip, 2000)
}

FindAnyDisconnect(&foundX, &foundY) {
    ; Check for either disconnect button or teleport failed message
    if (FindImage(DISCONNECT_IMAGE, &foundX, &foundY)) {
        return true
    }
    if (FindImage(TELEPORT_FAILED_IMAGE, &foundX, &foundY)) {
        return true
    }
    return false
}

FindAnyPlayButton(&foundX, &foundY) {
    ; Check for either normal or hovered play button
    if (FindImage(PLAY_BUTTON_IMAGE, &foundX, &foundY)) {
        return true
    }
    if (FindImage(PLAY_BUTTON_HOVERED_IMAGE, &foundX, &foundY)) {
        return true
    }
    return false
}

CheckAllImages() {
    ; Function to manually check for all images and display results
    disconnectFound := FindAnyDisconnect(&dx, &dy)
    disconnectNormalFound := FindImage(DISCONNECT_IMAGE, &dnx, &dny)
    teleportFailedFound := FindImage(TELEPORT_FAILED_IMAGE, &tfx, &tfy)
    playButtonFound := FindAnyPlayButton(&px, &py)
    playButtonNormalFound := FindImage(PLAY_BUTTON_IMAGE, &pnx, &pny)
    playButtonHoveredFound := FindImage(PLAY_BUTTON_HOVERED_IMAGE, &phx, &phy)
    gameLogoFound := FindImage(GAME_LOGO_IMAGE, &glx, &gly)
    matchmakingFound := FindImage(MATCHMAKING_IMAGE, &mx, &my)
    
    resultText := "Image Detection Results:`n`n"
    
    if (disconnectFound) {
        resultText .= "✓ Disconnect/Teleport Failed (any) found at (" . dx . ", " . dy . ")`n"
    } else {
        resultText .= "✗ Disconnect/Teleport Failed (any) not found`n"
    }
    
    if (disconnectNormalFound) {
        resultText .= "  ✓ Normal disconnect button found at (" . dnx . ", " . dny . ")`n"
    } else {
        resultText .= "  ✗ Normal disconnect button not found`n"
    }
    
    if (teleportFailedFound) {
        resultText .= "  ✓ Teleport failed message found at (" . tfx . ", " . tfy . ")`n"
    } else {
        resultText .= "  ✗ Teleport failed message not found`n"
    }
    
    if (playButtonFound) {
        resultText .= "✓ Play button (any state) found at (" . px . ", " . py . ")`n"
    } else {
        resultText .= "✗ Play button (any state) not found`n"
    }
    
    if (playButtonNormalFound) {
        resultText .= "  ✓ Normal play button found at (" . pnx . ", " . pny . ")`n"
    } else {
        resultText .= "  ✗ Normal play button not found`n"
    }
    
    if (playButtonHoveredFound) {
        resultText .= "  ✓ Hovered play button found at (" . phx . ", " . phy . ")`n"
    } else {
        resultText .= "  ✗ Hovered play button not found`n"
    }
    
    if (gameLogoFound) {
        resultText .= "✓ Game logo found at (" . glx . ", " . gly . ")`n"
    } else {
        resultText .= "✗ Game logo not found`n"
    }
    
    if (matchmakingFound) {
        resultText .= "✓ Matchmaking lobby found at (" . mx . ", " . my . ")`n"
    } else {
        resultText .= "✗ Matchmaking lobby not found`n"
    }
    
    ; Show results in center of screen
    ToolTip(resultText, 10, 10)
    SetTimer(RemoveToolTip, 8000)
}

ShowStatusTooltip(text) {
    ; Position tooltip at top left of screen
    ToolTip(text, 10, 10)
}

RemoveStatusTooltip() {
    SetTimer(RemoveStatusTooltip, 0)
    ToolTip()
}

JitterClick(x, y) {
    ; Move mouse to coordinates and continuously jitter for 0.75 seconds to simulate real movement
    ; This helps buttons register that the mouse is hovering over them
    
    totalDuration := 750  ; 0.75 seconds
    jitterInterval := 50  ; Move mouse every 50ms
    jitterSteps := totalDuration / jitterInterval  ; Number of jitter movements
    
    ; Initial move to target area
    MouseMove(x, y, 0)
    
    ; Continuously jitter the mouse for 0.75 seconds
    Loop jitterSteps {
        jitterX := Random(-JITTER_AMOUNT, JITTER_AMOUNT)
        jitterY := Random(-JITTER_AMOUNT, JITTER_AMOUNT)
        
        finalX := x + jitterX
        finalY := y + jitterY
        
        ; Move mouse with small jitter
        MouseMove(finalX, finalY, 0)
        Sleep(jitterInterval)
    }
    
    ; Final click at the target position (with slight jitter)
    finalJitterX := Random(-JITTER_AMOUNT, JITTER_AMOUNT)
    finalJitterY := Random(-JITTER_AMOUNT, JITTER_AMOUNT)
    Click(x + finalJitterX, y + finalJitterY)
}

FindImage(imagePath, &foundX, &foundY) {
    ; Initialize coordinates to ensure they have values
    foundX := 0
    foundY := 0
    
    ; Search for image on screen (exact match)
    try {
        if (ImageSearch(&foundX, &foundY, 0, 0, A_ScreenWidth, A_ScreenHeight, imagePath)) {
            return true
        } else {
            return false
        }
    } catch {
        foundX := 0
        foundY := 0
        return false
    }
}

RemoveToolTip() {
    SetTimer(RemoveToolTip, 0)
    ToolTip()
}

; ===== INITIALIZATION =====
; Display startup information with current coordinates
startupText := "Roblox Auto-Queue Macro Loaded (Fixed Coordinates)`n"
startupText .= "Current Screen: " . A_ScreenWidth . "x" . A_ScreenHeight . "`n`n"
startupText .= "Current Coordinates:`n"
startupText .= "Queue Button: (" . QUEUE_BUTTON_X . ", " . QUEUE_BUTTON_Y . ")`n"
startupText .= "Play Button: (" . PLAY_BUTTON_X . ", " . PLAY_BUTTON_Y . ")`n"
startupText .= "Any Key Button: (" . ANY_KEY_BUTTON_X . ", " . ANY_KEY_BUTTON_Y . ")`n"
startupText .= "Matchmaking Button: (" . MATCHMAKING_BUTTON_X . ", " . MATCHMAKING_BUTTON_Y . ")`n"
startupText .= "Slot Button: (" . SLOT_BUTTON_X . ", " . SLOT_BUTTON_Y . ")`n`n"
startupText .= "Controls:`n"
startupText .= "F1: Start/Stop Macro`n"
startupText .= "F2: Exit`n"
startupText .= "F3: Check All Images`n"
startupText .= "F4: Update Coordinates (Interactive Menu)`n"
startupText .= "F5: Update Screenshots (Interactive Menu)`n`n"
startupText .= "Required images in script folder:`n"
startupText .= "- disconnect_button.png`n"
startupText .= "- teleport_failed.png`n"
startupText .= "- matchmaking_screen.png`n"
startupText .= "- play_button.png`n"
startupText .= "- play_button_hovered.png`n"
startupText .= "- game_logo.png"

ToolTip(startupText, 10, 10)
SetTimer(RemoveToolTip, 15000)
