# kiosk-xp

=====================================================
  XP Kiosk — Setup Instructions
  Windows XP / POSReady 2009
=====================================================

FOLDER STRUCTURE (everything in one folder):
--------------------------------------------
kiosk-xp\
  START.bat              <- Double-click to launch
  kiosk-xp.ahk        <- Main launcher script
  AutoHotkey.exe         <- AHK runtime (you provide)
  setup.html             <- Device token entry screen
  offline.html           <- No-connection screen
  config.json            <- Created automatically on first run
  supermium\
    chrome.exe           <- Supermium browser (you provide)
    (all other Supermium files)


STEP 1 — Get AutoHotkey v1.1 (32-bit)
--------------------------------------
On a machine with internet access:
  https://www.autohotkey.com/download/1.1/

Download: AutoHotkey_1.1.xx.xx.zip
Inside the zip, find: AutoHotkeyU32.exe
Rename it to: AutoHotkey.exe
Place it in the kiosk-xp\ folder.

IMPORTANT: Use v1.1 NOT v2.x — the script is v1.1 syntax.
IMPORTANT: Use the U32 (Unicode 32-bit) variant for XP.


STEP 2 — Get Supermium (XP-compatible Chromium)
-------------------------------------------------
Supermium is a Chromium fork that supports Windows XP.

Download from: https://github.com/win32ss/supermium/releases
Get the ZIP version (portable, not installer).
Extract it and rename the folder to: supermium
Place the supermium\ folder inside kiosk-xp\.

The file kiosk-xp\supermium\chrome.exe must exist.


STEP 3 — Deploy to XP machine
------------------------------
Copy the entire kiosk-xp\ folder to the XP machine.
Suggested location: C:\kiosk-xp\

Double-click START.bat to launch.

On first run, the setup screen will appear.
Enter the device token provided by your administrator.
The token is saved to config.json automatically.
The app will load the kiosk screen immediately after.


FEATURES
--------
  Close button     Visible button top-left, always on top
  Close hotkey     Ctrl + Alt + Q
  Reset device     Ctrl + Alt + Shift + R (re-shows setup screen)
  Offline page     Shown automatically if server unreachable
  Auto-retry       Checks server every 10s when offline
  Auto-restart     Relaunches browser if it crashes


AUTOSTART ON WINDOWS XP BOOT
-----------------------------
To launch automatically when XP starts:
  1. Right-click START.bat -> Create Shortcut
  2. Move shortcut to:
     C:\Documents and Settings\All Users\Start Menu\Programs\Startup\


TROUBLESHOOTING
---------------
"Supermium not found"
  -> Check supermium\chrome.exe exists in the kiosk-xp folder

"AutoHotkey not found"
  -> Check AutoHotkey.exe exists in the kiosk-xp folder

Token screen keeps appearing
  -> config.json may be missing or corrupt
  -> Delete config.json and re-enter token

Server shows offline but network is connected
  -> Check that localhost is reachable (ping from cmd)
  -> Check IIS is running on the server
