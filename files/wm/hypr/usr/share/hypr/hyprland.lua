-- This is an example Hyprland Lua config file.
-- Refer to the wiki for more information.
-- https://wiki.hypr.land/Configuring/Start/

-- Please note not all available settings / options are set here.
-- For a full list, see the wiki

-- You can (and should!!) split this configuration into multiple files
-- Create your files separately and then require them like this:
-- require("myColors")

package.path = package.path .. ";/usr/share/hypr/?.lua"

require("animations")
require("autostart")
require("bindings")
require("envs")
require("looknfeel")
require("perm")
require("windows")

hl.config({
	ecosystem = {
        no_update_news = true,
		no_donation_nag = true,
    },

	misc = {
		force_default_wallpaper = 0, -- Set to 0 or 1 to disable the anime mascot wallpapers
		disable_hyprland_logo = true, -- If true disables the random hyprland logo / anime girl background. :(
        
		-- Wake
		key_press_enables_dpms = true,  -- key press will trigger wake
        mouse_move_enables_dpms = true, -- mouse move will trigger wake
	},

    xwayland = {
		enabled = true,
        force_zero_scaling = false,
	},
})

require("additionals")
