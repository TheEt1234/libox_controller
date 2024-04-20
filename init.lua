libox_controller = {
    basename = "libox_controller:controller"
}

local MP = minetest.get_modpath("libox_controller")

dofile(MP .. "/docmanager.lua")
dofile(MP .. "/common.lua")
dofile(MP .. "/ui.lua")
dofile(MP .. "/libraries.lua")
dofile(MP .. "/port_states.lua")
dofile(MP .. "/controller.lua")
