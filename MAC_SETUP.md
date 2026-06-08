# Setting Up on a Mac — A Beginner's Guide

> **You don't need to be a coder to use this.** This guide walks you through every step, uses plain language, and explains what's happening and why. Take it one step at a time — there's no rush.

---

## Before You Start — What Is This, Exactly?

This project lives on **GitHub** (think of it as a filing cabinet on the internet where code and files are shared). To use it, you'll download a copy of the files to your own Mac. That's it. Nothing gets installed on the internet — everything runs on your own computer.

---

## 📖 Glossary

New to terms like "repo" or "clone"? Here's a plain-English cheat sheet.

| Word | What it actually means |
|------|------------------------|
| **GitHub** | A website where people share and store project files publicly. Like Google Drive, but for code. |
| **Repository (Repo)** | One project's folder on GitHub — containing all its files, history, and instructions. This project is a repo. |
| **Clone** | Making a copy of a repo from GitHub onto your own computer. Like downloading a folder, but smarter — it stays connected so you can get updates later. |
| **Commit** | A saved snapshot of changes made to a project. Think of it like "Track Changes" in Word — every tweak is recorded with a note about what changed. |
| **Release** | A specific, stable version of the project that the author has packaged up and marked as ready to use. Releases have version numbers like `v1.0` or `v2.3`. |
| **Terminal** | A text-based window on your Mac where you can type commands directly. It looks plain, but it's very powerful. Don't worry — this guide tells you exactly what to type. |

---

## Step 1 — Download the Project Files

You have two options. **Option A is recommended** if you just want to use the tools. Option B is for anyone who wants to stay up to date automatically.

---

### Option A — Download as a ZIP (Easiest)

This is like downloading any file from the internet.

1. Go to the project page on GitHub: `https://github.com/bomkino/pitch-deck-tools`
2. Click the green **`<> Code`** button near the top right of the page.
3. In the dropdown that appears, click **"Download ZIP"**.
4. Your Mac will download a file called `pitch-deck-tools-main.zip` — probably into your **Downloads** folder.
5. Double-click the ZIP file to unzip it. A folder called `pitch-deck-tools-main` will appear.
6. Move that folder somewhere easy to find — your **Desktop** or **Documents** folder works well.

✅ You now have all the project files on your Mac.

---

### Option B — Clone with GitHub Desktop (Stays Up to Date)

If the project gets updated in the future and you want those updates easily:

1. Download **GitHub Desktop** (free) from [desktop.github.com](https://desktop.github.com).
2. Install it and sign in (or create a free GitHub account if you don't have one).
3. Go to `https://github.com/bomkino/pitch-deck-tools` in your browser.
4. Click the green **`<> Code`** button, then click **"Open with GitHub Desktop"**.
5. GitHub Desktop will ask where to save it — choose somewhere easy like your Documents folder.
6. Click **Clone**. The files will download to your Mac.

To get updates later, open GitHub Desktop and click **"Fetch origin"** then **"Pull"**.

---

## Step 2 — Running the Tools

The project includes two types of files you can run. Here's the difference:

---

### 🖱️ Double-Click Command Files (No typing required)

Some tools in this project are packaged as **`.command` files** (or `.sh` files). These are scripts — small sets of instructions your Mac can run automatically.

**To run one:**

1. Open the project folder.
2. Find the file ending in `.command` (for example, `run-tool.command`).
3. **Double-click it.** A Terminal window will open and the tool will run on its own.
4. When it's finished, you'll see something like `Done` or `Process completed` in the window. You can close it.

> **Nothing to type. Just double-click.**

---

### ⌨️ Terminal Commands (When the guide says to type something)

Some steps in the documentation ask you to type a command into Terminal. Here's how:

1. Press **`Command (⌘) + Space`** to open Spotlight Search.
2. Type `Terminal` and press **Return**.
3. A plain white (or black) window opens with a blinking cursor.
4. Type (or copy-paste) the command exactly as shown — then press **Return** to run it.

> **Tip:** To paste into Terminal, use **`Command (⌘) + V`** — same as anywhere else on a Mac.

---

## Step 3 — macOS Permissions Troubleshooting

macOS has safety features that may block unfamiliar files from running. This is normal and not a sign something is wrong. Here's how to handle the most common situations:

---

### ❌ "This app can't be opened because it is from an unidentified developer"

This happens when macOS doesn't recognise the source of a `.command` file.

**Fix:**
1. Don't double-click the file.
2. Instead, **right-click** (or hold `Control` and click) the file.
3. Select **"Open"** from the menu.
4. A warning box will appear — this time it will have an **"Open" button**. Click it.
5. The file will run, and macOS will remember your choice next time.

---

### 🔒 "Permission denied" in Terminal

If you see `Permission denied` after running a command, the file needs to be made executable first.

**Fix — type this in Terminal** (replace `filename.command` with the actual file name):

```
chmod +x filename.command
```

Then try double-clicking the file again.

---

### 🚫 Gatekeeper Blocking a Downloaded File

If you downloaded the ZIP and macOS is blocking everything in the folder:

1. Open **System Settings** (the gear icon in your Dock).
2. Go to **Privacy & Security**.
3. Scroll down — you'll see a message about the blocked file with an **"Allow Anyway"** button. Click it.
4. Try opening the file again and click **Open** when prompted.

---

### 📂 "No such file or directory" in Terminal

This usually means Terminal is looking in the wrong folder.

**Fix:** Navigate to the project folder first. In Terminal, type:

```
cd ~/Desktop/pitch-deck-tools-main
```

(Adjust the path if you saved the folder somewhere other than your Desktop.)

Then try your command again.

---

## You're All Set

If something isn't working and you've tried the steps above, open a new **Issue** on the GitHub page and describe what you see — including any exact error message. The more detail you give, the easier it is to help.

---

*This guide covers macOS 12 Monterey and later. Steps may look slightly different on older versions.*
