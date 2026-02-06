load("@rules_rust//rust:defs.bzl", "rust_binary")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "get_auth")

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

# Module extension for Bzlmod

def _local_archive_extension_impl(module_ctx):
    for mod in module_ctx.modules:
        for archive in mod.tags.archive:
            local_archive(
                name = archive.name,
                src = archive.src,
                build_file = archive.build_file,
            )

_archive_tag = tag_class(
    attrs = {
        "name": attr.string(mandatory = True),
        "src": attr.label(mandatory = True, allow_single_file = True),
        "build_file": attr.label(mandatory = True, allow_single_file = True),
    },
)

local_archive_ext = module_extension(
    implementation = _local_archive_extension_impl,
    tag_classes = {
        "archive": _archive_tag,
    },
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

def _crossplatform_http_archive_impl(repository_ctx):
    repository_ctx.download_and_extract(
        url = repository_ctx.attr.url,
        sha256 = repository_ctx.attr.sha256,
        stripPrefix = repository_ctx.attr.strip_prefix,
        auth = get_auth(repository_ctx, [repository_ctx.attr.url]),
    )

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

    if repository_ctx.attr.build_file:
        repository_ctx.file(
            "BUILD.bazel",
            repository_ctx.read(repository_ctx.attr.build_file),
        )
    elif repository_ctx.attr.build_file_content:
        repository_ctx.file("BUILD.bazel", repository_ctx.attr.build_file_content)
    else:
        fail("Either build_file or build_file_content must be provided")

crossplatform_http_archive = repository_rule(
    implementation = _crossplatform_http_archive_impl,
    attrs = {
        "url": attr.string(
            mandatory = True,
            doc = "URL of the archive to download",
        ),
        "sha256": attr.string(
            mandatory = True,
            doc = "Expected SHA256 hash of the archive",
        ),
        "strip_prefix": attr.string(
            default = "",
            doc = "Directory prefix to strip from extracted files",
        ),
        "build_file": attr.label(
            doc = "Label of the BUILD file template to use",
        ),
        "build_file_content": attr.string(
            doc = "Content of the BUILD file (alternative to build_file)",
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
    Downloads and extracts an archive, optionally transforming and duplicating files for cross-platform use-cases.

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
            url = "https://example.com/archive.zip",
            sha256 = "abc123...",
            strip_prefix = "archive-1.0/",
            build_file = "@//path:BUILD.template",
            transformations = {
                "include/driverspecs.h": "include/DriverSpecs.h",  # Exact file copy
                "include/*.inl": "include/*.h",                    # Pattern-based transform
                "include/*.h": "lowercase",                        # Lowercase duplicates
            },
        )
    """,
)
