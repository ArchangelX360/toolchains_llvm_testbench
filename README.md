# toolchains_llvm_testbench

Project to try out `bazel-contrib/toolchains_llvm` changes on different OSes.

## Usage

A toolchain is considered working the following script runs without errors on every supported host (Windows, Linux,
macOS, on
x86_64 and aarch64 architectures):

```shell
./build.cmd
```

## Cross-compilation specific patches

- on Windows, Developer Mode should be enabled, otherwise `windows.0.53.0.lib` is not found, because `"/LIBPATH:C:\\tmp\\testbench\\4gcvj3vr\\execroot\\_main\\bazel-out/arm64_windows-fastbuild-ST-532a4266b501/bin/external/rules_rust++crate+rust_crates__windows_aarch64_msvc-0.53.1/_bs.cargo_runfiles/rules_rust++crate+rust_crates__windows_aarch64_msvc-0.53.1/lib"` does not get a symlink to the lib
- `rules_rust` pwd patches `build/native/rules_rust-pwd.patch`
- Windows sysroots are wired using `crossplatform_local_archive` for Linux cross-compilation to work
- `cc-rs` crate is patched to force using `clang-cl`, and also includes also a few patches for `clang-cl` to work which
  we are trying to upstream
    - https://github.com/rust-lang/cc-rs/pull/1670
    - https://github.com/rust-lang/cc-rs/pull/1671

## Tested on

| rules         | host                        | target                      | outcome | additional information |
|---------------|-----------------------------|-----------------------------|---------|------------------------|
| `rules_cc`    | `aarch64-apple-darwin`      | `aarch64-apple-darwin`      | ✅       |                        |
| `rules_cc`    | `aarch64-apple-darwin`      | `x86_64-apple-darwin`       | ✅       |                        |
| `rules_cc`    | `aarch64-apple-darwin`      | `aarch64-unknown-linux-gnu` | ✅       |                        |
| `rules_cc`    | `aarch64-apple-darwin`      | `x86_64-unknown-linux-gnu`  | ✅       |                        |
| `rules_cc`    | `aarch64-apple-darwin`      | `aarch64-pc-windows-msvc`   | ✅       |                        |
| `rules_cc`    | `aarch64-apple-darwin`      | `x86_64-pc-windows-msvc`    | 🔴      | [1]                    |
| `rules_rust`* | `aarch64-apple-darwin`      | `aarch64-apple-darwin`      | ✅       |                        |
| `rules_rust`* | `aarch64-apple-darwin`      | `x86_64-apple-darwin`       | ✅       |                        |
| `rules_rust`* | `aarch64-apple-darwin`      | `aarch64-unknown-linux-gnu` | ✅       |                        |
| `rules_rust`* | `aarch64-apple-darwin`      | `x86_64-unknown-linux-gnu`  | ✅       |                        |
| `rules_rust`* | `aarch64-apple-darwin`      | `aarch64-pc-windows-msvc`   | ✅       |                        |
| `rules_rust`* | `aarch64-apple-darwin`      | `x86_64-pc-windows-msvc`    | ✅       |                        |
| `rules_cc`    | `aarch64-unknown-linux-gnu` | `aarch64-apple-darwin`      | ✅       |                        |
| `rules_cc`    | `aarch64-unknown-linux-gnu` | `x86_64-apple-darwin`       | ✅       |                        |
| `rules_cc`    | `aarch64-unknown-linux-gnu` | `aarch64-unknown-linux-gnu` | ✅       |                        |
| `rules_cc`    | `aarch64-unknown-linux-gnu` | `x86_64-unknown-linux-gnu`  | ✅       |                        |
| `rules_cc`    | `aarch64-unknown-linux-gnu` | `aarch64-pc-windows-msvc`   | ✅       |                        |
| `rules_cc`    | `aarch64-unknown-linux-gnu` | `x86_64-pc-windows-msvc`    | 🔴      | [1]                    |
| `rules_rust`* | `aarch64-unknown-linux-gnu` | `aarch64-apple-darwin`      | ✅       |                        |
| `rules_rust`* | `aarch64-unknown-linux-gnu` | `x86_64-apple-darwin`       | ✅       |                        |
| `rules_rust`* | `aarch64-unknown-linux-gnu` | `aarch64-unknown-linux-gnu` | ✅       |                        |
| `rules_rust`* | `aarch64-unknown-linux-gnu` | `x86_64-unknown-linux-gnu`  | ✅       |                        |
| `rules_rust`* | `aarch64-unknown-linux-gnu` | `aarch64-pc-windows-msvc`   | ✅       |                        |
| `rules_rust`* | `aarch64-unknown-linux-gnu` | `x86_64-pc-windows-msvc`    | ✅       |                        |
| `rules_cc`    | `aarch64-pc-windows-msvc`   | `aarch64-apple-darwin`      | ✅       |                        |
| `rules_cc`    | `aarch64-pc-windows-msvc`   | `x86_64-apple-darwin`       | ✅       |                        |
| `rules_cc`    | `aarch64-pc-windows-msvc`   | `aarch64-unknown-linux-gnu` | 🔴      | [2]                    |
| `rules_cc`    | `aarch64-pc-windows-msvc`   | `x86_64-unknown-linux-gnu`  | ✅       |                        |
| `rules_cc`    | `aarch64-pc-windows-msvc`   | `aarch64-pc-windows-msvc`   | ✅       |                        |
| `rules_cc`    | `aarch64-pc-windows-msvc`   | `x86_64-pc-windows-msvc`    | 🔴      | [1]                    |
| `rules_rust`* | `aarch64-pc-windows-msvc`   | `aarch64-apple-darwin`      | ✅       |                        |
| `rules_rust`* | `aarch64-pc-windows-msvc`   | `x86_64-apple-darwin`       | ✅       |                        |
| `rules_rust`* | `aarch64-pc-windows-msvc`   | `aarch64-unknown-linux-gnu` | 🔴      | [2]                    |
| `rules_rust`* | `aarch64-pc-windows-msvc`   | `x86_64-unknown-linux-gnu`  | 🔴      | [2]                    |
| `rules_rust`* | `aarch64-pc-windows-msvc`   | `aarch64-pc-windows-msvc`   | ✅       |                        |
| `rules_rust`* | `aarch64-pc-windows-msvc`   | `x86_64-pc-windows-msvc`    | ✅       |                        |

