-- so, for the setup
-- we need to place 1 libox_controller somewhere



local pos = vector.new({
    x = 0, y = 0, z = 0
})
local run = libox_controller.run
local set_program = libox_controller.set_program

local old_setings = table.copy(libox_controller.settings)


local function setup()
    mtt.emerge_area({ x = 0, y = 0, z = 0 }, { x = 0, y = 0, z = 0 })
    minetest.place_node(pos, {
        name = libox_controller.basename .. "0000"
    })
    libox_controller.settings = old_setings -- restore to normal
end


mtt.register("terminal stuffs", function(callback)
    setup()
    set_program(pos, [[
        print("Hello world")
        if event == "do it lol" then
            clearterm()
        end
    ]])
    local meta = minetest.get_meta(pos)
    assert(meta:get_string("terminal_text") == "Hello world")

    run(pos, "do it lol")

    assert(meta:get_string("terminal_text") == "")
    callback()
end)
--[[
    Do note: the lightweight interrupt setting cannot be changed at runtime!
]]

mtt.register("it burns + interrupts", function(callback)
    setup()

    set_program(pos, [[
        interrupt(0, "", false)
    ]])

    minetest.after(3, function()
        assert(minetest.get_node(pos).name == libox_controller.basename .. "_burnt")
        callback()
    end)
end)

mtt.register("Doesn't allow the nasty in mem", function(callback)
    setup()

    set_program(pos, [[
        mem = {
            x = string.sub,
        }
        mem.y = mem
    ]])

    callback()
end)

mtt.register("Lightweight interrupts work correctly", function(callback)
    setup()

    set_program(pos, [[
        if event.type=="program" then
            interrupt(1, "hi", true)
        elseif event.type=="interrupt" and event.iid == "hi" then
            port = {
                a = true,
                b = true,
                c = true,
                d = true
            }
        end
    ]])
    minetest.after(2, function()
        assert(minetest.get_node(pos).name == libox_controller.basename .. "1111")
        callback()
    end)
end)
