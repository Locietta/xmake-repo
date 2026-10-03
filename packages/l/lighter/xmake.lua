package("lighter")
    set_homepage("https://github.com/Locietta/lighter")
    set_description("C++26 coroutine runtime on libuv with libcurl HTTP/SSE, codecs and utilities")
    set_license("MIT")

    -- Development override: build from a local checkout instead of the pinned
    -- commit (then `xmake require -f lighter`).
    local source = os.getenv("LIGHTER_SOURCE_DIR")
    if source and #source > 0 then
        set_sourcedir(source)
    else
        add_urls("https://github.com/Locietta/lighter.git")
        add_versions("0.1.0", "23dabd52d8c22e28ec9e80d6ae5fae0426c86f31")
        add_versions("0.2.0", "536c017c65a3180be0832f9c29ec3fddfc329794")
    end

    -- Needs GCC 16 with -freflection/-fcontracts and the C dependencies from
    -- the consumer's Pixi environment (libuv, libcurl, libiconv).
    add_deps("glaze", "ngcpp-proxy")
    add_deps("pixi::libcurl", "pixi::libiconv", "pixi::libuv")

    on_load(function (package)
        package:add("syslinks", "stdc++exp")
        if package:is_plat("mingw", "windows") then
            package:add("syslinks", "psapi", "user32", "advapi32", "iphlpapi", "userenv", "ws2_32", "dbghelp", "ole32", "shell32")
        elseif package:is_plat("linux") then
            package:add("syslinks", "pthread")
        end
    end)

    on_install("mingw", "linux", function (package)
        import("package.tools.xmake").install(package, {sanitizers = false}, {target = "lighter"})
    end)

    on_test(function (package)
        -- A compile probe would need -freflection/-fcontracts, which xmake's
        -- flag checker drops for snippets; consumers' builds exercise the
        -- headers, so only check the installed layout here.
        assert(os.isfile(path.join(package:installdir("include"), "lighter", "async", "async.h")))
        assert(os.isfile(path.join(package:installdir("lib"), "liblighter.a")))
    end)