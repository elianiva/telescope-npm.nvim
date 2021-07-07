local Path = require "plenary.path"

local M = {}

local tbl_to_arr = function(tbl, kind)
  local result = {}

  for k, v in pairs(tbl) do
    table.insert(result, { key = k, value = v, kind = kind })
  end

  return result
end

M.get_package_json = function(dir, key)
  local p = Path.new(dir .. "/package.json")
  local raw = p:readlines()
  local result = vim.fn.json_decode(raw)
  if not result[key] then
    return nil
  end
  return tbl_to_arr(result[key], key)
end

M.merge_array = function(x, y)
  if not y then return x end
  if not x then return y end

  for i = 1, #y do
    x[#x + 1] = y[i]
  end

  return x
end

return M
