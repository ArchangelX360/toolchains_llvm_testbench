load("@crates//:data.bzl", "DEP_DATA")
load("@crates//:defs.bzl", "all_crate_deps")
load("@rules_rs//rs:cargo_build_script.bzl", "cargo_build_script")
load("@rules_rs//rs:rust_binary.bzl", "rust_binary")
load("@rules_rs//rs:rust_library.bzl", "rust_library")
load("@rules_rs//rs:rust_proc_macro.bzl", "rust_proc_macro")
load("@rules_rs//rs:rust_shared_library.bzl", "rust_shared_library")
load("@rules_rs//rs:rust_test.bzl", "rust_test")

def _local_archive_impl(repository_ctx):
    repository_ctx.extract(repository_ctx.attr.src)
    repository_ctx.file("BUILD.bazel", repository_ctx.read(repository_ctx.attr.build_file))

local_archive = repository_rule(
    attrs = {
        "src": attr.label(mandatory = True, allow_single_file = True),
        "build_file": attr.label(mandatory = True, allow_single_file = True),
    },
    implementation = _local_archive_impl,
)

def _crossplatform_local_archive_impl(repository_ctx):
    repository_ctx.extract(repository_ctx.attr.src)

    # Detect OS and determine if transformations should be skipped
    os_name = repository_ctx.os.name.lower()
    skip_transformations = "windows" in os_name

    if skip_transformations and repository_ctx.attr.transformations:
        print("Skipping file transformations on Windows (case-insensitive filesystem)")
    elif repository_ctx.attr.transformations:
        bash = repository_ctx.which("bash")
        if not bash:
            fail("bash not found. Bash is required for file transformations.")

        helper = repository_ctx.path(repository_ctx.attr._helper)
        cmd = [bash, str(helper), str(repository_ctx.path("."))]
        for src, dst in repository_ctx.attr.transformations.items():
            cmd.extend(["--transform", "{}:{}".format(src, dst)])

        result = repository_ctx.execute(
            cmd,
            quiet = False,
        )

        if result.return_code != 0:
            fail("File transformation failed:\nstdout: {}\nstderr: {}".format(
                result.stdout,
                result.stderr,
            ))

    repository_ctx.file("BUILD.bazel", repository_ctx.read(repository_ctx.attr.build_file))

crossplatform_local_archive = repository_rule(
    implementation = _crossplatform_local_archive_impl,
    attrs = {
       "src": attr.label(mandatory = True, allow_single_file = True),
        "build_file": attr.label(
            doc = "Label of the BUILD file template to use",
        ),
        "transformations": attr.string_dict(
            default = {},
            doc = """Dictionary mapping source paths/patterns to destination paths/patterns.
            Supports both exact file paths and glob patterns for file transformations.
            Examples:
            - Exact: {"include/driverspecs.h": "include/DriverSpecs.h"}
            - Pattern: {"include/*.inl": "include/*.h"}
            - Lowercase: {"include/*.h": "lowercase"} - creates lowercase duplicate
            Files are copied/transformed after extraction.""",
        ),
        "_helper": attr.label(
            default = Label("@//build:transform_helper.sh"),
            allow_single_file = True,
            doc = "Hermetic bash script for file transformations",
        ),
    },
    doc = """
    Extracts a local archive, optionally transforming and duplicating files for cross-platform use-cases.

    This rule provides hermetic, cross-platform support for transforming and duplicating
    archive contents, resolving case-sensitivity issues when building on
    case-sensitive filesystems (Linux, macOS) for case-insensitive targets (Windows).

    Platform behavior:
    - Linux: Always runs transformations (case-sensitive filesystem)
    - macOS: Always runs transformations (handles both case-sensitive and case-insensitive APFS)
    - Windows: Skips transformations (always case-insensitive by design)

    Example:
        crossplatform_http_archive(
            name = "my_archive",
            src = "//sysroots:sysroot-windows_x86_64-MSVC_14.50.35717-SDK_10.0.22621.0-1BEC42C526532C8C40162A045074FCE4.tar.gz",
            build_file = "@//path:BUILD.template",
            transformations = {
                "include/driverspecs.h": "include/DriverSpecs.h",  # Exact file copy
                "include/*.inl": "include/*.h",                    # Pattern-based transform
                "include/*.h": "lowercase",                        # Lowercase duplicates
            },
        )
    """,
)

