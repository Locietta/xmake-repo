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

import("package.manager.msys2.find_package", {alias = "msys2_find_package"})

-- Xmake resolves a "<manager>::" namespace to the module directory of the
-- same name and does not tell the module which namespace was used, so each
-- sub-environment gets this shim to bind its own identity.
function main(name, opt)
    opt = table.join(opt or {}, {manager_name = "msys2-mingw32"})
    return msys2_find_package(name, opt)
end
