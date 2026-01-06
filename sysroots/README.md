# Sysroots

List of sysroots we use (or will use) in our Bazel monorepo for our [LLVM toolchains][llvm-toolchain].

| OS      | Arch    | libc  | Content                                  | Using                                            |
|---------|---------|-------|------------------------------------------|--------------------------------------------------|
| Windows | ARM64   |       | MSVC + Windows SDK headers and libraries | `sysroots/build_sysroot_windows.ps1`             |
| Windows | x86_64  |       | MSVC + Windows SDK headers and libraries | `sysroots/build_sysroot_windows.ps1`             |
| macOS   | aarch64 |       | macOS SDK 15.2                           | `sysroots/build_sysroot_macos.ps1`               |
| macOS   | x86_64  |       | macOS SDK 15.2                           | `sysroots/build_sysroot_macos.ps1`               |

[llvm-toolchain]: https://github.com/bazel-contrib/toolchains_llvm
