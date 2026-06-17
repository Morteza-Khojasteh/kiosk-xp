; ============================================================
;  Clock System Kiosk Launcher — AutoHotkey v1.1
;   Windows XP / POSReady 2009 compatible
;
;  Features:
;    - Reads/writes device token from config.json
;    - Shows local setup.html if no token saved
;    - Loads Supermium in kiosk mode with device token URL
;    - Floating close button (always on top)
;    - Hotkey: Ctrl+Alt+Q to close
;    - Monitors for offline state, shows offline.html
;    - Auto-retries server when back online
; ============================================================

#NoEnv
#SingleInstance Force
#Persistent
SetWorkingDir %A_ScriptDir%

; ── Configuration ────────────────────────────────────────────
global SERVER_BASE   := "http://localhost/clockapp/"
global CONFIG_FILE   := A_ScriptDir . "\config.json"
global CHROME_EXE    := A_ScriptDir . "\supermium\chrome.exe"
global SETUP_PAGE    := "file:///" . A_ScriptDir . "\setup.html"
global OFFLINE_PAGE  := "file:///" . A_ScriptDir . "\offline.html"
global RETRY_MS      := 10000   ; retry server every 10s when offline
global CHECK_MS      := 15000   ; check server health every 15s when online

; ── State ────────────────────────────────────────────────────
global g_token       := ""
global g_chromePID   := 0
global g_mode        := ""   ; "setup", "kiosk", "offline"
global g_closeHwnd   := 0

; ── Startup ──────────────────────────────────────────────────
Gosub, ReadToken
Gosub, DrawCloseButton
Gosub, Launch
Return

; ── Read token from config.json ──────────────────────────────
ReadToken:
  g_token := ""
  If FileExist(CONFIG_FILE) {
    FileRead, raw, %CONFIG_FILE%
    ; Simple JSON parse — extract "token":"VALUE"
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

; ── Launch correct page ───────────────────────────────────────
Launch:
  Gosub, KillChrome
  If (g_token = "") {
    g_mode := "setup"
    url    := SETUP_PAGE
  } Else {
    ; Test server before loading kiosk URL
    If ServerReachable() {
      g_mode := "kiosk"
      url    := SERVER_BASE . g_token
    } Else {
      g_mode := "offline"
      url    := OFFLINE_PAGE
    }
  }
  Gosub, OpenChrome
  Gosub, StartMonitor
Return

; ── Open Supermium in kiosk mode ─────────────────────────────
OpenChrome:
  If !FileExist(CHROME_EXE) {
    MsgBox, 16, Clock System Error, Supermium not found:`n%CHROME_EXE%`n`nPlace the supermium folder next to ClockSystem.ahk
    ExitApp
  }
  args := "--kiosk --no-first-run --disable-translate"
       . " --disable-infobars --disable-session-crashed-bubble"
       . " --disable-features=TranslateUI"
       . " --app=" . """" . url . """"
  Run, %CHROME_EXE% %args%,, , g_chromePID
  ; Wait for window, then force focus
  Sleep, 2500
  WinWait, ahk_pid %g_chromePID%,, 10
  WinActivate, ahk_pid %g_chromePID%
  WinSet, AlwaysOnTop, Off, ahk_pid %g_chromePID%
  ; Bring close button back on top
  Gosub, ShowCloseButton
Return

; ── Kill any running Supermium instances ──────────────────────
KillChrome:
  If (g_chromePID > 0) {
    Process, Close, %g_chromePID%
    g_chromePID := 0
    Sleep, 800
  }
  ; Belt-and-braces: kill by name too
  Process, Close, chrome.exe
  Sleep, 400
Return

; ── Draw the floating close button ───────────────────────────
DrawCloseButton:
  Gui, Close: Destroy
  Gui, Close: +AlwaysOnTop +ToolWindow -Caption +Owner
  Gui, Close: Color, 1a1d27
  Gui, Close: Font, s11 w600 cFFFFFF, Segoe UI
  Gui, Close: Add, Button, x0 y0 w80 h32 gDoClose, ✕  Close
  Gui, Close: Show, x0 y0 w80 h32 NoActivate, ClockSystemClose
  WinSet, TransColor, , ClockSystemClose
  g_closeHwnd := WinExist("ClockSystemClose")
Return

ShowCloseButton:
  Gui, Close: Show, NoActivate
Return

; ── Close button clicked ──────────────────────────────────────
DoClose:
  MsgBox, 4, Clock System, Are you sure you want to close Clock System?
  IfMsgBox, Yes
  {
    Gosub, KillChrome
    Gui, Close: Destroy
    ExitApp
  }
Return

; ── Hotkey: Ctrl+Alt+Q ───────────────────────────────────────
^!q::
  Gosub, DoClose
Return

; ── Server reachability check (synchronous via COM) ──────────
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

; ── Monitor: watch window title for token command from setup.html ──
;    setup.html sets document.title = "CMD:SAVE_TOKEN:<token>"
;    Also monitors online/offline state transitions
StartMonitor:
  SetTimer, MonitorTick, 1500
Return

MonitorTick:
  ; ── Handle setup page token submission ──────────────────────
  If (g_mode = "setup") {
    WinGetTitle, title, ahk_pid %g_chromePID%
    If (InStr(title, "CMD:SAVE_TOKEN:") = 1) {
      tok := SubStr(title, 16)  ; strip "CMD:SAVE_TOKEN:"
      tok := Trim(tok)
      If (tok != "") {
        WriteToken(tok)
        g_token := tok
        Gosub, Launch   ; relaunch into kiosk mode
      }
    }
    Return
  }

  ; ── Handle offline → online transition ──────────────────────
  If (g_mode = "offline") {
    If ServerReachable() {
      g_mode := "kiosk"
      url    := SERVER_BASE . g_token
      Gosub, KillChrome
      Gosub, OpenChrome
    }
    Return
  }

  ; ── Handle online → offline transition ──────────────────────
  If (g_mode = "kiosk") {
    ; Check if chrome window still exists
    If !WinExist("ahk_pid " . g_chromePID) {
      ; Chrome died — check if server is reachable
      If ServerReachable() {
        Gosub, OpenChrome  ; restart chrome
      } Else {
        g_mode := "offline"
        url    := OFFLINE_PAGE
        Gosub, OpenChrome
      }
    }
    Return
  }
Return

; ── Reset device (removes token, goes back to setup) ─────────
ResetDevice:
  MsgBox, 4, Reset Device, This will remove the device token and return to setup.`n`nContinue?
  IfMsgBox, Yes
  {
    FileDelete, %CONFIG_FILE%
    g_token := ""
    Gosub, Launch
  }
Return

; ── Hidden hotkey to reset device: Ctrl+Alt+Shift+R ──────────
^!+r::
  Gosub, ResetDevice
Return
