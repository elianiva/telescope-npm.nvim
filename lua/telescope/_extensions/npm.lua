local conf = require("telescope.config").values
local entry_display = require "telescope.pickers.entry_display"
local finders = require "telescope.finders"
local Path = require "plenary.path"
local pickers = require "telescope.pickers"
local previewers = require "telescope.previewers.term_previewer"
local actions = require "telescope.actions"
local action_state = require "telescope.actions.state"
local utils = require "telescope.utils"
local Job = require "plenary.job"
local a, fn = vim.api, vim.fn

local M = {}

-- Table to store process group IDs
__TelescopeNPMJobState = {}
M.jobs = __TelescopeNPMJobState

local tbl_to_arr = function(tbl)
  local result = {}

  for k, v in pairs(tbl) do
    table.insert(result, { name = k, script = v })
  end

  return result
end

local decorate_str = function(str)
  return "[1;34m======[[1;32m" .. str .. "[1;34m]======[0m\r\n"
end

local get_npm_scripts = function(dir)
  local p = Path.new(dir .. "/package.json")
  local raw = p:readlines()
  local result = fn.json_decode(raw)
  return tbl_to_arr(result.scripts)
end

local gen_from_npm_scripts = function(opts)
  opts = opts or {}

  local displayer = entry_display.create {
    separator = " ",
    hl_chars = {
      ["["] = "TelescopeBorder",
      ["]"] = "TelescopeBorder",
      ["("] = "TelescopeBorder",
      [")"] = "TelescopeBorder",
    },
    items = {
      { width = 20 }, -- name
      { width = 5 }, -- name
      { remaining = true }, -- raw command
    },
  }

  local function make_display(entry)
    local status = M.jobs[entry.name]
        and { "(ON)", "TelescopeResultsField" }
      or { "(OFF)", "TelescopeResultsNumber" }

    return displayer {
      { "[" .. entry.name .. "]", "TelescopeResultsField" },
      status,
      { entry.value, "TelescopeNormal" },
    }
  end

  return function(entry)
    if entry == "" then
      return nil
    end

    return {
      name = entry.name,
      value = entry.script,
      ordinal = entry.name,
      display = make_display,
      id = entry.name .. "-" .. vim.loop.cwd(),
    }
  end
end

local map = function(bufnr)
  a.nvim_buf_set_keymap(
    bufnr,
    "",
    "q",
    string.format "<CMD>q<CR>",
    { noremap = true, nowait = true, silent = true }
  )
end

local open_term = function()
  local bufnr = a.nvim_get_current_buf()
  local chan_id = a.nvim_open_term(bufnr, {})

  vim.bo.buflisted = false

  map(bufnr)

  return bufnr, chan_id
end

local main_action = function(prompt_bufnr, cmd)
  local selection = action_state.get_selected_entry()
  local is_running = M.jobs[selection.name]

  if is_running then
    local action = fn.confirm(
      "Apply action for " .. selection.name .. " (default: kill)",
      "&Kill\n&Open",
      "Kill"
    )
    if action == 1 then
      local selected = M.jobs[selection.name]
      local pid = selected.pid

      actions.close(prompt_bufnr)

      vim.cmd [[ new ]]
      vim.api.nvim_set_current_buf(selected.bufnr)
      vim.fn.search("^.\\+")

      vim.loop.kill(pid, 15) -- SIGTERM

      -- reset the job
      -- vim.api.nvim_buf_delete(selected.bufnr, { force = true })
      -- M.jobs[selection.name] = nil

      return
    end

    if action == 2 then
      local selected = M.jobs[selection.name]

      actions.close(prompt_bufnr)

      vim.cmd [[ new ]]
      vim.api.nvim_set_current_buf(selected.bufnr)
      vim.fn.search("^.\\+")

      map(selected.bufnr)

      return
    end
    return
  end

  actions.close(prompt_bufnr)

  vim.cmd(cmd)

  local bufnr, chan_id = open_term()

  local job
  job = Job:new {
    command = "npm",
    args = { "run", selection.name },
    env = {
      PATH = vim.env.PATH,
      TERM = "xterm-256color",
      FORCE_COLOR = 2,
    },
    on_start = function()
      vim.schedule(function()
        a.nvim_chan_send(chan_id, decorate_str "Running...")
        a.nvim_buf_call(bufnr, function()
          vim.fn.search("^.\\+")
        end)
        M.jobs[selection.name] = {
          pid = job.pid,
          bufnr = bufnr,
        }
      end)
    end,
    on_stdout = function(err, data)
      assert(not err, err)

      if data == "\n" or data == "" then
        data = "\r\n"
      elseif not data or data == "" then
        data = ""
      else
        data = data .. "\r\n"
      end

      vim.schedule(function()
        a.nvim_chan_send(chan_id, data)
        a.nvim_buf_call(bufnr, function()
          vim.fn.search("^.\\+")
        end)
      end)
    end,
    on_exit = function()
      vim.schedule(function()
        a.nvim_chan_send(chan_id, decorate_str "Done!")
        a.nvim_buf_call(bufnr, function()
          vim.fn.search("^.\\+")
        end)

        M.jobs[selection.name] = nil
      end)
    end,
  }
  job:start()
end

M.scripts = function(opts)
  opts = opts or {}
  opts.cwd = utils.get_lazy_default(opts.cwd, vim.loop.cwd)
  opts.entry_maker = utils.get_lazy_default(
    opts.entry_maker,
    gen_from_npm_scripts,
    opts
  )

  pickers.new(opts, {
    prompt_title = "NPM Scripts",
    finder = finders.new_table {
      results = get_npm_scripts(opts.cwd),
      entry_maker = opts.entry_maker,
    },
    attach_mappings = function(prompt_bufnr)
      actions.select_default:replace(function()
        main_action(prompt_bufnr, "tabnew")
      end)

      actions.select_horizontal:replace(function()
        main_action(prompt_bufnr, "new")
      end)

      actions.select_vertical:replace(function()
        main_action(prompt_bufnr, "vnew")
      end)

      return true
    end,
    sorter = conf.file_sorter(opts),
    -- previewer = previewers.cat.new(opts),
  }):find()
end

function TelescopeNPMCleanup()
  for _, v in pairs(M.jobs) do
    vim.loop.kill(v.pid, 15) -- SIGTERM
  end
end

vim.cmd [[
  augroup TelescopeNPM
    au!
    au VimLeavePre * call v:lua.TelescopeNPMCleanup()
  augroup END
]]

return require("telescope").register_extension {
  setup = function(config)
    return config
  end,
  exports = {
    scripts = M.scripts,
  },
}
