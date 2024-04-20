# Libox controller

- Fork of mooncontroller, that makes use of helper functions from libox
# Differences
- Most of the environment is already handled by libox (this also means you get more stuff to play with, like `pcall` and `loadstring`, and also get traceback)

- You can transmit functions through digilines (their environment gets anniliated so you cant really use them for communication)
- You can transmit un-copied tables through digilines
- Code isn't limited by instructions but by a time limit

Code:
- LGPLv3, most of it is taken from https://github.com/mt-mods/mooncontroller

Media:
    - textures/*
    - CC-BY-SA 3.0 https://github.com/minetest-mods/mesecons/tree/master/mesecons_luacontroller/textures