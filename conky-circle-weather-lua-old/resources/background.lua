-- background.lua v1.5
-- by @wim66
-- June 10 2024

require 'cairo'
require 'cairo_xlib'

-- Determine the script's directory and set the path to load settings.lua from the parent directory
local script_path = debug.getinfo(1, 'S').source:match[[^@?(.*[\/])[^\/]-$]]
local parent_path = script_path:match("^(.*[\\/])resources[\\/].*$")
package.path = package.path .. ";" .. parent_path .. "?.lua"

-- Attempt to load settings.lua safely; exit if it fails to prevent runtime errors
local status, err = pcall(function() require("settings") end)
if not status then
    print("Error loading settings.lua: " .. err)
    return  -- Stop execution if settings.lua cannot be loaded
end

-- Check if conky_vars exists and call it to initialize variables; exit if missing
if not conky_vars then
    print("conky_vars function is not defined in settings.lua")
    return  -- Stop execution if conky_vars is not defined
end
conky_vars()

-- Define color options for the border with gradient stops (position, hex color, alpha)
local color_options = {
    green = { {0, 0x003E00, 1}, {0.5, 0x03F404, 1}, {1, 0x003E00, 1} },
    orange = { {0, 0xE05700, 1}, {0.5, 0xFFD145, 1}, {1, 0xE05700, 1} },
    blue = { {0, 0x0000ba, 1}, {0.5, 0x8cc7ff, 1}, {1, 0x0000ba, 1} },
    black = { {0, 0x2b2b2b, 1}, {0.5, 0xa3a3a3, 1}, {1, 0x2b2b2b, 1} },
    red = { {0, 0x5c0000, 1}, {0.5, 0xff0000, 1}, {1, 0x5c0000, 1} }
}

-- Define background color options (single color with alpha)
local bgcolor_options = {
    black = { {1, 0x000000, 0.5} },
    blue = { {1, 0x0000ba, 0.5} },
    white = { {1, 0xffffff, 0.5} }
}

-- Set border and background colors from settings.lua, defaulting to green and black if undefined
local border_color = color_options[border_COLOR] or color_options.green
local bg_color = bgcolor_options[background_COLOR] or bgcolor_options.black

-- Define the graphical elements to draw: background, layer2, and border
local boxes_settings = {
    -- Background box with solid color and rounded corners
    { type = "background", x = 10, y = 5, w = 200, h = 200, centre_x = true, colour = bg_color, corners = { {"circle", 100} }, draw_me = true },
    -- Second layer with linear gradient and optional width scaling
    { type = "layer2", x = 0, y = 210, w = 340, h = 210, centre_x = true, scale_width = true, linear_gradient = {0, 210, 0, 420}, colours = { {0, 0x000000, 0.66}, {0.5, 0x0000FF, 0.66}, {1, 0x000000, 0.66} }, corners = { {"circle", 10} }, draw_me = true },
    -- Border with gradient and adjustable thickness
    { type = "border", x = 80, y = 5, w = 200, h = 200, centre_x = true, colour = border_color, linear_gradient = {100, 0, 100, 200}, corners = { {"circle", 100} }, border = 8, draw_me = true },
}

-- Helper function to convert hex color to RGBA values (0-1 range)
local function hex_to_rgba(hex, alpha)
    return ((hex & 0xFF0000) >> 16) / 255, ((hex & 0x00FF00) >> 8) / 255, (hex & 0x0000FF) / 255, alpha
end

-- Draw a rectangle with rounded corners using Cairo
local function draw_rounded_rectangle(cr, x, y, w, h, r)
    cairo_new_path(cr)
    cairo_move_to(cr, x + r, y)  -- Start at top-left corner
    cairo_line_to(cr, x + w - r, y)  -- Top edge
    cairo_arc(cr, x + w - r, y + r, r, -math.pi/2, 0)  -- Top-right corner
    cairo_line_to(cr, x + w, y + h - r)  -- Right edge
    cairo_arc(cr, x + w - r, y + h - r, r, 0, math.pi/2)  -- Bottom-right corner
    cairo_line_to(cr, x + r, y + h)  -- Bottom edge
    cairo_arc(cr, x + r, y + h - r, r, math.pi/2, math.pi)  -- Bottom-left corner
    cairo_line_to(cr, x, y + r)  -- Left edge
    cairo_arc(cr, x + r, y + r, r, math.pi, 3*math.pi/2)  -- Top-left corner
    cairo_close_path(cr)  -- Close the shape
end

-- Calculate the x-coordinate to center a box within the Conky window
local function get_centered_x(canvas_width, box_width)
    return (canvas_width - box_width) / 2
end

-- Main function to draw the background elements in Conky
function conky_draw_background()
    if conky_window == nil then return end  -- Exit if Conky window is not initialized

    -- Create Cairo surface and context based on Conky window properties
    local cs = cairo_xlib_surface_create(conky_window.display, conky_window.drawable, conky_window.visual, conky_window.width, conky_window.height)
    local cr = cairo_create(cs)
    local canvas_width = conky_window.width  -- Get the width of the Conky window

    -- Iterate over each box in boxes_settings to draw it
    for _, box in ipairs(boxes_settings) do
        if box.draw_me then  -- Only draw if draw_me is true
            local x, w = box.x, box.w
            if box.centre_x then x = get_centered_x(canvas_width, box.w) end  -- Center the box if specified

            if box.type == "background" then
                -- Draw a solid background with rounded corners
                cairo_set_source_rgba(cr, hex_to_rgba(box.colour[1][2], box.colour[1][3]))
                draw_rounded_rectangle(cr, x, box.y, box.w, box.h, box.corners[1][2])
                cairo_fill(cr)  -- Fill the shape with the color
            elseif box.type == "layer2" then
                -- Adjust width and position if scaling to window width is enabled
                if box.scale_width then w, x = canvas_width, 0 end
                -- Create a linear gradient for the second layer
                local gradient = cairo_pattern_create_linear(table.unpack(box.linear_gradient))
                for _, color in ipairs(box.colours) do
                    cairo_pattern_add_color_stop_rgba(gradient, color[1], hex_to_rgba(color[2], color[3]))
                end
                cairo_set_source(cr, gradient)
                draw_rounded_rectangle(cr, x, box.y, w, box.h, box.corners[1][2])
                cairo_fill(cr)  -- Fill with gradient
                cairo_pattern_destroy(gradient)  -- Clean up gradient pattern
            elseif box.type == "border" then
                -- Draw a border with a gradient
                local gradient = cairo_pattern_create_linear(table.unpack(box.linear_gradient))
                for _, color in ipairs(box.colour) do
                    cairo_pattern_add_color_stop_rgba(gradient, color[1], hex_to_rgba(color[2], color[3]))
                end
                cairo_set_source(cr, gradient)
                cairo_set_line_width(cr, box.border)  -- Set border thickness
                -- Adjust position and size to account for border width
                draw_rounded_rectangle(cr, x + box.border / 2, box.y + box.border / 2, box.w - box.border, box.h - box.border, box.corners[1][2] - box.border / 2)
                cairo_stroke(cr)  -- Draw the outline
                cairo_pattern_destroy(gradient)  -- Clean up gradient pattern
            end
        end
    end

    -- Clean up Cairo resources
    cairo_destroy(cr)
    cairo_surface_destroy(cs)
end
