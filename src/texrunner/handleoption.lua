local COPYRIGHT_NOTICE = [[
Copyright (C) 2016,2018  ARATA Mizuki

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]

local pathutil    = require "texrunner.pathutil"
local parseoption = require "texrunner.option".parseoption
local KnownEngines = require "texrunner.tex_engine"

local function usage(arg)
  io.write(string.format([[
ClutTeX: Process TeX files without cluttering your working directory

Usage:
  %s [options] [--] FILE.tex

Options:
  -e, --engine=ENGINE          Specify which TeX engine to use.
                                 ENGINE is one of the following:
                                     pdflatex, pdftex, lualatex, luatex,
                                     xelatex, xetex, latex, etex, tex,
                                     platex, eptex, ptex,
                                     uplatex, euptex, uptex,
  -o, --output=FILE            The name of output file.
                                 [default: JOBNAME.pdf or JOBNAME.dvi]
      --fresh                  Clean intermediate files before running TeX.
                                 Cannot be used with --output-directory.
      --max-iterations=N       Maximum number of running TeX to resolve
                                 cross-references.  [default: 3]
      --[no-]change-directory  Change directory before running TeX.
      --watch                  Watch input files for change.  Requires fswatch
                                 program to be installed.
      --tex-option=OPTION      Pass OPTION to TeX as a single option.
      --tex-options=OPTIONs    Pass OPTIONs to TeX as multiple options.
      --dvipdfmx-option[s]=OPTION[s]  Same for dvipdfmx.
  -h, --help                   Print this message and exit.
  -v, --version                Print version information and exit.
  -V, --verbose                Be more verbose.

      --[no-]shell-escape
      --shell-restricted
      --synctex=NUMBER
      --[no-]file-line-error   [default: yes]
      --[no-]halt-on-error     [default: yes]
      --interaction=STRING     [default: nonstopmode]
      --jobname=STRING
      --output-directory=DIR   [default: somewhere in the temporary directory]
      --output-format=FORMAT   FORMAT is `pdf' or `dvi'.  [default: pdf]

%s
]], arg[0] or 'texlua cluttex.lua', COPYRIGHT_NOTICE))
end

local option_spec = {
  -- Options for ClutTeX
  {
    short = "e",
    long = "engine",
    param = true,
  },
  {
    short = "o",
    long = "output",
    param = true,
  },
  {
    long = "fresh",
  },
  {
    long = "max-iterations",
    param = true,
  },
  {
    long = "change-directory",
    boolean = true,
  },
  {
    long = "watch",
  },
  {
    short = "h",
    long = "help",
  },
  {
    short = "v",
    long = "version",
  },
  {
    short = "V",
    long = "verbose",
  },
  -- Options for TeX
  {
    long = "synctex",
    param = true,
  },
  {
    long = "file-line-error",
    boolean = true,
  },
  {
    long = "interaction",
    param = true,
  },
  {
    long = "halt-on-error",
    boolean = true,
  },
  {
    long = "shell-escape",
    boolean = true,
  },
  {
    long = "shell-restricted",
  },
  {
    long = "jobname",
    param = true,
  },
  {
    long = "output-directory",
    param = true,
  },
  {
    long = "output-format",
    param = true,
  },
  {
    long = "tex-option",
    param = true,
  },
  {
    long = "tex-options",
    param = true,
  },
  {
    long = "dvipdfmx-option",
    param = true,
  },
  {
    long = "dvipdfmx-options",
    param = true,
  },
}

-- Default values for options
local function set_default_values(options)
  if options.max_iterations == nil then
    options.max_iterations = 3
  end

  if options.interaction == nil then
    options.interaction = "nonstopmode"
  end

  if options.file_line_error == nil then
    options.file_line_error = true
  end

  if options.halt_on_error == nil then
    options.halt_on_error = true
  end
end

-- inputfile, engine, options, tex_extraoptions, dvipdfmx_extraoptions = handle_cluttex_options(arg)
local function handle_cluttex_options(arg)
  -- Parse options
  local option_and_params, non_option_index = parseoption(arg, option_spec)

  -- Handle options
  local options = {}
  local tex_extraoptions = {}
  local dvipdfmx_extraoptions = {}
  CLUTTEX_VERBOSITY = 0
  for _,option in ipairs(option_and_params) do
    local name = option[1]
    local param = option[2]

    if name == "engine" then
      assert(options.engine == nil, "multiple --engine options")
      options.engine = param

    elseif name == "output" then
      assert(options.output == nil, "multiple --output options")
      options.output = param

    elseif name == "fresh" then
      assert(options.fresh == nil, "multiple --fresh options")
      options.fresh = true

    elseif name == "max-iterations" then
      assert(options.max_iterations == nil, "multiple --max-iterations options")
      options.max_iterations = assert(tonumber(param), "invalid value for --max-iterations option")
      assert(options.max_iterations >= 1, "invalid value for --max-iterations option")

    elseif name == "watch" then
      assert(options.watch == nil, "multiple --watch options")
      options.watch = true

    elseif name == "help" then
      usage(arg)
      os.exit(0)

    elseif name == "version" then
      io.stderr:write("cluttex (prerelease)\n")
      os.exit(0)

    elseif name == "verbose" then
      CLUTTEX_VERBOSITY = CLUTTEX_VERBOSITY + 1

    elseif name == "change-directory" then
      assert(options.change_directory == nil, "multiple --change-directory options")
      options.change_directory = param

      -- Options for TeX
    elseif name == "synctex" then
      assert(options.synctex == nil, "multiple --synctex options")
      options.synctex = param

    elseif name == "file-line-error" then
      options.file_line_error = param

    elseif name == "interaction" then
      assert(options.interaction == nil, "multiple --interaction options")
      assert(param == "batchmode" or param == "nonstopmode" or param == "scrollmode" or param == "errorstopmode", "invalid argument for --interaction")
      options.interaction = param

    elseif name == "halt-on-error" then
      options.halt_on_error = param

    elseif name == "shell-escape" then
      assert(options.shell_escape == nil and options.shell_restricted == nil, "multiple --(no-)shell-escape or --shell-restricted options")
      options.shell_escape = param

    elseif name == "shell-restricted" then
      assert(options.shell_escape == nil and options.shell_restricted == nil, "multiple --(no-)shell-escape or --shell-restricted options")
      options.shell_restricted = true

    elseif name == "jobname" then
      assert(options.jobname == nil, "multiple --jobname options")
      options.jobname = param

    elseif name == "output-directory" then
      assert(options.output_directory == nil, "multiple --output-directory options")
      options.output_directory = param

    elseif name == "output-format" then
      assert(options.output_format == nil, "multiple --output-format options")
      assert(param == "pdf" or param == "dvi", "invalid argument for --output-format")
      options.output_format = param

    elseif name == "tex-option" then
      table.insert(tex_extraoptions, shellutil.escape(param))

    elseif name == "tex-options" then
      table.insert(tex_extraoptions, param)

    elseif name == "dvipdfmx-option" then
      table.insert(dvipdfmx_extraoptions, shellutil.escape(param))

    elseif name == "dvipdfmx-options" then
      table.insert(dvipdfmx_extraoptions, param)

    end
  end

  -- Handle non-options (i.e. input file)
  if non_option_index > #arg then
    -- No input file given
    usage()
    os.exit(1)
  elseif non_option_index < #arg then
    io.stderr("cluttex: Multiple input files are not supported.\n")
    os.exit(1)
  end
  local inputfile = arg[non_option_index]

  -- If run as 'cllualatex', then the default engine is lualatex
  if options.engine == nil and type(arg[0]) == "string" then
    local basename = pathutil.basename(arg[0])
    local engine_part = string.match(basename, "^cl(%w+)$")
    if engine_part and KnownEngines[engine_part] then
      options.engine = engine_part
    end
  end

  if options.engine == nil then
    io.stderr:write("cluttex: Engine not specified.\n")
    os.exit(1)
  end
  local engine = KnownEngines[options.engine]
  if not engine then
    io.stderr:write("cluttex: Unknown engine name '", options.engine, "'.\n")
    os.exit(1)
  end

  set_default_values(options)

  return inputfile, engine, options, tex_extraoptions, dvipdfmx_extraoptions
end

return {
  usage = usage,
  handle_cluttex_options = handle_cluttex_options,
}