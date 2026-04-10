package("mdspan")
    set_homepage("https://github.com/kokkos/mdspan")
    set_description("Reference implementation of mdspan targeting C++23")
    set_license("Apache-2.0 WITH LLVM-exception")

    add_urls("https://github.com/kokkos/mdspan.git")

    add_versions("2026.02.24", "80fc772eb812b45097c28fc0a46d8ff006138d69")

    on_install(function (package)
        return {
            includedirs = {path.join(package:sourcedir(), "include")}
        }
    end)

    on_test(function (package)
        assert(package:check_cxxsnippets({test = [[
            #include <mdspan/mdspan.hpp>
            #include <vector>
            #include <cstddef>
            void test() {
                std::vector<float> v(16);
                Kokkos::mdspan<float, Kokkos::dextents<std::size_t, 2>> view(v.data(), 4, 4);
                (void)view;
            }
        ]]}, {configs = {languages = "c++23"}}))
    end)
