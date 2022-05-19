local assets = require("assets")
local lume = require("lib.lume")

return {
    credits = {
        { title = "Code",
            {"Main developer", "Nelson Lopez"}
        },

        { title = "Graphics",
            {"Designer, Artist", "Nelson Lopez"}
        },

        { title = "Music",
            {"Composer, Producer", "Nelson Lopez"}
        },

        { title = "Sound",
            {"Sound designer", "Nelson Lopez"},
            {"Recording",      "Bridge Sound"}
        },

        { title = "Open source",
            {"Internals, Logging",   "rxi"},
            {"Collisions",           "Enrique Garcia Cota"},
            {"Encoding, Map format", "Calvin Rose"},
            {"Profiling",            "Luke Perkin"}
        },

        { title = "Special Thanks",
            {"Mantarays and cyborgs", "Shakesoda"},
            {"Linux knowledge", "Nameful"},
            {"Memes", "Miqueas Martinez"},
            {"Musicality check", "Marco Trosi"},
            {"General Support", "Dad"},
        },

        { title = "Thanks for playing!" }
    },

    scale = 1,
    text = {lume.color("#c5ccb8")},
    title = {lume.color("#be955c")},
    subtitle = {lume.color("#666092")},

    draw = function (self, delta)
        local w, h = lg.getDimensions()

        self.scale = lume.lerp(self.scale, math.floor(w/250), delta*16)
        local s = math.max(1, self.scale)
        
        lg.setFont(assets.font1)
        lg.scale(s)

        local y = 0
        for _, group in ipairs(self.credits) do
            lg.setColor(self.title)
            lg.print(group.title, 0, y)
            for _, v in ipairs(group) do
                y = y + 12
                lg.setColor(self.subtitle)
                lg.print(v[1], 0, y)
            end
            
            y = y + 16
        end

    end
}

--[[
    lib/log.lua:    (MIT License, in-file) github.com/rxi/log.lua
  lib/lume.lua:   (MIT License, in-file) github.com/rxi/lume
  lib/bump.lua:   (MIT License, in-file) github.com/kikito/bump.lua
  lib/binser.lua: (MIT License, in-file) github.com/bakpakin/
  lib/profi.lua:  (MIT License, Luke Perkin, 2012)
]]