-- Embed binary files as objects and generate a C++ header for each input.
-- foo.bin becomes <xmake/bin2obj/foo_bin.hpp> and xmake::foo_bin.
local rule_name = "utils.bin2obj.cpp"

local function _symbol_basename(sourcefile)
    return path.filename(sourcefile):gsub("[^A-Za-z0-9_]", "_")
end

local function _public_name(symbol_basename)
    if symbol_basename:match("^[A-Za-z]") then
        return symbol_basename
    end
    return "data_" .. symbol_basename
end

local function _header_content(symbol, name, size)
    return string.format([=[#pragma once

#include <cstddef>
#include <span>

namespace xmake::detail {

extern "C" {
extern const std::byte %s_start[];
extern const std::byte %s_end[];
}

} // namespace xmake::detail

namespace xmake {

inline constexpr std::span<const std::byte> %s{
    detail::%s_start,
    %d,
};

} // namespace xmake
]=], symbol, symbol, name, symbol, size)
end

local function _generate_headers(target)
    local sourcebatch = target:sourcebatches()[rule_name]
    if not sourcebatch then
        return
    end

    local headerroot = path.join(target:autogendir(), "rules", rule_name)
    local headerdir = path.join(headerroot, "xmake", "bin2obj")
    local symbol_prefix = target:extraconf("rules", rule_name, "symbol_prefix") or "_binary_"
    local seen = {}

    if not symbol_prefix:match("^[A-Za-z_][A-Za-z0-9_]*$") then
        raise("%s: symbol prefix '%s' cannot be named from C++", rule_name, symbol_prefix)
    end

    for _, sourcefile in ipairs(sourcebatch.sourcefiles) do
        local fileconfig = target:fileconfig(sourcefile)
        local transform = (fileconfig and fileconfig.transform) or target:extraconf("rules", rule_name, "transform")
        if transform then
            -- The transformed size is unavailable while headers are generated.
            raise("%s: transformed inputs cannot expose a constexpr span", rule_name)
        end

        local zeroend = fileconfig and fileconfig.zeroend
        if zeroend == nil then
            zeroend = target:extraconf("rules", rule_name, "zeroend") or false
        end

        local symbol_basename = _symbol_basename(sourcefile)
        local name = _public_name(symbol_basename)
        if seen[name] then
            raise("%s: '%s' and '%s' both generate xmake::%s", rule_name, seen[name], sourcefile, name)
        end
        seen[name] = sourcefile

        local size = os.filesize(sourcefile) + (zeroend and 1 or 0)
        local symbol = symbol_prefix .. symbol_basename
        local headerfile = path.join(headerdir, name .. ".hpp")
        local content = _header_content(symbol, name, size)

        if not os.isfile(headerfile) or io.readfile(headerfile) ~= content then
            os.mkdir(headerdir)
            io.writefile(headerfile, content)
        end
    end

    target:add("includedirs", headerroot)
end

rule(rule_name)
    set_extensions(".bin")
    add_orders(rule_name, "c++.build.modules.builder")
    on_load(_generate_headers)
    after_buildcmd_file(function (target, batchcmds, sourcefile, opt)
        import("rules.utils.bin2obj.utils", {alias = "bin2obj_utils", rootdir = os.programdir()})

        local objectfile = bin2obj_utils.generate_objectfile(target, batchcmds, sourcefile, {
            progress = opt.progress,
            rulename = rule_name,
        })

        batchcmds:add_depfiles(sourcefile)
        batchcmds:set_depmtime(os.mtime(objectfile))
        batchcmds:set_depcache(target:dependfile(objectfile))
    end)
