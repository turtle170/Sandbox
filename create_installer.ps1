$msiPath = "SandboxInstaller.msi"
$files = @(
    "zig-out\bin\Sandbox.exe",
    "zig-out\bin\unicorn.dll",
    "zig-out\bin\wintun.dll"
)

# Create a new MSI database
$installer = New-Object -ComObject WindowsInstaller.Installer
$database = $installer.OpenDatabase($msiPath, 1) # 1 = Create

# Create the minimal schema
# This is complex to do from scratch in COM, but let's try a simplified version
# or use a pre-existing template if available.
# Actually, creating a full MSI from scratch via COM is extremely verbose (requires ~20 tables).

# Alternative: Use a professional PowerShell wrapper if I can't do it raw.
# Since I can't download modules, I will create a professional SELF-INSTALLING EXE using IExpress.

# IExpress directive file (.sed)
$sedContent = @"
[Version]
Class=IEXPRESS
SEDVersion=3
[Options]
PackagePurpose=InstallApp
ShowInstallProgramWindow=0
HideExtractAnimation=0
UseLongFileName=1
InsideCompressed=0
CAB_FixedSize=0
CAB_ResvCodeSigning=0
RebootMode=N
InstallPrompt=%InstallPrompt%
DisplayLicense=%DisplayLicense%
FinishMessage=%FinishMessage%
TargetName=%TargetName%
FriendlyName=%FriendlyName%
AppLaunched=%AppLaunched%
PostInstallCmd=%PostInstall%
SourceFiles=SourceFiles
[Strings]
InstallPrompt=Do you want to install Zig Sandbox?
DisplayLicense=
FinishMessage=Installation Complete!
TargetName=$(Get-Location)\SandboxSetup.exe
FriendlyName=Zig Sandbox
AppLaunched=Sandbox.exe install
PostInstall=<None>
[SourceFiles]
SourceFiles0=$(Get-Location)\zig-out\bin\
[SourceFiles0]
%File0%=Sandbox.exe
%File1%=unicorn.dll
%File2%=wintun.dll
"@

$sedContent | Out-File -FilePath "setup.sed" -Encoding ascii

# Note: IExpress requires full paths in the [SourceFiles0] section mapping
# but I used a simplified version above. I'll fix it in the next step.
