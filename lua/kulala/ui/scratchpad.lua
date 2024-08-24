local GLOBALS = require("kulala.globals")
local CONFIG = require("kulala.config")

local M = {}

local check_buffer = function()
  local curr_bufnr = vim.api.nvim_get_current_buf()

  if vim.api.nvim_buf_get_name(curr_bufnr) == GLOBALS.SCRATCHPAD_ID then
    return curr_bufnr, true
  end

  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_get_name(bufnr) == GLOBALS.SCRATCHPAD_ID then
      return bufnr, false
    end
  end

  return nil, false
end

M.toggle = function()
  local bufnr, showed = check_buffer()

  if showed then
    vim.api.nvim_buf_delete(bufnr, { force = true })
    return
  end

  if bufnr then
    vim.api.nvim_win_set_buf(0, bufnr)
    return
  end

  bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(bufnr, GLOBALS.SCRATCHPAD_ID)
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = bufnr })
  vim.api.nvim_set_option_value("filetype", "http", { buf = bufnr })

  vim.api.nvim_buf_set_lines(
    bufnr,
    0,
    -1,
    false,
    CONFIG.get().scratchpad_default_contents
  )

  vim.api.nvim_win_set_buf(0, bufnr)
end

return M
