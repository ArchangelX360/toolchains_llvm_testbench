#!/usr/bin/env pwsh

param(
  [string]$OutputDirectory = $PSScriptRoot
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$buildToolMajorVersion = "18"
$buildToolVersion = "$buildToolMajorVersion.1.0"
$msvcMajorVersion = "14.50"
$msvcVersion = "$msvcMajorVersion.35717"
$sdkMajorVersion = "10"
$sdkMinorVersion = "22621"
$sdkVersion = "$sdkMajorVersion.0.$sdkMinorVersion.0"

Write-Host "Downloading Visual Studio Build Tools installer..."
# URL gotten from: https://github.com/microsoft/winget-pkgs/blob/master/manifests/m/Microsoft/VisualStudio/BuildTools/18.1.0/Microsoft.VisualStudio.BuildTools.installer.yaml
$installerUrl = "https://download.visualstudio.microsoft.com/download/pr/451b234a-4e25-491d-a007-bf3e55b2562f/442956195fde7b7a0be755d2dc1bc405c05b80115f26bac3b569cb0c358b303f/vs_BuildTools.exe"
$installerExe = Join-Path $OutputDirectory "vs_BuildTools.exe"
if (Test-Path $installerExe) { Remove-Item $installerExe -Force }
Invoke-WebRequest $installerUrl -OutFile $installerExe

Write-Host "Installing Visual Studio Build Tools with the following components..."
# See IDs here: https://learn.microsoft.com/en-us/visualstudio/install/workload-component-id-vs-build-tools?view=visualstudio
$components =`
  "Microsoft.VisualStudio.Component.VC.$msvcMajorVersion.$buildToolMajorVersion.0.ARM64",`
  "Microsoft.VisualStudio.Component.VC.$msvcMajorVersion.$buildToolMajorVersion.0.x86.x64",`
  "Microsoft.VisualStudio.Component.Windows11SDK.$sdkMinorVersion"
foreach ($p in $components) { Write-Host "  - $p" }
$msvcInstallationPath = Join-Path $OutputDirectory "BuildTools"
if (Test-Path $msvcInstallationPath) { Remove-Item $msvcInstallationPath -Recurse -Force }
# See CLI options here: https://learn.microsoft.com/en-us/visualstudio/install/use-command-line-parameters-to-install-visual-studio?view=visualstudio
$stdoutLogPath = Join-Path $OutputDirectory "install_stdout.log"
$stderrLogPath = Join-Path $OutputDirectory "install_stderr.log"
$installerDefaultArguments = "--quiet", "--wait", "--norestart", "--installPath", $msvcInstallationPath, "--force"
Start-Process -FilePath $installerExe -Wait -RedirectStandardOutput $stdoutLogPath -RedirectStandardError $stderrLogPath -ArgumentList ($installerDefaultArguments + ($components | ForEach-Object { "--add", $_ }))
echo "##teamcity[publishArtifacts '$stdoutLogPath']"
echo "##teamcity[publishArtifacts '$stderrLogPath']"

$msvcToolsPath = Join-Path $msvcInstallationPath "VC\Tools\MSVC\$msvcVersion"
$sdkPath = "C:\Program Files (x86)\Windows Kits\$sdkMajorVersion"
$includesPaths = (Join-Path $msvcToolsPath "include\*"),`
                 (Join-Path $sdkPath -ChildPath "Include" | Join-Path -ChildPath $sdkVersion | Join-Path -ChildPath "ucrt\*"),`
                 (Join-Path $sdkPath -ChildPath "Include" | Join-Path -ChildPath $sdkVersion | Join-Path -ChildPath "um\*"),`
                 (Join-Path $sdkPath -ChildPath "Include" | Join-Path -ChildPath $sdkVersion | Join-Path -ChildPath "shared\*")
$libPaths_arm64 = (Join-Path $msvcToolsPath -ChildPath "lib\arm64\*"),`
                  (Join-Path $sdkPath -ChildPath "Lib" | Join-Path -ChildPath $sdkVersion | Join-Path -ChildPath "ucrt\arm64\*"),`
                  (Join-Path $sdkPath -ChildPath "Lib" | Join-Path -ChildPath $sdkVersion | Join-Path -ChildPath "um\arm64\*")
$libPaths_x64 = (Join-Path $msvcToolsPath -ChildPath "lib\x64\*"),`
                (Join-Path $sdkPath -ChildPath "Lib" | Join-Path -ChildPath $sdkVersion | Join-Path -ChildPath "ucrt\x64\*"),`
                (Join-Path $sdkPath -ChildPath "Lib" | Join-Path -ChildPath $sdkVersion | Join-Path -ChildPath "um\x64\*")

# Copying instead of archiving directly to be able to have the following directory structure inside the zip which is used the Bazel's toolchain code:
# .
# ├── Lib
# └── Include
#
Write-Host "Preparing archive directory, copying headers and libraries..."
$SYSROOT_ARM64 = Join-Path $OutputDirectory "sysroot-windows_aarch64"
$SYSROOT_X64 = Join-Path $OutputDirectory "sysroot-windows_x86_64"
if (Test-Path $SYSROOT_ARM64) { Remove-Item $SYSROOT_ARM64 -Recurse -Force }
if (Test-Path $SYSROOT_X64) { Remove-Item $SYSROOT_X64 -Recurse -Force }
$includeFolder = "Include"
$arm64Include = Join-Path $SYSROOT_ARM64 $includeFolder
$x64Include = Join-Path $SYSROOT_X64 $includeFolder
$libFolder = "Lib"
$arm64Lib = Join-Path $SYSROOT_ARM64 $libFolder
$x64Lib = Join-Path $SYSROOT_X64 $libFolder
New-Item -ItemType Directory -Path $arm64Include -Force | Out-Null
New-Item -ItemType Directory -Path $x64Include -Force | Out-Null
New-Item -ItemType Directory -Path $arm64Lib -Force | Out-Null
New-Item -ItemType Directory -Path $x64Lib -Force | Out-Null
Copy-Item -Path $includesPaths -Destination $arm64Include -Recurse -Force
Copy-Item -Path $includesPaths -Destination $x64Include -Recurse -Force
Copy-Item -Path $libPaths_arm64 -Destination $arm64Lib -Recurse -Force
Copy-Item -Path $libPaths_x64 -Destination $x64Lib -Recurse -Force

Write-Host "Packing one zip per supported architecture..."
$scriptVersion = (Get-FileHash -Path $PSCommandPath -Algorithm MD5).Hash # If the script changed, the archives may be built differently, we want to record that as a different sysroot despite it having the same libraries/frameworks
$arm64ArchivePath = Join-Path $OutputDirectory "sysroot-windows_aarch64-MSVC_$msvcVersion-SDK_$sdkVersion-$scriptVersion.tar.gz"
$x64ArchivePath = Join-Path $OutputDirectory "sysroot-windows_x86_64-MSVC_$msvcVersion-SDK_$sdkVersion-$scriptVersion.tar.gz"
if (Test-Path $arm64ArchivePath) { Remove-Item $arm64ArchivePath -Force }
if (Test-Path $x64ArchivePath) { Remove-Item $x64ArchivePath -Force }

Start-Process -FilePath "tar" -Wait -ArgumentList @("-czf", $arm64ArchivePath, "-C", $SYSROOT_ARM64, ".")
Start-Process -FilePath "tar" -Wait -ArgumentList @("-czf", $x64ArchivePath, "-C", $SYSROOT_X64, ".")

Write-Host "Sysroot archives successfully created:"
Write-Host "  - $arm64ArchivePath"
Write-Host "  - $x64ArchivePath"

Write-Host "Cleaning up..."
Write-Host "  Deleting sysroot temporary folders..."
if (Test-Path $SYSROOT_ARM64) { Remove-Item $SYSROOT_ARM64 -Recurse -Force }
if (Test-Path $SYSROOT_X64) { Remove-Item $SYSROOT_X64 -Recurse -Force }
Write-Host "  Uninstalling Visual Studio Build Tools and components..."
Start-Process -FilePath $installerExe -Wait -ArgumentList (@("uninstall") + $installerDefaultArguments)
Write-Host "  Deleting Visual Studio Build Tools installer..."
if (Test-Path $installerExe) { Remove-Item $installerExe -Force }
