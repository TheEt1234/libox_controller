-- literally just mooncontroller docs again
-- -> Literally just chiepie's lcdocs again
libox_controller.lc_docs = {}

--Other mods can place their own examples in here.
--The table key will be used as the name.
libox_controller.lc_docs.examples = {}

minetest.register_on_mods_loaded(function()
    --Build a list of example names so that the order will stay the same when the formspecs are redrawn
    libox_controller.lc_docs.example_order = {}
    for k in pairs(libox_controller.lc_docs.examples) do
        table.insert(libox_controller.lc_docs.example_order, k)
    end
    table.sort(libox_controller.lc_docs.example_order)
end)

function libox_controller.lc_docs.generate_example_formspec(sel_index)
    sel_index = math.max(sel_index, 1)
    sel_index = math.min(sel_index, #libox_controller.lc_docs.example_order)
    local selected_text = libox_controller.lc_docs.examples[libox_controller.lc_docs.example_order[sel_index]]
    local fs = "textlist[0.25,0.6;3,9.05;example_list;"
    for _, i in ipairs(libox_controller.lc_docs.example_order) do
        fs = fs .. minetest.formspec_escape(i) .. ","
    end
    fs = string.sub(fs, 1, -2) .. ";" .. sel_index .. ";false]"
        .. "textarea[3.25,0.6;11.5,8.05;;;" .. minetest.formspec_escape(selected_text) .. "]"
    return fs
end

local included_examples = {
    ["R/S Latch"] = "rslatch.lua",
    ["Clock"] = "clock.lua",
    ["LCD Counter"] = "counter.lua",
    ["Executing code from the terminal"] = "terminal_execute.lua",
}

for k, v in pairs(included_examples) do
    local f = io.open(minetest.get_modpath("libox_controller") .. "/examples/" .. v, "r")
    libox_controller.lc_docs.examples[k] = f:read("*all")
    f:close()
end

--Other mods can provide their own help pages too, but the order of these must be specified and is not automatically sorted.
--In this table, the key is a number representing the position in the list, and the value is the description.
libox_controller.lc_docs.help_order = {}
--In this table, the key is the description and the value in the content.
libox_controller.lc_docs.help_pages = {}

function libox_controller.lc_docs.generate_help_formspec(sel_index)
    sel_index = math.max(sel_index, 1)
    sel_index = math.min(sel_index, #libox_controller.lc_docs.help_order)
    local selected_text = libox_controller.lc_docs.help_pages[libox_controller.lc_docs.help_order[sel_index]]
    local fs = "textlist[0.25,0.6;3,9.05;help_list;"
    for _, i in ipairs(libox_controller.lc_docs.help_order) do
        fs = fs .. minetest.formspec_escape(i) .. ","
    end
    fs = string.sub(fs, 1, -2) .. ";" .. sel_index .. ";false]"
        .. "textarea[3.25,0.6;11.5,9.05;;;" .. minetest.formspec_escape(selected_text) .. "]"
    return fs
end

local included_help_order = {
    "Introduction",
    "Events",
    "Lua Functions",
    "Mesecons I/O",
    "Terminal I/O",
    "Digilines I/O",
    "Interrupts",
    "Differences from mooncontroller"
}

local included_help_content = {
    ["Introduction"] = "introduction.txt",
    ["Events"] = "events.txt",
    ["Lua Functions"] = "luafunctions.txt",
    ["Mesecons I/O"] = "mesecons.txt",
    ["Terminal I/O"] = "terminal.txt",
    ["Digilines I/O"] = "digilines.txt",
    ["Interrupts"] = "interrupts.txt",
    ["Differences from mooncontroller"] = "differences.txt"
}

for _, v in ipairs(included_help_order) do
    local filename = included_help_content[v]
    local f = io.open(minetest.get_modpath("libox_controller") .. "/help/" .. filename, "r")
    table.insert(libox_controller.lc_docs.help_order, v)
    libox_controller.lc_docs.help_pages[v] = f:read("*all")
    f:close()
end
