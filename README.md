<div align="center">
  <a href="https://xmake.io">
    <img width="160" height="160" src="https://xmake.io/assets/img/logo.png">
  </a>

  <h1>xmake-repo</h1>

  <p>Personal xmake package repository</p>
</div>

This is a personal xmake package repository, which is used to store the xmake packages I created and maintained. The repository is based on the official xmake-repo.

## Use packages from Pixi

Projects can consume Conda packages from a Pixi workspace through the dedicated `pixi::` namespace. Register the project-provided manager during Xmake's option-check phase:

```lua
add_moduledirs("xmake/modules")
option("__pixi_package_manager")
    set_showmenu(false)
    on_check(function (option)
        import("package.manager.pixi.register")()
        option:enable(true)
    end)
option_end()

add_requires("pixi::fmt 12.2.0", {alias = "fmt"})
add_requires("pixi::libuv", {alias = "libuv"})

target("example")
    add_packages("fmt", "libuv")
```

The `pixi::` adapter is independent of Xmake's native `conda::` package manager. The default Pixi environment is used unless `configs.environment` or `PIXI_ENVIRONMENT_NAME` selects another one. `configs.manifest` can point at a different `pixi.toml`, `pyproject.toml`, or workspace directory. If a package is missing, Xmake invokes `pixi add`; use `configs.feature` to choose which Pixi feature is updated.

If you want to know more, please refer to the xmake documentation:

* [Documents](https://xmake.io/guide/project-configuration/add-packages.html)
* [Github](https://github.com/xmake-io/xmake)
* [HomePage](https://xmake.io)

## Submit package to repository

Write a xmake.lua of new package in `packages/x/xxx/xmake.lua` and push a pull-request to the dev branch.

For example, [packages/z/zlib/xmake.lua](https://github.com/xmake-io/xmake-repo/blob/dev/packages/z/zlib/xmake.lua):

If you want to know more, please see: [Create and Submit packages to the official repository](https://xmake.io/guide/package-management/package-distribution.html#submit-package-to-the-official-repository)

## Create a package template from Github

We need to install the [gh](https://github.com/cli/cli) cli tool first, and then execute the following command to log in to github.

```console
$ gh auth login
```

Create a package configuration file to this warehouse based on the package address of github.

```console
$ xmake l scripts/new.lua github:glennrp/libpng
package("libpng")
    set_homepage("http://libpng.sf.net")
    set_description("LIBPNG: Portable Network Graphics support, official libpng repository")

    add_urls("https://github.com/glennrp/libpng/archive/refs/tags/$(version).tar.gz",
             "https://github.com/glennrp/libpng.git")
    add_versions("v1.6.35", "6d59d6a154ccbb772ec11772cb8f8beb0d382b61e7ccc62435bf7311c9f4b210")

    add_deps("cmake")

    on_install(function (package)
        local configs = {}
        table.insert(configs, "-DCMAKE_BUILD_TYPE=" .. (package:debug() and "Debug" or "Release"))
        table.insert(configs, "-DBUILD_SHARED_LIBS=" .. (package:config("shared") and "ON" or "OFF"))
        import("package.tools.cmake").install(package, configs)
    end)

    on_test(function (package)
        assert(package:has_cfuncs("foo", {includes = "foo.h"}))
    end)
packages/l/libpng/xmake.lua generated!
```

### Test a package in local

```console
$ xmake l scripts/test.lua --shallow -vD zlib
$ xmake l scripts/test.lua --shallow -vD -p iphoneos zlib
$ xmake l scripts/test.lua --shallow -vD -k shared -m debug zlib
$ xmake l scripts/test.lua --shallow -vD --runtimes=MD zlib
```

## Project Templates

This repository also provides official project templates for `xmake create`.

You can use these templates to create new projects quickly:

```console
$ xmake create -l c++ -t console myproject
```

The templates are located in the `templates` directory.
