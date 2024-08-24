local Fs = require("kulala.utils.fs")
local M = {}

M.clear_global = function(...)
  local globals_fp = Fs.get_global_scripts_variables_file_path()
  local globals = Fs.file_exists(globals_fp)
      and vim.fn.json_decode(Fs.read_file(globals_fp))
    or {}

  local keys_length = select("#", ...)

  if keys_length > 0 then
    local keys = {}

    for i = 1, select("#", ...) do
      local item = select(i, ...)
      table.insert(keys, item)
    end

    for _, key in ipairs(vim.iter(keys):flatten():totable()) do
      globals[key] = nil
    end
  else
    globals = {}
  end

  Fs.write_file(globals_fp, vim.fn.json_encode(globals))
end

return M
