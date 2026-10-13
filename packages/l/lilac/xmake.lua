package("lilac")
    set_homepage("https://github.com/Locietta/lilac")
    set_description("C++26 syntax-highlighting lexers ported from Notepad4/Lexilla, with streaming re-lexing")
    set_license("MIT")

    -- Development override: build from a local checkout instead of the pinned
    -- commit (then `xmake require -f lilac`).
    local source = os.getenv("LILAC_SOURCE_DIR")
    if source and #source > 0 then
        set_sourcedir(source)
    else
        add_urls("https://github.com/Locietta/lilac.git")
        add_versions("0.1.0", "37ff17d0a51ea34710190ef353e1969a02151149")
        add_versions("0.1.1", "a201cd520fc438744696512f83a57e1149bb0972")
    end

    -- Needs GCC 16 with -freflection/-fcontracts from the consumer's Pixi
    -- environment. On MinGW the consumer must define handle_contract_violation
    -- (see lilac's README).
    add_deps("ngcpp-proxy")

    on_load(function (package)
        package:add("syslinks", "stdc++exp")
    end)

    on_install("mingw", "linux", function (package)
        import("package.tools.xmake").install(package, {sanitizers = false}, {target = "lilac"})
    end)

    on_test(function (package)
        -- A compile probe would need -freflection/-fcontracts, which xmake's
        -- flag checker drops for snippets; consumers' builds exercise the
        -- headers, so only check the installed layout here.
        assert(os.isfile(path.join(package:installdir("include"), "lilac", "lexer.h")))
        assert(os.isfile(path.join(package:installdir("lib"), "liblilac.a")))
    end)
