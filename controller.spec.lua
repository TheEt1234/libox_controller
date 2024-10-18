-- so, for the setup
-- we need to place 1 libox_controller somewhere


-- anyway enjoy this brainrot
-- i hate every single line of code written here about mesecon queue

-- luacheck: ignore

--- mesecon queue emulator
local mesecon_queue = { funcs = {}, actions = {} }
local mesecon_queue_meta = {
    __index = {
        add_function = function(self, name, func)
            self.funcs[name] = func
        end,
        add_action = function(self, pos, func, params, _, _, _)
            -- we ignore like 3 values for simplicity, who cares if time is all jumbled up
            local action = {
                pos = pos,
                func = func,
                params = params or {},
            }
            table.insert(self.actions, action)
        end,
    },
    __call = function()
        local to_delete = {}
        local t = table.copy(mesecon_queue.actions) -- idk the behaviour of foreachi man
        for k, v in pairs(t) do
            to_delete[#to_delete + 1] = k
            minetest.log("EXECUTING " .. v.func .. " ACTION")
            table.insert(v.params, 1, v.pos)
            mesecon_queue.funcs[v.func](unpack(v.params))
        end
        for _, v in ipairs(to_delete) do
            mesecon_queue.actions[v] = nil
        end
    end
}

setmetatable(mesecon_queue, mesecon_queue_meta)
mesecon_queue.funcs = mesecon.queue.funcs

mesecon.queue = mesecon_queue

local pos = vector.new({
    x = 0, y = 0, z = 0
})
local run = libox_controller.run
local set_program = libox_controller.set_program

local old_setings = table.copy(libox_controller.settings)


local function setup(other_pos)
    minetest.set_node(other_pos or pos, {
        name = libox_controller.basename .. "0000"
    })
    minetest.registered_nodes[libox_controller.basename .. "0000"].on_construct(pos)
    libox_controller.settings = old_setings -- restore to normal
end


mtt.emerge_area({ x = 0, y = 0, z = 0 }, { x = 0, y = 0, z = 0 })

mtt.register("terminal stuffs", function(callback)
    setup()

    assert(set_program(pos, [[
        if event.type=="program" then
            print("Hello world")
        elseif event == "do it lol" then
            clearterm()
        end
    ]]))
    local meta = minetest.get_meta(pos)
    assert(meta:get_string("terminal_text") == "Hello world")

    assert(run(pos, "do it lol"))

    assert(meta:get_string("terminal_text") == "")
    callback()
end)

--[[
    Do note: the lightweight interrupt setting cannot be changed at runtime!
]]

mtt.emerge_area({ x = 0, y = 0, z = 0 }, { x = 0, y = 0, z = 0 })

mtt.register("it burns + interrupts", function(callback)
    setup()

    assert(set_program(pos, [[
        interrupt(0, "", false)
    ]]))
    -- ok now time to execute tem globalsteps
    for _ = 1, 100 do
        mesecon_queue()
    end

    assert(minetest.get_node(pos).name == libox_controller.basename .. "_burnt")
    callback()
end)

mtt.register("Doesn't allow the nasty in mem", function(callback)
    setup()

    set_program(pos, [[
        mem = {
            x = string.sub,
        }
        mem.y = mem
    ]])

    assert(not select(1, set_program(pos, [[
        mem = string.rep("a", 64000)
        mem = mem .. mem
    ]])
    ))

    callback()
end)

mtt.register("Lightweight interrupts work correctly", function(callback)
    local my_pos = {
        x = 0,
        y = 1,
        z = 0
    }
    setup(my_pos)

    set_program(my_pos, [[
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
    callback()
    minetest.after(3, function()
        assert(minetest.get_node(my_pos).name == libox_controller.basename .. "1111")
    end)
end)
