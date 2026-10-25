# Installing HomePad

HomePad is a free app made by a friend, not by a company, so it isn't registered with Apple. Because of that, your
Mac blocks it the first time and you have to tell it once that the app is OK. The steps below take about five
minutes and you only do them once.

**You need:** a Mac with macOS 13 (Ventura) or newer. Both Apple silicon and Intel Macs work.

---

## 1. Put HomePad in Applications

1. Download **HomePad.zip** and double-click it if it wasn't unzipped already. You get a **HomePad** folder with
   the app (a blue grid icon) and these instructions.
2. Open a Finder window, click **Applications** in the sidebar, and drag the **HomePad** app into it.

Do this before opening the app. Started from Downloads, it can lose its permissions later.

## 2. Open it the first time

1. In Applications, double-click **HomePad**.
2. A message says **"HomePad" Not Opened** (or "Apple could not verify..."). Click **Done**. Don't click Move to
   Trash.
3. Open **System Settings** ( menu → System Settings) and click **Privacy & Security** in the sidebar.
4. Scroll down to the **Security** section. Next to *"HomePad" was blocked to protect your Mac*, click **Open
   Anyway**.
5. Enter your Mac password or use Touch ID, then click **Open Anyway** or **Open** in the message that follows.

From now on HomePad opens normally.

> **On macOS 13 Ventura or 14 Sonoma** there's a shortcut: right-click HomePad in Applications, choose **Open**,
> then click **Open** again.

## 3. The Setup Guide

A **Welcome to HomePad** window appears. It asks for three permissions. Each one is optional, but HomePad works
best with all three. Go from top to bottom:

**Screen Recording** (shows a preview of each window when you point at a running app)
1. Click the red **Allow…**. A message with a padlock appears.
2. Click **Open System Settings** in that message.
3. Turn on the switch next to **HomePad**.
4. Click **Quit & Reopen**. HomePad restarts by itself and the Welcome window comes back.

**Accessibility** (jumps to the window you pick, and powers the double-tap shortcut)
1. Click the red **Allow…**, then **Open System Settings** in the padlock message.
2. Turn on the switch next to **HomePad** and enter your password if asked. The Welcome window comes back by itself.

**Full Disk Access** (lets search find files in Documents, Desktop and Downloads)
1. Click the red **Allow…**. System Settings opens, with a small HomePad window next to it.
2. Turn on the switch next to **HomePad**. If HomePad isn't in the list, drag the icon from the small window into
   the list, then turn its switch on.
3. Click **Quit & Reopen**.

When all three are green, choose how to open HomePad (the standard shortcut is **Option-Space**) and click **Get
started**.

> Don't worry about the screen recording wording: HomePad only makes small window previews on your own screen.
> Nothing is recorded, saved or sent anywhere.

## 4. Using it

- Press **Option-Space** to open HomePad and press it again to close it. Then start typing to search, or click an
  app.
- HomePad lives in the **menu bar** at the top of the screen (the grid icon), not in the Dock. Its menu has
  **Settings…**, **Setup Guide…** and **Quit HomePad**.
- In **Settings**, you can turn on **Launch at login** so HomePad is always there, or **Hide the Dock** if you want
  HomePad to replace it.

---

## Installing a newer version

1. Quit HomePad (menu-bar icon → **Quit HomePad**).
2. Drag the new **HomePad** into Applications and choose **Replace**.
3. Open it. If your Mac blocks it again, repeat step 2 ("Open it the first time").

Your apps, categories and settings are kept.

## Removing HomePad

1. If you turned on **Hide the Dock**, turn it off first in HomePad's Settings, so your Dock comes back.
2. Quit HomePad and drag it from Applications to the Trash.
3. Optional: in System Settings → Privacy & Security, remove HomePad from Screen & System Audio Recording,
   Accessibility and Full Disk Access with the **−** button.

## If something goes wrong

**"HomePad is damaged and can't be opened"**
That's the same block in a different form. The app isn't damaged. Open **Terminal** (Applications → Utilities),
paste this line, press Return, then open HomePad again:

```
xattr -dr com.apple.quarantine /Applications/HomePad.app
```

**Nothing seems to happen when I open it**
HomePad has no window of its own. Look for the grid icon in the menu bar, or press Option-Space.

**Option-Space doesn't work**
Another app may be using that shortcut. HomePad tells you in Settings → Shortcut when it can tell who. Pick another
shortcut there, or choose a double-tap key.

**A permission is switched on in System Settings, but HomePad still shows it red**
In that System Settings list, select HomePad, remove it with **−**, then click **Allow…** in HomePad again.

**I want to start from scratch**
HomePad Settings → **Start Over…** takes back the permissions and shows the Setup Guide again.
