package("slang-rhi")
    set_homepage("https://github.com/shader-slang/slang-rhi")
    set_license("https://github.com/shader-slang/slang-rhi/blob/main/LICENSE")
    set_description("Slang Render Hardware Interface")

    add_urls("https://github.com/shader-slang/slang-rhi.git")
    add_versions("2026.08.20", "d1ef4f5549fc6ce3d1c47512759a8de0af51e084")
    add_versions("2026.06.23", "35f5396e4e55c161893fb8b1049e2bfae2400dd2")
    add_versions("2026.05.13", "19a511e13490b0affe8a5653af345c9b5ab88b0d")

    add_deps("slang")
    add_deps("cmake")

    add_configs("shared", { description = "Build shared library", default = false, type = "boolean", readonly = true })

    -- Backend selection. Defaults mirror slang-rhi's own platform defaults so an
    -- unconfigured require keeps building every backend the platform supports.
    -- Consumers that only need one backend (e.g. Vulkan) disable the rest to cut
    -- the static library size and the transitive system libraries.
    local windows = is_plat("windows")
    local linux = is_plat("linux")
    local macosx = is_plat("macosx")
    add_configs("cpu", { description = "Build the CPU backend", default = true, type = "boolean" })
    add_configs("vulkan", { description = "Build the Vulkan backend", default = true, type = "boolean" })
    add_configs("d3d11", { description = "Build the D3D11 backend (Windows)", default = windows, type = "boolean" })
    add_configs("d3d12", { description = "Build the D3D12 backend (Windows)", default = windows, type = "boolean" })
    add_configs("agility_sdk", { description = "Bundle the D3D12 Agility SDK (requires d3d12)", default = windows, type = "boolean" })
    add_configs("nvapi", { description = "Link NVAPI for the D3D backends (Windows x64)", default = windows, type = "boolean" })
    add_configs("fetch_dxc", { description = "Fetch DirectXShaderCompiler for the D3D12 backend (Windows)", default = windows, type = "boolean" })
    add_configs("cuda", { description = "Build the CUDA backend", default = windows or linux, type = "boolean" })
    add_configs("optix", { description = "Build OptiX support (requires cuda)", default = windows or linux, type = "boolean" })
    add_configs("wgpu", { description = "Build the WebGPU (Dawn) backend", default = true, type = "boolean" })
    add_configs("metal", { description = "Build the Metal backend (macOS)", default = macosx, type = "boolean" })
    add_configs("aftermath", { description = "Enable Nsight Aftermath support", default = false, type = "boolean" })

    on_load(function (package)
        if package:is_plat("windows") then
            package:add("syslinks", "Advapi32")
            if package:config("d3d11") or package:config("d3d12") then
                package:add("syslinks", "dxgi", "dxguid")
            end
            if package:config("d3d11") then package:add("syslinks", "d3d11") end
            if package:config("d3d12") then package:add("syslinks", "d3d12") end
        elseif package:is_plat("linux") then
            package:add("syslinks", "dl", "pthread")
        elseif package:is_plat("macosx") then
            package:add("frameworks", "Foundation", "QuartzCore")
            if package:config("metal") then package:add("frameworks", "Metal") end
        end
    end)

    on_install("windows|x64", "macosx", "linux|x86_64", function (package)
        local configs = {}

        local slang_path = package:dep("slang"):installdir()
        -- convert to cmake style path
        slang_path = slang_path:gsub("\\", "/")

        local function onoff(name)
            return package:config(name) and "ON" or "OFF"
        end

        table.insert(configs, "-DSLANG_RHI_BUILD_SHARED=" .. (package:config("shared") and "ON" or "OFF"))
        table.insert(configs, "-DSLANG_RHI_SLANG_INCLUDE_DIR=" .. slang_path .. "/include")
        table.insert(configs, "-DSLANG_RHI_SLANG_BINARY_DIR=" .. slang_path)
        -- disable tests and examples
        table.insert(configs, "-DSLANG_RHI_BUILD_TESTS=OFF")
        table.insert(configs, "-DSLANG_RHI_BUILD_TESTS_WITH_GLFW=OFF")
        table.insert(configs, "-DSLANG_RHI_BUILD_EXAMPLES=OFF")

        table.insert(configs, "-DSLANG_RHI_FETCH_SLANG=OFF")
        table.insert(configs, "-DSLANG_RHI_FETCH_DXC=" .. onoff("fetch_dxc"))
        for _, backend in ipairs({"CPU", "VULKAN", "D3D11", "D3D12", "AGILITY_SDK", "NVAPI", "CUDA", "OPTIX", "WGPU", "METAL", "AFTERMATH"}) do
            table.insert(configs, "-DSLANG_RHI_ENABLE_" .. backend .. "=" .. onoff(backend:lower()))
        end
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
            -- slang-rhi-d3d12ma (D3D12 Memory Allocator, private dep of the D3D12 backend)
            if package:config("d3d12") and try_copy_lib(path.join(build_dir, "slang-rhi-d3d12ma.lib")) then
                package:add("links", "slang-rhi-d3d12ma")
            end
            -- slang-rhi-vma (Vulkan Memory Allocator, private dep of the Vulkan backend)
            if package:config("vulkan") and try_copy_lib(path.join(build_dir, "slang-rhi-vma.lib")) then
                package:add("links", "slang-rhi-vma")
            end
        else
            -- *nix
            if try_copy_lib(path.join(build_dir, "libslang-rhi-resources.a")) then
                package:add("links", "slang-rhi-resources")
            end
            if package:config("vulkan") and try_copy_lib(path.join(build_dir, "libslang-rhi-vma.a")) then
                package:add("links", "slang-rhi-vma")
            end
        end

        -- Copy NVAPI library to package lib directory
        if is_plat("windows") and package:config("nvapi") then
            local nvapi_lib = path.join(build_dir, "_deps/nvapi-src/amd64/nvapi64.lib")
            if os.isfile(nvapi_lib) then
                os.cp(nvapi_lib, package:installdir("lib"))
                package:add("links", "nvapi64")
            end
        end
    end)

    on_test(function (package)
        local configs = {languages = "c++17"}

        if is_plat("linux") then
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
