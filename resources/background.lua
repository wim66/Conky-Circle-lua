-- background.lua
-- Version: 2
-- By @wim66
-- Updated: April 6, 2025
-- Description:
-- This script draws customizable rounded rectangles in Conky using Cairo.
-- Each box supports independent corner radii (TL, TR, BR, BL) and a rotation flag to rotate corner placement.

-- === Required Cairo Modules ===
require 'cairo'
require 'cairo_xlib'

-- === Load settings.lua from parent directory ===
local script_path = debug.getinfo(1, 'S').source:match[[^@?(.*[\/])[^\/]-$]]
local parent_path = script_path:match("^(.*[/\\])resources[/\\].*$") or ""
package.path = package.path .. ";" .. parent_path .. "?.lua"

local status, err = pcall(function() require("settings") end)
if not status then print("Error loading settings.lua: " .. err); return end
if not conky_vars then print("conky_vars function is not defined in settings.lua"); return end
conky_vars()

-- === Utility ===
local unpack = table.unpack or unpack  -- Compatibility for Lua 5.1 and newer

-- === Color Definitions ===
local color_options = {
    green = { {0, 0x003E00, 1}, {0.5, 0x03F404, 1}, {1, 0x003E00, 1} },
    orange = { {0, 0xE05700, 1}, {0.5, 0xFFD145, 1}, {1, 0xE05700, 1} },
    orange2 = { {0, 0xFFD145, 1}, {0.5, 0xE05700, 1}, {1, 0xFFD145, 1} },
    blue = { {0, 0x0000ba, 1}, {0.5, 0x8cc7ff, 1}, {1, 0x0000ba, 1} },
    black = { {0, 0x2b2b2b, 1}, {0.5, 0xa3a3a3, 1}, {1, 0x2b2b2b, 1} },
    red = { {0, 0x5c0000, 1}, {0.5, 0xff0000, 1}, {1, 0x5c0000, 1} }
}

local bgcolor_options = {
    black = { {1, 0x000000, 0.5} },
    blue = { {1, 0x0000ba, 0.5} },
    white = { {1, 0xffffff, 0.5} }
}

local border_color = color_options[border_COLOR] or color_options.green
local bg_color = bgcolor_options[background_COLOR] or bgcolor_options.black

-- === All drawable elements (partially included, continued in part 2) ===
local boxes_settings = {
    {
        type = "background",
        x = 10, y = 50, w = 200, h = 200,
        centre_x = true,
        corners = {80, 0, 80, 0},  -- TL, TR, BR, BL
        rotation = 45,            -- Rotate entire box
        draw_me = true,
        colour = bg_color
    },
    {
        type = "border",
        x = 80, y = 50, w = 200, h = 200,
        centre_x = true,
        corners = {80, 0, 80, 0},
        rotation = 45,
        draw_me = true,
        border = 8,
        colour = border_color,
        linear_gradient = {80, 50, 80, 250}  -- Aangepast aan positie van border
    },

        {
        type = "layer2",
        x = 0, y = 295, w = 340, h = 210,
        centre_x = true,
        scale_width = false,
        corners = {50, 0, 50, 0},
        draw_me = true,
        linear_gradient = {0, 210, 0, 420},
        colours = { {0, 0x000000, 0.66}, {0.5, 0x0000FF, 0.66}, {1, 0x000000, 0.66} },
    }
}

-- === Helper: Convert hex to RGBA ===
local function hex_to_rgba(hex, alpha)
    return ((hex >> 16) & 0xFF) / 255, ((hex >> 8) & 0xFF) / 255, (hex & 0xFF) / 255, alpha
end

