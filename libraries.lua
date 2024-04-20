-- Mods can place their own "libraries" in here to be loaded via require() from in a Luacontroller.
-- These can take two different forms:
-- Function (recommended for libraries adding new functionality): A function that, when called, returns something that will be passed to the LuaC code.
-- Function signature is getlibrary(env, pos) where 'env' is the environment that the Luacontroller code is running in, and 'pos' is the position of the controller.
-- Table (recommended for libraries containing mostly lookup tables): A table that will be copied, and the copy returned to the LuaC code.
-- When using the table format, any functions in the table will have their environment changed to that of the Luacontroller.
libox_controller.luacontroller_libraries = {}

--This prepares the actual require() function that will be available in the LuaC environment.
function libox_controller.get_require(pos, env)
    return function(name)
        if type(libox_controller.luacontroller_libraries[name]) == "function" then
            return libox_controller.luacontroller_libraries[name](env, pos)
        elseif type(libox_controller.luacontroller_libraries[name]) == "table" then
            return libox_controller.tablecopy_change_env(libox_controller.luacontroller_libraries[name], env)
        end
    end
end
