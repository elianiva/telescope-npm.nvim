local entry_display = require "telescope.pickers.entry_display"
local utils = require "telescope.utils"
local finders = require "telescope.finders"
local actions = require "telescope.actions"
local action_state = require "telescope.actions.state"
local pickers = require "telescope.pickers"
local conf = require("telescope.config").values
local get_package_json =
  require("telescope._extensions.npm.utils").get_package_json

local M = {}

__TelescopeNPMJobState = __TelescopeNPMJobState or {}
M.jobs = __TelescopeNPMJobState

local execute = function(prompt_bufnr, cmd)
  local entry = action_state.get_selected_entry()
  local is_running = M.jobs[entry.name]

  if is_running then
    local term_buf = M.jobs[entry.name]
    actions.close(prompt_bufnr)

    if cmd == "new" then
      vim.cmd(term_buf .. "sb")
    elseif cmd == "vnew" then
      vim.cmd("sp")
    end

    vim.cmd(term_buf .. "b")

    vim.api.nvim_win_set_buf(0, term_buf)
    vim.bo.buflisted = false
    vim.cmd "wincmd p"

    return
  end

  actions.close(prompt_bufnr)

  vim.cmd(string.format("%s term://npm run %s", cmd, entry.name))
  M.jobs[entry.name] = vim.api.nvim_get_current_buf()
  vim.bo.buflisted = false
  vim.cmd "wincmd p"
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
    -- TODO(elianiva): find better way to detect this
    local status = M.jobs[entry.key] and { "(ON)", "TelescopeResultsField" }
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
      name = entry.key,
      value = entry.value,
      ordinal = entry.key,
      display = make_display,
    }
  end
end

M.picker = function(opts)
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
      results = get_package_json(opts.cwd, "scripts"),
      entry_maker = opts.entry_maker,
    },
    attach_mappings = function(prompt_bufnr)
      actions.select_default:replace(function()
        execute(prompt_bufnr, "tabnew")
      end)

      actions.select_horizontal:replace(function()
        execute(prompt_bufnr, "new")
      end)

      actions.select_vertical:replace(function()
        execute(prompt_bufnr, "vnew")
      end)

      return true
    end,
    sorter = conf.file_sorter(opts),
    -- previewer = previewers.cat.new(opts),
  }):find()
end

return M
