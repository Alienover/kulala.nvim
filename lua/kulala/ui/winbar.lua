local UICallbacks = require("kulala.ui.callbacks")
local CONFIG = require("kulala.config")
local M = {}

local active_view = "%%#KulalaTabSel#%s%%*"
local normal_view = "%%#KulalaTab#%s%%*"

local viewTitles = {
  [CONFIG.preset_views.HEADERS_VIEW] = "Headers [H]",
  [CONFIG.preset_views.BODY_VIEW] = "Body [B]",
  [CONFIG.preset_views.HEADERS_BODY_VIEW] = "All [A]",
}

local ns_id = vim.api.nvim_create_namespace("kulala-winbar-ns")
local default_hl = vim.api.nvim_get_hl(0, { name = "CursorLineNr" })
vim.api.nvim_set_hl(
  ns_id,
  "KulalaTabSel",
  vim.tbl_extend("force", default_hl, { bold = true, underline = true })
)
vim.api.nvim_set_hl(ns_id, "Kulalatab", { link = "CursorLineNr" })

---set local key mapping
---@param buf integer|nil Buffer
local winbar_set_key_mapping = function(buf)
  if buf and vim.api.nvim_buf_is_valid(buf) then
    local base_cmd = "<CMD>Kulala toggle_view %s<CR>"

    local keymaps = {
      { "H", string.format(base_cmd, CONFIG.preset_views.HEADERS_VIEW) },
      { "B", string.format(base_cmd, CONFIG.preset_views.BODY_VIEW) },
      { "A", string.format(base_cmd, CONFIG.preset_views.HEADERS_BODY_VIEW) },
      { "<Tab>", string.format(base_cmd, "") },
      { "H", string.format(base_cmd, "-1") },
      { "L", string.format(base_cmd, "1") },
    }

    for _, keymap in ipairs(keymaps) do
      local lhs, rhs = unpack(keymap)
      vim.keymap.set("n", lhs, rhs, { silent = true, buffer = buf })
    end
  end
end

---@param win_id integer|nil Window id
local toggle_winbar_tab = function(win_id)
  if win_id then
    local curr_view = CONFIG.get().default_view

    local value = {}
    for _, view in ipairs(CONFIG.views_order) do
      local title = string.format(
        view == curr_view and active_view or normal_view,
        viewTitles[view]
      )

      table.insert(value, title)
    end

    vim.api.nvim_set_option_value(
      "winbar",
      "  " .. table.concat(value, " | "),
      { win = win_id }
    )
    vim.api.nvim_set_hl_ns(ns_id)
  end
end

---@param window integer|nil Window id
---@param buffer integer|nil
M.update = function(window, buffer)
  if window then
    toggle_winbar_tab(window)
    winbar_set_key_mapping(buffer)
    UICallbacks.add("on_replace_buffer", function(new_buffer)
      winbar_set_key_mapping(new_buffer)
    end)
  end
end

return M
