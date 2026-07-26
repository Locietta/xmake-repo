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

import("package.manager.msys2.utils", {alias = "msys2_utils"})

-- Search packages in the MSYS2 repositories (`pacman -Ss`).
function main(name, opt)
    opt = opt or {}

    local pacman = msys2_utils.pacman(opt)
    if not pacman then
        raise("pacman not found! please install MSYS2 and set %%MSYS2%% to its root directory.")
    end

    local info, subenv_name = msys2_utils.subenv(opt.manager_name)
    local namespace = subenv_name and ("msys2-" .. subenv_name) or "msys2"

    local output = try {function ()
        return os.iorunv(pacman.program, {"-Ss", name})
    end}
    if not output then
        return {}
    end

    -- `pacman -Ss` alternates a "<repo>/<package> <version> [tags]" line with
    -- an indented description line
    local results = {}
    local pending = nil
    for _, line in ipairs(output:split('\n', {plain = true})) do
        if line:startswith(" ") or line:startswith("\t") then
            if pending then
                pending.description = line:trim()
                table.insert(results, pending)
                pending = nil
            end
        else
            local repo, package_name, version = line:trim():match("^(%S+)/(%S+)%s+(%S+)")
            if package_name then
                -- only offer packages belonging to the requested sub-env
                if not info or repo == info.root or (info.root == "usr" and repo == "msys") then
                    -- report the short name, the form used in add_requires()
                    local short_name = package_name
                    if info and info.arch then
                        local prefix = "mingw%-w64%-" .. (info.prefix and (info.prefix .. "%-") or "") .. info.arch .. "%-"
                        short_name = package_name:gsub("^" .. prefix, "")
                    end
                    pending = {
                        name = namespace .. "::" .. short_name,
                        version = version:split('-', {plain = true})[1],
                        description = ""
                    }
                end
            end
        end
    end
    return results
end
