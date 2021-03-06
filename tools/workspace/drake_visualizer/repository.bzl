# -*- mode: python -*-
# vi: set ft=python :

"""
Downloads and unpacks a precompiled version of drake-visualizer (a subset of
Director, https://git.io/vNKjq) and makes it available to be used as a
dependency of shell scripts.

Archive naming convention:
    dv-<version>-g<commit>-python-<python version>-qt-<qt version>
        -vtk-<vtk version>-<platform>-<arch>[-<rebuild>]

Build configuration:
    BUILD_SHARED_LIBS=OFF
    CMAKE_BUILD_TYPE=Release
    DD_QT_VERSION=5
    USE_EXTERNAL_INSTALL=ON
    USE_LCM=ON
    USE_LCMGL=ON
    USE_SYSTEM_EIGEN=ON
    USE_SYSTEM_LCM=ON
    USE_SYSTEM_LIBBOT=ON
    USE_SYSTEM_VTK=ON

Example:
    WORKSPACE:
        load(
            "@drake//tools/workspace/drake_visualizer:repository.bzl",
            "drake_visualizer_repository",
        )
        drake_visualizer_repository(name = "foo")

    BUILD:
        sh_binary(
            name = "foobar",
            srcs = ["bar.sh"],
            data = ["@foo//:drake_visualizer"],
        )

Argument:
    name: A unique name for this rule.
"""

load("@drake//tools/workspace:os.bzl", "determine_os")

# TODO(jamiesnape): Publish scripts used to create binaries. There will be a CI
# job for developers to build new binaries on demand.
def _impl(repository_ctx):
    os_result = determine_os(repository_ctx)
    if os_result.error != None:
        fail(os_result.error)

    if os_result.is_macos:
        archive = "dv-0.1.0-318-gd10dfa9-python-2.7.15-qt-5.12.0-vtk-8.1.1-mac-x86_64.tar.gz"  # noqa
        sha256 = "74a3532512829b7ca5accad7fb27a366131d5363cbda6c6794cac7599150a548"  # noqa
    elif os_result.ubuntu_release == "16.04":
        archive = "dv-0.1.0-318-gd10dfa9-python-2.7.12-qt-5.5.1-vtk-8.1.1-xenial-x86_64.tar.gz"  # noqa
        sha256 = "818f049ce43f1fcbb0552cfe152a43aae4f990179092689e6215176ca216b00a"  # noqa
    elif os_result.ubuntu_release == "18.04":
        archive = "dv-0.1.0-318-gd10dfa9-python-2.7.15-qt-5.9.5-vtk-8.1.1-bionic-x86_64.tar.gz"  # noqa
        sha256 = "fb1a36196eefea1879b5cd9c75338add1baef880727475f44f0453887ccc1b2f"  # noqa
    else:
        fail("Operating system is NOT supported", attr = os_result)

    urls = [
        x.format(archive = archive)
        for x in repository_ctx.attr.mirrors.get("director")
    ]
    root_path = repository_ctx.path("")

    repository_ctx.download_and_extract(urls, root_path, sha256 = sha256)

    file_content = """# -*- python -*-

# DO NOT EDIT: generated by drake_visualizer_repository()

licenses([
    "notice",  # Apache-2.0 AND BSD-3-Clause AND Python-2.0
    "reciprocal",  # MPL-2.0
    "restricted",  # LGPL-2.1-only AND LGPL-2.1-or-later AND LGPL-3.0-or-later
    "unencumbered",  # Public-Domain
])

# drake-visualizer has the following non-system dependencies in addition to
# those declared in deps:
#   bot2-lcmgl: LGPL-3.0-or-later
#   ctkPythonConsole: Apache-2.0
#   Eigen: BSD-3-Clause AND MPL-2.0 AND Public-Domain
#   LCM: BSD-3-Clause AND LGPL-2.1-only AND LGPL-2.1-or-later
#   Python: Python-2.0
#   PythonQt: LGPL-2.1-only
#   QtPropertyBrowser: LGPL-2.1-only
# TODO(jamiesnape): Enumerate system dependencies.

py_library(
    name = "drake_visualizer_python_deps",
    deps = [
        "@lcmtypes_bot2_core//:lcmtypes_bot2_core_py",
        # TODO(eric.cousineau): Expose VTK Python libraries here for Linux.
        "@lcmtypes_robotlocomotion//:lcmtypes_robotlocomotion_py",
    ],
    visibility = ["//visibility:public"],
)

# TODO(jamiesnape): Install this when Drake supports Python 3 only.
filegroup(
    name = "lcm_python",
    srcs = [
        "lib/python2.7/site-packages/lcm/__init__.py",
        "lib/python2.7/site-packages/lcm/_lcm.so",
    ],
    visibility = ["//visibility:public"],
)

# TODO(eric.cousineau): Ensure that Drake Visualizer works even when Bazel
# uses a separate version of Python.
filegroup(
    name = "drake_visualizer",
    srcs = glob([
        "lib/libPythonQt.*",
        "lib/libddApp.*",
        "lib/python2.7/site-packages/bot_lcmgl/**/*.py",
        "lib/python2.7/site-packages/director/**/*.py",
        "lib/python2.7/site-packages/director/**/*.so",
        "lib/python2.7/site-packages/urdf_parser_py/**/*.py",
    ]) + [
        "bin/drake-visualizer",
        "share/doc/director/LICENSE.txt",
    ],
    data = [
        ":drake_visualizer_python_deps",
        "@lcm//:libdrake_lcm.so",
        "@vtk",
    ],
    visibility = ["//visibility:public"],
)

load("@drake//tools/install:install.bzl", "install_files")
install_files(
    name = "install",
    dest = ".",
    files = [":drake_visualizer"],
    visibility = ["//visibility:public"],
)
"""

    repository_ctx.file(
        "BUILD.bazel",
        content = file_content,
        executable = False,
    )

drake_visualizer_repository = repository_rule(
    attrs = {
        "mirrors": attr.string_list_dict(),
    },
    implementation = _impl,
)
