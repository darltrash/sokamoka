local vector = require "lib.vector"

local modes = {
    keyboard = {
        times = {},
        map = {
            up = "w", down = "s", left = "a", right = "d", action = "e"
        },

        get_direction = function (self)
            local vector = vector(0, 0)

            if love.keyboard.isDown(self.map.up) then
                vector.y = -1
            end

            if love.keyboard.isDown(self.map.left) then
                vector.x = -1
            end

            if love.keyboard.isDown(self.map.down) then
                vector.y = vector.y + 1
            end

            if love.keyboard.isDown(self.map.right) then
                vector.x = vector.x + 1
            end

            return vector
        end,

        update = function (self)
            local done
            for k, v in pairs(self.map) do
                if love.keyboard.isDown(v) then
                    self.times[k] = (self.times[k] or 0) +1
                    done = true
                
                else
                    self.times[k] = 0
                    
                end
            end

            return done
        end,

        just_pressed = function (self, what)
            return self.times[what] == 1
        end,

        holding = function (self, what)
            return self.times[what] > 0
        end
    }
}
local current = modes.keyboard

return {
    update = function ()
        for k, v in pairs(modes) do
            if v:update() then
                current = v
            end
        end
    end,

    get_direction = function ()
        return current:get_direction()
    end,

    just_pressed = function (what)
        return current:just_pressed(what)
    end,

    holding = function (what)
        return current:holding(what)
    end
}
