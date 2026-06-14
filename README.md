# Krita for Windows on Arm

**Krita, running natively on your ARM laptop.** No emulation, no x64 trickery —
just the painting app, built to run directly on Snapdragon / Windows-on-ARM
devices so it opens faster and is kinder to your battery.

<img width="334" height="98" alt="Krita on Windows on ARM" src="https://github.com/user-attachments/assets/d4cf777d-bdaa-4056-a3f9-7afdfaf4d455" />

If you're a painter who just wants to open the program and draw, you're in the
right place. 🎨

---

## Download &amp; install

Head to the **[Releases page](../../releases/latest)** and pick one:

| File | What it's for |
|------|---------------|
| **krita-…-windows-arm64-setup.exe** | The normal installer. Double-click, click through, done. Krita shows up in your Start Menu with a desktop shortcut, and you can remove it later from *Add or remove programs* like any other Windows app. |
| **krita-…-windows-arm64.zip** | The portable version. Unzip it anywhere and run `bin\krita.exe`. Nothing gets installed — handy for a USB stick or trying it out. |

**You'll need:** Windows 10 or 11 on an **ARM64** device (Snapdragon X and
friends). On a regular Intel/AMD PC, grab the official build from
[krita.org](https://krita.org/) instead — this one is just for ARM.

That's it. Open Krita and paint.

---

## Good to know

- This is an independent, community-made build compiled from Krita's source for
  ARM64. Brushes, layers, animation, the usual file formats and Python scripting
  all work.
- It's lovingly hand-built rather than officially released, so if something
  feels off, please [open an issue](../../issues) — and keep backups of artwork
  you care about, as you would with any new tool.

---

## Why this exists

Upstream Krita only ships x64 Windows builds. On an ARM laptop those run through
an emulation layer — they work, but they're slower to launch and use more
battery. This project adds the tooling and patches needed to compile a **truly
native arm64 Krita**, so the app runs on the hardware directly.

---

## Building it yourself (for developers)

You don't need this section to *use* Krita — only if you want to compile it.

On a Windows 11 ARM64 machine, double-click **`build-krita-arm64.bat`**. It
self-elevates, installs the toolchain it needs, then compiles Krita's whole
dependency tree and Krita itself from source. The first run takes hours.

Under the hood it runs `scripts/build-krita-arm64.ps1`, which drives KDE's
`krita-deps-management` recipes plus the ARM64 fixes tracked here:

- `arm64-patches/` — every source/recipe patch that makes the toolchain build
  on arm64, with `CHANGES.md` and `KRITA-SOURCE-PATCHES.md` explaining why.
- `packaging/arm64-installer/` — the self-contained packaging + NSIS installer
  used to produce the files on the Releases page.
- `BUILD-STATE.md` — current status of the dependency tree.

---

## Credits / license

Krita is © the Krita / KDE community (GPL). The arm64 build tooling and patches
in this repo are provided under the same licenses as the files they modify.
This is an unofficial community port, made with care for everyone painting on an
ARM laptop.
