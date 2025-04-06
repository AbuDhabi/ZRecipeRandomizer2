local bigunpack = require "__big-data-string2__.unpack"
local values = require "scripts.values"
local missing_check = require "scripts.missing_check"
local F = {}

local function make_nice_missing(s)
    return string.gsub(s, "(%a+)%.([%a%d%-_:]+)", "[%1=%2]  %2  (%1)")
end

local function make_nice_recipes(s)
    s = string.gsub(s, "%[i%](%a+)%.([%a%d%-_:]+)", " recipes are missing [%1=%2]  %2  (%1):")
    s = string.gsub(s, "%[c%]([%a%d%-_:]+)", " recipes are missing a machine with category [color=230,208,175]%1[/color]:")
    return string.gsub(s, "%[r%]([%a%d%-_ ]+)", "[recipe=%1]")
end

local function make_frame(player, name)
    local screen_element = game.get_player(player).gui.screen
    local id = "zrr-frame-" .. name
    for i = 1, #screen_element.children_names, 1 do
        if screen_element.children_names[i] == id then
            screen_element.children[i].destroy()
            break
        end
    end
    local main_frame = screen_element.add {type = "frame", style = "frame", name = id, direction = "vertical"}
    main_frame.auto_center = true
    main_frame.style.minimal_width = 480
    local title_flow = main_frame.add {type = "flow", direction = "horizontal"}
    title_flow.style.vertically_stretchable = false
    title_flow.drag_target = main_frame
    local title_text = title_flow.add {type = "label", style = "frame_title", caption = {"z-randomizer-gui." .. name .. "-title"}}
    title_text.drag_target = main_frame
    local padding = title_flow.add {type = "empty-widget", style = "draggable_space_header"}
    padding.style.vertically_stretchable = true
    padding.style.horizontally_stretchable = true
    padding.style.height = 24
    padding.style.right_margin = 4
    padding.drag_target = main_frame
    title_flow.add {type = "sprite-button", style = "frame_action_button", sprite = "utility/close_white", name = "close-button"}
    local content_frame = main_frame.add {type = "frame", direction = "vertical", style = "inside_shallow_frame_with_padding"}
    return content_frame
end

local function add_label(frame, caption, width)
    local label = frame.add {type = "label", caption = {"z-randomizer-gui." .. caption}}
    label.style.width = width
    label.style.single_line = false
    return label
end

local function popup(event, t, data)
    local players = {}
    if event == nil or event.player_index == nil then
        for _, p in pairs(game.players) do
            table.insert(players, p.name)
        end
    else
        players = {event.player_index}
    end
    for _, p_i in ipairs(players) do
        local content_frame = make_frame(p_i, "info")

        if t == "missing" then
            local alert_frame = content_frame.add {type = "frame", style = "negative_subheader_frame"}
            alert_frame.style.horizontally_stretchable = true
            alert_frame.style.vertically_stretchable = true
            alert_frame.style.margin = {-12, -12, 12, -12}

            local alert_flow = alert_frame.add {type = "flow", style = "centering_horizontal_flow"}
            alert_flow.style.horizontally_stretchable = true
            alert_flow.style.left_padding = 16
            alert_flow.style.right_padding = 16

            alert_flow.add {type = "label", caption = {"z-randomizer-gui.not-randomized-alert"}}

            add_label(content_frame, "missing-resources").style.bottom_padding = 4

            local count = 1
            for _ in string.gmatch(data, "\n") do
                count = count + 1
            end
            local scroll_pane = content_frame.add {type = "scroll-pane", style = "text_holding_scroll_pane"}
            scroll_pane.style.height = math.min(count * 20, 300)
            scroll_pane.style.bottom_margin = 16
            local missing_label = scroll_pane.add {type = "label", caption = make_nice_missing(data)}
            missing_label.style.horizontally_stretchable = true
            missing_label.style.horizontally_squashable = false
            missing_label.style.vertically_squashable = false
            missing_label.style.single_line = false

            add_label(content_frame, "missing-resources-setup")
        elseif t == "recipes" then
            add_label(content_frame, "missing-recipes").style.bottom_padding = 4

            local count = 1
            for _ in string.gmatch(data, "\n") do
                count = count + 1
            end
            local scroll_pane = content_frame.add {type = "scroll-pane", style = "text_holding_scroll_pane"}
            scroll_pane.style.height = math.min(count * 20, 300)
            scroll_pane.style.bottom_margin = 16
            local missing_label = scroll_pane.add {type = "label", caption = make_nice_recipes(data)}
            missing_label.style.horizontally_stretchable = true
            missing_label.style.horizontally_squashable = false
            missing_label.style.vertically_squashable = false
            missing_label.style.single_line = false

            add_label(content_frame, "missing-recipes-setup")
        end
    end
end

function F.run_checks(event)
    if game.item_prototypes["big-data-" .. values.data_missing] then
        local missing = bigunpack(values.data_missing)
        popup(event, "missing", missing)
    end
    if game.item_prototypes["big-data-" .. values.data_recipes] then
        local recipes = bigunpack(values.data_recipes)
        popup(event, "recipes", recipes)
    end
end

function F.click(event)
    if event.element.name == "close-button" then
        event.element.parent.parent.destroy()
    end
end

return F
