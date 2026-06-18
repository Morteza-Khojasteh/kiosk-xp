# kiosk-xp

A lightweight Windows XP kiosk launcher using **AutoHotkey** and **Supermium**.

---

## System Requirements

* Windows XP SP3
* AutoHotkey v1.1 (32-bit Unicode)
* Supermium Browser (XP-compatible Chromium)

---

# Installation Guide

## Folder Structure

Place all files in a single directory:

```text
kiosk-xp/
│
├── START.bat              # Double-click to launch
├── kiosk-xp.ahk           # Main launcher script
├── AutoHotkey.exe         # AutoHotkey runtime
├── setup.html             # Device token setup screen
├── offline.html           # Offline screen
├── config.json            # Created automatically on first run
│
└── supermium/
    ├── chrome.exe         # Supermium browser
    └── (other Supermium files)
```

---

## Step 1 — Install AutoHotkey v1.1 (32-bit)

On a machine with internet access:

**Download:**

https://www.autohotkey.com/download/1.1/

Download the ZIP package:

```text
AutoHotkey_1.1.xx.xx.zip
```

Inside the ZIP archive, locate:

```text
AutoHotkeyU32.exe
```

Rename it to:

```text
AutoHotkey.exe
```

Copy it into the root `kiosk-xp` folder.

### Important

> Use **AutoHotkey v1.1**, not v2.x.
>
> The launcher script uses v1.1 syntax and is not compatible with v2.
>
> Use the **Unicode 32-bit (U32)** version for Windows XP.

---

## Step 2 — Install Supermium

Supermium is a Chromium-based browser that supports Windows XP.

### Download

GitHub Releases:

https://github.com/win32ss/supermium/releases

### Installation

1. Download the **portable ZIP** version.
2. Extract the archive.
3. Rename the extracted folder to:

```text
supermium
```

4. Place the folder inside:

```text
kiosk-xp/
```

Final structure:

```text
kiosk-xp/
└── supermium/
    └── chrome.exe
```

### Verify

Ensure the following file exists:

```text
kiosk-xp/supermium/chrome.exe
```

---

## Step 3 — Deploy to the XP Machine

Copy the entire `kiosk-xp` folder to the target machine.

Recommended location:

```text
C:\kiosk-xp\
```

Launch the kiosk by running:

```text
START.bat
```

### First Run

When launched for the first time:

1. The setup screen will appear.
2. Enter the device token provided by your administrator.
3. The token is automatically saved to:

```text
config.json
```

4. The kiosk application will start immediately.

---

# Features

| Feature           | Description                                        |
| ----------------- | -------------------------------------------------- |
| Close Button      | Always-visible close button in the top-left corner |
| Close Hotkey      | `Ctrl + Alt + Q`                                   |
| Reset Device      | `Ctrl + Alt + Shift + R`                           |
| Offline Detection | Displays offline screen when server is unreachable |
| Auto Retry        | Re-checks server connectivity every 10 seconds     |
| Auto Restart      | Automatically relaunches browser if it crashes     |

---

# Automatic Startup

To launch the kiosk automatically when Windows XP starts:

### 1. Create a Shortcut

Right-click:

```text
START.bat
```

Select:

```text
Create Shortcut
```

### 2. Move the Shortcut

Copy the shortcut to:

```text
C:\Documents and Settings\All Users\Start Menu\Programs\Startup\
```

The kiosk will now launch automatically after system boot.

---

# Troubleshooting

## Supermium Not Found

**Error**

```text
Supermium not found
```

**Solution**

Verify the following file exists:

```text
kiosk-xp\supermium\chrome.exe
```

---

## AutoHotkey Not Found

**Error**

```text
AutoHotkey not found
```

**Solution**

Verify the following file exists:

```text
kiosk-xp\AutoHotkey.exe
```

---

## Setup Screen Appears Every Time

### Possible Cause

The configuration file is missing or corrupted.

### Solution

Delete:

```text
config.json
```

Restart the application and enter the device token again.

---

## Offline Screen Appears Despite Network Connectivity

### Checks

1. Verify the server is reachable:

```cmd
ping localhost
```

2. Verify IIS is running on the server.

3. Verify firewall rules are not blocking access.

4. Verify the configured application URL is correct.

---

# Security Notes

* Device tokens are stored locally in `config.json`.
* Restrict access to the kiosk folder where possible.
* Prevent users from modifying the configuration files.
* Disable unnecessary Windows XP services for kiosk deployments.

---

# Support

For deployment issues, verify:

* AutoHotkey is installed correctly.
* Supermium launches manually.
* Network connectivity is available.
* The backend server is reachable.
* The device token is valid.

---

**Version:** 1.0
**Platform:** Windows XP SP3
**Browser:** Supermium Chromium
