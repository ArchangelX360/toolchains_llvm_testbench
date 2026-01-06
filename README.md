# toolchains_llvm_testbench
Project to try out `bazel-contrib/toolchains_llvm` changes on different OSes.

## Usage

A toolchain is considered working if all the following commands succeed, on every supported host (Windows, Linux, macOS, on x86_64 and aarch64 architectures):

```shell
bazel build //... --platforms=//native/platforms:linux-x86_64-glibc
bazel build //... --platforms=//native/platforms:linux-aarch64-glibc
bazel build //... --platforms=//native/platforms:macos-x86_64
bazel build //... --platforms=//native/platforms:macos-aarch64
bazel build //... --platforms=//native/platforms:windows-x86_64
bazel build //... --platforms=//native/platforms:windows-aarch64
```
