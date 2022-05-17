local gr = love.graphics
local au = love.audio 
gr.setDefaultFilter("nearest", "nearest")

local a = {
    steps = au.newSource("assets/snd_steps.ogg", "static"),
    elevator = au.newSource("assets/snd_elevator.ogg", "static"),

    atlas0 = gr.newImage("assets/atl_main.png"),
    
    -- https://joebrogers.itch.io/bitpotion
    font0 = gr.newFont("assets/fnt_bitpotion.ttf"),
    
    -- https://datagoblin.itch.io/monogram
    font1 = gr.newFont("assets/fnt_monogram.ttf", 16),
    
    music = {
        fluorescent_loop = au.newSource("assets/amb_fluorescent_loop.ogg", "static"),
        fluorescent_intro = au.newSource("assets/amb_fluorescent_intro.ogg", "stream"),
        comfortably_abstract = au.newSource("assets/mus_comfortably_abstract.ogg", "stream")
    },
    
    OST = {
        ["Comfortably Abstract"] = au.newSource("OST/00 Comfortably Abstract.mp3", "stream")
    },
    
    shaders = {
        lightpass = lg.newShader("assets/shd_lightpass.glsl"),
        blur = lg.newShader("assets/shd_blur.glsl"),
        main = lg.newShader("assets/shd_main.glsl")
    },

    cache = {}
}

for _, v in pairs(a.OST) do
    v:setLooping(true)
end

return a
