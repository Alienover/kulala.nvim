local CONFIG = require("kulala.config")
local GLOBALS = require("kulala.globals")
local BuiltIns = require("kulala.builtins")

local M = {}

M.setup = function(config)
  CONFIG.setup(config)

  BuiltIns.setup(M)

  -- Create an autocmd to delete the buffer when the window is closed
  -- This is necessary to prevent the buffer from being left behind
  -- when the window is closed
  vim.api.nvim_create_autocmd("WinClosed", {
    pattern = { GLOBALS.UI_FILETTYP },
    group = vim.api.nvim_create_augroup(
      "kulala_window_closed",
      { clear = true }
    ),
    callback = M.close,
  })
end

return M
