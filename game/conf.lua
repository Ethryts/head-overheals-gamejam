local project = require("project")

function love.conf(t)
    t.identity = project.identity
    t.version = "11.4"
    t.window.title = project.title
    t.window.width = project.width
    t.window.height = project.height
    t.window.minwidth = 480
    t.window.minheight = 270
    t.window.resizable = true
    t.window.highdpi = true
    t.window.vsync = 1
end
