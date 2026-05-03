const std = @import("std");
const windows = std.os.windows;
const ntdll = windows.ntdll;

const WPARAM = usize;
const LPARAM = isize;
const LRESULT = isize;

const kernel32 = struct {
    pub extern "kernel32" fn GetModuleHandleW(lpModuleName: ?windows.LPCWSTR) callconv(.winapi) ?windows.HANDLE;
};

const user32 = struct {
    pub extern "user32" fn RegisterClassExW(lpwcx: *const WNDCLASSEXW) callconv(.winapi) windows.ATOM;
    pub extern "user32" fn CreateWindowExW(
        dwExStyle: windows.DWORD,
        lpClassName: windows.LPCWSTR,
        lpWindowName: windows.LPCWSTR,
        dwStyle: windows.DWORD,
        x: i32,
        y: i32,
        nWidth: i32,
        nHeight: i32,
        hWndParent: ?windows.HWND,
        hMenu: ?windows.HMENU,
        hInstance: windows.HINSTANCE,
        lpParam: ?windows.LPVOID,
    ) callconv(.winapi) ?windows.HWND;
    pub extern "user32" fn ShowWindow(hWnd: windows.HWND, nCmdShow: i32) callconv(.winapi) windows.BOOL;
    pub extern "user32" fn UpdateWindow(hWnd: windows.HWND) callconv(.winapi) windows.BOOL;
    pub extern "user32" fn GetMessageW(lpMsg: *MSG, hWnd: ?windows.HWND, wMsgFilterMin: u32, wMsgFilterMax: u32) callconv(.winapi) windows.BOOL;
    pub extern "user32" fn TranslateMessage(lpMsg: *const MSG) callconv(.winapi) windows.BOOL;
    pub extern "user32" fn DispatchMessageW(lpMsg: *const MSG) callconv(.winapi) LRESULT;
    pub extern "user32" fn DefWindowProcW(hWnd: windows.HWND, Msg: u32, wParam: WPARAM, lParam: LPARAM) callconv(.winapi) LRESULT;
    pub extern "user32" fn BeginPaint(hWnd: windows.HWND, lpPaint: *PAINTSTRUCT) callconv(.winapi) ?windows.HDC;
    pub extern "user32" fn EndPaint(hWnd: windows.HWND, lpPaint: *const PAINTSTRUCT) callconv(.winapi) windows.BOOL;
    pub extern "user32" fn PostQuitMessage(nExitCode: i32) callconv(.winapi) void;
};

const gdi32 = struct {
    pub extern "gdi32" fn SetDIBitsToDevice(
        hdc: windows.HDC,
        xDest: i32,
        yDest: i32,
        w: u32,
        h: u32,
        xSrc: i32,
        ySrc: i32,
        StartScan: u32,
        cLines: u32,
        lpvBits: [*]const u8,
        lpbmi: *const BITMAPINFO,
        ColorUse: u32,
    ) callconv(.winapi) i32;
};

const WNDCLASSEXW = extern struct {
    cbSize: u32 = @sizeOf(WNDCLASSEXW),
    style: u32,
    lpfnWndProc: *const fn (windows.HWND, u32, WPARAM, LPARAM) callconv(.winapi) LRESULT,
    cbClsExtra: i32 = 0,
    cbWndExtra: i32 = 0,
    hInstance: windows.HINSTANCE,
    hIcon: ?windows.HICON = null,
    hCursor: ?windows.HCURSOR = null,
    hbrBackground: ?windows.HBRUSH = null,
    lpszMenuName: ?windows.LPCWSTR = null,
    lpszClassName: windows.LPCWSTR,
    hIconSm: ?windows.HICON = null,
};

const POINT = extern struct {
    x: i32,
    y: i32,
};

const MSG = extern struct {
    hWnd: ?windows.HWND,
    message: u32,
    wParam: WPARAM,
    lParam: LPARAM,
    time: u32,
    pt: POINT,
};

const RECT = extern struct {
    left: i32,
    top: i32,
    right: i32,
    bottom: i32,
};

const PAINTSTRUCT = extern struct {
    hdc: windows.HDC,
    fErase: windows.BOOL,
    rcPaint: RECT,
    fRestore: windows.BOOL,
    fIncUpdate: windows.BOOL,
    rgbReserved: [32]u8,
};

const BITMAPINFOHEADER = extern struct {
    biSize: u32 = @sizeOf(BITMAPINFOHEADER),
    biWidth: i32,
    biHeight: i32,
    biPlanes: u16 = 1,
    biBitCount: u16 = 32,
    biCompression: u32 = 0, // BI_RGB
    biSizeImage: u32 = 0,
    biXPelsPerMeter: i32 = 0,
    biYPelsPerMeter: i32 = 0,
    biClrUsed: u32 = 0,
    biClrImportant: u32 = 0,
};

