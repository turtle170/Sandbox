# Zig Sandbox Professional Installer
$InstallDir = "$env:LOCALAPPDATA\ZigSandbox"
$AppName = "Zig Sandbox"

Write-Host "Installing $AppName..." -ForegroundColor Cyan

# 1. Create directory
if (!(Test-Path $InstallDir)) {
    New-Item -Path $InstallDir -ItemType Directory | Out-Null
}

# 2. Copy files
Copy-Item -Path "zig-out\bin\Sandbox.exe" -Destination $InstallDir\Sandbox.exe -Force
Copy-Item -Path "zig-out\bin\unicorn.dll" -Destination $InstallDir\unicorn.dll -Force
Copy-Item -Path "zig-out\bin\wintun.dll" -Destination $InstallDir\wintun.dll -Force

# 3. Register Context Menu
Set-Location $InstallDir
.\Sandbox.exe install

# 4. Create Uninstaller in Registry
$UninstallKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\ZigSandbox"
if (!(Test-Path $UninstallKey)) {
    New-Item -Path $UninstallKey | Out-Null
}
Set-ItemProperty -Path $UninstallKey -Name "DisplayName" -Value $AppName
Set-ItemProperty -Path $UninstallKey -Name "UninstallString" -Value "powershell.exe -ExecutionPolicy Bypass -File `"$InstallDir\Uninstall.ps1`""
Set-ItemProperty -Path $UninstallKey -Name "DisplayVersion" -Value "1.0.0"
Set-ItemProperty -Path $UninstallKey -Name "Publisher" -Value "ZigSandbox"

# 5. Create Uninstall Script
$UninstallScript = @"
`$InstallDir = `"$InstallDir`"
Write-Host `"Uninstalling Zig Sandbox...`" -ForegroundColor Yellow
Set-Location `$InstallDir
.\Sandbox.exe uninstall
Remove-Item -Path `$InstallDir -Recurse -Force
Remove-Item -Path `"HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\ZigSandbox`" -Force
Write-Host `"Uninstallation Complete!`"
"@
$UninstallScript | Out-File -FilePath "$InstallDir\Uninstall.ps1" -Encoding utf8

Write-Host "Installation Complete! You can now right-click any .exe and select 'Run in Sandbox'." -ForegroundColor Green
