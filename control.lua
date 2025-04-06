local gui = require "scripts.gui"

script.on_event(defines.events.on_player_created,  gui.run_checks)
script.on_configuration_changed(gui.run_checks)
script.on_init(gui.run_checks)

script.on_event(defines.events.on_gui_click, gui.click)