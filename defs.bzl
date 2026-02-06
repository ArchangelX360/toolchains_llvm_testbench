load("@rules_rust//rust:defs.bzl", "rust_binary")

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

def _rust_binary_for_platforms_impl(name, visibility, platforms, **kwargs):
    for p in platforms:
        rust_binary(
            name = "{}_{}".format(name, p.name),
            platform = p,
            visibility = visibility,
            **kwargs
        )

rust_binary_for_platforms = macro(
    inherit_attrs = rust_binary,
    attrs = {
        "platform": None, # do not inherit that attribute from `rust_binary`, as we set it via the macro
        # configurable = False because we cannot iterate of selectables https://github.com/bazelbuild/bazel/issues/8419
        "platforms": attr.label_list(mandatory = True, configurable = False, doc = "The platforms for which that `rust_binary` must be defined"),
    },
    implementation = _rust_binary_for_platforms_impl,
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
