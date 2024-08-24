local FS = require("kulala.utils.fs")

local M = {}

local plugin_tmp_dir = FS.get_plugin_tmp_dir()

local normalize = function(base, path)
  return vim.fs.normalize(vim.fs.joinpath(base, path))
end

M.VERSION = "3.5.0"
M.UI_ID = "kulala://ui"
M.UI_FILETTYP = "kulala-http-result"
M.SCRATCHPAD_ID = "kulala://scratchpad"
M.HEADERS_FILE = normalize(plugin_tmp_dir, "./headers.txt")
M.BODY_FILE = normalize(plugin_tmp_dir, "./body.txt")
M.COOKIES_JAR_FILE = normalize(plugin_tmp_dir, "./cookies.txt")

return M
