--        ______
--       |
--       |
--       |        __       ___  _   __         _  _
--       |       |  | |\ |  |  |_| |  | |  |  |_ |_|
--  libox|______ |__| | \|  |  | \ |__| |_ |_ |_ |\
--
-- api changes: uses libox and no itbl

-----------------
-- Overheating --
-----------------

local settings = {
    digiline_channel_maxlen = 256, -- in characters (1 byte/character + 25 for lua stuff)
    digiline_maxlen = 50000,       -- in bytes
    memory_max_size = 100000,      -- in serialized characters (whatever minetest feels like doing lmao, 1 byte/character + 25)
    time_limit = 3000,             -- in microseconds, 1 milisecond = 1000 microseconds
    lightweight_interrupts = mesecon.setting("luacontroller_lightweight_interrupts", false)
    -- lightweight interrupts can't be changed in runtime
}

local sound
if mesecon.node_sound then -- YES this can happen where there is no node_sound
    sound = mesecon.node_sound.stone
end

for k, v in pairs(settings) do
    local s = minetest.settings:get("libox_controller_" .. k)
    s = tonumber(s) or s
    settings[k] = s or v
end

settings.allow_functions = minetest.settings:get_bool("libox_controller_allow_functions") or false

libox_controller.settings = settings -- allow override in tests later

local BASENAME = libox_controller.basename


local function burn_controller(pos)
    local node = minetest.get_node(pos)
    node.name = libox_controller.basename .. "_burnt"
    minetest.swap_node(pos, node)
    minetest.get_meta(pos):set_string("lc_memory", "");
    -- Wait for pending operations
    minetest.after(0.2, mesecon.receptor_off, pos, mesecon.rules.flat)
end --

local function overheat(pos)
    if mesecon.do_overheat(pos) then
        burn_controller(pos)
        return true
    end
end

------------------------
-- Ignored off events --
------------------------

local function ignore_event(event, meta)
    if event.type ~= "off" then return false end
    local ignore_offevents = minetest.deserialize(meta:get_string("ignore_offevents"), true) or {}
    if ignore_offevents[event.pin.name] then
        ignore_offevents[event.pin.name] = nil
        meta:set_string("ignore_offevents", minetest.serialize(ignore_offevents))
        return true
    end
end


-------------------------
-- Parsing and running --
-------------------------

local libf = libox.sandbox_lib_f
-- the string sandbox escaper, gone are the days of doing it manually

local function terminal_write(pos, text, nolf)
    local meta = minetest.get_meta(pos)
    local oldtext = meta:get_string("terminal_text")
    local delim = (string.len(oldtext) > 0 and not nolf) and "\n" or ""
    local newtext = string.sub(oldtext .. delim .. text, -100000, -1)
    meta:set_string("terminal_text", newtext)
end



local function get_safe_print(pos)
    return function(param, nolf)
        if param == nil then param = "" end
        if type(param) == "string" then
            terminal_write(pos, param, nolf)
        else
            terminal_write(pos, dump(param), nolf)
        end
    end
end

local function get_clear(pos)
    return function()
        libox_controller.terminal_clear(pos)
    end
end

local function remove_functions(obj)
    local function is_bad(x)
        return type(x) == "function" or type(x) == "userdata" or type(x) == "thread" -- the nasty 3
    end

    if is_bad(obj) then
        return nil
    end

    -- Make sure to not serialize the same table multiple times, otherwise
    -- writing mem.test = mem in the Luacontroller will lead to infinite recursion
    local seen = {}

    local function rfuncs(x)
        if x == nil then return end
        if seen[x] then return end
        seen[x] = true
        if type(x) ~= "table" then return end

        for key, value in pairs(x) do
            if is_bad(key) or is_bad(value) then
                x[key] = nil
            else
                if type(key) == "table" then
                    rfuncs(key)
                end
                if type(value) == "table" then
                    rfuncs(value)
                end
            end
        end
    end

    rfuncs(obj)

    return obj
end

local function validate_iid(iid)
    if iid == nil then return true end -- nil is OK

    if type(iid) == "number" or type(iid) == "boolean" then
        return true
    end

    if type(iid) == "string" then
        -- string type interrupt
        local limit = 256 -- you dont need more than this
        if #iid <= limit then
            return true
        end
        return false, "An interrupt ID was too large!"
    end

    -- non-string and non-nil type interrupt
    return false, "Non-string interrupt IDs are invalid"
