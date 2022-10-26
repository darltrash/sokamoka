lg = love.graphics
lm = love.math
lc = love.mouse
la = love.audio
lt = love.timer

NOOP = function() end
local input = require "input"
local log = require "lib.log"
local lume = require "lib.lume"
local profi = require "lib.profi"
local assets = require "assets"
log.usecolor = love.system.getOS() ~= "Windows"
lg.quad = lume.memoize(lg.newQuad)

State = {
    timestep = 1/30,
    lag = 1/30,
    timer = 0,
    delta = 0,
    
    STATE   = tonumber(os.getenv("SOKA_STATE")),
    PROFILE = "1" == os.getenv("SOKA_PROFILE"),
    DEBUG   = "1" == os.getenv("SOKA_DEBUG"),
    MUTED   = "1" == os.getenv("SOKA_MUTED"),
    SHOWFPS = "1" == os.getenv("SOKA_SHOW_FPS"),
    FCOMPAT = "1" == os.getenv("SOKA_FORCE_COMPAT"),
    NOVSYNC = "1" == os.getenv("SOKA_NO_VSYNC")
}

local current
local states = {
    [1] = require("game"),
    [2] = require("credits"),
    [99] = require("keything")
}

State.set_state = function (s, ...)
    log.info("Loading state '%s'", s)
    current = assert(states[s], "No state '"..s.."' found!")

    current.init = current.init or NOOP
    current.loop = current.loop or NOOP
    current.draw = current.draw or NOOP
    current.resize = current.resize or NOOP
    current:init()
end

function love.load(...)
    if State.PROFILE then
        profi:start()
        log.info("Profiling has started!")
    end

    if State.MUTED then
        la.setVolume(0)
        log.info("Game is muted!")
    end

    State.set_state(State.STATE or 1)
    
    love.window.setTitle("")
    love.window.setMode(800, 600, {
        resizable = true,
        vsync = State.NOVSYNC and 0 or 1
    })
end

function love.resize(w, h)
    current:resize(w, h)
end

function love.update(dt)
    State.delta = dt
    State.lag = State.lag + dt

    local n = 0
    while (State.lag > State.timestep and n ~= 5) do
        input.update()
        
        current:loop(State.timestep)
        
        State.lag = State.lag - State.timestep
        n = n + 1
    end

    if (n == 5) then
        State.lag = 0
        log.info("CHOKING!")
    end
    
    State.timer = State.timer + dt
end

function love.draw()
    lg.reset()
    State.debug_stack = {}

    if State.SHOWFPS then
        table.insert(
            State.debug_stack,
            ("FPS: %s"):format( lt.getFPS() )
        )
    end

    if State.DEBUG then
        table.insert(
            State.debug_stack,
            ("delta: %s"):format( lt.getDelta() * 1000 )
        )
    end

    current:draw(lt.getDelta())

    lg.reset()
    if #State.debug_stack > 0 then
        lg.scale(2)
    
        lg.setFont(assets.font1)
        for k, v in ipairs(State.debug_stack) do
            lg.setColor(0, 0, 0, 0.8)
            lg.print(v, 5, ((k-1)*10)+1)
            lg.setColor(1, 1, 1, 1)
            lg.print(v, 4, (k-1)*10)
        end
    end

    if State.PROFILE then
        profi:reset()
    end
end

function love.quit()
    if State.PROFILE then
        profi:stop()
        profi:writeReport("SOKA_PROFILE_REPORT")
        log.info("The profile info was saved as './SOKA_PROFILE_REPORT'")
    end
end
