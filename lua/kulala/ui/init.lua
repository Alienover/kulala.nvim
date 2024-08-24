local CONFIG = require("kulala.config")
local FORMATTER = require("kulala.formatter")
local FS = require("kulala.utils.fs")
local GLOBALS = require("kulala.globals")
local INT_PROCESSING = require("kulala.internal_processing")
local ResultUI = require("kulala.ui.result")
local ScratchPad = require("kulala.ui.scratchpad")

local M = {}

local contents = setmetatable({
  __contents = {
    body = GLOBALS.BODY_FILE,
    headers = GLOBALS.HEADERS_FILE,
  },
}, {
  __index = function(ctx, key)
    local filepath = ctx.__contents[key]

    return function(formatter)
      if not filepath or not FS.file_exists(filepath) then
        vim.notify(string.format("No %s found", key), vim.log.levels.ERROR)

        return nil
      end

      local content = FS.read_file(filepath)

      if formatter then
        return FORMATTER.format(formatter, content)
      end

      return content
    end
  end,
})

--- @class RenderOpts
--- @field append boolean | nil Render the HTTP result after the current content
--- @field highlight boolean |nil Whether call `vim.treesitter` to highlight the content
---
---@param request Request
---@param opts RenderOpts | nil
---@return nil
M.render_result = function(request, opts)
  opts =
    vim.tbl_extend("force", { append = false, highlight = true }, opts or {})

  local contenttype = INT_PROCESSING.get_config_contenttype()

  if not opts.append then
    ResultUI.open()
  end

  ResultUI.render(CONFIG.get().default_view, {
    headers = contents.headers(function(content)
      local headers = content:gsub("\r\n", "\n"):gsub("\n+$", "")
      return table.concat({
        string.format("%s %s", request.method, request.url),
        "",
        headers,
      }, "\n")
    end),
    body = contents.body(contenttype.formatter),
    filetype = contenttype.ft,
  }, opts)
end

M.close_result = function()
  ResultUI.clear()
end

M.scratchpad = ScratchPad.toggle

---@param content string[]
M.inspect = function(content)
  -- Create a new buffer
  local buf = vim.api.nvim_create_buf(false, true)

  -- Set the content of the buffer
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, content)

  -- Set the filetype to http to enable syntax highlighting
  vim.bo[buf].filetype = "http"

  -- Get the total dimensions of the editor
  local total_width = vim.o.columns
  local total_height = vim.o.lines

  -- Calculate the content dimensions
  local content_width = 0
  for _, line in ipairs(content) do
    if #line > content_width then
      content_width = #line
    end
  end
  local content_height = #content

  -- Ensure the window doesn't exceed 80% of the total size
  local win_width = math.min(content_width, math.floor(total_width * 0.8))
  local win_height = math.min(content_height, math.floor(total_height * 0.8))

  -- Calculate the window position to center it
  local row = math.floor((total_height - win_height) / 2)
  local col = math.floor((total_width - win_width) / 2)

  -- Define the floating window configuration
  local win_config = {
    relative = "editor",
    width = win_width,
    height = win_height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
  }

  -- Create the floating window with the buffer
  local win = vim.api.nvim_open_win(buf, true, win_config)

  -- Set up an autocommand to close the floating window on any buffer leave
  vim.api.nvim_create_autocmd("BufLeave", {
    buffer = buf,
    once = true,
    callback = function()
      vim.api.nvim_win_close(win, true)
    end,
  })

  -- Map the 'q' key to close the window
  vim.api.nvim_buf_set_keymap(buf, "n", "q", "", {
    noremap = true,
    silent = true,
    callback = function()
      vim.api.nvim_win_close(win, true)
    end,
  })
end

return M
