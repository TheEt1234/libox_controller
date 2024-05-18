--[[
    What if... this mod just supported everything...
]]

-- wrench support, licensed under LGPLv2.1, by mt-mods, the license can be found at https://github.com/mt-mods/wrench/blob/master/LICENSE
-- also lightly modified
if minetest.global_exists("wrench") then
    local S = wrench.translator

    local luacontroller_def = {
        drop = true,
        metas = {
            code = wrench.META_TYPE_STRING,
            lc_memory = wrench.META_TYPE_STRING,
            luac_id = wrench.META_TYPE_INT,
            terminal_text = wrench.META_TYPE_STRING,
            tab = wrench.META_TYPE_INT,
            formspec = wrench.META_TYPE_STRING,
            real_portstates = wrench.META_TYPE_INT,
            ignore_offevents = wrench.META_TYPE_STRING,
        },
        description = function()
            local desc = minetest.registered_nodes[libox_controller.basename .. "0000"].description
            return S("@1 with code", desc)
        end,
    }

    for a = 0, 1 do
        for b = 0, 1 do
            for c = 0, 1 do
                for d = 0, 1 do
                    local state = d .. c .. b .. a
                    wrench.register_node(libox_controller.basename .. state, luacontroller_def)
                end
            end
        end
    end

    luacontroller_def.drop = nil
    wrench.register_node(libox_controller.basename .. "_burnt", luacontroller_def)
end

-- ratelimiter support with lightweight interrupts
-- the ratelimiter support is licensed under:
-- (and also lightly modified)
--[[

    The MIT License (MIT)
    Copyright (C) 2023 BuckarooBanzay

    Permission is hereby granted, free of charge, to any person obtaining a copy of this
    software and associated documentation files (the "Software"), to deal in the Software
    without restriction, including without limitation the rights to use, copy, modify, merge,
    publish, distribute, sublicense, and/or sell copies of the Software, and to permit
    persons to whom the Software is furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all copies or
    substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
    INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
    PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE
    FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
    OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
    DEALINGS IN THE SOFTWARE.

    For more details:
    https://opensource.org/licenses/MIT
]]
if minetest.global_exists("mesecons_debug") then
    local function override_node_timer(node_name)
        local old_node_timer = minetest.registered_nodes[node_name].on_timer
        minetest.override_item(node_name, {
            on_timer = function(pos, elapsed)
                if not mesecons_debug.enabled then
                    return old_node_timer(pos, elapsed)
                elseif not mesecons_debug.mesecons_enabled then
                    return true
                end

                local ctx = mesecons_debug.get_context(pos)

                if ctx.whitelisted or elapsed > ctx.penalty then
                    return old_node_timer(pos, elapsed)
                else
                    -- defer
                    return true
                end
            end,
        })
    end
    for a = 0, 1 do
        for b = 0, 1 do
            for c = 0, 1 do
                for d = 0, 1 do
                    override_node_timer((libox_controller.basename .. "%i%i%i%i"):format(a, b, c, d))
                end
            end
        end
    end
end

-- luatool support
if minetest.global_exists("metatool") and minetest.get_modpath("metatool") then
    --[[
        From https://github.com/S-S-X/metatool/blob/master/luatool/nodes/luacontroller.lua#L1
        (also modified)

        This applies to the following code in the if statement:

            MIT License

            Copyright (c) 2020 SX

            Permission is hereby granted, free of charge, to any person obtaining a copy
            of this software and associated documentation files (the "Software"), to deal
            in the Software without restriction, including without limitation the rights
            to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
            copies of the Software, and to permit persons to whom the Software is
            furnished to do so, subject to the following conditions:

            The above copyright notice and this permission notice shall be included in all
            copies or substantial portions of the Software.

            THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
            IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
            FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
            AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
            LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
            OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
            SOFTWARE.
    ]]
    local o2b_lookup = {
        ['0'] = '000',
        ['1'] = '001',
        ['2'] = '010',
        ['3'] = '011',
        ['4'] = '100',
        ['5'] = '101',
        ['6'] = '110',
        ['7'] = '111',
    }
    local o2b = function(o)
        return o:gsub('.', o2b_lookup)
    end
    local d2b = function(d)
        return o2b(string.format('%o', d))
    end
    local lpadcut = function(s, c, n)
        return (c:rep(n - #s) .. s):sub(math.max(0, #s - n + 1), #s + 1)
    end

    local nodes = {}
    for i = 0, 15 do
        table.insert(nodes, libox_controller.basename .. lpadcut(d2b(i), '0', 4))
    end
    table.insert(nodes, libox_controller.basename .. '_burnt')

    local ns = metatool.ns('luatool')

    local definition = {
        name = 'libox controller',
        nodes = nodes,
        group = 'libox controller',
        protection_bypass_read = "interact",
    }
    function definition.info(_, _, pos, player, itemstack)
        local meta = minetest.get_meta(pos)
        local mem = meta:get_string("lc_memory")
        return ns.info(pos, player, itemstack, mem, "lua controller")
    end

    function definition.copy(_, _, pos, _)
        local meta = minetest.get_meta(pos)

        -- get and store lua code
        local code = meta:get_string("code")

        -- return data required for replicating this controller settings
        return {
            description = string.format("Lua controller at %s", minetest.pos_to_string(pos)),
            code = code,
        }
    end

    function definition.paste(_, node, pos, player, data)
        -- restore settings and update lua controller, no api available
        local meta = minetest.get_meta(pos)
        if data.mem_stored then
            meta:set_string("lc_memory", data.mem)
        end
        local fields = {
            program = 1,
            code = data.code or meta:get_string("code"),
        }
        local nodedef = minetest.registered_nodes[node.name]
        nodedef.on_receive_fields(pos, "", fields, player)
    end

    return definition
end
