# Libox controller 
- Fork of mooncontroller, that makes use of helper functions from libox

# The one huge difference
Everything, when it can be handled by libox, is handled by libox

This means that:
- The environment is mostly handled by libox, see [libox's env_docs.md](https://github.com/TheEt1234/libox/blob/master/env_docs.md) for the docs of that
- The code is limited by time, not instructions
- You get traceback

# Small differences
- you can't store userdata and threads in `mem` now (not like you can obtain that anyway)
- *if* enabled (not by default), `digiline_send` can send functions (but their environment gets erased)
- extra environment stuffs: 
    - `code` - the code that the luacontroller was ran with
    - `conf` - the configuration table (*the settings*)
- if the libox controller overheats, you now *know* why (memory or overheated) because it makes an error message
- your `digiline_send`s and `interrupt`s get executed even when the libox controller errors, and your memory gets saved too (i think this is a huge qol change)

# Mostly technical differences
- Doesn't use itbl anymore, instead doing string sandbox escaping

# Oh yeah also the support (different from the mooncontroller also)
- wrench: the libox controller can now be picked up by a wrench
- luatool: can be operated by luatool
- mesecons_debug: lightweight interrupts now respect penalty

### Almost everything besides that is *basically* identical to the mooncontroller

# TODOs:
- user generated libraries
- cbd release
- tests