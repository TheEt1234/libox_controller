-- Executes arbitrary code from the terminal
if event.type == "terminal" then
    print(">" .. event.text)
    local func, msg = loadstring(event.text)
    if func == nil then
        print("[ERR]: " .. msg)
    else
        func()
    end
end