end
--[[
    Mooncontroller lightweight interrupts, ah

    i really don't like them.... like... luacontroller supports interrupts that are 0.5s
    Why can't mooncontroller??? oh because iids
    they are also using os.time to do things which has limited precision

    Great... let's see what we can do

    Oh.... the node timer supports only one timer.... oh....

    Welll we can still do something right...
    Or you know what... let's just not bother.

    Also no, i tried, you can't replace the time_function with minetest.get_us_time, it doesn't return wall time, so crap will get messed up
]]


local time_function = os.time
local function get_next_nodetimer_interrupt(interrupts)
    local nextint = 0
    for _, v in pairs(interrupts) do
        if nextint == 0 or v < nextint then
            nextint = v
        end
    end
    if nextint ~= 0 then return (nextint) end
end

local function get_current_nodetimer_interrupts(interrupts)
    local current = {}
    for k, v in pairs(interrupts) do
        if v <= time_function() then
            table.insert(current, k)
        end
    end
    return (current)
end

local function set_nodetimer_interrupt(pos, time, iid)
    if time < 1 then -- and no, this single if statement isn't guarding you from the dream of interrupt(0)
        error(
            "Sorry, lightweight interrupts under 1 second aren't supported (mooncontroller does lightweight interrupts weirdly)")
    end
    if type(iid) ~= "string" then iid = "" end
    local meta = minetest.get_meta(pos)
    local timer = minetest.get_node_timer(pos)
    local interrupts = minetest.deserialize(meta:get_string("interrupts")) or {}
    if time == nil then
        interrupts[iid] = nil
    else
        interrupts[iid] = time_function() + time
    end
    local nextint = get_next_nodetimer_interrupt(interrupts)
    if nextint then
        timer:start(nextint - time_function())
    end
    meta:set_string("interrupts", minetest.serialize(interrupts))
end

local get_interrupt
-- The setting affects API so is not intended to be changeable at runtime
if settings.lightweight_interrupts then
    -- use node timer
    get_interrupt = function(pos, send_warning)
        return libf(function(time, iid, lightweight)
            if lightweight == false then send_warning("Interrupts are always lightweight on this server") end
            if type(time) ~= "nil" and type(time) ~= "number" then
                error("Delay must be a number to set or nil to cancel")
            end
            local ok, warn = validate_iid(iid)
            if ok then set_nodetimer_interrupt(pos, time, iid) end
            if warn then send_warning(warn) end
        end)
    end
else
    -- use global action queue
    get_interrupt = function(pos, send_warning)
        -- iid = interrupt id
        return libf(function(time, iid, lightweight)
            -- NOTE: This runs within string metatable sandbox, so don't *rely* on anything of the form (""):y
            -- Hence the values get moved out. Should take less time than original, so totally compatible
            if lightweight then
                if type(time) ~= "nil" and type(time) ~= "number" then
                    error("Delay must be a number to set or nil to cancel")
                end
            else
                if type(time) ~= "number" then error("Delay must be a number") end
            end
            local luac_id = minetest.get_meta(pos):get_int("luac_id")
            local ok, warn = validate_iid(iid)
            if ok then
                if lightweight then
                    set_nodetimer_interrupt(pos, time, iid)
                else
                    mesecon.queue:add_action(pos, "libox_lc_interrupt", { luac_id, iid }, time, iid, 1)
                end
            end
            if warn then send_warning(warn) end
        end)
    end
end

local function get_digiline_send(pos, send_warning)
    if not minetest.global_exists("digilines") then return end
    local chan_maxlen = settings.digiline_channel_maxlen
    local maxlen = settings.digiline_maxlen
    local allow_functions = settings.allow_functions
    return libf(function(channel, msg)
        -- NOTE: This runs within string metatable sandbox

        if type(channel) == "string" then
            if #channel > chan_maxlen then
                send_warning("Channel string too long.")
                return false
            end
        elseif (type(channel) ~= "string" and type(channel) ~= "number" and type(channel) ~= "boolean") then
            send_warning("Channel must be string, number or boolean.")
            return false
        end

        local msg_cost
        msg, msg_cost = libox.digiline_sanitize(msg, allow_functions,
            function(f)
                setfenv(f, {})
                return f
            end
        )

        if msg == nil then
            send_warning("Message was nil")
            return false
        end

        if msg_cost > maxlen then
            send_warning("Message contained too much data")
            return false
        end

        local luac_id = minetest.get_meta(pos):get_int("luac_id")
        mesecon.queue:add_action(pos, "libox_lc_digiline_relay", { channel, luac_id, msg })

        return true
    end)
end

