-------------------
---- AUTOSTART ----
-------------------

-- See https://wiki.hypr.land/Configuring/Basics/Autostart/

-- Autostart necessary processes (like notifications daemons, status bars, etc.)
-- Or execute your favorite apps at launch like this:

hl.on("hyprland.start", function()
	hl.exec_cmd("dbus-update-activation-environment --systemd --all")
end)

hl.on("hyprland.shutdown", function()
    -- Noctalia does not terminate on SIGTERM; kill it outright so uwsm stop
    -- does not stall for TimeoutStopSec (see noctalia.service).
    os.execute("systemctl --user kill --signal=KILL noctalia.service 2>/dev/null || true")
    os.execute("uwsm stop && sleep 0.1")
    -- uses a blocking exec function and sleeps a bit to give things time to close
    -- you might also want to kill troublesome/crashing non-systemd background services here:
    -- os.execute("pkill wallpaperthing; systemctl --user stop hyprland-session.target && sleep 0.1")
end)
