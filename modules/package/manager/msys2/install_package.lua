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

import("core.base.option")
import("package.manager.msys2.utils", {alias = "msys2_utils"})

-- Install a missing package into the MSYS2 installation via pacman.
function main(name, opt)
    opt = opt or {}

    local pacman = msys2_utils.pacman(opt)
    if not pacman then
        raise("pacman not found! please install MSYS2 and set %%MSYS2%% to its root directory.")
    end

    local info = msys2_utils.subenv(opt.manager_name)
    local full_name = msys2_utils.package_name(name, info, opt)

    -- pacman writes to the shared installation, so it needs elevation; --noconfirm
    -- keeps it from blocking on a prompt xmake cannot answer
    local argv = {"-Sy", "--noconfirm", "--needed", full_name}
    if option.get("verbose") then
        cprint("${dim}> %s %s", pacman.program, table.concat(argv, " "))
    end
    os.vrunv(pacman.program, argv)
end
