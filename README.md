# Zig Sandbox

A lightweight, multi-architecture sandbox for Windows.

## Features
- **Passive Context Menu:** Right-click any `.exe` to "Run in Sandbox".
- **Multi-Arch Support:** x86-64 (Native WHPX) and x86/ARM (Unicorn Emulation).
- **Auto-Fit Memory:** Demand-paging with 1MB rolling headroom.
- **Isolated Network:** Randomized MAC and IP using WinTun.
- **Seamless GUI:** Shared Memory backbuffer relay.

## Installation (Out-of-the-Box)
To install the Sandbox and register the context menu, run the following command in PowerShell:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\Install.ps1
```

## Manual MSI Creation
If you have the **WiX Toolset** installed, you can generate a standard `.msi` installer:

```powershell
candle.exe Sandbox.wxs
light.exe Sandbox.wixobj -o Sandbox.msi
```

## Development
To rebuild the project:
```powershell
zig build
```
The binaries and required DLLs will be in `zig-out/bin`.
