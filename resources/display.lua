--[[
 conky-circle-weather-lua  display.lua   
 by @wim66    
 v2.1 31-march-2025       
]]
require 'cairo'
require 'cairo_xlib'

-- Function to select labels based on language
local function get_labels(lang)
    if lang == "nl" then
        return { humidity = "Luchtvochtigheid", wind_speed = "Wind snelheid" }
    elseif lang == "en" then
        return { humidity = "Humidity", wind_speed = "Wind Speed" }
    elseif lang == "fr" then
        return { humidity = "Humidité", wind_speed = "Vitesse du vent" }
    elseif lang == "es" then
        return { humidity = "Humedad", wind_speed = "Velocidad del viento" }
    elseif lang == "de" then
        return { humidity = "Luftfeuchtigkeit", wind_speed = "Windgeschwindigkeit" }
    else
        return { humidity = "Humidity", wind_speed = "Wind Speed" } -- Fallback to English
    end
end

-- Function to read and parse weather data
local function read_weather_data()
    local weather_data = {}
    local weather_file = "./resources/weather_data.txt"
    local file = io.open(weather_file, "r")

    if not file then
        print("Could not open weather data file: " .. weather_file)
        return weather_data
    end

    for line in file:lines() do
        local key, value = line:match("([^=]+)=([^=]+)")
        if key and value then
            weather_data[key] = value
        end
    end

    file:close()
    return weather_data
end

-- Function to load and draw an image with Cairo
local function draw_image(cr, img_path, x, y, width, height)
    local image = cairo_image_surface_create_from_png(img_path)
    local img_w = cairo_image_surface_get_width(image)
    local img_h = cairo_image_surface_get_height(image)

    cairo_save(cr)
    cairo_translate(cr, x, y)
    cairo_scale(cr, width / img_w, height / img_h)
    cairo_set_source_surface(cr, image, 0, 0)
    cairo_paint(cr)
    cairo_restore(cr)

    cairo_surface_destroy(image)
end

-- Function to draw text with Cairo
local function draw_text(cr, text, x, y, font, size, color)
    cairo_select_font_face(cr, font, CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_NORMAL)
    cairo_set_font_size(cr, size)
    cairo_set_source_rgba(cr, color[1], color[2], color[3], color[4])
    
    -- Calculate the width of the text
    local text_extents = cairo_text_extents_t:create()
    cairo_text_extents(cr, text, text_extents)
    local text_width = text_extents.width

    -- Calculate the x-position for centering
    local centered_x = x - (text_width / 2)

    cairo_move_to(cr, centered_x, y)
    cairo_show_text(cr, text)
    cairo_stroke(cr)
end

-- Function to display weather data
function conky_draw_weather()
    if conky_window == nil then
        return
    end
    
    local weather_data = read_weather_data()

    local city = weather_data.CITY or "N/A"
    local weather_icon_path = "./resources/cache/weathericon.png"
    local weather_desc = weather_data.WEATHER_DESC or "N/A"
    local temp = weather_data.TEMP or "N/A"
    local humidity = weather_data.HUMIDITY or "N/A"
    local wind_speed = weather_data.WIND_SPEED or "N/A"
    local lang = weather_data.LANG or "en" -- Fallback to English

    -- Get labels based on the language
    local labels = get_labels(lang)

    -- Create a Cairo surface and context
    local cs = cairo_xlib_surface_create(conky_window.display, conky_window.drawable, conky_window.visual, conky_window.width, conky_window.height)
    local cr = cairo_create(cs)

    local canvas_width = conky_window.width
    local img_width = 150
    local img_x = (canvas_width - img_width) / 2

    draw_image(cr, weather_icon_path, img_x, 75, img_width, 150)

    local text_center_x = canvas_width / 2
    draw_text(cr, city, text_center_x, 365, "ChopinScript", 72, {1, 0.4, 0, 1})
    draw_text(cr, temp, text_center_x, 400, "ubuntu", 22, {249, 168, 0, 1})
    draw_text(cr, weather_desc, text_center_x, 430, "ubuntu", 22, {249, 168, 0, 1}) 
    draw_text(cr, labels.humidity .. ": " .. humidity .. "%", text_center_x, 460, "ubuntu", 22, {249, 168, 0, 1})
    draw_text(cr, labels.wind_speed .. ": " .. wind_speed .. " m/s", text_center_x, 490, "ubuntu", 22, {249, 168, 0, 1})

    -- Destroy the Cairo context and surface
    cairo_destroy(cr)
    cairo_surface_destroy(cs)
end

function conky_draw_weather_text()
    return ""
end
