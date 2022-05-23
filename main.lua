NOOP = function() end
local input = require "input"
local log = require "lib.log"
local lume = require "lib.lume"
local profi = require "lib.profi"
log.usecolor = love.system.getOS() ~= "Windows"

lg = love.graphics
lg.quad = lume.memoize(lg.newQuad)
lm = love.math
lc = love.mouse
la = love.audio
lt = love.timer

State = {
    timestep = 1/30,
    lag = 1/30,
    timer = 0,
    delta = 0,
    
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
    [2] = require("credits")
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

    State.set_state(1)
    
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
    current:draw(lt.getDelta())

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
