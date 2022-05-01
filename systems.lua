local lume = require "lib.lume"
local vector = require "lib.vector"
local input = require "input"
local assets = require "assets"

local atlas = assets.atlas0

local lightbulb = {
    filter = function (self, ent)
        return ent.type == "LightBulb"
    end,
    
    setup = function (self, ent, world)
        ent.interactable = true
        
        ent.Color[4] = 0.25
        table.insert(world.level.lights, {
            x = ent.position.x+(ent.collider.w/2),
            y = ent.position.y+(ent.collider.h/2),
            area = ent.Area or 30, 
            color = ent.Color or {1, 1, 1, 1} 
        })
        
        ent.collider = nil
    end,
    
    process = function (self, ent)
        ent.destroy = true
    end
}

local speaker = {
    filter = function(self, ent)
        return ent.type == "Speaker" and 
            assets.music[ent.Stream] and 
            ent.position
    end,

    setup = function(self, ent)
        local snd = assets.music[ent.Stream]
        ent.current = ent.Share and snd or snd:clone()
        ent.current:setVolume(ent.Volume)
        ent.current:setLooping(not ent.Stops)
        ent.current:play()
        ent.collider = nil
    end,
    
    process = function(self, ent, _, world)
        local x, y = ent.position:unpack()
        ent.current:setPosition(x + world.level.x, y + world.level.y)
        ent.current:setAttenuationDistances(2, ent.Area)
        
        self.destroy = ent.Stops and not ent.current:isPlaying()
    end
}

local door = {
    filter = function(self, ent)
        return ent.type == "Door" and ent.Door
    end,
    
    setup = function(self, ent)
        ent.collider = nil
        ent.velocity = nil
        ent.interactable = true
        ent.indicator_offset = vector(4, 0)
    end,
    
    process = function(self, ent, delta, world)
        if ent.interacting then
            world.transition.happening = true
            world.transition.callback = function()
                local snd = assets[ent.Sound]
                if snd then
                    snd:stop()
                    snd:setAttenuationDistances(0, math.huge)
                    snd:setVolume(0.3)
                    snd:setPosition(0, 0)
                    snd:play()
                end
            
                world.player.position = vector.from_table(ent.Door.position)
                world.camera.real = world.player.position:copy()
                world:load_level(ent.Door.in_level)
                
            end
        end
    end
}

local slime = {
    filter = function(self, ent)
        return ent.type == "Slime"
    end,
    
    setup = function(self, ent)
        ent.is_enemy = true
        ent.scale = vector(1, 1)
        ent.sprite_offset = vector(0, 0)
        ent.sprite_center = vector(8, 16)
        ent.velocity = vector(0, 0)
        ent.direction = 1
        ent.gravity_acceleration = 0
    end,
    
    process = function(self, ent)
        local sin = 0.7+((1+math.sin(State.timer*4))/6)
        ent.scale.y = sin
        ent.sprite_offset.y = (1-sin) * 16
        
        -- The AI for those is the sokamoka equivalent
        -- of a goomba. :P
        if ent.collider.against_wall then
            ent.direction = -ent.direction
        end
        
        ent.scale.x = ent.direction
        ent.velocity.x = sin * ent.direction * 16
        ent.sprite_offset.x = ent.direction < 0 and 16 or 0
    end
}

local enemy = {
    filter = function(self, ent)
        return ent.is_enemy and 
            vector.is_vector(ent.position)
    end,
    
    process = function(self, ent)
    end
}

local bullet = {
    filter = function(self, ent)
        return ent.type == "Bullet"
    end,
    
    setup = function(self, ent) 
        ent.gravity_acceleration = 1
        ent.sprite = atlas
        
        if ent.horizontal then
            ent.collider = { w = 1, h = 4 }
            ent.quad = lg.quad(3*8, 8, 1, 4, atlas:getWidth(), atlas:getHeight())
            return
        end
        
        ent.collider = { w = 4, h = 1 }
        ent.quad = lg.quad(3*8, 8, 4, 1, atlas:getWidth(), atlas:getHeight())
    end,
    
    process = function(self, ent)
        ent.destroy = ent.detonated
        
        if ent.collider.against_wall or 
            ent.collider.against_ceil or 
            ent.collider.against_ground then
           
            ent.detonated = true
        end
    end
}

