function love.conf(t)
    t.identity = "longland"
    t.version = "11.5"
    t.window.title = "Longland"
    -- The game renders internally at 800x450 (16:9) and is letterboxed to fit.
    -- Start at a 16:9 multiple so the CRT effect has room to breathe.
    t.window.width = 1280
    t.window.height = 720
    t.window.minwidth = 400
    t.window.minheight = 225
    t.window.resizable = true
    t.window.vsync = 1
    t.window.msaa = 0
    t.console = false
end
