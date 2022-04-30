local core = require "core"
local command = require "core.command"
local keymap = require "core.keymap"
local console = require "plugins.console"

command.add(nil, {
  ["project:run"] = function()
    core.log "Running!"
    console.run {
      command = "make run",
      file_pattern = "(.*):(%d+):(%d+): (.*)$",
      cwd = ".",
      on_complete = function(retcode)
        core.log("Build complete with return code " .. retcode) 
      end
    }
  end
})

keymap.add { ["f7"] = "project:run" }
