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