# Heavily inspired by https://github.com/openai/codex/blob/18206a9c1ea3f060e7fc581dd7c9639413e965c2/defs.bzl#L31
def rust_crate(
        name,
        crate_name,
        crate_features = None,
        crate_srcs = None,
        crate_edition = None,
        proc_macro = False,
        build_script_enabled = True,
        build_script_data = [],
        compile_data = [],
        lib_data_extra = [],
        rustc_flags_extra = [],
        rustc_env = {},
        deps_extra = [],
        integration_deps_extra = [],
        integration_compile_data_extra = [],
        test_data_extra = [],
        test_tags = [],
        extra_binaries = [],
        platforms = [],
        visibility = ["//visibility:public"]):
    """Defines a Rust crate with library, binaries, and tests wired for Bazel + Cargo parity.

    The macro mirrors Cargo conventions: it builds a library when `src/` exists,
    wires build scripts, exports `CARGO_BIN_EXE_*` for integration tests, and
    creates unit + integration test targets. Dependency buckets map to the
    Cargo.lock resolution in `@crates`.

    Args:
        name: Bazel target name for the library, should be the directory name.
            Example: `sparkle-fleet`.
        crate_name: Cargo crate name from Cargo.toml
            Example: `sparkle_fleet`.
        crate_features: Cargo features to enable for this crate.
            Crates are only compiled in a single configuration across the workspace, i.e.
            with all features in this list enabled. So use sparingly, and prefer to refactor
            optional functionality to a separate crate.
        crate_srcs: Optional explicit srcs; defaults to `src/**/*.rs`.
        crate_edition: Rust edition override, if not default.
            You probably don't want this, it's only here for a single caller.
        proc_macro: Whether this crate builds a proc-macro library.
        build_script_data: Data files exposed to the build script at runtime.
        compile_data: Non-Rust compile-time data for the library target.
        lib_data_extra: Extra runtime data for the library target.
        rustc_env: Extra rustc_env entries to merge with defaults.
        deps_extra: Extra normal deps beyond @frc resolution.
            Typically only needed when features add additional deps.
        integration_deps_extra: Extra deps for integration tests only.
        integration_compile_data_extra: Extra compile_data for integration tests.
        test_data_extra: Extra runtime data for tests.
        test_tags: Tags applied to unit + integration test targets.
            Typically used to disable the sandbox, but see https://bazel.build/reference/be/common-definitions#common.tags
        extra_binaries: Additional binary labels to surface as test data and
            `CARGO_BIN_EXE_*` environment variables. These are only needed for binaries from a different crate.
    """

    build_deps = all_crate_deps(build = True)
    deps = all_crate_deps(normal = True) + deps_extra
    dev_deps = all_crate_deps(normal_dev = True)

    rustc_env = {
        "BAZEL_PACKAGE": native.package_name(),
    } | rustc_env

    # TODO: maybe use crate_features_by_platform if relevant one day
    # crate_features = DEP_DATA.get(native.package_name())["crate_features"] if crate_features == None else crate_features

    rustc_flags_extra = rustc_flags_extra + select({
        "@rules_rs//rs/experimental/platforms/constraints:windows_msvc": ["-Ctarget-feature=+crt-static"],
        "//conditions:default": [],
    })

    binaries = DEP_DATA.get(native.package_name())["binaries"]
    shared_libraries = DEP_DATA.get(native.package_name())["shared_libraries"]

    lib_srcs = crate_srcs or native.glob(["src/**/*.rs"], exclude = binaries.values() + shared_libraries.values(), allow_empty = True)

    if build_script_enabled and native.glob(["build.rs"], allow_empty = True):
        cargo_build_script(
            name = name + "-build-script",
            srcs = ["build.rs"],
            deps = build_deps,
            data = build_script_data,
            # Some build script deps sniff version-related env vars...
            version = "0.0.0",
        )

        deps = deps + [name + "-build-script"]

    if lib_srcs and "src/lib.rs" in lib_srcs:
        lib_rule = rust_proc_macro if proc_macro else rust_library
        lib_rule(
            name = name,
            crate_name = crate_name,
            # crate_features = crate_features,
            deps = deps,
            compile_data = compile_data,
            data = lib_data_extra,
            srcs = lib_srcs,
            edition = crate_edition,
            rustc_flags = rustc_flags_extra,
            rustc_env = rustc_env,
            visibility = visibility,
        )

        rust_test(
            name = name + "-unit-tests",
            crate = name,
            env = {},
            deps = dev_deps,  # TODO: shouldn't it also take `deps`?
            rustc_flags = rustc_flags_extra,
            rustc_env = rustc_env,
            data = test_data_extra,
            tags = test_tags,
        )

        maybe_lib = [name]
    else:
        maybe_lib = []

    sanitized_binaries = []
    sanitized_shared_libraries = []
    cargo_env = {}
    for binary, main in binaries.items():
        for p in platforms:
            bin_target_name = "{}_{}".format(binary, Label(p).name)

            #binary = binary.replace("-", "_")
            sanitized_binaries.append(bin_target_name)
            cargo_env["CARGO_BIN_EXE_" + bin_target_name] = "$(rlocationpath :%s)" % bin_target_name

            rust_binary(
                name = bin_target_name,
                visibility = visibility,
                platform = p,
                crate_name = binary.replace("-", "_"),
                crate_root = main,
                deps = maybe_lib + deps,
                edition = crate_edition,
                rustc_flags = rustc_flags_extra,
                compile_data = compile_data,
                srcs = native.glob(["src/**/*.rs"]),
            )

    for shared_library, main in shared_libraries.items():
        for p in platforms:
            shared_library_target_name = "{}_{}".format(shared_library, Label(p).name)
            sanitized_shared_libraries.append(shared_library_target_name)

            rust_shared_library(
                name = shared_library_target_name,
                visibility = visibility,
                platform = p,
                crate_name = shared_library.replace("-", "_"),
                crate_root = main,
                deps = maybe_lib + deps,
                proc_macro_deps = maybe_lib + deps,
                edition = crate_edition,
                rustc_flags = rustc_flags_extra,
                compile_data = compile_data,
                srcs = native.glob(["src/**/*.rs"]),
            )

    for binary_label in extra_binaries:
        sanitized_binaries.append(binary_label)
        binary = Label(binary_label).name
        cargo_env["CARGO_BIN_EXE_" + binary] = "$(rlocationpath %s)" % binary_label

    for test in native.glob(["tests/*.rs"], allow_empty = True):
        test_file_stem = test.removeprefix("tests/").removesuffix(".rs")
        test_crate_name = test_file_stem.replace("-", "_")
        test_name = name + "-" + test_file_stem.replace("/", "-")
        if not test_name.endswith("-test"):
            test_name += "-test"

        rust_test(
            name = test_name,
            crate_name = test_crate_name,
            crate_root = test,
            srcs = [test],
            data = native.glob(["tests/**"], allow_empty = True) + sanitized_binaries + test_data_extra,
            compile_data = native.glob(["tests/**"], allow_empty = True) + integration_compile_data_extra,
            deps = maybe_lib + deps + dev_deps + integration_deps_extra,
            # Keep `file!()` paths Cargo-like (`core/tests/...`) instead of
            # Bazel workspace-prefixed (`codex-rs/core/tests/...`) for snapshot parity.
            rustc_flags = rustc_flags_extra,  # + ["--remap-path-prefix=codex-rs="],
            rustc_env = rustc_env,
            env = cargo_env,
            tags = test_tags,
        )
