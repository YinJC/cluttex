local function create_initialization_script(filename, options)
  local initscript = assert(io.open(filename,"w"))
  if type(options.file_line_error) == "boolean" then
    initscript:write(string.format("texconfig.file_line_error = %s\n", options.file_line_error))
  end
  if type(options.halt_on_error) == "boolean" then
    initscript:write(string.format("texconfig.halt_on_error = %s\n", options.halt_on_error))
  end
  initscript:write(string.format("local output_directory = %q\n", options.output_directory))
  initscript:write([==[
local print = print
local io_open = io.open
local io_write = io.write
local texio_write = texio.write
local texio_write_nl = texio.write_nl
local function start_file_cb(category, filename)
  if category == 1 then -- a normal data file, like a TeX source
    texio_write_nl("log", "("..filename)
  elseif category == 2 then -- a font map coupling font names to resources
    texio_write("log", "{"..filename)
  elseif category == 3 then -- an image file (png, pdf, etc)
    texio_write("<"..filename)
  elseif category == 4 then -- an embedded font subset
    texio_write("<"..filename)
  elseif category == 5 then -- a fully embedded font
    texio_write("<<"..filename)
  else
    print("start_file: unknown category", category, filename)
  end
end
callback.register("start_file", start_file_cb)
local function stop_file_cb(category)
  if category == 1 then
    texio_write("log", ")")
  elseif category == 2 then
    texio_write("log", "}")
  elseif category == 3 then
    texio_write(">")
  elseif category == 4 then
    texio_write(">")
  elseif category == 5 then
    texio_write(">>")
  else
    print("stop_file: unknown category", category)
  end
end
callback.register("stop_file", stop_file_cb)
texio.write = function(...)
  if select("#",...) == 1 then
    -- Suppress luaotfload's message (See src/fontloader/runtime/fontload-reference.lua)
    if string.match(...,"^%(using cache: ") then
      return
    elseif string.match(...,"^%(using write cache: ") then
      return
    elseif string.match(...,"^%(using read cache: ") then
      return
    elseif string.match(...,"^%(load luc: ") then
      return
    elseif string.match(...,"^%(load cache: ") then
      return
    end
  end
  return texio_write(...)
end
io.open = function(...)
  local fname, mode = ...
  -- luatexja-ruby
  if mode == "w" and fname == tex.jobname .. ".ltjruby" then
    return io_open(output_directory .. "/" .. fname, "w")
  else
    return io_open(...)
  end
end
]==])
  initscript:close()
end

return {
  create_initialization_script = create_initialization_script
}