--!nonstrict
-- Night Light Sync service for Noctalia v5.
-- While night light gamma is active: apply the configured night palette and
-- set a wallpaper from the configured night directory.
-- Otherwise: leave everything to the user's Noctalia settings, restoring the
-- day palette and wallpapers saved before the night switch. Wallpaper rotation
-- stays with Noctalia's own wallpaper automation.
-- Night state comes from the shell's live gamma log (sees manual force
-- toggles, which are runtime-only and never reach the config), with the
-- config schedule as fallback.
-- Settings live in plugin.toml (night_palette_source, night_palette,
-- night_wallpapers_dir).

local STATE_FILE = "night-sync.json"
local IMAGE_EXTS = { png = true, jpg = true, jpeg = true, webp = true, gif = true, svg = true, ico = true, jxl = true }
local GAMMA_FRESH_MS = 180000

local state = { active = "day", day_scheme = nil, day_wallpapers = nil, index = 0, images_sig = "" }
local gamma = { night = nil, at_ms = 0 }
local busy = true
local missing_logged = false
local fail_notified = false
local night_wallpaper_set = false
local dataDir = nil

local function getDataPath()
    if not dataDir then
        local dir, err = noctalia.pluginDataDir()
        if not dir then
            noctalia.log("NightLight: pluginDataDir failed: " .. tostring(err))
            return nil
        end
        dataDir = dir
    end
    return dataDir .. "/" .. STATE_FILE
end

local function loadState()
    local path = getDataPath()
    if not path then return end
    local raw = noctalia.readFile(path)
    if not raw then return end
    local parsed = noctalia.json.decode(raw)
    if type(parsed) == "table" then
        if parsed.active == "night" then state.active = "night" end
        if type(parsed.day_scheme) == "table" then state.day_scheme = parsed.day_scheme end
        if type(parsed.day_wallpapers) == "table" then state.day_wallpapers = parsed.day_wallpapers end
        if type(parsed.index) == "number" then state.index = parsed.index end
        if type(parsed.images_sig) == "string" then state.images_sig = parsed.images_sig end
        if type(parsed.day_default) == "string" then state.day_default = parsed.day_default end
    end
end

local function saveState()
    local path = getDataPath()
    if not path then return end
    local encoded = noctalia.json.encode(state)
    if encoded then noctalia.writeFile(path, encoded) end
end

local function fail(msg)
    noctalia.log("NightLight: " .. msg)
    if not fail_notified then
        fail_notified = true
        noctalia.notifyError("Night Light Sync", msg)
    end
end

local function nightConfig()
    return {
        source = noctalia.getConfig("night_palette_source") or "custom",
        name = noctalia.getConfig("night_palette") or "Ristretto",
        dir = noctalia.getConfig("night_wallpapers_dir") or "~/Pictures/Wallpapers-Night",
    }
end

local function parseGammaLine(line)
    local target, day, night, force = string.match(line, "target (%d+)K %(day=(%d+)K night=(%d+)K force=(%l+)")
    if not target then return nil end
    target = tonumber(target)
    local mid = (tonumber(day) + tonumber(night)) / 2
    if force == "true" then return true end
    return target <= mid
end

local function onGammaLine(line)
    local is_night = parseGammaLine(line)
    if is_night ~= nil then
        gamma.night = is_night
        gamma.at_ms = noctalia.nowMs()
        sync()
    end
end

local function startGammaTail()
    local ok = noctalia.runStream("journalctl --user -u noctalia -o cat -n 0 -f --no-pager 2>/dev/null", onGammaLine)
    if not ok then
        noctalia.log("NightLight: gamma tail unavailable, config fallback only")
    end
end

local function seedGamma(cb)
    local done = false
    local function finish()
        if not done then
            done = true
            if cb then cb() end
        end
    end
    local ok = noctalia.runAsync("journalctl --user -u noctalia -o cat --since '5 minutes ago' --no-pager 2>/dev/null | grep '\\[gamma\\]' | tail -3", function(result)
        if result.exitCode == 0 then
            local count = 0
            for line in string.gmatch(result.stdout or "", "[^\n]+") do
                count = count + 1
                local is_night = parseGammaLine(line)
                if is_night ~= nil then
                    gamma.night = is_night
                    gamma.at_ms = noctalia.nowMs()
                end
            end
            noctalia.log("NightLight: seed saw " .. count .. " gamma lines")
        else
            noctalia.log("NightLight: seed query failed: " .. tostring(result.stderr))
        end
        finish()
    end)
    if not ok then finish() end
