# Krita for Windows on Arm

Native **ARM64** build of Krita for Windows.

Go to releases page and download the latest .zip file and extract it wherever you want 
on your Windows 11 ARM64 machine and run krita-x.x.x.x-windows-arm64-setup.exe

Upstream Krita ships only x64 Windows builds, which run under emulation on ARM
devices (Snapdragon X, etc.): slower and heavier on battery. This fork adds the
tooling and patches needed to produce a **native arm64** Krita.


## Credits / license

Krita is © the Krita/KDE community (GPL). KDE Craft is © KDE (BSD-2-Clause).
The arm64 build tooling and patches in this repo are provided under the same
licenses as the files they modify. This is an unofficial community port.
