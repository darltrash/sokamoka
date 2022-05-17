#!/usr/bin/env luajit

local json   = require("dkjson")
local binser = require("lib.binser")

local function readFile(name)
    local file = io.open(name, "rb")
    local data = file:read("*a")
    file:close()

    return data
end

local function writeFile(name, contents)
    local file = io.open(name, "w+")
    file:write(contents)
    file:close()
end

local function hex(hex, a)
    hex = hex:gsub("#","")
    return {
        tonumber("0x"..hex:sub(1,2))/255,
        tonumber("0x"..hex:sub(3,4))/255,
        tonumber("0x"..hex:sub(5,6))/255,
        (a or 255)/255
    }
end

for line in io.popen("find assets/*.ldtk"):lines() do
    print("> Compiling '"..line.."'")
    local data = json.decode(readFile(line))

    local world = {}
    
    local atlas = {}
    for _, tileset in ipairs(data.defs.tilesets) do
        atlas[tileset.uid] = tileset.relPath
    end

    local entity_references = {}
    for _, raw_level in ipairs(data.levels) do
        local level = {
            bg = hex(raw_level.__bgColor),
            width  = raw_level.pxWid,
            height = raw_level.pxHei,
            
            tiles = {},
            entities = {},
            
            x = raw_level.worldX,
            y = raw_level.worldY
        }
        for _, field in ipairs(raw_level.fieldInstances) do
            if field.__type == "Color" then
                level[field.__identifier] = hex(field.__value)
            else
                level[field.__identifier] = field.__value
            end
        end

        for _, layer in ipairs(raw_level.layerInstances) do
            if layer.__type == "Tiles" then
                for k, tile in ipairs(layer.gridTiles) do
                    table.insert(level.tiles, {
                        x  = tile.px [1],
                        y  = tile.px [2],
                        sx = tile.src[1],
                        sy = tile.src[2],

                        s = layer.__gridSize
                    })
                    
                end
                level.tiles.tileset = layer.__tilesetRelPath

            elseif layer.__type == "Entities" then
                for _, ent in ipairs(layer.entityInstances) do
                    local fields = {}
                    local c

                    for _, field in ipairs(ent.fieldInstances) do
                        if field.__type == "EntityRef" then
                            fields.in_level = raw_level.identifier
                        
                            if field.__value then
                                local d = entity_references[field.__value.entityIid]
                                fields[field.__identifier] = d
                                if d then
                                    d[field.__identifier] = fields
                                end
                            end
                        elseif field.__type == "Color" then
                            fields[field.__identifier] = hex(field.__value)
                        else
                            fields[field.__identifier] = field.__value
                        end
                        
                        c = true
                    end

                    if not c then 
                        fields._nothing_ = true
                    end
                    
                    if ent.__tile then
                        fields.sprite = atlas[ent.__tile.tilesetUid]
                        fields.quad = {
                            x = ent.__tile.x,
                            y = ent.__tile.y,
                            w = ent.__tile.w,
                            h = ent.__tile.h
                        }
                    end
                    
                    fields.type = ent.__identifier
                    fields.position = {
                        x = ent.px[1],
                        y = ent.px[2]
                    }
                    fields.collider = {
                        w = ent.width, h = ent.height
                    }

                    entity_references[ent.iid] = fields

                    table.insert(level.entities, fields)
                end

            end
        end
        
        --table.insert(world, level)
        world[raw_level.identifier] = level
    end

    writeFile(line:sub(0, #line-5)..".map", binser.serialize(world))
end
