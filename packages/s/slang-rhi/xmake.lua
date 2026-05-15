package("slang-rhi")
    set_homepage("https://github.com/shader-slang/slang-rhi")
    set_license("https://github.com/shader-slang/slang-rhi/blob/main/LICENSE")
    set_description("Slang Render Hardware Interface")

    add_urls("https://github.com/shader-slang/slang-rhi.git")
    add_versions("2026.05.13", "19a511e13490b0affe8a5653af345c9b5ab88b0d")
    add_versions("2026.04.24", "558bfda10cbb1178e54087b5485ef7baaff1e337")
    add_versions("2026.03.30", "9eb7734ab0ebd4ead90b9ec0782dbb83521da164")

    if is_plat("windows") then
        add_syslinks("d3d11", "d3d12", "dxgi", "dxguid", "Advapi32")
    elseif is_plat("linux") then
        add_syslinks("dl", "pthread")
    elseif is_plat("macosx") then
        add_frameworks("Foundation", "QuartzCore", "Metal")
    end

    add_deps("slang")
    add_deps("cmake")

    add_configs("shared", { description = "Build shared library", default = false, type = "boolean", readonly = true })

    on_install("windows|x64", "macosx", "linux|x86_64", function (package)
        local configs = {}          

        local slang_path = package:dep("slang"):installdir()
        -- convert to cmake style path
        slang_path = slang_path:gsub("\\", "/")

        table.insert(configs, "-DSLANG_RHI_BUILD_SHARED=" .. (package:config("shared") and "ON" or "OFF"))
        table.insert(configs, "-DSLANG_RHI_SLANG_INCLUDE_DIR=" .. slang_path .. "/include")
        table.insert(configs, "-DSLANG_RHI_SLANG_BINARY_DIR=" .. slang_path)
        -- disable tests and examples
        table.insert(configs, "-DSLANG_RHI_BUILD_TESTS=OFF")
        table.insert(configs, "-DSLANG_RHI_BUILD_TESTS_WITH_GLFW=OFF")
        table.insert(configs, "-DSLANG_RHI_BUILD_EXAMPLES=OFF")

        table.insert(configs, "-DSLANG_RHI_FETCH_SLANG=OFF")
        if is_plat("windows") then
            table.insert(configs, "-DCMAKE_C_FLAGS_INIT=/utf-8")
            table.insert(configs, "-DCMAKE_CXX_FLAGS_INIT=/utf-8")
        end

        import("package.tools.cmake").install(package, configs)

        package:add("links", "slang-rhi")

        local build_dir = package:builddir()

        -- Copy private static dependencies that cmake install() doesn't install
        local function try_copy_lib(lib_path)
            if os.isfile(lib_path) then
                os.cp(lib_path, package:installdir("lib"))
                return true
            end
            return false
        end

        if is_plat("windows") then
            -- slang-rhi-resources (embedded shaders)
            if try_copy_lib(path.join(build_dir, "slang-rhi-resources.lib")) then
                package:add("links", "slang-rhi-resources")
            end
            -- slang-rhi-d3d12ma (D3D12 Memory Allocator, private dep of slang-rhi)
            if try_copy_lib(path.join(build_dir, "slang-rhi-d3d12ma.lib")) then
                package:add("links", "slang-rhi-d3d12ma")
            end
            -- slang-rhi-vma (Vulkan Memory Allocator, private dep of slang-rhi)
            if try_copy_lib(path.join(build_dir, "slang-rhi-vma.lib")) then
                package:add("links", "slang-rhi-vma")
            end
        else
            -- *nix
            if try_copy_lib(path.join(build_dir, "libslang-rhi-resources.a")) then
                package:add("links", "slang-rhi-resources")
            end
            if try_copy_lib(path.join(build_dir, "libslang-rhi-vma.a")) then
                package:add("links", "slang-rhi-vma")
            end
        end

        -- Copy NVAPI library to package lib directory
        if is_plat("windows") then
            local nvapi_lib = path.join(build_dir, "_deps/nvapi-src/amd64/nvapi64.lib")
            if os.isfile(nvapi_lib) then
                os.cp(nvapi_lib, package:installdir("lib"))
                package:add("links", "nvapi64")
            end
        end
    end)

    on_test(function (package)
        local configs = {languages = "c++17"}
        
        if is_plat("windows") then
            configs.syslinks = {"d3d11", "d3d12", "dxgi", "dxguid", "Advapi32"}
        elseif is_plat("linux") then
            configs.syslinks = {"dl", "pthread"}
        elseif is_plat("macosx") then
            -- QUESTION: does this work for macos?
            configs.links = {"-framework Foundation", "-framework QuartzCore", "-framework Metal"}
        end

        assert(package:check_cxxsnippets({test = [[
            #include <slang-rhi.h>
            void test() {
                rhi::DeviceDesc device_desc = {};
                device_desc.slang.targetProfile = "spirv_1_6";
                device_desc.deviceType = rhi::DeviceType::Vulkan;
                auto device = rhi::getRHI()->createDevice(device_desc);
                auto session = device->getSlangSession(); 
            }
        ]]}, {configs = configs}))
    end)