local function create_environment(pos, mem, event, send_warning)
    -- Gather variables for the environment
    local vports = minetest.registered_nodes[minetest.get_node(pos).name].virtual_portstates
    local vports_copy = {}
    for k, v in pairs(vports) do vports_copy[k] = v end
    local rports = libox_controller.get_real_port_states(pos)

    -- Create new library tables on each call to prevent one Luacontroller
    -- from breaking a library and messing up other Luacontrollers.
    local env = libox.create_basic_environment()

    -- the basic luacontroller library
    -- i shall call it lclib
    local env_add = {
        pin = libox_controller.merge_port_states(vports, rports),
        port = vports_copy,
        event = event,
        mem = mem,
        heat = mesecon.get_heat(pos),
        heat_max = mesecon.setting("overheat_max", 20),
        pos = { x = pos.x, y = pos.y, z = pos.z },
        print = get_safe_print(pos),
        clearterm = libf(get_clear(pos)),
        interrupt = libf(get_interrupt(pos, send_warning)),
        digiline_send = libf(get_digiline_send(pos, send_warning)),
        conf = table.copy(settings),
        code = minetest.get_meta(pos):get_string("code"),
    }

    for k, v in pairs(env_add) do
        env[k] = v
    end

    env.require = libf(libox_controller.get_require(pos, env))

    return env
end





local function load_memory(meta)
    return minetest.deserialize(meta:get_string("lc_memory"), true) or {}
end


