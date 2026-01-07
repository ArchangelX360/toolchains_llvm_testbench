:<<"::CMDLITERAL"
@ECHO OFF
GOTO :CMDSCRIPT
::CMDLITERAL

set -eux

bazel build //... --platforms=//native/platforms:linux-x86_64-glibc
bazel build //... --platforms=//native/platforms:linux-aarch64-glibc
bazel build //... --platforms=//native/platforms:macos-x86_64
bazel build //... --platforms=//native/platforms:macos-aarch64
bazel build //... --platforms=//native/platforms:windows-x86_64
bazel build //... --platforms=//native/platforms:windows-aarch64
:CMDSCRIPT

call bazel build //... --platforms=//native/platforms:linux-x86_64-glibc
call bazel build //... --platforms=//native/platforms:linux-aarch64-glibc
call bazel build //... --platforms=//native/platforms:macos-x86_64
call bazel build //... --platforms=//native/platforms:macos-aarch64
call bazel build //... --platforms=//native/platforms:windows-x86_64
call bazel build //... --platforms=//native/platforms:windows-aarch64
set _exit_code=%ERRORLEVEL%
popd
EXIT /B %_exit_code%
