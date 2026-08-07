-------------------
---- AUTOSTART ----
-------------------

-- See https://wiki.hypr.land/Configuring/Basics/Autostart/

-- Autostart necessary processes (like notifications daemons, status bars, etc.)
-- Or execute your favorite apps at launch like this:

hl.on("hyprland.start", function()
	hl.exec_cmd("dbus-update-activation-environment --all")
	hl.exec_cmd("/usr/bin/gnome-keyring-daemon --start --components=secrets")
	hl.exec_cmd("exec /usr/libexec/pam_kwallet_init")
end)

hl.on("hyprland.shutdown", function()
    os.execute("uwsm stop && sleep 0.1")
    -- uses a blocking exec function and sleeps a bit to give things time to close
    -- you might also want to kill troublesome/crashing non-systemd background services here:
    -- os.execute("pkill wallpaperthing; systemctl --user stop hyprland-session.target && sleep 0.1")
end)
