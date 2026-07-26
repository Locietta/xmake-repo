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

import("lib.detect.find_tool")

-- MSYS2 sub-environments, keyed by the name used in the `msys2-<subenv>::`
-- namespace. @see https://www.msys2.org/docs/environments/
--
-- `prefix` is the package-name infix (mingw-w64-<prefix>-<arch>-<name>); the
-- msys environment takes no prefix at all. `root` is the sub-environment
-- directory below the MSYS2 installation, which is also the POSIX absolute
-- path pacman reports for its files.
local k_subenvs = {
    msys      = {root = "usr",        arch = nil,        prefix = nil},
    mingw64   = {root = "mingw64",    arch = "x86_64",   prefix = nil},
    mingw32   = {root = "mingw32",    arch = "i686",     prefix = nil},
    ucrt64    = {root = "ucrt64",     arch = "x86_64",   prefix = "ucrt"},
    clang64   = {root = "clang64",    arch = "x86_64",   prefix = "clang"},
    clang32   = {root = "clang32",    arch = "i686",     prefix = "clang"},
    clangarm64 = {root = "clangarm64", arch = "aarch64", prefix = "clang"}
}

-- Get every known sub-environment descriptor, keyed by name.
function subenvs()
    return k_subenvs
end

-- Get the sub-environment descriptor for a `msys2-<subenv>` manager name.
-- Plain `msys2` has no sub-environment: names pass through unchanged and
-- files may live anywhere in the installation.
function subenv(manager_name)
    local name = (manager_name or ""):lower()
    local suffix = name:match("^msys2%-(.+)$")
    if not suffix then
        return
    end
    local info = k_subenvs[suffix]
    assert(info, "unknown MSYS2 sub-environment '%s', expected one of: msys, mingw64, mingw32, ucrt64, clang64, clang32, clangarm64", suffix)
    return info, suffix
end

-- Get the MSYS2 installation root.
--
-- MSYS2 has no registry entry and is deliberately kept off PATH by most
-- users (its binaries shadow tools that vcpkg/conan/cmake rely on), so the
-- %MSYS2% environment variable is the contract. `configs.msys2_root` and
-- the common install locations act as fallbacks.
function rootdir(opt)
    local configs = opt and opt.configs or {}
    local candidates = {configs.msys2_root, os.getenv("MSYS2"), os.getenv("MSYS2_ROOT")}
    if is_host("windows") then
        table.join2(candidates, {"C:\\msys64", "C:\\msys32"})
    end
    for _, candidate in ipairs(candidates) do
        if candidate and os.isdir(candidate) then
            return candidate
        end
    end
end

-- Find the pacman shipped with the MSYS2 installation.
--
-- Deliberately not find_tool("pacman"): resolving through PATH would either
-- fail (MSYS2 is normally not on PATH) or, on a machine where it is, pick up
-- an unrelated installation. The MSYS2 root is the single source of truth.
function pacman(opt)
    local root = rootdir(opt)
    if not root then
        return
    end
    local program = path.join(root, "usr", "bin", "pacman.exe")
    if not os.isfile(program) then
        program = path.join(root, "usr", "bin", "pacman")
        if not os.isfile(program) then
            return
        end
    end
    return {program = program, version = nil}
end

-- Translate a POSIX path reported by pacman into a native path below the
-- MSYS2 root, e.g. /ucrt64/lib/libiconv.a -> D:\msys64\ucrt64\lib\libiconv.a
--
-- Done by string surgery rather than cygpath: cygpath only exists inside an
-- MSYS2 shell, and this manager is meant to work from a native xmake run.
-- Paths below /usr map onto the installation root as-is; every sub-env root
-- is a top-level directory there too, so a single join covers both.
function to_native_path(root, posix_path)
    local relative = posix_path:gsub("^/+", "")
    return path.normalize(path.join(root, relative))
end

-- Build the full MSYS2 package name for a sub-environment.
-- @see https://www.msys2.org/docs/package-naming/
function package_name(name, info, opt)
    if not info or not info.prefix and not info.arch then
        return name -- msys environment: no prefix
    end
    if name:startswith("mingw-w64-") then
        return name -- already fully qualified
    end
    local prefix = "mingw-w64-"
    if info.prefix then
        prefix = prefix .. info.prefix .. "-"
    end
    return prefix .. info.arch .. "-" .. name
end

-- List the files owned by an installed package (`pacman -Ql`), as POSIX
-- paths. Returns nil when the package is not installed.
function package_files(pacman_tool, name)
    local list = try {function ()
        return os.iorunv(pacman_tool.program, {"-Q", "-l", name})
    end}
    if not list then
        return
    end

    local files = {}
    for _, line in ipairs(list:split('\n', {plain = true})) do
        -- each line is "<package> <path>"; paths may contain spaces
        local file = line:trim():match("^%S+%s+(.+)$")
        if file and not file:endswith("/") then
            table.insert(files, file)
        end
    end
    return files
end

-- Get the installed version of a package (`pacman -Q`), without the pkgrel.
function package_version(pacman_tool, name)
    local output = try {function ()
        return os.iorunv(pacman_tool.program, {"-Q", name})
    end}
    if not output then
        return
    end
    local version = output:trim():match("^%S+%s+(%S+)$")
    if not version then
        return
    end
    -- strip an epoch prefix ("1:1.3.204-1") and the pkgrel suffix
    version = version:split(':', {plain = true})
    version = version[#version]
    return version:split('-', {plain = true})[1]
end
