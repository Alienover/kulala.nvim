local INLAY = require("kulala.inlay")
local GLOBALS = require("kulala.globals")
local SELECTOR = require("kulala.ui.selector")
local CONFIG = require("kulala.config")
local PARSER = require("kulala.parser")
local JUMPS = require("kulala.jumps")
local CMD = require("kulala.cmd")
local ENV = require("kulala.parser.env")
local UI = require("kulala.ui")
local DB = require("kulala.db")

local Graphql = require("kulala.graphql")
local Inspect = require("kulala.parser.inspect")
local ScriptsUtils = require("kulala.scripts.utils")

---@alias callbackFun fun(req: Request): nil
---@param opts {prioritized: boolean| nil,on_success: callbackFun, on_error: callbackFun}
local run_request = function(request, opts)
  INLAY.clear()
  request = request or PARSER.parse()
  local icon_linenr = request.show_icon_line_number
  if icon_linenr then
    INLAY:show_loading(icon_linenr)
  end

  CMD.run_parser(request, function(success, time_cost)
    if not success then
      if icon_linenr then
        INLAY:show_error(icon_linenr)
      end

      if opts.on_error then
        opts.on_error(request)
      end

      return
    else
      if icon_linenr then
        INLAY:show_done(icon_linenr, string.format("%.2fms", time_cost))
      end

      if opts.on_success then
        opts.on_success(request)
      end
    end
  end, { prioritized = opts.prioritized })
end

--- @class BuiltInCMD
--- @field desc ?string Description
--- @field alias ?string[] Differenet names for the command. Used in the compatitable stage in renaming command
--- @field handler ?fun(args: string[]): nil

--- @type table<string, BuiltInCMD>
local builtins = {
  -- INFO: request
  run = {
    desc = "Run the request under cursor",
    handler = function()
      run_request(nil, {
        on_success = function(req)
          UI.render_result(req)
        end,
      })
    end,
  },

  run_all = {
    desc = "Run all the requests in the file",
    handler = function()
      local _, doc = PARSER.get_document()

      local append = false
      for idx, node in ipairs(doc) do
        local is_last = (idx + 1) == #doc

        local request = PARSER.parse(node.start_line)

        run_request(request, {
          prioritized = false,
          on_success = function(req)
            UI.render_result(req, { append = append, highlight = is_last })
            append = append or true
          end,
        })
      end
    end,
  },

  replay = {
    desc = "Run the last request",
    handler = function()
      local last_request = DB.data.current_request
      run_request(last_request, {
        on_success = function(req)
          UI.render_result(req)
        end,
      })
    end,
  },

  -- INFO: navigate
  jump_prev = {
    desc = "Jump to the previous request",
    handler = JUMPS.jump_prev,
  },

  jump_next = {
    desc = "Jump the next request",
    handler = JUMPS.jump_next,
  },

  -- INFO: inspect/copy
  inspect = {
    desc = "Show the parsed request",
    handler = function()
      local parsed = Inspect.get_contents()
      UI.inspect(parsed)
    end,
  },

  copy = {
    desc = "Copy the request under cursor as cURL command",
    handler = function()
      local request = PARSER.parse()

      vim.fn.setreg("+", table.concat(request.cmd, " "))
      vim.notify("Copied to clipboard", vim.log.levels.INFO)
    end,
  },

  -- INFO: env/variables
  select_env = {
    alias = { "set_selected_env" },
    desc = "Choose request environment",
    handler = function(env)
      ENV.get_env()
      if env == nil then
        local has_telescope, telescope = pcall(require, "telescope")
        if has_telescope then
          telescope.extensions.kulala.select_env()
        else
          SELECTOR.select_env()
        end
        return
      end
      vim.g.kulala_selected_env = env
    end,
  },

  clear_global_variables = {
    alias = { "scripts_clear_global" },
    desc = "Clear global variable(s)",
    handler = function(...)
      ScriptsUtils.clear_global(...)
    end,
  },

  -- INFO: mis
  close = {
    desc = "Close the kulala HTTP result window",
    handler = UI.close_result,
  },
  toggle_view = {
    desc = "Switch the view between `headers`, `body`, and `headers_body`",
    handler = function()
      local default_view = CONFIG.get().default_view

      local views = {
        CONFIG.preset_views.HEADERS_VIEW,
        CONFIG.preset_views.BODY_VIEW,
        CONFIG.preset_views.HEADERS_BODY_VIEW,
      }

      local next = 1
      for idx, view in ipairs(views) do
        if view == default_view then
          next = (idx % #views) + 1
        end
      end

      CONFIG.set({ default_view = views[next] })

      UI.render_result(DB.data.current_request)
    end,
  },

  search = {
    desc = "Search all the `.http` and `.rest` in the current working directory",
    handler = function()
      local has_telescope, telescope = pcall(require, "telescope")
      if has_telescope then
        telescope.extensions.kulala.search()
      else
        SELECTOR.search()
      end
    end,
  },

  scratchpad = {
    desc = "Open a throwaway buffer for request",
    handler = UI.scratchpad,
  },

  download_graphql_schema = {
    desc = "Download schema for GraphQL",
    handler = Graphql.download_schema,
  },

  version = {
    desc = "Kulala Version",
    handler = function()
      local neovim_version = vim.fn.execute("version") or "Unknown"

      vim.notify(
        "Kulala version: "
          .. GLOBALS.VERSION
          .. "\n\n"
          .. "Neovim version: "
          .. neovim_version
      )
    end,
  },
}

local M = {}

M.setup = function(ctx)
  local options = {}

  -- INFO: Register the commands to Kulala module
  for name, cmd in pairs(builtins) do
    if cmd.handler then
      ctx[name] = cmd.handler
      table.insert(options, name)

      for _, alias in ipairs(cmd.alias or {}) do
        ctx[alias] = cmd.handler
        table.insert(options, alias)
      end
    end
  end

  -- INFO: Create `Kulala` with command completions
  vim.api.nvim_create_user_command("Kulala", function(args)
    local name = #args.fargs == 0 and "run" or args.fargs[1]

    if ctx[name] then
      ctx[name](unpack(args.fargs, 2))
    end
  end, {
    nargs = "*",
    desc = "Kulala - A minimal HTTP-client",
    complete = function(prefix, line)
      local tokens = vim.split(line, "%s+")
      local n = #tokens - 2

      if n == 0 then
        return vim.tbl_filter(function(each)
          return vim.startswith(each, prefix)
        end, options)
      end
    end,
  })
end

return M
