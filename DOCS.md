The environment is mostly handled by libox, see [libox's env_docs.md](https://github.com/TheEt1234/libox/blob/master/env_docs.md) for the docs of that....

# But what isn't handled by libox (is given by this mod):

* pin - the mesecons INPUT table
* port - the mesecons OUTPUT table
* event - the reason why the libox controller ran
* mem - persistant storage of values, unserializable stuff isn't allowed in there
* heat - the amount of events executed on this libox controller per second
* heat_max - if heat is above this value the libox_controller will overheat
* pos - the libox controller's position,
* print(text, no_new_line) - prints the text to the terminal, 
   * optionally when no_new_line is enabled it won't print out a new line...
   * if given a table, it creates a readable representation
* clearterm() - clears the terminal
* interrupt(time, iid, lightweight) - starts a timer
   * once it has finished it will send an interrupt event
   * that interrupt event has an iid field, that just returns the iid
   * iid must be a string, that's less than 256 characters
   * if lightweight mode is enabled, it will use node timers instead of mesecons queue 
   * (this helps save server resources by not executing when the controller is unloaded, may even be forced by a setting)
   * iid and lightweight arguments are optional
* digiline_send(channel, msg) - sends a digiline message 
* conf - The libox_controller configuration
* code - The code that the luacontroller has been loaded with
* require - Adds a library from another mod (currently unused)

# What's this event thing really..

So.... to save compute the luacontroller isn't being ran always, instead, it is being ran when an ***event*** gets to it

That event can have properties... like `type` which indicates what event is it and what can you expect from it

If you have more than `heat_max` events per one second... your libox controller will overheat

you can do `print(event)` to see every event that your libox controller is receiving

# Also... how does the limiting work...

So... you have 3000 microseconds (by default) to run your program
If your program is still running even if more than 3 000 microseconds passed it will terminate with an error

This is very different from the luacontroller's way of doing things, which is limiting by *instructions*

I chose to limit by *time* because limiting by instructions is vurnable to a not so fun attack

The interrupting of your program gets done with debug hooks  
The debug hook is defined [here](https://github.com/TheEt1234/libox/blob/master/utils.lua#L1)

Also... because of the limitations of debug hooks on luajit, luajit optimizations will be disabled on your codes

# How do i make something useful

with *digilines* of course, see [digistuff](https://github.com/mt-mods/digistuff) for an example, there are many mods with fun digiline devices  
or mesecons...  
or with the terminal.....  
or maybe you are feeling funny, and edited the source code to set the environment to the mod environment
