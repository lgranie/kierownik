--!nonstrict
-- Kierownik tasks launcher provider for Noctalia v5.
-- Type /krw in the launcher to browse by group or search tasks.
-- Task catalog is discovered from TASKS_DIR at plugin load and
-- prebuilt into result rows; onQuery only filters.
-- Selected tasks run in a terminal (interactive tasks need a TTY).

local TASKS_DIR = "/usr/lib/kierownik/tasks/"
local HOLD_SECONDS = 10

-- Parse a task file: MISE description becomes the title.
-- A task is listed only when every required positional arg
-- (#USAGE arg "<...>") declares default=. Required args without
-- a default stay hidden since the launcher passes no arguments.
local function hasUnsatisfiableArg(content)
    for line in content:gmatch("[^\n]+") do
        if line:match('#USAGE arg "<') and not line:match("default=") then
            return true
        end
    end
    return false
end

local function parseTaskFile(path)
    local content = noctalia.readFile(path)
    if not content then return nil end
    local desc = content:match('#MISE description="([^"]+)"')
    if not desc then return nil end
    if hasUnsatisfiableArg(content) then return nil end
    return desc
end

-- Discover groups (subdirectories) and runnable tasks inside each.
-- listDir returns bare filenames, but strip any directory prefix
-- defensively so absolute entries still resolve.
local function basename(p)
    return p:match("([^/]+)$") or p
end

local function discoverTasks()
    local found = {}
    local groups, err = noctalia.listDir(TASKS_DIR)
    if not groups then
        noctalia.log("krw: listDir " .. TASKS_DIR .. " failed: " .. tostring(err))
        return found
    end
    table.sort(groups)
    for _, rawG in ipairs(groups) do
        local g = basename(rawG)
        local groupPath = TASKS_DIR .. g
        local info = noctalia.fileInfo(groupPath)
        if info and info.isDir then
            local files, ferr = noctalia.listDir(groupPath)
            if not files then
                noctalia.log("krw: listDir " .. groupPath .. " failed: " .. tostring(ferr))
            else
                table.sort(files)
                for _, rawF in ipairs(files) do
                    local f = basename(rawF)
                    -- Skip helpers (underscore prefix) and dotted names.
                    if not f:match("^_") and not f:match("%.") then
                        local desc = parseTaskFile(groupPath .. "/" .. f)
                        if desc then
                            table.insert(found, { group = g, name = f, title = desc, path = g .. "/" .. f, args = {} })
                        end
                    end
                end
            end
        end
    end
    return found
end

local tasks = discoverTasks()
noctalia.log("krw: discovered " .. #tasks .. " tasks in " .. TASKS_DIR)
if #tasks == 0 then
    noctalia.log("krw: no tasks found, check " .. TASKS_DIR .. " exists and task files carry #MISE description")
end

local selectedCategory = "all"
local currentQuery = ""

-- Prebuilt once at plugin load: formatted entries, search haystacks,
-- per-group index, and category browse rows.
local entries = {}
local byGroup = {}
local categoryEntries = {}
local categories = {}

for _, t in ipairs(tasks) do
    local entry = {
        id = t.path,
        title = t.title,
        subtitle = t.group .. " / " .. t.name,
        glyph = "terminal",
        group = t.group,
        haystack = (t.group .. " " .. t.name .. " " .. t.title):lower(),
    }
    table.insert(entries, entry)
    if not byGroup[t.group] then
        byGroup[t.group] = {}
        table.insert(categories, t.group)
        table.insert(categoryEntries, { id = "category:" .. t.group, title = t.group, subtitle = "Browse category", glyph = "tag" })
    end
    table.insert(byGroup[t.group], entry)
end

local function getSettings()
    return {
        terminal = noctalia.getConfig("terminal") or "footclient",
    }
end

local function findTask(path)
    for _, t in ipairs(tasks) do
        if t.path == path then return t end
    end
    return nil
end

function onQuery(query)
    currentQuery = query or ""
    local text = noctalia.string.trim(currentQuery) or ""

    if #entries == 0 then
        launcher.setResults(currentQuery, {
            { id = "", title = "No tasks found", subtitle = "Check " .. TASKS_DIR, glyph = "mood-empty" },
        })
        return
    end

    if text == "" then
        selectedCategory = "all"
        local results = {}
        for _, c in ipairs(categoryEntries) do table.insert(results, c) end
        for _, e in ipairs(entries) do table.insert(results, e) end
        launcher.setResults(currentQuery, results)
        return
    end

    local lowerQuery = text:lower()
    local activeCategory = selectedCategory
    if activeCategory == "all" then
        for _, c in ipairs(categories) do
            if lowerQuery == c:lower() then
                activeCategory = c
                break
            end
        end
    end

    local pool = entries
    if activeCategory ~= "all" then
        pool = byGroup[activeCategory] or {}
    end

    local showAll = activeCategory ~= "all" and lowerQuery == activeCategory:lower()
    local results = {}
    local count = 0
    for _, e in ipairs(pool) do
        if count >= 50 then break end
        if showAll or e.haystack:find(lowerQuery, 1, true) then
            table.insert(results, e)
            count = count + 1
        end
    end

    if #results == 0 then
        table.insert(results, { id = "", title = "No results", subtitle = "No tasks found", glyph = "mood-empty" })
    end

    launcher.setResults(currentQuery, results)
end

function onActivate(id)
    local settings = getSettings()

    local category = id:match("^category:(.+)$")
    if category then
        selectedCategory = category
        -- setQuery takes text after our prefix; the host adds the
        -- prefix itself. Never hardcode "/krw" here.
        launcher.setQuery(category .. " ")
        return
    end

    local task = findTask(id)
    if not task then return end

    local inner = TASKS_DIR .. task.path
    for _, a in ipairs(task.args) do
        inner = inner .. " " .. a
    end
    local wrapped = inner .. '; printf "\\n--- done, closing in ' .. HOLD_SECONDS .. 's ---\\n"; sleep ' .. HOLD_SECONDS
    -- Float rule matches foot app-id; other terminals tile.
    local cmd = { settings.terminal }
    if settings.terminal == "foot" or settings.terminal == "footclient" then
        table.insert(cmd, "--app-id=krw-task")
    end
    table.insert(cmd, "sh")
    table.insert(cmd, "-c")
    table.insert(cmd, wrapped)
    noctalia.runAsync(cmd)
end
