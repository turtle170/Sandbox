# Zig Sandbox Application Design Document

## 1. Overview
The Sandbox is a passive virtualization and API-forwarding layer written in Zig. It allows users to execute Windows `.exe` files in an isolated environment directly from the Windows Context Menu, with multi-architecture support (x86, x86-64, ARM32, ARM64).

## 2. Core Components

### 2.1. Shell Integration (`src/shell_integration.zig`)
*   **Context Menu:** Edits `HKEY_CLASSES_ROOT\exefile\shell\RunInSandbox` to pass the `.exe` path to the sandbox orchestrator.
*   **Environment Variables:** Reads a designated environment variable (e.g., `ZIG_SANDBOX_ARCH`) to force a specific architecture variant, overriding the PE header detection.

### 2.2. Execution Engine (`src/engine/`)
To achieve seamless execution across architectures, the sandbox employs two distinct execution backends:
*   **Native/Host Arch (WHPX):** Uses the Windows Hypervisor Platform (WHPX) for near-native performance when the target architecture matches the host.
*   **Cross-Arch (Unicorn Engine):** Uses the Unicorn Engine (a lightweight CPU emulator based on QEMU) to emulate instructions when running x86 on ARM or ARM on x86.

### 2.3. Memory Management ("Auto-Fit") (`src/memory.zig`)
To achieve the "perfect byte + 1MB headroom" requirement:
*   The Sandbox does not pre-allocate a massive block of RAM.
*   Instead, it uses **Demand Paging**. Memory is mapped in the Hypervisor/Emulator as "unbacked". 
*   When the guest code triggers a page fault (Memory Access Violation), the Sandbox intercepts it, allocates exactly 1 page (4KB) of host memory, maps it into the guest, and resumes execution.
*   A background threshold monitor ensures a rolling 1MB of pre-allocated (but mapped) "headroom" exists ahead of the heap/stack to prevent excessive page-fault stalls during rapid allocations.
*   On shutdown/crash, the memory mapping is immediately destroyed, returning resources to the host OS instantly.

### 2.4. OS Subsystem & API Forwarding (`src/subsystem/`)
Rather than booting a full copy of Windows inside the VM (which is slow and bloats RAM), the Sandbox acts as a **Library OS / API Forwarder** (similar to Microsoft Drawbridge).
*   **PE Loader:** Parses the `.exe`, allocates virtual memory, and loads sections.
*   **IAT Hooking / Syscall Interception:** Traps calls to standard Windows DLLs (kernel32.dll, user32.dll).
*   **File System:** Creates a Virtual File System (VFS) overlay. The app sees a fake `C:\` drive, while writes are redirected to a temporary sandbox directory in memory or on disk.

### 2.5. GUI & Windows Hooking (`src/gui/`)
*   **Shared Memory (SHM) Backbuffer:** When the sandboxed app attempts to create a window, the Sandbox creates a transparent Host Window.
*   The Sandbox intercepts GDI/DirectX drawing calls and redirects them to a Shared Memory buffer.
*   The Host process reads this SHM buffer and composites it onto the Host Window.
*   Mouse and keyboard inputs on the Host Window are translated and injected back into the Sandbox's virtual event queue.

### 2.6. Networking (`src/network.zig`)
*   **WinTUN Integration:** The Sandbox installs/uses a WinTUN virtual network adapter.
*   **Randomization:** On startup, the Sandbox generates a random MAC address and assigns a random private IP (e.g., in the `10.x.x.x` range).
*   **NAT:** A lightweight user-mode NAT translates the Sandbox's random IP traffic to the Host's real network adapter, completely isolating the app from discovering the host's real IP or MAC.

## 3. Development Phases

*   **Phase 1: Shell Integration & PE Parsing**
    *   Setup Zig project, handle Context Menu registry keys, parse PE files to detect architecture.
*   **Phase 2: Execution Engine & Memory**
    *   Integrate Unicorn Engine via C ABI.
    *   Setup WHPX API.
    *   Implement Demand Paging for the "Auto-Fit" memory model.
*   **Phase 3: Subsystem & API Forwarding**
    *   Implement basic `kernel32` (memory, threads) forwarding.
*   **Phase 4: GUI & SHM Backbuffer**
    *   Implement `user32` and `gdi32` intercepts. Host window creation and SHM blitting.
*   **Phase 5: Networking (WinTUN)**
    *   Integrate WinTUN, MAC/IP spoofing, and NAT.

## 4. Dependencies
*   **Zig:** `master` (or latest stable)
*   **Win32 API:** Zig bindings (e.g., `zigwin32`)
*   **Unicorn Engine:** `unicorn.dll` and C headers
*   **WinTUN:** `wintun.dll` and C headers