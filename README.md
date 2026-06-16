# Adobe Flash CS6 on Linux — with Huion pen pressure

Run **Adobe Flash Professional CS6** on Linux through Wine, with **working pen
pressure** on a **Huion** tablet.

<img width="500" height="500" alt="flashcs6linux_deploy_logo" src="https://github.com/user-attachments/assets/96d99be9-4e3b-4e2f-aed0-17e520ec0aa6" />

Everything needed is bundled, and one script does the whole job. You do **not**
need to know Wine, and you do **not** need to install it yourself — the installer
brings its own. The only command you ever type is `./install.sh`.

Tested on **Pop!_OS 24.04 / Ubuntu (noble)** with a Huion display tablet.

---

## Table of contents

1. [What you need](#1-what-you-need)
2. [Install Flash — the simple way](#2-install-flash--the-simple-way)
3. [Install with no internet (offline)](#3-install-with-no-internet-offline)
4. [For maintainers — building the pack](#4-for-maintainers--building-the-pack)
5. [How it works](#5-how-it-works)
6. [The unique part — the XWinTab patches](#6-the-unique-part--the-xwintab-patches)
7. [What gets installed](#7-what-gets-installed)
8. [Settings](#8-settings)
9. [If something is not right](#9-if-something-is-not-right)
10. [Credits](#10-credits)

---

## 1. What you need

- A computer running **Linux** (Ubuntu, Pop!_OS, or a close relative).
- Your **Flash CS6 installer** — an `.iso` file, or the folder that contains
  `Set-up.exe`.
- Your **`amtlib.dll`** file.
- A **Huion pen tablet**, plugged in.
- Either an **internet connection** (for the normal install, one download),
  **or** the offline **pack file** `flashcs6-pack.tar.gz` (see section 3).

You do **not** need to install Wine yourself.

---

## 2. Install Flash — the simple way

### 2.1 Get the project

Click the green **Code** button on the project's GitHub page, then **Download
ZIP**. Unzip it. You now have a folder containing `install.sh`.

(If you know how to use `git`, you can instead run
`git clone <repository-url>`.)

### 2.2 Put your two files into the `local` folder

Inside the project there is a folder named **`local`**. Using your normal file
manager, drag your two files into it:

- your Flash installer (the `.iso` file, **or** the installer folder), and
- your `amtlib.dll`.

### 2.3 Open a terminal in the project folder

The terminal is a small window where you type commands.

- Many file managers have a right‑click option like **"Open Terminal Here"** —
  use it inside the project folder, **or**
- open your applications, search for **"Terminal"**, then type `cd ` (with a
  space) and drag the project folder onto the window, and press **Enter**.

Tip: to paste into a terminal, press **Ctrl + Shift + V**.

### 2.4 Run the installer

Type this and press **Enter**:

```
./install.sh
```

- If you see **"Permission denied"**, type this once, then run it again:

  ```
  chmod +x install.sh
  ./install.sh
  ```

- The installer will ask for your **password** (to install software). Type it
  and press Enter. The password stays **invisible** while you type — that is
  normal, keep going.

The installer downloads everything it needs (Wine and the rest) the first time,
and keeps it for next time.

### 2.5 Follow the on‑screen prompts

The installer does most things on its own, but it will pause and ask you to do a
few things by hand. Read each message:

1. **Turn off your internet** when asked. The old Adobe setup tries to reach
   servers that no longer exist and will freeze otherwise.
2. A **Windows‑style setup window** opens. Click through it: choose the
   **"Try"** option, let it install, and **do not open Flash at the end**.
3. The installer shows you a **copy‑paste command** that puts your `amtlib.dll`
   in the right place. Copy it, paste it (Ctrl + Shift + V), press **Enter**.
4. The installer finishes everything else automatically.

When it is done, you can turn the internet back on.

### 2.6 Restart, then open Flash

Restart the computer once (this makes the tablet and pressure turn on
automatically every time).

Then find **Adobe Flash CS6** in your applications menu, under **Graphics**.
Pick the **Brush** tool, turn on pressure, and draw — the line gets **thicker
when you press harder**.

---

## 3. Install with no internet (offline)

If the computer has no internet, you only need one extra file: the pack,
**`flashcs6-pack.tar.gz`** (get it from the project's **Releases** page on
GitHub, or copy it from a USB stick).

1. Put `flashcs6-pack.tar.gz` **inside the project folder**, right next to
   `install.sh`.
2. Run `./install.sh` exactly as in section 2.

The installer notices the pack and **unpacks it automatically** — you never type
an unzip command. Everything installs without any internet.

---

## 4. For maintainers — building the pack

This section is only for the person who prepares the package for others (or
rebuilds it for a new Ubuntu version). A normal user can skip it.

On a working, **online** machine of the **same Ubuntu version** as the target:

1. Put the patched XWinTab source into the `xwintab` folder:

   ```
   cp -r /path/to/XWinTab/src            xwintab/src
   cp    /path/to/XWinTab/build32-def.sh  xwintab/build32-def.sh
   ```

2. Build the pack:

   ```
   ./make-offline-bundle.sh
   ```

   This downloads Wine and its dependencies, copies the Windows components,
   compiles the tablet code, and produces **`flashcs6-pack.tar.gz`**.

3. Create a **Release** on GitHub and attach `flashcs6-pack.tar.gz` to it.

4. Copy the file's download link into `config/settings.env`:

   ```
   WINE_PACK_URL="https://github.com/<you>/<repo>/releases/download/<tag>/flashcs6-pack.tar.gz"
   ```

5. Commit and push.

The git repository stays small (only scripts and source). The large pack lives
on the Release. Because the pack contains Wine packages, it is tied to **one
Ubuntu version and one CPU type** — build one pack per kind of target system.

---

## 5. How it works

Three pieces have to cooperate:

- **Wine** runs the Windows program (Flash) on Linux.
- **The tablet** needs two things to give pressure: it must be switched into its
  full ("proprietary") mode, and Flash must talk to it through a tablet driver
  called *wintab*. The standard Linux wintab support does not work with Flash, so
  this project ships a **patched driver** (see section 6).
- **System glue** turns the tablet's full mode on at every boot and keeps the
  pen mapped to the right screen.

The installer sets up all three, plus a menu shortcut.

---

## 6. the XWinTab patches

This patch is specific for the project.

Getting pen pressure into Flash through Wine normally fails, for a whole chain of
reasons. The solution is a **patched version of XWinTab** — a small open‑source
"wintab" driver.

XWinTab was originally written for the painting app **Rebelle**. Flash uses the
tablet in ways Rebelle never does, which exposed several hidden problems. We
found and fixed **seven** of them so XWinTab now works with the whole
**Flash / Animate** family:

1. **Function numbers.** Flash looks up the tablet functions by *number*, not by
   name. We added the official numbering so Flash can find them at all.
2. **Pens with no buttons.** The Huion pen reports zero buttons; the old code
   rejected it for that. We relaxed the check.
3. **The "is there a tablet?" question.** Flash asks a specific question to
   detect a tablet; it was going unanswered, so Flash thought there was none. We
   answered it.
4. **Pressure capabilities.** Before showing its pressure controls, Flash asks
   what the tablet can do (pressure range, axes). Those questions were ignored.
   We supplied the answers.
5. **A copy‑paste typo.** One line of the original code pointed a value at
   itself, which crashed Flash the instant the pen moved. Fixed.
6. **A missing safety check.** Flash asks "how many pen events are waiting?"
   while passing an empty bucket; the old code wrote into nothing and crashed.
   We added the guard.
7. **Re‑opening the tablet.** Flash lets go of the tablet and re‑opens it every
   time you close your last document. The old code refused the re‑open, so
   pressure died until you restarted Flash. It now re‑connects cleanly.

The full technical write‑up (including the exact crash signatures for problems 5
and 6) is in **`xwintab/PATCHES.md`**. These fixes are generic: they help any
Flash/Animate‑style program, not just one setup, and can be contributed back to
the original XWinTab project.

---

## 7. What gets installed

**Wine** (stable 11.0) — runs the Windows program.

**Windows components**, added into Wine using *winetricks*:

| Component             | What it is for                          |
|-----------------------|-----------------------------------------|
| `corefonts`           | the standard Windows fonts              |
| `vcrun2008`,`vcrun2010` | Visual C++ runtimes that Flash needs  |
| `msxml3`, `msxml6`    | XML engines that Flash uses             |
| `gdiplus`             | a graphics drawing library              |
| `atmlib`              | font support                            |
| `riched20`, `riched30`| rich‑text fields                        |
| `fontsmooth=rgb`      | clean font smoothing                    |

**The patched tablet driver** — `wintab32.dll` plus its helper, placed inside
Wine and set as the tablet driver **for Flash only**.

**Huion full mode** — `uclogic-tools` switches the tablet into the mode that
exposes full pressure. A small system service turns this on **automatically at
every boot**.

**Screen mapping** — a small login script keeps the pen mapped to the tablet's
own screen (so the pen does not roam across all your monitors).

**Menu launcher** — an "Adobe Flash CS6" entry under **Graphics**.

---

## 8. Settings

Most people never need this. If your hardware is different, open
**`config/settings.env`** in any text editor and change the values:

| Setting            | Meaning                                                    |
|--------------------|------------------------------------------------------------|
| `WINEPREFIX_DIR`   | where Flash gets installed                                 |
| `FLASH_INSTALL_SUBDIR` | the folder Flash installs into, inside Wine            |
| `TABLET_VID` / `TABLET_PID` | your tablet's USB ID (default Huion `256c:006e`)  |
| `KAMVAS_OUTPUT`    | the screen name the tablet uses (e.g. `HDMI-0`)            |
| `WINE_PACK_URL`    | the Release link to the offline pack                       |

The exact package versions known to work together are listed in
**`config/versions-known-good.txt`**.

---

## 9. If something is not right

**The pen moves the mouse across all screens instead of just the tablet.**
Restart the computer once more. If it continues, your screen may have a different
name on your machine — change `KAMVAS_OUTPUT` in `config/settings.env` (you can
list your screens with `xrandr --listmonitors`).

**There is no pen pressure at all.**
Make sure the tablet is plugged in, then restart. If other drawing programs (such
as Krita) also have no pressure, the tablet's full mode did not start.

**Flash will not start from the menu.**
Open a terminal and type `flash-cs6`, then press Enter — any error message there
helps identify the problem.

**Flash crashes while drawing.**
This is exactly what the seven patches fix. Make sure it is the **patched**
XWinTab that was installed (the pack contains it), not a stock version.

---

## 10. Credits

- **XWinTab** by Graham--M — https://github.com/Graham--M/XWinTab
  (a patched version is included here; see the `xwintab` folder and
  `xwintab/PATCHES.md`).
- **uclogic-tools** and the **hid_uclogic** driver by DIGImend —
  https://github.com/DIGImend

Adobe Flash Professional CS6 is a trademark and product of Adobe. It is not
included in this project.