end

local function nightState()
    if gamma.night ~= nil and (noctalia.nowMs() - gamma.at_ms) < GAMMA_FRESH_MS then
        if gamma.night then return true, "gamma" end
        return false, "gamma-day"
    end
    if noctalia.getSetting("nightlight.force") == true then return true, "force" end
    if noctalia.getSetting("nightlight.enabled") ~= true then return false, "disabled" end
    if noctalia.isDarkMode() then return true, "schedule" end
    return false, "daytime"
end

local function parseScheme(output)
    if type(output) ~= "string" then return nil end
    local source, name = string.match(output, "^(%S+)%s+(.-)%s*$")
    if not source or not name or name == "" then return nil end
    return { source = source, name = name }
end

local function getCurrentScheme(cb)
    local ok = noctalia.runAsync({ "noctalia", "msg", "color-scheme-get" }, function(result)
        if result.exitCode ~= 0 then
            cb(nil, "color-scheme-get failed: " .. tostring(result.stderr))
            return
        end
        local scheme = parseScheme(noctalia.string.trim(result.stdout or ""))
        if scheme then
            cb(scheme, nil)
        else
            cb(nil, "color-scheme-get gave unparsable output")
        end
    end)
    if not ok then cb(nil, "color-scheme-get not accepted") end
end

local function applyScheme(scheme, cb)
    local ok = noctalia.runAsync({ "noctalia", "msg", "color-scheme-set", scheme.source, scheme.name }, function(result)
        if cb then cb(result.exitCode == 0, tostring(result.stderr)) end
    end)
    if not ok and cb then cb(false, "color-scheme-set not accepted") end
end

local function saveDayWallpapers()
    local saved = {}
    local outputs = noctalia.outputs()
    if type(outputs) ~= "table" then return saved end
    for _, out in ipairs(outputs) do
        if type(out) == "table" and type(out.name) == "string" then
            saved[out.name] = noctalia.wallpaperPath(out.name)
        end
    end
    return saved
end

local function getDefaultWallpaper(cb)
    local ok = noctalia.runAsync({ "noctalia", "msg", "wallpaper-get" }, function(result)
        if result.exitCode ~= 0 then
            cb(nil)
            return
        end
        local path = noctalia.string.trim(result.stdout or "")
        if path == "" then cb(nil) else cb(path) end
    end)
    if not ok then cb(nil) end
end

local function restoreDayWallpapers()
    if type(state.day_default) == "string" and state.day_default ~= "" then
        noctalia.setWallpaper(state.day_default)
    end
    if type(state.day_wallpapers) ~= "table" then return end
    for connector, path in pairs(state.day_wallpapers) do
        if type(path) == "string" and path ~= "" and noctalia.fileExists(path) then
            noctalia.setWallpaper(connector, path)
        end
    end
end

local function listImages(dir)
    local names = noctalia.listDir(dir)
    if not names then return nil end
    local images = {}
    for _, name in ipairs(names) do
        local ext = string.match(string.lower(name), "%.(%w+)$")
        if ext and IMAGE_EXTS[ext] then
            local info = noctalia.fileInfo(dir .. "/" .. name)
            if info and not info.isDir then table.insert(images, name) end
        end
    end
    table.sort(images)
    return images
end

