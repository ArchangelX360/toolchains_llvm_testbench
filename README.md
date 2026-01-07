# toolchains_llvm_testbench
Project to try out `bazel-contrib/toolchains_llvm` changes on different OSes.

## Usage

A toolchain is considered working if the following command succeeds on every supported host (Windows, Linux, macOS, on x86_64 and aarch64 architectures):

```shell
./build.cmd
```
