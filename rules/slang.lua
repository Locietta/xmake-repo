-- compile slang shaders to Slang IR (.slang-module)

local function _is_parent_relpath(p)
    return p and p:find("^%.%.[/\\]?") ~= nil
end

local function _collect_slang_dependencies(roots, sourcefile)
    -- `slangc -depfile` does not emit a depfile together with the `-no-codegen`
    -- mode required by our generic entry-point modules. Track every Slang source
    -- below each import root as a conservative, reliable fallback until the rule
    -- uses the Slang API's dependency enumeration.
    local dependencies = {}
    local seen = {}
    local function add_dependency(dependency)
        local absolute_path = path.absolute(dependency)
        if not seen[absolute_path] then
            seen[absolute_path] = true
            table.insert(dependencies, absolute_path)
        end
    end

    add_dependency(sourcefile)
    for _, root in ipairs(roots) do
        for _, dependency in ipairs(os.files(path.join(root, "**.slang"))) do
            add_dependency(dependency)
        end
        for _, dependency in ipairs(os.files(path.join(root, "**.slangh"))) do
            add_dependency(dependency)
        end
    end
    return dependencies
end

rule("slang")
    set_extensions(".slang", ".slangh")

    on_buildcmd_file(function (target, batchcmds, sourcefile, opt)
        import("lib.detect.find_tool")
        import("rules.utils.bin2obj.utils", {alias = "bin2obj_utils", rootdir = os.programdir()})

        local function _resolve_relative_output(sourcefile, scriptdir, output_subdir)
            local source_abs = path.absolute(sourcefile)
            local anchors = {
                path.absolute(path.join(scriptdir, output_subdir)),
                path.absolute(scriptdir)
            }
            for _, anchor in ipairs(anchors) do
                local rel = path.relative(source_abs, anchor)
                if rel and rel ~= "" and not _is_parent_relpath(rel) then
                    if rel == "." then
                        return path.filename(sourcefile)
                    end
                    return rel
                end
            end
            return path.filename(sourcefile)
        end

        local function _ensure_output_dir(outputdir, relpath)
            if not os.isdir(outputdir) then
                os.mkdir(outputdir)
            end
            local rel_dir = path.directory(relpath)
            if rel_dir and rel_dir ~= "." then
                local final_outputdir = path.join(outputdir, rel_dir)
                if not os.isdir(final_outputdir) then
                    os.mkdir(final_outputdir)
                end
                return final_outputdir
            end
            return outputdir
        end

        local basename = path.basename(sourcefile)
        local filename = path.filename(sourcefile)
        local scriptdir = target:scriptdir()
        local extname = (path.extension(sourcefile) or ""):lower()
        local is_header = extname == ".slangh"
        local fileconfig = target:fileconfig(sourcefile) or {}
        local embed = fileconfig.slang_embed or false

        local output_subdir = target:extraconf("rules", "slang", "outputdir") or "shaders"
        local output_root = embed and path.join(target:autogendir(), "rules", "slang", "embed") or target:targetdir()
        local outputdir = path.join(output_root, output_subdir)
        local relpath = _resolve_relative_output(sourcefile, scriptdir, output_subdir)
        local final_outputdir = _ensure_output_dir(outputdir, relpath)

        local outputname = is_header and filename or (basename .. ".slang-module")
        local outputfile = path.join(final_outputdir, outputname)

        if is_header then
            batchcmds:show_progress(opt.progress, "${color.build.object}copying.slangh %s", sourcefile)
            os.cp(sourcefile, outputfile)
            batchcmds:add_depfiles(sourcefile)
        else
            local slangc = assert(find_tool("slangc"), "slangc not found!")
            local language_version = target:extraconf("rules", "slang", "language_version") or "default"
            local slangc_opt = {
                path(sourcefile),
                "-std", language_version,
                "-O2",
                "-no-codegen",
                "-o", path(outputfile),
            }

            local include_dirs = target:extraconf("rules", "slang", "include_dirs") or {}
            local resolved_include_dirs = {}
            for _, dir in ipairs(include_dirs) do
                local resolved_dir = path(path.join(scriptdir, dir))
                table.insert(resolved_include_dirs, resolved_dir)
                table.insert(slangc_opt, "-I")
                table.insert(slangc_opt, resolved_dir)
            end

            local dependency_roots = {
                path.join(scriptdir, output_subdir),
                path.directory(sourcefile),
            }
            table.join2(dependency_roots, resolved_include_dirs)
            local dependency_files = _collect_slang_dependencies(dependency_roots, sourcefile)

            batchcmds:show_progress(opt.progress, "${color.build.object}compiling.slang %s", sourcefile)
            batchcmds:vrunv(slangc.program, slangc_opt)

            if embed then
                local objectfile = bin2obj_utils.generate_objectfile(target, batchcmds, outputfile, {
                    rulename = "slang",
                })
                batchcmds:set_depmtime(os.mtime(objectfile))
                batchcmds:set_depcache(target:dependfile(objectfile))
                batchcmds:add_depfiles(dependency_files, slangc.program)
                batchcmds:add_depvalues(language_version, "-O2", "-no-codegen", resolved_include_dirs)
                return
            end
            batchcmds:add_depfiles(dependency_files, slangc.program)
            batchcmds:add_depvalues(language_version, "-O2", "-no-codegen", resolved_include_dirs)
        end

        batchcmds:set_depmtime(os.mtime(outputfile))
        batchcmds:set_depcache(target:dependfile(outputfile))
    end)

    after_clean(function (target)
        import("private.action.clean.remove_files")
        local output_subdir = target:extraconf("rules", "slang", "outputdir") or "shaders"
        local generated_dirs = {
            path.join(target:targetdir(), output_subdir),
            path.join(target:autogendir(), "rules", "slang"),
            path.join(target:autogendir(), "rules", "slang2obj"),
            path.join(target:objectdir(), "gens", "rules", "slang"),
            path.join(target:objectdir(), "gens", "rules", "slang2obj"),
        }

        for _, dir in ipairs(generated_dirs) do
            remove_files(dir)
        end
    end)
