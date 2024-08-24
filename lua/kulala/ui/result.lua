local CONFIG = require("kulala.config")
local GLOBALS = require("kulala.globals")

local buffer_opts = {
  bufhidden = "wipe",
  buftype = "nofile",
  buflisted = false,
  swapfile = false,
  modifiable = false,
  filetype = GLOBALS.UI_FILETTYP,
}

---@class ResultContext
---@field buffer ?integer
---@field window ?integer
---@field source_win ?integer

---@class HTTPResult
---@field context ?ResultContext
local M = {
  context = nil,
}

local check_context = function()
  local source_win = vim.api.nvim_get_current_win()
  if M.context == nil then
    M.context = {
      buffer = nil,
      window = nil,
      source_win = source_win,
    }
  else
    local is_same_source = source_win == M.context.source_win
    local is_context_valid = true

    if
      M.context.window == nil or not vim.api.nvim_win_is_valid(M.context.window)
    then
      is_context_valid = false
    end

    if
      M.context.buffer == nil or not vim.api.nvim_buf_is_valid(M.context.buffer)
    then
      is_context_valid = false
    end

    if not (is_same_source and is_context_valid) then
      M.clear(M.context.window, M.context.buffer)

      M.context.buffer = nil
      M.context.window = nil
    end
  end
end

local buffer_write = function(bufnr, start_line, end_line, content)
  vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })
  vim.api.nvim_buf_set_lines(bufnr, start_line, end_line, false, content)
  vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })
end

M.clear = function(window, buffer)
  window = window or M.context.window
  buffer = buffer or M.context.buffer

  if window and vim.api.nvim_win_is_valid(window) then
    vim.api.nvim_win_close(window, { force = true })
  end

  if buffer and vim.api.nvim_buf_is_valid(buffer) then
    vim.api.nvim_buf_delete(buffer, { force = true })
  end
end

M.open = function()
  check_context()

  if not (M.context.window and M.context.buffer) then
    local direction = CONFIG.get().split_direction == "vertical" and "vnew"
      or "new"
    vim.cmd("rightbelow " .. direction)

    M.context.window = vim.api.nvim_get_current_win()
    M.context.buffer = vim.api.nvim_get_current_buf()

    vim.api.nvim_buf_set_name(M.context.buffer, GLOBALS.UI_ID)

    for opt, value in pairs(buffer_opts) do
      vim.api.nvim_set_option_value(opt, value, { buf = M.context.buffer })
    end
  end

  buffer_write(M.context.buffer, 0, -1, {})
  vim.api.nvim_set_current_win(M.context.source_win)
end

--- comment
--- @param view ConfigDefaultView
--- @param contents {headers: string| nil, body: string| nil, filetype: string | nil}
--- @param opts RenderOpts
M.render = function(view, contents, opts)
  local headers, body
  local filetype = "text"

  if
    view == CONFIG.preset_views.HEADERS_VIEW
    or view == CONFIG.preset_views.HEADERS_BODY_VIEW
  then
    headers = contents.headers
  end

  if
    view == CONFIG.preset_views.BODY_VIEW
    or view == CONFIG.preset_views.HEADERS_BODY_VIEW
  then
    body = contents.body
    filetype = contents.filetype == "json" and "jsonc"
      or (contents.filetype or filetype)
  end

  if headers and body then
    local start_c, end_c, sep

    if contents.filetype == "json" then
      start_c = "/"
      end_c = "/"
      sep = "*"
    elseif contents.filetype == "html" or contents.filetype == "xml" then
      start_c = "<!"
      end_c = ">"
      sep = "-"
    end

    if start_c and end_c and sep then
      headers = table.concat({
        start_c .. string.rep(sep, 80 - #start_c),
        headers,
        string.rep(sep, 80 - #end_c) .. end_c,
      }, "\n")
    end
  end

  local content =
    table.concat({ headers or "", "", body or "" }, "\n"):gsub("^\n+", "")

  local lines = vim.split(content, "\n")

  local start_line, end_line = 0, -1

  if opts.append then
    local curr_lines =
      vim.api.nvim_buf_get_lines(M.context.buffer, 0, -1, false)
    start_line = #curr_lines + 1
  end

  buffer_write(M.context.buffer, start_line, end_line, lines)

  if opts.highlight then
    vim.schedule(function()
      if filetype ~= "text" then
        local lang = vim.treesitter.language.get_lang(filetype)
        vim.treesitter.start(M.context.buffer, lang)
      end
    end)
  end
end

return M