local player = {
    filter = function (self, ent)
        return ent.type == "Player"
    end,
    
    ANI_MAIN = {
        lg.quad(48, 00, 16, 16, atlas:getWidth(), atlas:getHeight()),
        lg.quad(48, 16, 16, 16, atlas:getWidth(), atlas:getHeight()),
        lg.quad(48, 32, 16, 16, atlas:getWidth(), atlas:getHeight()),
        lg.quad(48, 48, 16, 16, atlas:getWidth(), atlas:getHeight()),
        lg.quad(48, 64, 16, 16, atlas:getWidth(), atlas:getHeight())
    },
    
    setup = function (self, ent, world)
        ent.quad = self.ANI_MAIN[1]
        ent.sprite = atlas
        ent.acceleration = 64
        ent.velocity = vector.zero:copy()
        ent.scale = vector.one:copy()
        ent.center = vector(8, 16)
        ent.gravity_acceleration = 0
        
        ent.collider.w = 8
        ent.sprite_offset = vector(-4, 0)
        ent.anim_counter = 0
        world.player = ent
        world.level.has_player = true
        ent.is_listener = true
        ent.is_player = true

        ent.checkpoint = {
            position = ent.position,
            collider = ent.collider
        }
    end,
    
    process = function (self, ent, delta, world)
        ent.camera_target = true
        
        local velocity = input.get_direction() * ent.acceleration
        
        if math.abs(velocity.x) > 0 then
            ent.acceleration = math.min(ent.acceleration+delta, 128)
            
            if velocity.x>0 then
                ent.scale.x = 1
            elseif velocity.x<0 then
                ent.scale.x = -1
            end
            
            if not ent.moving then
                ent.anim_counter = 2
            end
            
            ent.anim_counter = ent.anim_counter + delta * 5
            ent.moving = true
        else
            ent.acceleration = 64
            ent.anim_counter = 0
            ent.moving = false
        end
        
        local q = math.floor(ent.anim_counter % 4) +1
        ent.quad = self.ANI_MAIN[q]
        
        if ent.collider.against_ground then
            ent.velocity.y = 0
        end
        
        if input.holding("up") and ent.collider.against_ground then
            ent.velocity.y = -86
        end
        
        if not ent.collider.against_ground then
            if ent.velocity.y > 0 then
                ent.quad = self.ANI_MAIN[5]
                q = 5
            else
                ent.quad = self.ANI_MAIN[2]
                q = 2
            end
            
            if input.just_pressed("up") and not ent.double_jumped then
                ent.velocity.y = -86
                ent.gravity_acceleration = 0
            
                ent.double_jumped = true
                
                assets.steps:play()
                assets.steps:setPosition((ent.position + world.level.position + ent.velocity * delta):unpack())
            end
        else
            ent.double_jumped = false
        end
        
        if ent.collider.against_ceil then
            ent.velocity.y = 0
        end
        
        ent.velocity.x = lume.lerp(ent.velocity.x, velocity.x, delta*6)
        
        if (q == 2 or q == 4) and self.past_quad ~= q then
            assets.steps:play()
            assets.steps:setPosition((ent.position + world.level.position + ent.velocity * delta):unpack())
        end
        self.past_quad = q
        
        --if lc.isDown(1) then
        --    local window = vector(lg.getDimensions()) / world.camera.scale / 2
        --    local mouse = vector(lc.getX(), lc.getY()) / world.camera.scale
        --    
        --    local center = (ent.past_position or ent.position):lerp(ent.position, State.alpha) + vector(4, 8)
        --    mouse = mouse + world.camera.real - window
        --    local direction = (mouse - center) * 4
        --    
        --    world:add_entity({
        --        type = "Bullet", 
        --        velocity = direction,
        --        position = center,
        --    })
        --end

        local out_of_bounds =
            ent.position.x > world.level.width or
            ent.position.x < 0 or
            ent.position.y > world.level.height or
            ent.position.y < 0

        if out_of_bounds then
            world.transition.happening = true
            world.transition.callback = function ()
                local ck = ent.checkpoint
                ent.position = ck.position:copy()-- + vector(ck.collider.w / 2, ck.collider.h / 2)
                ent.past_position = ent.position:copy()
                print(ent.position, ck.position)
                ent.gravity_acceleration = 0
                ent.velocity = vector(0, 0)
                ent.acceleration = 64
            end
            
        end
    end
}

local movement = {
    filter = function (self, ent)
        return vector.is_vector(ent.position) and 
               vector.is_vector(ent.velocity)
    end,

    collision_filter = function(a, b)
        if (a.type == "Player" and b.type == "Checkpoint") then
            a.checkpoint = b
            return "cross"
        end

        if (b.is_enemy or b.type == "Player" or b.is_bullet) then
            return "cross"
        end

        if b.Trespass and b.position.y < (a.position.y+a.collider.h) then
            return "cross"
        end
        
        return "slide"
    end,

    process = function (self, ent, delta, world)
        ent.past_position = ent.position
        local _position = ent.position + ent.velocity * delta
        
        if ent.collider then
            local x, y = world.level.world:move(ent, _position.x, _position.y, self.collision_filter)
            
            local diffx = lume.bsign(x - _position.x)
            local diffy = lume.bsign(y - _position.y)
            
            _position.x = x
            _position.y = y
            
            ent.collider.against_wall = diffx ~= 0
            ent.collider.against_ground = diffy == -1
            ent.collider.against_ceil = diffy == 1
        end
        
        ent.position = _position
    end
}

local listener = {
    filter = function (self, ent)
        return ent.is_listener and ent.position and ent.past_position
    end,
    
    process = function (self, ent, _, world)
        local x, y = ent.position:unpack()
        la.setPosition(x + world.level.x, y + world.level.y)
        la.setVolume(2)
        --la.setVelocity((ent.position - ent.past_position):unpack())
    end
}

local gravity = {
    filter = function (self, ent)
        return vector.is_vector(ent.velocity) 
            and ent.gravity_acceleration
            and ent.collider
    end,
    
    process = function (self, ent, delta)
        if ent.collider.against_ground then
            ent.gravity_acceleration = 0
        end
        ent.gravity_acceleration = ent.gravity_acceleration + delta * 30
        ent.velocity.y = ent.velocity.y + ent.gravity_acceleration
    end
}

local out = {
    speaker, door, player, lightbulb, bullet,
    enemy, slime, gravity, movement, listener
}

return out
