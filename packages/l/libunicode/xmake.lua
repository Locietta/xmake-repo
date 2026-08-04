package("libunicode")
    set_homepage("https://github.com/contour-terminal/libunicode")
    set_description("Modern C++20 Unicode library")
    set_license("Apache-2.0")

    add_urls("https://github.com/contour-terminal/libunicode.git")

    add_versions("0.9.2", "5a5b964937a6bfd650775fa76077b0b254f148c0")

    add_deps("cmake")

    on_install(function (package)
        import("package.tools.cmake").install(package, {
            "-DLIBUNICODE_BUILD_STATIC=ON",
            "-DLIBUNICODE_TESTING=OFF",
            "-DLIBUNICODE_BENCHMARK=OFF",
            "-DLIBUNICODE_EXAMPLES=OFF",
            "-DLIBUNICODE_TOOLS=OFF",
            "-DLIBUNICODE_SIMD_IMPLEMENTATION=none",
            "-DLIBUNICODE_INSTALL_CMAKE_FILES=OFF",
            "-DCMAKE_CXX_STANDARD=20"
        })
    end)

    on_test(function (package)
        assert(package:check_cxxsnippets({test = [[
            void test() {
                auto const width = unicode::grapheme_cluster_width("👩‍💻");
                (void)width;
            }
        ]]}, {configs = {languages = "c++20"}, includes = "libunicode/width.h"}))
    end)
