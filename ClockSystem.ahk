; ============================================================
;  Clock System Kiosk Launcher — AutoHotkey v1.1
;  Greenhalgh's — Windows XP / POSReady 2009 compatible
;
;  Features:
;    - Reads/writes device token from config.json
;    - Shows local setup.html if no token saved
;    - Loads Supermium in kiosk mode with device token URL
;    - Floating close button (always on top, delayed appearance)
;    - Hotkey: Ctrl+Alt+Q to close
;    - Monitors for offline state, shows offline.html
;    - Auto-retries server when back online
;    - Cold-boot tolerant browser launch with one auto-retry
; ============================================================

#NoEnv
#SingleInstance Force
#Persistent
SetTitleMatchMode, 2  ; Match partial titles for robust targeting
SetWorkingDir %A_ScriptDir%

; ── Configuration ────────────────────────────────────────────
global SERVER_BASE   := "http://localhost/clockapp/"
global CONFIG_FILE   := A_ScriptDir . "\config.json"
global CHROME_EXE    := A_ScriptDir . "\supermium\chrome.exe"
global SETUP_PAGE    := "file:///" . A_ScriptDir . "\setup.html"
global OFFLINE_PAGE  := "file:///" . A_ScriptDir . "\offline.html"

global RETRY_MS      := 10000   ; retry server every 10s when offline
global CHECK_MS      := 15000   ; check server health every 15s when online
global CLOSE_BTN_DELAY_MS := 1500 ; delay after window appears before showing close button

; ── State ────────────────────────────────────────────────────
global g_token        := ""
global g_mainPID      := 0
global g_mainHWND     := 0
global g_closeHWND    := 0
global g_loaderHWND   := 0
global g_firstStart   := true  ; Controls visual loader display state
global g_mode         := ""   ; "setup", "kiosk", "offline"
global g_offlineCheckMs := 0
global g_onlineCheckMs  := 0   ; Tracks time elapsed between online health checks
global g_closeAllowedAfter := 0 ; Tick-count timestamp after which the close button may appear

; ── Startup Cleanup ──────────────────────────────────────────
; Purge any lingering chrome processes to prevent profiling conflicts
Loop {
  Process, Exist, chrome.exe
  If !ErrorLevel
    Break
  Process, Close, chrome.exe
}
Sleep, 500

; ── Startup ──────────────────────────────────────────────────
Gosub, CreateStartupLoader
Gosub, ReadToken
Gosub, Launch
SetTimer, WatchActiveWindow, 400  ; Sync close button visibility with active workspace
Return

; ── Read token from config.json ──────────────────────────────
ReadToken:
  g_token := ""
  If FileExist(CONFIG_FILE) {
    FileRead, raw, %CONFIG_FILE%
    RegExMatch(raw, """token""\s*:\s*""([^""]+)""", m)
    g_token := m1
  }
Return

