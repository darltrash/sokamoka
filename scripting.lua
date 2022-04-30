local status, json = pcall(require, "dkjson")
if not status then
    error("'dkjson' is not installed!\ntry:   sudo luarocks install dkjson")
end

local instruction_types = {
    SAY = 0, ASK = 1, GOTO = 2, CMD = 3
}

local parse = function (code)
    local instructions = {}
    local questions = {}
    local labels = {}

    local cLineText, cLineNumber = "", 1
    local expandable

    local assert = function (condt, text)
        if condt then return end
        print(
            ("| %s | %s\n\27[35mError: %s\27[0m"):format (
                cLineNumber, cLineText, text
            )
        )
    end

    local parsers = {
        ["-"] = function (line)
            expandable = true
            table.insert(instructions, {
                type = instruction_types.SAY,
                text = line
            })
        end,

        ["?"] = function (line)
            expandable = true
            local this = {
                type = instruction_types.ASK,
                text = line,
                options = {}
            }

            table.insert(instructions, this)
            table.insert(questions, this)
        end,

        [">"] = function (line)
            expandable = false
            assert(#questions > 0, "No open questions left!")

            table.insert(questions[#questions].options, {
                text = line, into = #instructions+1
            })
        end,

        ["!"] = function (line)
            expandable = false
            assert(#questions > 0, "No open questions left!")

            questions[#questions] = nil
        end,

        [":"] = function (line)
            expandable = false
            assert(not line:find("%s"), "Label name cannot contain spaces!")
            labels[line] = #instructions+1
        end,

        ["$"] = function (line)
            expandable = true
            assert(not line:find("%s"), "Label name cannot contain spaces!")
            table.insert(instructions, {
                type = instruction_types.GOTO,
                into = assert(labels[line])
            })
        end,

        ["@"] = function (line)
            table.insert(instructions, {
                type = instruction_types.CMD,
                command = line
            })
            
        end
    }

    for line in code:gmatch('[^\r\n]+') do
        cLineText = line
        line = line:gsub('^%s*(.-)%s*$', '%1'):gsub("#+.*", "")

        if #line > 0 then
            local cmd = line:sub(1, 1)
            local parser = parsers[cmd]

            if expandable and not parser then
                instructions[#instructions].text =
                    instructions[#instructions].text .. "\n" .. line

            else assert(parser, "lol not found lmaoooo")
                parser(line:sub(2):gsub('^%s*(.-)%s*$', '%1'))

            end
        end
        cLineNumber = cLineNumber + 1
    end

    return instructions
end

local to_coroutine = function (list)
    return coroutine.create(function(state)
        local i = 1
        while (i <= #list) do
            local inst = list[i]
            print(inst.type, inst.text, i)

            if inst.type == instruction_types.SAY then
                state:say(inst.text)
                i = i + 1

            elseif inst.type == instruction_types.ASK then
                local answers = {}
                for k, v in ipairs(inst.options) do
                    table.insert(answers, inst.text)
                end

                local answ = state:ask(inst.text, answers)
                i = inst.options[answ].into

            elseif inst.type == instruction_types.GOTO then
                i = inst.into

            elseif inst.type == instruction_types.CMD then
                state[inst.command](state)
                i = i + 1

            end
            print(i)

            coroutine.yield()
        end
    end)
end

if ... then
    return {
        parse = parse,
        to_coroutine = to_coroutine
    }

end

local example = parse [[
    : loop
        - Hello!
            It seems like we're stuck on this weird loop

        - If only there was... a way of turning it off...

        ? Exit simulation?
            > YES
                ? Are you sure?
                    > YES
                        @ quit
                    > NO
                        $ loop
                !
            > NO
                $ loop
        !
]]

local state = {
    say = function (text)
        print(">" .. text .. "\n\t(Any key to continue)")
        local a = io.read()
    end,

    ask = function (text, commands)
        local tab = {}
        local out = text .. " ("
        for k, v in ipairs(commands) do
            tab[v] = k

            out = out .. v
        end
        print(out..")")
        
        local i 
        repeat
            i = io.open()
        until tab[i]

        return tab[i]
    end,

    quit = os.exit
}

local a = to_coroutine(example)
while (coroutine.resume(a, state)) do
    
end
