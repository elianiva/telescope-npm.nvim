local M = {}

return require("telescope").register_extension {
  setup = function(config)
    return config
  end,
  exports = {
    scripts = require("telescope._extensions.npm.npm_scripts").picker,
    packages = require("telescope._extensions.npm.packages").picker,
  },
}
