:<<"::CMDLITERAL"
@ECHO OFF
GOTO :CMDSCRIPT
::CMDLITERAL

set -eux

bazel build //cc/... --platforms=//native/platforms:linux-x86_64-glibc || echo "failed on linux-x86_64 (cc)"
bazel build //cc/... --platforms=//native/platforms:linux-aarch64-glibc || echo "failed on linux-aarch64 (cc)"
bazel build //cc/... --platforms=//native/platforms:macos-x86_64 || echo "failed on macos-x86_64 (cc)"
bazel build //cc/... --platforms=//native/platforms:macos-aarch64 || echo "failed on macos-aarch64 (cc)"
bazel build //cc/... --platforms=//native/platforms:windows-x86_64 || echo "failed on windows-x86_64 (cc)"
bazel build //cc/... --platforms=//native/platforms:windows-aarch64 || echo "failed on windows-aarch64 (cc)"
bazel build //rust/... --platforms=//native/platforms:linux-x86_64-glibc || echo "failed on linux-x86_64 (rust)"
bazel build //rust/... --platforms=//native/platforms:linux-aarch64-glibc || echo "failed on linux-aarch64 (rust)"
bazel build //rust/... --platforms=//native/platforms:macos-x86_64 || echo "failed on macos-x86_64 (rust)"
bazel build //rust/... --platforms=//native/platforms:macos-aarch64 || echo "failed on macos-aarch64 (rust)"
bazel build //rust/... --platforms=//native/platforms:windows-x86_64 || echo "failed on windows-x86_64 (rust)"
bazel build //rust/... --platforms=//native/platforms:windows-aarch64 || echo "failed on windows-aarch64 (rust)"
exit 0
:CMDSCRIPT

echo "linux-x86_64-glibc (rust)" && call bazelisk.exe build //rust/... --platforms=//native/platforms:linux-x86_64-glibc
echo "linux-aarch64-glibc (rust)" && call bazelisk.exe build //rust/... --platforms=//native/platforms:linux-aarch64-glibc
echo "macos-x86_64 (rust)" && call bazelisk.exe build //rust/... --platforms=//native/platforms:macos-x86_64
echo "macos-aarch64 (rust)" && call bazelisk.exe build //rust/... --platforms=//native/platforms:macos-aarch64
echo "windows-x86_64 (rust)" && call bazelisk.exe build //rust/... --platforms=//native/platforms:windows-x86_64
echo "windows-aarch64 (rust)" && call bazelisk.exe build //rust/... --platforms=//native/platforms:windows-aarch64
echo "linux-x86_64-glibc (cc)" && call bazelisk.exe build //cc/... --platforms=//native/platforms:linux-x86_64-glibc
echo "linux-aarch64-glibc (cc)" && call bazelisk.exe build //cc/... --platforms=//native/platforms:linux-aarch64-glibc
echo "macos-x86_64 (cc)" && call bazelisk.exe build //cc/... --platforms=//native/platforms:macos-x86_64
echo "macos-aarch64 (cc)" && call bazelisk.exe build //cc/... --platforms=//native/platforms:macos-aarch64
echo "windows-x86_64 (cc)" && call bazelisk.exe build //cc/... --platforms=//native/platforms:windows-x86_64
echo "windows-aarch64 (cc)" && call bazelisk.exe build //cc/... --platforms=//native/platforms:windows-aarch64

set _exit_code=%ERRORLEVEL%
popd
EXIT /B %_exit_code%
