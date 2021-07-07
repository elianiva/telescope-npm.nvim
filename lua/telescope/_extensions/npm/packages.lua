local entry_display = require "telescope.pickers.entry_display"
local utils = require "telescope.utils"
local finders = require "telescope.finders"
local action_state = require "telescope.actions.state"
local pickers = require "telescope.pickers"
local conf = require("telescope.config").values
local get_package_json =
  require("telescope._extensions.npm.utils").get_package_json
local merge_array = require("telescope._extensions.npm.utils").merge_array

local M = {}

local gen_from_npm_packages = function(opts)
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
      { width = 32 }, -- package name
      { width = 14 }, -- version
      { remaining = true }, -- kind
    },
  }

  local function make_display(entry)
    return displayer {
      { "[" .. entry.name .. "]", "TelescopeResultsField" },
      { "(" .. entry.version .. ")", "TelescopeResultsNumber" },
      { entry.type, "TelescopeBorder" },
    }
  end

  return function(entry)
    if entry == "" then
      return nil
    end

    return {
      name = entry.key,
      value = entry.key,
      type = entry.kind,
      version = entry.value,
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
    gen_from_npm_packages,
    opts
  )

  opts.new_finder = opts.new_finder
    or function()
      return finders.new_table {
        results = merge_array(
          get_package_json(opts.cwd, "dependencies"),
          get_package_json(opts.cwd, "devDependencies")
        ),
        entry_maker = opts.entry_maker,
      }
    end

  pickers.new(opts, {
    prompt_title = "NPM Packages",
    finder = opts.new_finder(),
    attach_mappings = function(prompt_bufnr, map)
      map("i", "<CR>", function() end) -- noop
      map("i", "<C-v>", function() end) -- noop
      map("i", "<C-x>", function() end) -- noop

      map("i", "<C-d>", function()
        local picker = action_state.get_current_picker(prompt_bufnr)
        local entry = action_state.get_selected_entry()
        vim.cmd("!npm uninstall " .. entry.name)
        picker:refresh(opts.new_finder(), { reset_prompt = true })
      end)

      map("i", "<C-i>", function()
        local picker = action_state.get_current_picker(prompt_bufnr)
        local line = action_state.get_current_line()
        vim.cmd("!npm install " .. line)
        picker:refresh(
          opts.new_finder(),
          { reset_prompt = true, new_prefix = ">" }
        )
      end)

      return true
    end,
    sorter = conf.file_sorter(opts),
    -- previewer = previewers.cat.new(opts),
  }):find()
end

return M
