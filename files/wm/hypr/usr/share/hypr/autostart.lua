-------------------
---- AUTOSTART ----
-------------------

-- See https://wiki.hypr.land/Configuring/Basics/Autostart/

-- Autostart necessary processes (like notifications daemons, status bars, etc.)
-- Or execute your favorite apps at launch like this:

hl.on("hyprland.start", function()
	hl.exec_cmd("uwsm app -- qs -c noctalia-shell")
	hl.exec_cmd("uwsm app -- dbus-update-activation-environment --all")
	hl.exec_cmd("uwsm app -- /usr/bin/gnome-keyring-daemon --start --components=secrets")
	hl.exec_cmd("exec /usr/libexec/pam_kwallet_init")
end)
