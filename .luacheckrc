globals = {
    "libox_controller"
}

read_globals = {
    string = {fields = {"split", "trim"}},
    table = {fields = {
        "copy"
    }},
    "minetest", "vector", "bit", "ItemStack",
    "dump", "dump2",

    "mesecon", "digilines", "libox", "default"

}

ignore = {
    "631" -- line too long
}

files["examples/*"] = {
    globals = {
        "mem", "port"
    },
    read_globals = {
        "event","pin","interrupt","digiline_send"
    }
}