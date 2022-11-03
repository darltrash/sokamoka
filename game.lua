local systems = require "systems"
local vector  = require "lib.vector"
local assets  = require "assets"
local lume    = require "lib.lume"
local binser  = require "lib.binser"
local log     = require "lib.log"
local bump    = require "lib.bump"
local input   = require "input"

local BLACK = {lume.color("#433455")}
local WHITE = {lume.color("#c5ccb8")}
local CLEAR = {1, 1, 1, 1}

local COMPAT = lg.getSystemLimits().multicanvas < 2

if COMPAT then
    log.warn("Multiple canvas unsupported! Compat mode enabled.")
end

return {
    camera = {
        scale = 2,
        real = vector.zero:copy()
    },

    transition = {
        alpha = 0,
        callback = NOOP,
        happening = false
    },

    init = function (self)
        self.map = {}
        self.level = {
            entities = {},
            tiles = {}
        }

        self:load_map("assets/map_basic0.map")
        self:load_level("Test")
    end,

    resize = function (self, w, h)
        if self.main_canvas then
            self.main_canvas:release()
            self.light_canvas:release()
        end
        self.main_canvas  = lg.newCanvas(w, h)
        self.light_canvas = lg.newCanvas(w, h)
    end,

    add_entity = function(self, ent)
        for _, sys in ipairs(systems) do
            if sys.setup and sys:filter(ent) then
                sys:setup(ent, self)
            end
        end
    
        if ent.collider and ent.position then
            self.level.world:add(ent, ent.position.x, ent.position.y, ent.collider.w, ent.collider.h)
        end
    
        table.insert(self.level.entities, ent)
    end,

    load_map = function(self, map_name)
        local raw, size = love.filesystem.read(map_name)
        if not raw then 
            log.fatal("File not readable! '%s'", map_name)
            return false
        end
        
        self.map = binser.deserialize(raw)[1]
    
        return true
    end,

    load_level = function(self, level)
        if self.level then
            if self.level.baked then
                self.level.baked:release()
                self.level.baked = nil
            end
        end

        local lev = self.map[level]
        if not lev then
            return log.fatal("Level '%s' not available!", level)
        end
        
        self.level = lev
        if lev.processed then return end
        lev.world = bump.newWorld()
        lev.lights = {}
        lev.position = vector(lev.x, lev.y)
        lev.processed = true
        
        for _, ent in ipairs(lev.entities) do
            if ent.sprite then
                if not assets.cache[ent.sprite] then
                    assets.cache[ent.sprite] = lg.newImage("assets/"..ent.sprite)
                end
                ent.sprite = assets.cache[ent.sprite]
                
                if ent.quad then
                    local tw, th = ent.sprite:getDimensions()
                    ent.quad = lg.quad(ent.quad.x, ent.quad.y, ent.quad.w, ent.quad.h, tw, th)
                end
            end   
            
            if ent.position then
                ent.position = vector.from_table(ent.position) 
            end 
        
            for _, sys in ipairs(systems) do
                if sys.setup and sys:filter(ent) then
                    sys:setup(ent, self)
                end
            end
            
            if ent.collider and ent.position then
                lev.world:add(ent, ent.position.x, ent.position.y, ent.collider.w, ent.collider.h)
            end   
        end
        
        if not lev.has_player then
            lev.has_player = true
            table.insert(lev.entities, self.player)
            
            lev.world:add(
                self.player, 
                self.player.position.x, 
                self.player.position.y, 
                self.player.collider.w, 
                self.player.collider.h
            )
        end
    end,

    loop = function (self, delta)
        if self.transition.happening then return end
        
        local _entities = {}
        for _, ent in ipairs(self.level.entities) do
            for _, sys in ipairs(systems) do
                if sys:filter(ent) then
                    if sys.process and not ent.asleep then
                        sys:process(ent, delta, self)
                    end
                    
                    if ent.destroy and sys.destroy then
                        sys:destroy(ent, self)
                    end
                end 
            end
            
            if ent.destroy then
                if ent.collider then
                    self.level.world:remove(ent)
                end
            else
                table.insert(_entities, ent)
            end
        end
        self.level.entities = _entities
    end,

    main_draw = function (self, delta)
        local w, h = lg.getWidth(), lg.getHeight()

        lg.setColor(self.level.Tint or CLEAR)

        self.camera.scale = lume.lerp(self.camera.scale, math.floor(math.min(w, h)/100), delta*16)
        local s = math.max(1, self.camera.scale)
        lg.scale(s)
        lg.translate(
            lume.round(-self.camera.real.x+(w/s/2), 1/s), 
            lume.round(-self.camera.real.y+(h/s/2), 1/s)
        )
        lg.rotate((lm.noise(State.timer*0.1)-0.5)*0.01*s)
        lg.setFont(assets.font1)
        
        local ts = (math.floor(s) > 1) and 0.5 or 1
        
        if (not COMPAT) then
            assets.shaders.main:send("threshold", 1)
        end
        lg.draw(self.level.baked)
    
        local alpha = lume.clamp(State.lag / State.timestep, 0, 1)
        
        if self.transition.happening then alpha = 1 end
        State.alpha = alpha
        
        for _, ent in ipairs(self.level.entities) do
            if vector.is_vector(ent.position) then
                local lerped_position = (ent.past_position or ent.position):lerp(ent.position, alpha)
                
                if State.DEBUG and ent.collider then
                    lg.rectangle("fill", lerped_position.x, lerped_position.y, ent.collider.w, ent.collider.h)
                end
                
                if ent.camera_target then
                    self.camera.real = self.camera.real:lerp(lerped_position, delta*4)
                end
                
                if not COMPAT then
                    assets.shaders.main:send("threshold", 1)
                end
                lg.setBlendMode("alpha")
                if ent.interactable and ent.position and self.player then
                    local a = ent.interaction_area or 32
                    local off = (ent.indicator_offset or vector(0, 0, 0))
                    local dest = 0
                    
                    if (ent.position + off):dist(self.player.position) < a then
                        dest = 1
                        
                        ent.interacting = input.just_pressed("down")
                    end
                    
                    ent.interaction_alpha = lume.lerp(
                        ent.interaction_alpha or 0, 
                        dest, delta*3
                    )
                    local m = ent.interaction_alpha or 0 
                    
                    local p = ent.position + off
                    p.x = p.x-lm.noise(State.timer)
                    p.y = p.y-(10*m)-lm.noise(0, State.timer) 
                    
                    p = p:round(1/s)
                    
                    lg.setColor(BLACK[1], BLACK[2], BLACK[3], m)
                    lg.rectangle("fill", p.x, p.y, 8, 8)
                    
                    lg.setColor(WHITE[1], WHITE[2], WHITE[3], m)
                    lg.setLineWidth(0.5)
                    lg.rectangle("line", p.x+1, p.y+1, 6, 6)
                    lg.polygon("fill", p.x+2, p.y+2, p.x+6, p.y+2, p.x+4, p.y+6)
                end
                
                if not ent.invisible then 
                    -- TODO: Fix vector.zero! apparently it doesnt stay as zero lol
                
                    local color = ent.Tint or self.level.Tint or CLEAR
                    lg.setColor(color[1], color[2], color[3], (ent.alpha or 1) * color[4])

                    if ent.sprite then
                        local x, y = (lerped_position + (ent.sprite_offset or vector(0, 0, 0))):unpack()
                        local sx, sy = (ent.scale  or vector.one ):unpack()
                        local cx, cy = (ent.center or vector.zero):unpack()
                        local r = ent.rotation or 0
                        
                        if ent.shine and not COMPAT then
                            lg.setBlendMode("alpha")
                            assets.shaders.main:send("threshold", ent.shine)

                            if ent.quad then
                                lg.draw(ent.sprite, ent.quad, x+cx, y+cy, r, sx, sy, cx, cy)
                            else
                                lg.draw(ent.sprite, x+cx, y+cy, r, sx, sy, cx, cy)
                            end
                        end

                        if not COMPAT then
                            assets.shaders.main:send("threshold", 1)
                        end

                        local s = ent.shear or 0
                        lg.shear(s, 0)
                        x = x - s

                        lg.setBlendMode(ent.blend or "alpha", ent.blend=="multiply" and "premultiplied" or nil)
                        if ent.quad then
                            lg.draw(ent.sprite, ent.quad, x+cx, y+cy, r, sx, sy, cx, cy)
                        else
                            lg.draw(ent.sprite, x+cx, y+cy, r, sx, sy, cx, cy)
                        end

                        lg.shear(-s, 0)
                    end
                end
            end    
        end

        if self.level.Name then
            lg.setColor(WHITE)
            lg.setBlendMode("alpha")
            lg.print(self.level.Name, 4, -3, 0, ts, ts)
        end
    end,

    draw = function (self, delta)
        local w, h = lg.getWidth(), lg.getHeight()

        if not self.level.baked then
            self.level.baked = lg.newCanvas(
                self.level.width, self.level.height
            )

            lg.setCanvas(self.level.baked)
            for _, til in ipairs(self.level.tiles) do
                local tileset = self.level.tiles.tileset
                if not assets.cache[tileset] then
                    assets.cache[tileset] = lg.newImage("assets/"..tileset)
                end
                tileset = assets.cache[tileset]
            
                local tw, th = tileset:getDimensions()
                local quad = lg.quad(til.sx, til.sy, til.s, til.s, tw, th)
                
                lg.draw(tileset, quad, til.x, til.y)
            end
            lg.setCanvas()

            self.level.baked:setFilter("nearest", "nearest")
        end

        do  
            lg.push("all")
            if COMPAT then
                lg.setCanvas(self.main_canvas)
                    lg.clear()
                    self:main_draw(delta)

            else
                lg.setCanvas(self.main_canvas, self.light_canvas)
                    lg.setShader(assets.shaders.main)
                    lg.clear()

                    self:main_draw(delta)
            end
            lg.pop()

            lg.setColor(CLEAR)
            lg.draw(self.main_canvas)

            if not COMPAT then
                lg.setShader(assets.shaders.blur)
                lg.setBlendMode("add")
                lg.setColor(1, 1, 1, 1/4/3)
                for i = 1, 4 do
                    local x, y = lume.vector((i/4)*math.pi, 1.5)
                    assets.shaders.blur:send("direction_mip", {x, y, 0})
                    lg.draw(self.light_canvas)
                end
                lg.setShader()
            end

        end

        do
            local s = math.max(1, self.camera.scale)

            lg.setBlendMode("alpha")
            lg.push()
            lg.scale(s)
                self.transition.alpha = self.transition.alpha + 
                (self.transition.happening and delta or -delta) * 3
                
                if self.transition.alpha > 1.3 then
                    self.transition.happening = false
                    self.transition.callback()
                end
                self.transition.alpha = lume.clamp(self.transition.alpha, 0, 1.3)
                
                lg.setColor(BLACK)
                
                local ox, oy = (w/s), (h/s)
                if self.transition.alpha > 0 then
                    for x = 0, math.ceil(w/s/16) do
                        for y = 0, math.ceil(h/s/16) do
                            local rs = self.transition.alpha*13
                            local s = 3+(self.transition.alpha*5)
                        
                            lg.circle("fill", ox-(x*16), oy-(y*16), rs, s)
                            lg.circle("line", ox-(x*16), oy-(y*16), rs, s)
                            
                        end
                    end 
                end
            
            lg.pop()
            
            if self.transition.alpha > 1 then
                lg.rectangle("fill", 0, 0, w, h)
            end
            
            if State.DEBUG then
                table.insert(
                    State.debug_stack,
                    ("[ceil: %s, ground: %s, wall: %s]"):format(
                        self.player.collider.against_ceil,
                        self.player.collider.against_ground,
                        self.player.collider.against_wall
                    )
                )

                table.insert(
                    State.debug_stack,
                    ("[acceleration: %s]"):format(
                        self.player.gravity_acceleration
                    )
                )

                table.insert(
                    State.debug_stack,
                    ("[position: %s]"):format(
                        self.player.position
                    )
                )

                table.insert(
                    State.debug_stack,
                    ("[velocity: %s]"):format(
                        self.player.velocity
                    )
                )
            end
        end
    end
}
