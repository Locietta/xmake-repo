--!A cross-platform build utility based on Lua
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

import("core.base.hashset")
import("core.project.target")
import("package.manager.msys2.utils", {alias = "msys2_utils"})

-- Find a package installed in an MSYS2 sub-environment.
--
-- Unlike Xmake's builtin pacman manager, this runs from a native (non-MSYS2)
-- shell: pacman is located through the MSYS2 root instead of PATH, and the
-- POSIX paths it reports are translated to native paths without cygpath.
--
-- @param name  package name, e.g. libiconv (short, sub-env prefix implied)
-- @param opt   options, including opt.manager_name and configs.msys2_root
--
function main(name, opt)
    opt = opt or {}

    local info = msys2_utils.subenv(opt.manager_name)
    if info and info.arch then
        -- the sub-environment fixes the target architecture
        local wanted = info.arch == "x86_64" and "x64" or (info.arch == "i686" and "x86" or "arm64")
        if opt.arch and opt.arch ~= wanted then
            return
        end
    end

    local root = msys2_utils.rootdir(opt)
    if not root then
        return
    end

    local pacman = msys2_utils.pacman(opt)
    if not pacman then
        return
    end

    local full_name = msys2_utils.package_name(name, info, opt)
    local files = msys2_utils.package_files(pacman, full_name)
    if not files then
        return
    end

    -- restrict discovery to the sub-environment's own directory, so a query
    -- for ucrt64 never picks up mingw64's copy of the same library
    local scope = info and ("/" .. info.root .. "/") or nil

    -- A sub-environment's own include directory is already the compiler's
    -- default system include path. Passing it again with -isystem reorders
    -- the chain ahead of the bundled libstdc++ headers, which breaks
    -- #include_next (<cstdlib> then fails to find <stdlib.h>). Headers there
    -- are reachable without any flag, so record the hit and emit nothing.
    -- Without a sub-environment (plain msys2::) the package's own path tells
    -- us which root it belongs to.
    local default_includedirs = hashset.new()
    if info then
        default_includedirs:insert("/" .. info.root .. "/include")
    else
        for _, subenv_info in pairs(msys2_utils.subenvs()) do
            default_includedirs:insert("/" .. subenv_info.root .. "/include")
        end
    end

    local result = {}
    local found = false
    for _, file in ipairs(files) do
        if not scope or file:startswith(scope) then
            local native = msys2_utils.to_native_path(root, file)
            if file:find("/include/", 1, true) then
                -- the include root, not the header's own directory: nested
                -- headers (e.g. /include/foo/bar.h) are included as <foo/bar.h>
                local include_root = file:match("^(.*/include)/")
                if include_root then
                    found = true
                    if not default_includedirs:has(include_root) then
                        result.sysincludedirs = result.sysincludedirs or {}
                        table.insert(result.sysincludedirs, msys2_utils.to_native_path(root, include_root))
                    end
                end
            elseif file:endswith(".dll.a") or file:endswith(".a") or file:endswith(".lib") then
                result.linkdirs = result.linkdirs or {}
                result.links = result.links or {}
                result.libfiles = result.libfiles or {}
                table.insert(result.linkdirs, path.directory(native))
                table.insert(result.links, target.linkname(path.filename(native), {plat = opt.plat}))
                table.insert(result.libfiles, native)
                if file:endswith(".dll.a") then
                    result.shared = true
                else
                    result.static = true
                end
            elseif file:endswith(".dll") then
                -- runtime dependency: xmake copies these next to the binary
                result.libfiles = result.libfiles or {}
                table.insert(result.libfiles, native)
            end
        end
    end

    if not result.links and not found then
        return
    end

    if result.sysincludedirs then
        result.sysincludedirs = table.unique(result.sysincludedirs)
    end
    if result.linkdirs then
        result.linkdirs = table.unique(result.linkdirs)
    end
    if result.libfiles then
        result.libfiles = table.unique(result.libfiles)
    end
    if result.links then
        result.links = table.reverse_unique(result.links)
        -- pacman lists files alphabetically, but GNU ld resolves left to
        -- right: a package's namesake library must precede its helpers, or
        -- static links fail (libiconv.a needs libcharset.a after it, yet
        -- sorts before it). Promote the link matching the package name.
        local primary = (name:gsub("^lib", ""))
        for index, link in ipairs(result.links) do
            if index > 1 and link == primary then
                table.remove(result.links, index)
                table.insert(result.links, 1, link)
                break
            end
        end
    end

    result.version = msys2_utils.package_version(pacman, full_name)
    return result
end