local function setNightWallpaper(cfg)
    local dir = noctalia.expandPath(cfg.dir)
    noctalia.mkdirAll(dir)
    local images = listImages(dir)
    if not images or #images == 0 then
        if not missing_logged then
            noctalia.log("NightLight: no wallpapers in " .. dir)
            missing_logged = true
        end
        return
    end
    missing_logged = false
    state.index = (state.index % #images) + 1
    noctalia.setWallpaper(dir .. "/" .. images[state.index])
    state.images_sig = table.concat(images, "\n")
    saveState()
end

local function nightDirImages(cfg)
    local dir = noctalia.expandPath(cfg.dir)
    local images = listImages(dir) or {}
    return dir, images, table.concat(images, "\n")
end

local function underNightDir(cfg)
    local dir = noctalia.expandPath(cfg.dir)
    local prefix = dir .. "/"
    local outputs = noctalia.outputs()
    if type(outputs) ~= "table" then return true end
    for _, out in ipairs(outputs) do
        if type(out) == "table" and type(out.name) == "string" then
            local path = noctalia.wallpaperPath(out.name)
            if type(path) == "string" and path ~= "" and string.sub(path, 1, #prefix) ~= prefix then
                return false
            end
        end
    end
    return true
end

local function ensureNightWallpaper(cfg, why)
    if not underNightDir(cfg) then
        noctalia.log("NightLight: applying night wallpaper (" .. why .. ")")
        setNightWallpaper(cfg)
    end
end

local function enterNight(cfg)
    missing_logged = false
    getCurrentScheme(function(current, err)
        if not current then
            busy = false
            fail(err or "could not read current palette")
            return
        end
        local night = { source = cfg.source, name = cfg.name }
        local already = current.source == night.source and current.name == night.name
        if not already then
            state.day_scheme = current
            state.day_wallpapers = saveDayWallpapers()
            saveState()
        end
        getDefaultWallpaper(function(def)
            if def and not already then
                state.day_default = def
                saveState()
            end
            if already then
                busy = false
                state.active = "night"
                saveState()
                fail_notified = false
            else
                applyScheme(night, function(ok, setErr)
                    busy = false
                    if ok then
                        state.active = "night"
                        saveState()
                        fail_notified = false
                    else
                        fail("night palette '" .. night.source .. " " .. night.name .. "' failed: " .. setErr)
                    end
                end)
            end
            if not night_wallpaper_set then
                night_wallpaper_set = true
                setNightWallpaper(cfg)
            end
        end)
    end)
end

local function enterDay()
    missing_logged = false
    night_wallpaper_set = false
    local day = state.day_scheme
    restoreDayWallpapers()
    if type(day) ~= "table" then
        busy = false
        state.active = "day"
        saveState()
        fail("no saved day palette, keeping current")
        return
    end
    getCurrentScheme(function(current, err)
        if not current then
            busy = false
            fail(err or "could not read current palette")
            return
        end
        if current.source ~= day.source or current.name ~= day.name then
            applyScheme(day, function(ok, setErr)
                busy = false
                if ok then
                    state.active = "day"
                    saveState()
                    fail_notified = false
                else
                    fail("day palette restore failed: " .. setErr)
                end
            end)
        else
            busy = false
            state.active = "day"
            saveState()
            fail_notified = false
        end
    end)
end

function sync()
    if busy then return end
    local cfg = nightConfig()
    local want, why = nightState()
    if want then
        if state.active ~= "night" then
            busy = true
            noctalia.log("NightLight: night active (" .. why .. "), applying " .. cfg.source .. " " .. cfg.name)
            enterNight(cfg)
        else
            local _, _, sig = nightDirImages(cfg)
            if sig ~= "" and sig ~= state.images_sig then
                ensureNightWallpaper(cfg, "directory changed")
            end
        end
    elseif state.active ~= "day" then
        busy = true
        noctalia.log("NightLight: day active (" .. why .. "), restoring user settings")
        enterDay()
    end
end

local function reconcile()
    getCurrentScheme(function(current)
        if current and state.active == "night" then
            local cfg = nightConfig()
            local is_night = current.source == cfg.source and current.name == cfg.name
            local day = state.day_scheme
            local is_day = type(day) == "table" and current.source == day.source and current.name == day.name
            if not is_night and is_day then
                state.active = "day"
                saveState()
                noctalia.log("NightLight: stale night flag healed, will retry")
            end
        end
        busy = false
        if state.active == "night" then
            ensureNightWallpaper(nightConfig(), "startup check")
        end
        sync()
    end)
end

function update()
    sync()
end

function onConfigChanged()
    sync()
end

function onExit(_signal, reason)
    if (reason == "disable" or reason == "uninstall") and state.active == "night" then
        local day = state.day_scheme
        if type(day) == "table" then
            noctalia.runAsync("noctalia msg color-scheme-set " .. day.source .. " " .. day.name)
        end
    end
end

noctalia.setUpdateInterval(5000)
loadState()
startGammaTail()
seedGamma(reconcile)