*: simple program with a dependency on `zstd-sys` crate which has a `cc` crate call in its `build.rs` (c++ compilation),
`rules_rust` is patched on `INCLUDE` env var setting

[1]:
`lld-link: error: bazel-out/darwin_arm64-fastbuild/bin/cc/clang-rt/_objs/example/main.obj: machine type arm64 conflicts with x64`

[2]: Permission denied failures

```
ERROR: C:/users/titouan.bion/developer_windows/toolchains_llvm_testbench/rust/with-cc-build/BUILD.bazel:6:12: Compiling
Rust bin example (1 file) failed: (Exit 1): process_wrapper.exe failed: error executing Rustc command (from target
//rust/with-cc-build:example)
bazel-out\arm64_windows-opt-exec-ST-d57f47055a04\bin\external\rules_rust+\util\process_wrapper\process_wrapper.exe
--arg-file ... (remaining 39 arguments skipped)
error: linking with
`C:/users/titouan.bion/_bazel_titouan.bion/7zqqiyu3/external/toolchains_llvm++llvm+llvm_toolchain_llvm/bin/clang.exe`
failed: exit code: 1
|
= note: "C:/users/titouan.bion/_
bazel_titouan.bion/7zqqiyu3/external/toolchains_llvm++llvm+llvm_toolchain_llvm/bin/clang.exe" "C:\\Users\\TITOUA~
1.BIO\\AppData\\Local\\Temp\\rustcqcEMtQ\\symbols.o" "<2 object files omitted>" "-Wl,--as-needed" "
-Wl,-Bstatic" "<sysroot>\\lib\\rustlib\\aarch64-unknown-linux-gnu\\lib/{libstd-*,libpanic_unwind-*,libobject-
*,libmemchr-*,libaddr2line-*,libgimli-*,librustc_demangle-*,libstd_detect-*,libhashbrown-
*,librustc_std_workspace_alloc-*,libminiz_oxide-*,libadler2-*,libunwind-*,libcfg_if-*,liblibc-
*,librustc_std_workspace_core-*,liballoc-*,libcore-*,libcompiler_builtins-*}.rlib" "-Wl,-Bdynamic" "-lgcc_s" "-lutil" "
-lrt" "-lpthread" "-lm" "-ldl" "-lc" "-L" "C:\\Users\\TITOUA~1.BIO\\AppData\\Local\\Temp\\rustcqcEMtQ\\raw-dylibs" "
-Wl,--eh-frame-hdr" "-Wl,-z,noexecstack" "-L" "<sysroot>/lib/rustlib/aarch64-unknown-linux-gnu/lib" "-L" "C:
\\users\\titouan.bion\\_bazel_titouan.bion\\7zqqiyu3\\execroot\\_
main\\bazel-out/arm64_windows-fastbuild/bin/external/rules_rust++crate+rust_crates__zstd-sys-2.0.16-zstd.1.5.7/_
bs.out_dir" "-L" "<sysroot>\\lib\\rustlib\\aarch64-unknown-linux-gnu\\lib" "-o" "
bazel-out/arm64_windows-fastbuild/bin/rust/with-cc-build/example" "-Wl,--gc-sections" "-pie" "-Wl,-z,relro,-z,now" "
-nodefaultlibs" "--target=aarch64-unknown-linux-gnu" "-no-canonical-prefixes" "-fuse-ld=lld" "-lm" "
-Wl,--build-id=md5" "-Wl,--hash-style=gnu" "-Wl,-z,relro,-z,now" "-l:libstdc++.a" "
--sysroot=external/+local_archive_ext+sysroot-linux-aarch64/"
= note: some arguments are omitted. use `--verbose` to show all linker arguments
= note: ld.lld: error: cannot open external/+local_archive_ext+sysroot-linux-aarch64/usr/lib\libutil.so: permission
denied␍
ld.lld: error: cannot open external/+local_archive_ext+sysroot-linux-aarch64/usr/lib\librt.so: permission denied␍
ld.lld: error: cannot open external/+local_archive_ext+sysroot-linux-aarch64/usr/lib\libdl.so: permission denied␍
clang: error: linker command failed with exit code 1 (use -v to see invocation)␍
```
OR
```
ERROR: C:/users/titouan.bion/developer/toolchains_llvm_testbench/cc/clang-rt/BUILD.bazel:3:10: Linking cc/clang-rt/example failed: (Exit 1): clang.exe failed: error executing CppLink command (from target //cc/clang-rt:example) C:\tmp\testbench\4gcvj3vr\external\toolchains_llvm++llvm+llvm_toolchain_llvm\bin\clang.exe @bazel-out/arm64_windows-fastbuild/bin/cc/clang-rt/example-0.params
ld.lld: error: cannot open external/+_repo_rules2+sysroot-linux-aarch64/usr/lib\libm.so: permission denied
clang: error: linker command failed with exit code 1 (use -v to see invocation)
Target //cc/clang-rt:example failed to build
Use --verbose_failures to see the command lines of failed build steps.
```