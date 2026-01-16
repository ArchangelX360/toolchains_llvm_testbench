# toolchains_llvm_testbench

Project to try out `bazel-contrib/toolchains_llvm` changes on different OSes.

## Usage

A toolchain is considered working the following script runs without errors on every supported host (Windows, Linux,
macOS, on
x86_64 and aarch64 architectures):

```shell
./build.cmd
```

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
| `rules_cc`    | `aarch64-pc-windows-msvc`   | `aarch64-apple-darwin`      | 🔴      | [2]                    |
| `rules_cc`    | `aarch64-pc-windows-msvc`   | `x86_64-apple-darwin`       | 🔴      | [2]                    |
| `rules_cc`    | `aarch64-pc-windows-msvc`   | `aarch64-unknown-linux-gnu` | ✅       |                        |
| `rules_cc`    | `aarch64-pc-windows-msvc`   | `x86_64-unknown-linux-gnu`  | ✅       |                        |
| `rules_cc`    | `aarch64-pc-windows-msvc`   | `aarch64-pc-windows-msvc`   | ✅       |                        |
| `rules_cc`    | `aarch64-pc-windows-msvc`   | `x86_64-pc-windows-msvc`    | 🔴      | [1]                    |
| `rules_rust`* | `aarch64-pc-windows-msvc`   | `aarch64-apple-darwin`      | 🔴      | [2]                    |
| `rules_rust`* | `aarch64-pc-windows-msvc`   | `x86_64-apple-darwin`       | 🔴      | [2]                    |
| `rules_rust`* | `aarch64-pc-windows-msvc`   | `aarch64-unknown-linux-gnu` | 🔴      | [4]                    |
| `rules_rust`* | `aarch64-pc-windows-msvc`   | `x86_64-unknown-linux-gnu`  | 🔴      | [4]                    |
| `rules_rust`* | `aarch64-pc-windows-msvc`   | `aarch64-pc-windows-msvc`   | ✅       |                        |
| `rules_rust`* | `aarch64-pc-windows-msvc`   | `x86_64-pc-windows-msvc`    | ✅       |                        |

*: simple program with a dependency on `zstd-sys` crate which has a `cc` crate call in its `build.rs` (c++ compilation),
`rules_rust` is patched on `INCLUDE` env var setting

[1]:
`lld-link: error: bazel-out/darwin_arm64-fastbuild/bin/cc/clang-rt/_objs/example/main.obj: machine type arm64 conflicts with x64`

[2]:

```
ld64.lld: error: unknown argument '--build-id=md5'
ld64.lld: error: unknown argument '--hash-style=gnu'
ld64.lld: error: unknown argument '-z'
ld64.lld: error: unknown argument '-z'
```

[3]: `lld-link: error: could not open 'kernel32.lib': No such file or directory`, potential lead sysroot path seems
incorrect `/LIBPATH:external/+local_archive_ext+sysroot-windows_aarch64//Lib
`

[4]: Permission denied failures

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