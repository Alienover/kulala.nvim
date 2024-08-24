local GLOBALS = require("kulala.globals")
local Fs = require("kulala.utils.fs")
local EXT_PROCESSING = require("kulala.external_processing")
local INT_PROCESSING = require("kulala.internal_processing")
local Api = require("kulala.api")
local Scripts = require("kulala.scripts")

local M = {}

---@alias CMDTaskCompleted {code:integer, time_cost: number}
---
---@class CMDTask
---@field cmd table<string>
---@field on_stderr ( fun(string): nil ) | nil
---@field on_exit ( fun(out: CMDTaskCompleted): nil ) | nil

local TaskQueue = {
  ---@type CMDTask[]
  queue = {},
  running = false,
}

---@param task CMDTask
function TaskQueue:push(task)
  table.insert(self.queue, task)

  vim.schedule(function()
    self:run()
  end)
end

---@return CMDTask
function TaskQueue:pop()
  return table.remove(self.queue, 1)
end

---@param task CMDTask
function TaskQueue:prioritize(task)
  self.queue = { task }
  self.running = false

  self:run()
end

function TaskQueue:run()
  if self.running then
    return
  end

  local next = TaskQueue:pop()

  if next then
    self.running = true
    local start = vim.uv.hrtime()

    vim.fn.jobstart(next.cmd, {
      on_stderr = next.on_stderr,
      on_exit = function(_, code)
        self.running = false

        if next.on_exit then
          next.on_exit({
            code = code,
            time_cost = (vim.uv.hrtime() - start) / 1e6,
          })
        end

        if code == 0 then
          vim.schedule(function()
            self:run()
          end)
        end
      end,
    })
  end
end

--- Set the output file before executing the cURL command
---@param result Request
---@return string[]|nil
local function get_request_cmd(result)
  if result.url == "" then
    vim.notify("Invalid URL to cURL request", vim.log.levels.ERROR)
    return nil
  end

  local cmd = vim.tbl_extend("force", {}, result.cmd)

  return vim.list_extend(
    cmd,
    { "-D", GLOBALS.HEADERS_FILE, "-o", GLOBALS.BODY_FILE }
  )
end

---Runs the parser and returns the result
---@param request Request
---@param callback fun(success: boolean, time_cost: number): nil
---@param opts { prioritized: boolean| nil}
M.run_parser = function(request, callback, opts)
  opts = vim.tbl_extend("force", { prioritized = true }, opts or {})

  local cmd = get_request_cmd(request)
  if not cmd then
    callback(false, 0)
    return
  end

  local on_stderr = function(_, datalist)
    if callback then
      if #datalist > 0 and #datalist[1] > 0 then
        vim.notify(vim.inspect(datalist), vim.log.levels.ERROR)
      end
    end
  end

  ---@param out CMDTaskCompleted
  local on_exit = function(out)
    local success = out.code == 0
    if success then
      local body = Fs.read_file(GLOBALS.BODY_FILE)
      for _, metadata in ipairs(request.metadata) do
        if metadata then
          if metadata.name == "name" then
            INT_PROCESSING.set_env_for_named_request(metadata.value, body)
          elseif metadata.name == "env-json-key" then
            INT_PROCESSING.env_json_key(metadata.value, body)
          elseif metadata.name == "env-header-key" then
            INT_PROCESSING.env_header_key(metadata.value)
          elseif metadata.name == "stdin-cmd" then
            EXT_PROCESSING.stdin_cmd(metadata.value, body)
          elseif metadata.name == "env-stdin-cmd" then
            EXT_PROCESSING.env_stdin_cmd(metadata.value, body)
          end
        end
      end
      INT_PROCESSING.redirect_response_body_to_file(
        request.redirect_response_body_to_files
      )
      Scripts.javascript.run("post_request", request.scripts.post_request)
      Api.trigger("after_request")
    end
    Fs.delete_request_scripts_files()
    if callback then
      callback(success, out.time_cost)
    end
  end

  local task = {
    cmd = cmd,
    on_exit = on_exit,
    on_stderr = on_stderr,
  }

  if opts.prioritized then
    TaskQueue:prioritize(task)
  else
    TaskQueue:push(task)
  end
end

return M
