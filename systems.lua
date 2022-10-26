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

local blank = {
    filter = function (self, ent)
        return ent.type == "Blank" or ent.type == "Bloom"
    end,

    setup = function (self, ent)
        local w, h = ent.sprite:getDimensions()
        if ent.quad then
            _, _, w, h = ent.quad:getViewport()
        end

        ent.shine = ent.Shine or 1

        ent.scale = vector(ent.collider.w / w, ent.collider.h / h)
        ent.blend = (ent.Blend or "alpha"):lower()
        if ent.Tint then
            ent.Tint[4] = ent.Alpha or 1
        end
        ent.collider = nil
    end
}

local particle = {
    filter = function (self, ent)
        return ent.type == "Particle"
    end,

    setup = function (self, ent)
        ent.life = ent.life or 0
        local s = lm.random(50, 100)/100
        ent.scale = vector(s, s)
        ent.sprite_offset = vector(1, 1)
        ent.alpha = 0.7
    end,

    process = function (self, ent, delta)
        local l = ent.life/ent.lifespan
        local d = math.abs(((l + 0.5) % 1) - 0.5) *2
        --ent.Tint[4] 
        --if ent.sus then
        --    print(ent.Tint[4])
        --end
        --ent.scale = ent.scale:lerp(ent.end_scale, l)
        ent.scale.x = d * (ent.scale_end or 1)
        ent.scale.y = d * (ent.scale_end or 1)

        ent.destroy = ent.life > ent.lifespan
        ent.life = ent.life + delta*4
        --ent.rotation = ent.life/10
    end
}

local particle_spawner = {
    filter = function (self, ent)
        return ent.type == "ParticleSpawner"
    end,

    setup = function(self, ent)
        ent.invisible = true
        ent.timer = 0
        ent.w = ent.collider.w
        ent.h = ent.collider.h
        ent.collider = nil
    end,

    particle_quads = {
        lg.quad(8, 48, 8, 8, atlas:getWidth(), atlas:getHeight()),
        lg.quad(8, 56, 8, 8, atlas:getWidth(), atlas:getHeight())
    },

    process = function (self, ent, delta, world)
        if ent.timer > ent.Frequency then
            ent.timer = ((lm.random(0, 20))/100)*ent.Frequency
            for x=1, ent.Rate do
                world:add_entity{
                    type = "Particle",
                    lifespan = ent.Lifespan, 
                    sprite = ent.sprite,
                    quad = lume.randomchoice(self.particle_quads),
                    blend = "add",
                    velocity = vector(
                        lume.vector(lm.random(0, 10), lm.random(50, 150)/100)
                    ),
                    Tint = ent.Color,
                    shine = 0.1,
                    alpha = 0.3,
                    position = ent.position + vector(
                        lm.random(ent.w), 
                        lm.random(ent.h)
                    )
                }
            end
        end
        ent.timer = ent.timer + delta
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
            
                world.player.checkpoint = ent.Door
                world.player.position = vector.copy(ent.Door.position)
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
    
    PARTICLE_QUAD = lg.quad(0, 56, 8, 8, atlas:getWidth(), atlas:getHeight()),

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

    fake_filter = function ()
        return "cross"
    end,

    cloud = function (self, ent, world, amount, range, offset)
        for x=1, amount or 3 do
            world:add_entity{
                type = "Particle",
                lifespan = 8,
                life = 4,
                sprite = ent.sprite,
                quad = self.PARTICLE_QUAD,
                sprite_offset = vector(4, 4),
                center = vector(4, 4),
                scale_end = 0.6,
                velocity = vector(
                    lume.vector(math.rad(lm.random(0, 360)), lm.random(50, 150)/50)
                ),
                position = ent.position + vector(-(range or 4) *2, 10) + (offset or vector.zero:copy())  
                + vector(
                    lm.random(range or 4), 
                    0
                ) * 3
            }
        end
    end,
    
    process = function (self, ent, delta, world)
        ent.camera_target = true

        local velocity = input.get_direction() * ent.acceleration

        if math.abs(velocity.x) > 0 then
            if lume.sign(velocity.x) ~= lume.sign(ent.velocity.x) and
                ent.acceleration > 80 then
                self:cloud(ent, world, ent.acceleration/20, 3, vector(-2, 0))
            end

            ent.acceleration = math.min(ent.acceleration+delta, 128)
            
            if velocity.x>0 then
                ent.scale.x = 1
            elseif velocity.x<0 then
                ent.scale.x = -1
            end
            
            if not ent.moving then
                ent.anim_counter = 2
            end
            
            ent.anim_counter = ent.anim_counter + delta * ent.acceleration * 0.1
            ent.moving = true
        else
            ent.acceleration = 80
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

        if input.just_pressed("down") then
            ent.velocity.y = 80
            ent.gravity_acceleration = 20
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
                assets.steps:setPosition(
                    (ent.position + world.level.position + ent.velocity * delta):unpack()
                )
                self:cloud(ent, world, 10)

            end
        else
            ent.double_jumped = false
        end
        
        if ent.collider.against_ceil then
            ent.velocity.y = 0
        end
        
        ent.velocity.x = lume.lerp(ent.velocity.x, velocity.x, delta*6)
        
        local y_offset = 0
        if (q == 2 or q == 4)  then
            if ent.past_quad ~= q then
                assets.steps:play()
                assets.steps:setPosition(
                    (ent.position + world.level.position + ent.velocity * delta):unpack()
                )
            end

            if ent.collider.against_ground then
                y_offset = -1
            end
        end
        ent.past_quad = q
        
        ent.sprite_offset.y = lume.lerp(ent.sprite_offset.y, y_offset, delta*22) 
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
            ent.on_transition = true

            world.transition.happening = true
            world.transition.callback = function ()
                local ck = ent.checkpoint
                ent.position = ck.position:copy()-- + vector(ck.collider.w / 2, ck.collider.h / 2)
                ent.past_position = ent.position:copy()
                ent.gravity_acceleration = 0
                ent.velocity = vector(0, 0)
                ent.acceleration = 64
                ent.on_transition = false

                world.level.world:move(ent, ent.position.x, ent.position.y, self.fake_filter)
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
        if (a.on_transition) then
            return "cross"
        end

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
        la.setPosition(x + world.level.x, y + world.level.y, 0)
        la.setVolume(State.MUTED and 0 or 1)
        la.setDistanceModel("linearclamped")
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
    blank, particle_spawner, particle,
    speaker, door, player, lightbulb, bullet,
    enemy, slime, gravity, movement, listener
}

return out