-- === Helper: Draw custom rounded rectangle ===
local function draw_custom_rounded_rectangle(cr, x, y, w, h, r)
    local tl, tr, br, bl = unpack(r)

    cairo_new_path(cr)
    cairo_move_to(cr, x + tl, y)
    cairo_line_to(cr, x + w - tr, y)
    if tr > 0 then cairo_arc(cr, x + w - tr, y + tr, tr, -math.pi/2, 0) else cairo_line_to(cr, x + w, y) end
    cairo_line_to(cr, x + w, y + h - br)
    if br > 0 then cairo_arc(cr, x + w - br, y + h - br, br, 0, math.pi/2) else cairo_line_to(cr, x + w, y + h) end
    cairo_line_to(cr, x + bl, y + h)
    if bl > 0 then cairo_arc(cr, x + bl, y + h - bl, bl, math.pi/2, math.pi) else cairo_line_to(cr, x, y + h) end
    cairo_line_to(cr, x, y + tl)
    if tl > 0 then cairo_arc(cr, x + tl, y + tl, tl, math.pi, 3*math.pi/2) else cairo_line_to(cr, x, y) end
    cairo_close_path(cr)
end

-- === Helper: Center X position ===
local function get_centered_x(canvas_width, box_width)
    return (canvas_width - box_width) / 2
end

-- === Main drawing function ===
function conky_draw_background()
    if conky_window == nil then return end

    local cs = cairo_xlib_surface_create(conky_window.display, conky_window.drawable, conky_window.visual, conky_window.width, conky_window.height)
    local cr = cairo_create(cs)
    local canvas_width = conky_window.width

    for _, box in ipairs(boxes_settings) do
        if box.draw_me then
            local x, y, w, h = box.x, box.y, box.w, box.h
            if box.centre_x then x = get_centered_x(canvas_width, w) end

            local cx, cy = x + w / 2, y + h / 2
            local angle = (box.rotation or 0) * math.pi / 180

            if box.type == "background" then
                -- Apply rotation for the background
                cairo_save(cr)
                cairo_translate(cr, cx, cy)
                cairo_rotate(cr, angle)
                cairo_translate(cr, -cx, -cy)

                cairo_set_source_rgba(cr, hex_to_rgba(box.colour[1][2], box.colour[1][3]))
                draw_custom_rounded_rectangle(cr, x, y, w, h, box.corners)
                cairo_fill(cr)

                cairo_restore(cr)

            elseif box.type == "border" then
                -- Create the gradient in the original coordinate system
                local grad = cairo_pattern_create_linear(unpack(box.linear_gradient))
                for _, color in ipairs(box.colour) do
                    cairo_pattern_add_color_stop_rgba(grad, color[1], hex_to_rgba(color[2], color[3]))
                end
                cairo_set_source(cr, grad)

                -- Apply rotation only to the shape
                cairo_save(cr)
                cairo_translate(cr, cx, cy)
                cairo_rotate(cr, angle)
                cairo_translate(cr, -cx, -cy)

                cairo_set_line_width(cr, box.border)
                draw_custom_rounded_rectangle(
                    cr,
                    x + box.border / 2,
                    y + box.border / 2,
                    w - box.border,
                    h - box.border,
                    {
                        math.max(0, box.corners[1] - box.border / 2),
                        math.max(0, box.corners[2] - box.border / 2),
                        math.max(0, box.corners[3] - box.border / 2),
                        math.max(0, box.corners[4] - box.border / 2)
                    }
                )
                cairo_stroke(cr)

                cairo_restore(cr)
                cairo_pattern_destroy(grad)

            elseif box.type == "layer2" then
                if box.scale_width then w, x = canvas_width, 0 end

                -- Create the gradient in the original coordinate system
                local grad = cairo_pattern_create_linear(unpack(box.linear_gradient))
                for _, color in ipairs(box.colours) do
                    cairo_pattern_add_color_stop_rgba(grad, color[1], hex_to_rgba(color[2], color[3]))
                end
                cairo_set_source(cr, grad)

                -- Apply rotation (0 for layer2)
                cairo_save(cr)
                cairo_translate(cr, cx, cy)
                cairo_rotate(cr, angle)
                cairo_translate(cr, -cx, -cy)

                draw_custom_rounded_rectangle(cr, x, y, w, h, box.corners)
                cairo_fill(cr)

                cairo_restore(cr)
                cairo_pattern_destroy(grad)
            end
        end
    end

    cairo_destroy(cr)
    cairo_surface_destroy(cs)
end