const BITMAPINFO = extern struct {
    bmiHeader: BITMAPINFOHEADER,
    bmiColors: [1]u32 = .{0},
};

var global_gui: ?*Gui = null;

fn wndProc(hWnd: windows.HWND, msg: u32, wParam: WPARAM, lParam: LPARAM) callconv(.winapi) LRESULT {
    switch (msg) {
        0x0002 => { // WM_DESTROY
            user32.PostQuitMessage(0);
            return 0;
        },
        0x000F => { // WM_PAINT
            var ps: PAINTSTRUCT = undefined;
            if (user32.BeginPaint(hWnd, &ps)) |hdc| {
                if (global_gui) |gui| {
                    const bmi = BITMAPINFO{
                        .bmiHeader = .{
                            .biWidth = @intCast(gui.width),
                            .biHeight = -@as(i32, @intCast(gui.height)), // Top-down
                        },
                    };
                    _ = gdi32.SetDIBitsToDevice(
                        hdc,
                        0, 0, gui.width, gui.height,
                        0, 0, 0, gui.height,
                        gui.shm_buffer,
                        &bmi,
                        0, // DIB_RGB_COLORS
                    );
                }
                _ = user32.EndPaint(hWnd, &ps);
            }
            return 0;
        },
        else => return user32.DefWindowProcW(hWnd, msg, wParam, lParam),
    }
}

pub const Gui = struct {
    shm_handle: windows.HANDLE,
    shm_buffer: [*]u8,
    host_window: windows.HWND = undefined,
    width: u32,
    height: u32,

    pub fn init(width: u32, height: u32) !Gui {
        const size: i64 = @intCast(width * height * 4);
        var handle: windows.HANDLE = undefined;
        var max_size: windows.LARGE_INTEGER = size;

        const status = ntdll.NtCreateSection(
            &handle,
            .{ .STANDARD = .{ .RIGHTS = .REQUIRED, .SYNCHRONIZE = true }, .SPECIFIC = .{ .bits = 0xF } },
            null,
            &max_size,
            .{ .READWRITE = true },
            .{ .COMMIT = true },
            null,
        );

        if (status != .SUCCESS) return error.ShmCreationFailed;

        var base_addr: ?windows.PVOID = null;
        var view_size: usize = 0;
        const map_status = ntdll.NtMapViewOfSection(
            handle,
            @ptrFromInt(@as(usize, @bitCast(@as(isize, -1)))),
            @ptrCast(&base_addr),
            null,
            0,
            null,
            &view_size,
            @enumFromInt(1),
            .{ .RESERVE = false },
            .{ .READWRITE = true },
        );

        if (map_status != .SUCCESS) {
            _ = ntdll.NtClose(handle);
            return error.MapViewFailed;
        }

        const shm_ptr: [*]u8 = @ptrCast(base_addr.?);
        @memset(shm_ptr[0..@intCast(size)], 0xAA);

        return .{
            .shm_handle = handle,
            .shm_buffer = shm_ptr,
            .width = width,
            .height = height,
        };
    }

    pub fn show(self: *Gui) !void {
        global_gui = self;
        const hInstance = @as(windows.HINSTANCE, @ptrCast(kernel32.GetModuleHandleW(null)));
        const className = try std.unicode.utf8ToUtf16LeAllocZ(std.heap.page_allocator, "SandboxWindowClass");
        defer std.heap.page_allocator.free(className);

        const wcx = WNDCLASSEXW{
            .style = 0,
            .lpfnWndProc = wndProc,
            .hInstance = hInstance,
            .lpszClassName = className.ptr,
            .hbrBackground = @ptrFromInt(6), // COLOR_WINDOW + 1
        };

        _ = user32.RegisterClassExW(&wcx);

        const hwnd = user32.CreateWindowExW(
            0,
            className.ptr,
            className.ptr,
            0x00CF0000, // WS_OVERLAPPEDWINDOW
            100, 100, @intCast(self.width), @intCast(self.height),
            null, null, hInstance, null,
        ) orelse return error.WindowCreationFailed;

        self.host_window = hwnd;
        _ = user32.ShowWindow(hwnd, 5); // SW_SHOW
        _ = user32.UpdateWindow(hwnd);
        
        std.debug.print("GUI: Host window created and shown.\n", .{});
    }

    pub fn loop(self: *Gui) void {
        _ = self;
        var msg: MSG = undefined;
        while (user32.GetMessageW(&msg, null, 0, 0) != .FALSE) {
            _ = user32.TranslateMessage(&msg);
            _ = user32.DispatchMessageW(&msg);
        }
    }

    pub fn deinit(self: *Gui) void {
        _ = ntdll.NtUnmapViewOfSection(
            @ptrFromInt(@as(usize, @bitCast(@as(isize, -1)))),
            self.shm_buffer,
        );
        _ = ntdll.NtClose(self.shm_handle);
    }
};