local function save_memory(pos, meta, mem)
    local memstring = minetest.serialize(remove_functions(mem))
    local memsize_max = settings.memory_max_size

    if (#memstring <= memsize_max) then
        meta:set_string("lc_memory", memstring)
        meta:mark_as_private("lc_memory")
    else
        burn_controller(pos)
        return "Luacontroller memory overflow. " .. memsize_max .. " bytes available, "
            .. #memstring .. " required. Controller overheats"
    end
end

-- Returns success (boolean), errmsg (string)
-- run (as opposed to run_inner) is responsible for setting up meta according to this output
local function run_inner(pos, meta, event)
    -- Note: These return success, presumably to avoid changing LC ID.
    if overheat(pos) then return true, "[ERROR] Too much heat, overheated." end
    if ignore_event(event, meta) then return true, "" end

    -- Load code & mem from meta
    local mem     = load_memory(meta)

    -- 'Last warning' label.
    local warning = ""
    local function send_warning(str)
        warning = "Warning: " .. str
        terminal_write(pos, "[WARNING] " .. str)
    end

    -- Create environment
    local env = create_environment(pos, mem, event, send_warning)

    -- Create the sandbox and execute code
    local success, msg = libox.normal_sandbox({
        env = env,
        code = meta:get_string("code"),
        max_time = settings.time_limit
    })

    local mem_save_error = save_memory(pos, meta, env.mem)
    if mem_save_error ~= nil then -- save memory regardless of error
        success = false
        msg = mem_save_error
    end


    if not success then return false, msg end
    if type(env.port) ~= "table" then
        return false, "Ports set are invalid."
    end

    -- Actually set the ports
    libox_controller.set_port_states(pos, env.port)
    return true, warning
end

local function reset_formspec(pos, meta, code, errmsg)
    meta:set_string("code", code)
    meta:mark_as_private("code")
    meta:set_string("errmsg", tostring(errmsg or ""))
    meta:mark_as_private("errmsg")
    libox_controller.update_formspec(pos)
end

local function reset_meta(pos, code, errmsg)
    local meta = minetest.get_meta(pos)
    reset_formspec(pos, meta, code, errmsg)
    meta:set_int("luac_id", math.random(1, 65535))
end

-- Wraps run_inner with LC-reset-on-error
function libox_controller.run(pos, event)
    if minetest.get_item_group(minetest.get_node(pos).name, "mesecons_luacontroller") <= 0 then
        return false, "Luacontroller no longer exists"
    end
    local meta = minetest.get_meta(pos)
    local code = meta:get_string("code")
    local ok, errmsg = run_inner(pos, meta, event)


    if not ok then
        errmsg = tostring(errmsg)
        terminal_write(pos, "[ERROR] " .. errmsg)
        reset_meta(pos, code, errmsg)
    else
        reset_formspec(pos, meta, code, errmsg)
    end


    return ok, errmsg
end

local function reset(pos)
    libox_controller.set_port_states(pos, { a = false, b = false, c = false, d = false })
end

local function on_nodetimer_interrupt(pos)
    local meta = minetest.get_meta(pos)
    local timer = minetest.get_node_timer(pos)
    local interrupts = minetest.deserialize(meta:get_string("interrupts")) or {}
    local current = get_current_nodetimer_interrupts(interrupts)
    for _, i in ipairs(current) do
        interrupts[i] = nil
        local event = {}
        event.type = "interrupt"
        event.iid = i
        libox_controller.run(pos, event)
    end
    interrupts = minetest.deserialize(meta:get_string("interrupts")) or {} --Reload as it may have changed
    for _, i in ipairs(current) do
        if interrupts[i] and interrupts[i] <= os.time() then
            interrupts[i] = nil
        end
    end
    local nextint = get_next_nodetimer_interrupt(interrupts)
    if nextint then
        timer:start(nextint - os.time())
    else
        timer:stop()
    end
    meta:set_string("interrupts", minetest.serialize(interrupts))
end

local function node_timer(pos)
    if minetest.registered_nodes[minetest.get_node(pos).name].is_burnt then
        return false
    end
    on_nodetimer_interrupt(pos)
    return false
end

-------------------------------------
-- Mesecons ActionQueue™ callbacks --
-------------------------------------

--[[
    Due to a mod we have to say libox_lc_x instead of just lc_x
    i mean thats fair
]]

mesecon.queue:add_function("libox_lc_interrupt", function(pos, luac_id, iid)
    -- There is no luacontroller anymore / it has been reprogrammed / replaced / burnt
    if (minetest.get_meta(pos):get_int("luac_id") ~= luac_id) then return end
    if (minetest.registered_nodes[minetest.get_node(pos).name].is_burnt) then return end
    libox_controller.run(pos, { type = "interrupt", iid = iid })
end)

mesecon.queue:add_function("libox_lc_digiline_relay", function(pos, channel, luac_id, msg)
    if not digilines then return end
    -- This check is only really necessary because in case of server crash, old actions can be thrown into the future
    if (minetest.get_meta(pos):get_int("luac_id") ~= luac_id) then return end
    if (minetest.registered_nodes[minetest.get_node(pos).name].is_burnt) then return end
    -- The actual work
    digilines.receptor_send(pos, digilines.rules.default, channel, msg)
end)

-----------------------
-- Node Registration --
-----------------------



local output_rules = {}
local input_rules = {}

local node_box = {
    type = "fixed",
    fixed = {
        { -8 / 16, -8 / 16, -8 / 16, 8 / 16, -7 / 16, 8 / 16 }, -- Bottom slab
        { -5 / 16, -7 / 16, -5 / 16, 5 / 16, -6 / 16, 5 / 16 }, -- Circuit board
        { -3 / 16, -6 / 16, -3 / 16, 3 / 16, -5 / 16, 3 / 16 }, -- IC
    }
}

local selection_box = {
    type = "fixed",
    fixed = { -8 / 16, -8 / 16, -8 / 16, 8 / 16, -5 / 16, 8 / 16 },
}

local digiline = {
    receptor = {},
    effector = {
        action = function(pos, _, channel, msg)
            msg = libox.digiline_sanitize(msg, settings.allow_functions) -- receiver doesn't need wrapping, as that was applied already
            libox_controller.run(pos, { type = "digiline", channel = channel, msg = msg })
        end
    }
}

function libox_controller.get_program(pos)
    local meta = minetest.get_meta(pos)
    return meta:get_string("code")
end

function libox_controller.set_program(pos, code)
    reset(pos)
    reset_meta(pos, code)
    return libox_controller.run(pos, { type = "program" })
end

for a = 0, 1 do -- 0 = off  1 = on
    for b = 0, 1 do
        for c = 0, 1 do
            for d = 0, 1 do
                local cid = tostring(d) .. tostring(c) .. tostring(b) .. tostring(a)
                local node_name = BASENAME .. cid
                local top = "libox_controller_top.png"
                if a == 1 then
                    top = top .. "^jeija_luacontroller_LED_A.png"
                end
                if b == 1 then
                    top = top .. "^jeija_luacontroller_LED_B.png"
                end
                if c == 1 then
                    top = top .. "^jeija_luacontroller_LED_C.png"
                end
                if d == 1 then
                    top = top .. "^jeija_luacontroller_LED_D.png"
                end

                local groups
                if a + b + c + d ~= 0 then
                    groups = { dig_immediate = 2, not_in_creative_inventory = 1, overheat = 1, mesecons_luacontroller = 1, }
                else
                    groups = { dig_immediate = 2, overheat = 1, mesecons_luacontroller = 1, }
                end

                output_rules[cid] = {}
                input_rules[cid] = {}
                if a == 1 then table.insert(output_rules[cid], libox_controller.rules.a) end
                if b == 1 then table.insert(output_rules[cid], libox_controller.rules.b) end
                if c == 1 then table.insert(output_rules[cid], libox_controller.rules.c) end
                if d == 1 then table.insert(output_rules[cid], libox_controller.rules.d) end

                if a == 0 then table.insert(input_rules[cid], libox_controller.rules.a) end
                if b == 0 then table.insert(input_rules[cid], libox_controller.rules.b) end
                if c == 0 then table.insert(input_rules[cid], libox_controller.rules.c) end
                if d == 0 then table.insert(input_rules[cid], libox_controller.rules.d) end

                local mesecons = {
                    effector = {
                        rules = input_rules[cid],
                        action_change = function(pos, _, rule_name, new_state)
                            libox_controller.update_real_port_states(pos, rule_name, new_state)
                            libox_controller.run(pos, { type = new_state, pin = rule_name })
                        end,
                    },
                    receptor = {
                        state = mesecon.state.on,
                        rules = output_rules[cid]
                    },
                    luacontroller = {
                        get_program = libox_controller.get_program,
                        set_program = libox_controller.set_program,
                    },
                }

                minetest.register_node(node_name, {
                    description = "Libox controller",
                    drawtype = "nodebox",
                    tiles = {
                        top,
                        "jeija_microcontroller_bottom.png",
                        "jeija_microcontroller_sides.png",
                        "jeija_microcontroller_sides.png",
                        "jeija_microcontroller_sides.png",
                        "jeija_microcontroller_sides.png"
                    },
                    inventory_image = top,
                    paramtype = "light",
                    is_ground_content = false,
                    groups = groups,
                    drop = BASENAME .. "0000",
                    sunlight_propagates = true,
                    selection_box = selection_box,
                    node_box = node_box,
                    on_construct = reset_meta,
                    on_receive_fields = libox_controller.on_receive_fields,
                    sounds = sound,
                    mesecons = mesecons,
                    digiline = digiline,
                    -- Virtual portstates are the ports that
                    -- the node shows as powered up (light up).
                    virtual_portstates = {
                        a = a == 1,
                        b = b == 1,
                        c = c == 1,
                        d = d == 1,
                    },
                    after_dig_node = function(pos)
                        mesecon.do_cooldown(pos)
                        mesecon.receptor_off(pos, output_rules)
                    end,
                    is_luacontroller = true,
                    on_timer = node_timer,
                    on_blast = mesecon.on_blastnode,
                })
            end
        end
    end
end

------------------------------
-- Overheated Luacontroller --
------------------------------

minetest.register_node(BASENAME .. "_burnt", {
    drawtype = "nodebox",
    tiles = {
        "libox_controller_burnt_top.png",
        "jeija_microcontroller_bottom.png",
        "jeija_microcontroller_sides.png",
        "jeija_microcontroller_sides.png",
        "jeija_microcontroller_sides.png",
        "jeija_microcontroller_sides.png"
    },
    inventory_image = "libox_controller_burnt_top.png",
    is_burnt = true,
    paramtype = "light",
    light_source = minetest.LIGHT_MAX, -- those who are brave will use the burnt luacontroller to explore the caves
    is_ground_content = false,
    groups = { dig_immediate = 2, not_in_creative_inventory = 1 },
    drop = BASENAME .. "0000",
    sunlight_propagates = true,
    selection_box = selection_box,
    node_box = node_box,
    on_construct = reset_meta,
    on_receive_fields = libox_controller.on_receive_fields,
    sounds = sound,
    virtual_portstates = { a = false, b = false, c = false, d = false },
    mesecons = {
        effector = {
            rules = mesecon.rules.flat,
            action_change = function(pos, _, rule_name, new_state)
                libox_controller.update_real_port_states(pos, rule_name, new_state)
            end,
        },
    },
    on_blast = mesecon.on_blastnode,
})

------------------------
-- Craft Registration --
------------------------


minetest.register_craft({
    output = BASENAME .. "0000 3",
    recipe = {
        { 'mesecons_luacontroller:luacontroller0000', 'group:mesecon_conductor_craftable', 'mesecons_luacontroller:luacontroller0000' },
        { 'mesecons_luacontroller:luacontroller0000', 'mesecons_materials:silicon',        'mesecons_luacontroller:luacontroller0000' },
        { 'mesecons_luacontroller:luacontroller0000', 'group:mesecon_conductor_craftable', 'mesecons_luacontroller:luacontroller0000' },
    }
})