; ── Write token to config.json ───────────────────────────────
WriteToken(tok) {
  global CONFIG_FILE
  json := "{""token"":""" . tok . """}"
  FileDelete, %CONFIG_FILE%
  FileAppend, %json%, %CONFIG_FILE%
}

; ── Main launch sequence ───────────────────────────────────────
Launch:
  Gosub, KillMain

  If (g_token = "") {
    g_mode := "setup"
    Gosub, OpenMain
    Return
  }

  ; Pre-flight network check: run check while the splash screen is active
  ; This prevents the browser from being double-launched and flashed on startup
  If ServerReachable() {
    g_mode := "kiosk"
    g_onlineCheckMs := 0
  } Else {
    g_mode := "offline"
    g_offlineCheckMs := 0
  }
  
  Gosub, OpenMain
Return

; ── Open the correct page for current g_mode ──────────────────
OpenMain:
  If (g_mode = "setup") {
    url := SETUP_PAGE
  } Else If (g_mode = "offline") {
    url := OFFLINE_PAGE
  } Else {
    url := SERVER_BASE . g_token
  }
  Gosub, OpenMainWithUrl
  SetTimer, MonitorTick, 2000  ; Monitor loop (evaluates every 2s)
Return

; ── Launch the browser, tolerating slow cold-boot startup ─────
; Waits up to 25s per attempt for the window to appear, detects an
; early process death (real crash) and retries once before giving up.
; Close button is intentionally NOT shown immediately — see g_closeAllowedAfter.
OpenMainWithUrl:
  If !FileExist(CHROME_EXE) {
    Gosub, DestroyStartupLoader
    MsgBox, 16, Clock System Error, Supermium not found:`n%CHROME_EXE%`n`nPlace the supermium folder next to ClockSystem.exe
    ExitApp
  }
  
  ; Transition Masking: if we are re-launching the browser, draw the loader
  ; to completely hide the desktop background during the loading lag
  if (g_loaderHWND = 0) {
    g_firstStart := true
    Gosub, CreateStartupLoader
  }

  args := "--kiosk --no-first-run --disable-translate --disable-infobars"
       . " --disable-session-crashed-bubble --disable-features=TranslateUI"
       . " --disable-gpu --disable-software-rasterizer --disable-gpu-compositing"
       . " --enable-low-end-device-mode"
       . " --user-data-dir=" . """" . A_ScriptDir . "\profile_main"""
       . " " . """" . url . """"

  g_mainHWND := 0

  Loop, 2 {  ; allow one full relaunch attempt before giving up
    Run, %CHROME_EXE% %args%,, , g_mainPID

    ; Cold boot can take a long time on first run; poll for up to 25s,
    ; but bail out early if the process dies (real crash, not just slow).
    Loop, 100 {  ; 100 × 250ms = 25 seconds max
      g_mainHWND := GetMainWindowHWND()
      if (g_mainHWND > 0 && DllCall("IsWindowVisible", "Ptr", g_mainHWND)) {
        break
      }
      Process, Exist, %g_mainPID%
      if (!ErrorLevel) {
        ; process died before painting a window — stop waiting, retry
        break
      }
      Sleep, 250
    }

    if (g_mainHWND > 0 && DllCall("IsWindowVisible", "Ptr", g_mainHWND)) {
      break  ; success, no need for second attempt
    }

    ; Clean up a dead/stuck launch before retrying
    Process, Close, %g_mainPID%
    g_mainPID := 0
    Sleep, 500
  }
  
  if (g_mainHWND > 0) {
    Gosub, StyleMainWindow
    WinActivate, ahk_id %g_mainHWND%
    
    ; Destroy the loader only when the new window is active
    Gosub, DestroyStartupLoader

    ; Don't show the close button immediately — give the page time to
    ; actually render first, otherwise it flashes over a blank/loading window.
    ; MonitorTick's regular RaiseCloseButton call will pick it up once the delay passes.
    g_closeAllowedAfter := A_TickCount + CLOSE_BTN_DELAY_MS
  } else {
    Gosub, DestroyStartupLoader
    MsgBox, 16, Clock System Error, Failed to initialize the kiosk browser.
    ExitApp
  }
Return

; ── Force the main window into borderless fullscreen (Fake Kiosk Fallback) ─
StyleMainWindow:
  If (g_mainHWND > 0) {
    WinSet, Style, -0xC40000, ahk_id %g_mainHWND%
    WinMove, ahk_id %g_mainHWND%,, 0, 0, %A_ScreenWidth%, %A_ScreenHeight%
  }
Return

; ── Kill the main kiosk window ─────────────────────────────────
KillMain:
  ; FIXED: Immediately turn off the crash monitor loop during any intentional window tear-down
  SetTimer, MonitorTick, Off
  
  g_mainHWND := GetMainWindowHWND()
  If (g_mainHWND > 0) {
    WinClose, ahk_id %g_mainHWND%
    Sleep, 400
  }
  If (g_mainPID > 0) {
    Process, Close, %g_mainPID%
    g_mainPID := 0
  }
  g_mainHWND := 0
Return

; ── Professional Startup Loader GUI (Splash Screen) ─────────────────────────
CreateStartupLoader:
  if (!g_firstStart)
    Return

  ; Temporarily hide the close button if it exists so it doesn't float over the loader
  if (g_closeHWND > 0) {
    WinHide, ahk_id %g_closeHWND%
  }

  Gui, Loader:New, +AlwaysOnTop -Caption +ToolWindow +LastFound +HWNDg_loaderHWND
  Gui, Loader:Color, 1E293B  ; Flat slate dark background
  
  ; Logo Text
  Gui, Loader:Font, s20 bold, Arial
  Gui, Loader:Add, Text, x0 y35 w450 Center c10B981, Staff Clock System
  
  ; Subtext
  Gui, Loader:Font, s11, Arial
  Gui, Loader:Add, Text, x0 y80 w450 Center c94A3B8, Initializing secure terminal...
  
  ; Static custom emerald status bar
  Gui, Loader:Add, Progress, x50 y115 w350 h6 Background334155 c10B981, 45
  
  Gui, Loader:Show, w450 h160 Center NoActivate
Return

DestroyStartupLoader:
  if (g_loaderHWND > 0) {
    Gui, Loader:Destroy
    g_loaderHWND := 0
    g_firstStart := false  ; Suppress future flashes during setup/reloads
  }
Return

; ── Native Close Button GUI ─────────────────────────────────────────────────
CreateNativeCloseButton:
  buttonSize := 45
  ; Calculate position: Top-Right of the screen with 20px padding
  posX := A_ScreenWidth - buttonSize - 20
  posY := 20
  
  Gui, CloseBtn:New, +AlwaysOnTop -Caption +ToolWindow +LastFound +HWNDg_closeHWND
  Gui, CloseBtn:Color, CC3333  ; Flat crimson background
  
  Gui, CloseBtn:Font, s16 bold, Arial
  Gui, CloseBtn:Add, Text, x0 y10 w%buttonSize% h35 Center cWhite gDoClose, X
  
  Gui, CloseBtn:Show, x%posX% y%posY% w%buttonSize% h%buttonSize% NoActivate
Return

RaiseCloseButton:
  ; Only create close button if the splash screen is gone and main window is active
  If (g_firstStart)
    Return

  ; Respect the post-launch delay so the button doesn't appear before the page renders
  If (A_TickCount < g_closeAllowedAfter)
    Return

  If (g_closeHWND = 0 || !WinExist("ahk_id " . g_closeHWND)) {
    Gosub, CreateNativeCloseButton
  } Else {
    WinSet, AlwaysOnTop, On, ahk_id %g_closeHWND%
    WinShow, ahk_id %g_closeHWND%
  }
Return

; ── Focus Synchronization Engine (Handles Window Switching Safely) ──────────
WatchActiveWindow:
  ; If loader is displaying transitions, skip sync cycle
  if (g_loaderHWND > 0)
    Return

  activeHWND := WinActive("A")
  if (g_mainHWND > 0 && WinExist("ahk_id " . g_mainHWND)) {
    ; Only display the close button if the active foreground window is either the Kiosk or the button itself
    if (activeHWND = g_mainHWND || activeHWND = g_closeHWND) {
      if (g_closeHWND > 0 && !DllCall("IsWindowVisible", "Ptr", g_closeHWND)) {
        WinShow, ahk_id %g_closeHWND%
        WinSet, AlwaysOnTop, On, ahk_id %g_closeHWND%
      }
    } else {
      ; Another window has been focused; seamlessly hide the close button
      if (g_closeHWND > 0 && DllCall("IsWindowVisible", "Ptr", g_closeHWND)) {
        WinHide, ahk_id %g_closeHWND%
      }
    }
  }
Return

; ── Close everything immediately ────────────────────────────────
DoClose:
  ; FIXED: Immediately turn off active timers to prevent any race conditions during shutdown!
  SetTimer, MonitorTick, Off
  SetTimer, WatchActiveWindow, Off

  ; 1. Instantly destroy the close button so it disappears from the screen in 1ms
  If (g_closeHWND > 0) {
    Gui, CloseBtn:Destroy
    g_closeHWND := 0
  }
  Sleep, 50  ; Let the OS repaint the screen immediately
  
  ; 2. Terminate the main container cleanly
  Gosub, KillMain
  
  ; 3. Asynchronously flush background processes in the background
  Run, taskkill /F /IM chrome.exe,, Hide
  Process, Close, chrome.exe
  
  ExitApp
Return

; ── Hotkey: Ctrl+Alt+Q also closes ─────────────────────────────
^!q::
  Gosub, DoClose
Return

; ── Hotkey: Ctrl+Alt+Shift+R resets device token ───────────────
^!+r::
  MsgBox, 4, Reset Device, This will remove the device token and return to setup.`n`nContinue?
  IfMsgBox, Yes
  {
    FileDelete, %CONFIG_FILE%
    g_token := ""
    Gosub, Launch
  }
Return

; ── Server reachability check ───────────────────────────────────
ServerReachable() {
  global SERVER_BASE
  try {
    http := ComObjCreate("WinHttp.WinHttpRequest.5.1")
    http.Open("HEAD", SERVER_BASE, false)
    http.SetTimeouts(4000, 4000, 4000, 4000)
    http.Send()
    return (http.Status >= 200 && http.Status < 500)
  } catch {
    return false
  }
}

; ── Helper Function: Handle Crawler (Only executed when handle is lost) ──
GetMainWindowHWND() {
  WinGet, winList, List, ahk_class Chrome_WidgetWin_1
  Loop, %winList% {
    this_hwnd := winList%A_Index%
    WinGetTitle, this_title, ahk_id %this_hwnd%
    if (this_title != "" && !InStr(this_title, "close.html") && !InStr(this_title, "CMD:CLOSE_APP")) {
      return this_hwnd
    }
  }
  return 0
}

; ── Periodic monitor: token submit, offline retry, crash recovery ──
MonitorTick:
  ; Periodically pull close button to topmost layer so browser clicks never hide it
  ; (RaiseCloseButton internally respects g_closeAllowedAfter, so this is a no-op
  ; until the post-launch delay has elapsed)
  Gosub, RaiseCloseButton

  if (g_mainHWND = 0 || !WinExist("ahk_id " . g_mainHWND)) {
    g_mainHWND := GetMainWindowHWND()
  }

  ; ── setup.html sets title to CMD:SAVE_TOKEN:<token> ───────────
  If (g_mode = "setup") {
    If (g_mainHWND > 0) {
      WinGetTitle, title, ahk_id %g_mainHWND%
      If (InStr(title, "CMD:SAVE_TOKEN:") = 1) {
        tok := Trim(SubStr(title, 16))
        If (tok != "") {
          ; Strip trailing browser branding strings from target token
          tok := RegExReplace(tok, "i)\s*-\s*Supermium\s*$")
          tok := RegExReplace(tok, "i)\s*-\s*Google Chrome\s*$")
          tok := RegExReplace(tok, "i)\s*-\s*Chromium\s*$")
          
          WriteToken(tok)
          g_token := tok
          Gosub, Launch
        }
      }
    }
    Return
  }

  ; ── offline.html: retry server checking based on RETRY_MS ────
  If (g_mode = "offline") {
    g_offlineCheckMs += 2000
    If (g_offlineCheckMs >= RETRY_MS) {
      g_offlineCheckMs := 0
      If ServerReachable() {
        g_mode := "kiosk"
        g_onlineCheckMs := 0
        Gosub, KillMain
        Gosub, OpenMain
      }
    }
    Return
  }

  ; ── kiosk mode: check for crash or online server health drops based on CHECK_MS ──
  If (g_mode = "kiosk") {
    If (g_mainHWND = 0) {
      If ServerReachable() {
        Gosub, OpenMain
      } Else {
        g_mode := "offline"
        g_offlineCheckMs := 0
        Gosub, OpenMain
      }
      Return
    }
    
    ; Periodically monitor the server health while online
    g_onlineCheckMs += 2000
    If (g_onlineCheckMs >= CHECK_MS) {
      g_onlineCheckMs := 0
      If !ServerReachable() {
        g_mode := "offline"
        g_offlineCheckMs := 0
        Gosub, OpenMain
      }
    }
    Return
  }
Return
