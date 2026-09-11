-- Copyright (C) 2026 PrincessSiren
--
-- This program is free software: you can redistribute it and/or modify it
-- under the terms of the GNU General Public License as published by the Free
-- Software Foundation, either version 3 of the License, or (at your option)
-- any later version.
--
-- This program is distributed in the hope that it will be useful, but WITHOUT
-- ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
-- FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
-- more details. You should have received a copy of the GNU General Public
-- License along with this program. If not, see <https://www.gnu.org/licenses/>.

-- AchaeaBeckon -- who is allowed to move you.
--
-- Global namespace is `beckonlist`, which is also the command prefix. It is
-- deliberately long. This is not a reflex you drive: you set the list up once
-- and then forget it, so nothing here is worth a short name at the front of a
-- command line -- where a bare `beckon` would collide with the game's own verb.
-- That was a guess when the prefix was chosen and is now settled: BECKON is a
-- real emote, and `SHOWEMOTE BECKON` prints its text from every side.
--
-- A beckon moves you to somebody else's room without asking, and accepting one
-- is not a single room change you could walk back. HELP 6.4 GROUPS AND
-- ENTOURAGES, under Group Movement: "If you follow another adventurer, then
-- when he moves, you'll move too (assuming you can)." Following hands over
-- where your character is until you LOSE them or walk away, which is why the
-- answer is a list rather than a prompt. That is fine when it is one of four
-- people you raid with and a problem when it is not, so the whole package is
-- one question asked of one line of game output: is this name on the list?
-- Trusted, and you follow automatically; not trusted, and you get a red line
-- and nothing is sent.
--
-- Two things are worth knowing before reading further.
--
-- The line is captured, not inferred. `SHOWEMOTE BECKON` prints an emote from
-- every side at once, and what the person being beckoned reads is:
--
--   Vellis will see: Aliapoe beckons you to her.
--
-- Actor's name first, "you" as the object, " to <pronoun>", terminal period --
-- HELP 3.8 EMOTIONS' directed-emote shape exactly, which is why the pattern
-- read off that shape before any capture existed turned out to match. Type
-- `SHOWEMOTE BECKON` in game to print all three perspectives again.
--
-- M.DEFAULT_PATTERN still stops at "you" rather than anchoring the tail, and
-- the same capture is the reason. The pronoun belongs to the *actor* -- "to
-- her" is Aliapoe's, not Vellis's, matching 3.8's "flutters her eyelashes" --
-- so it changes with whoever beckoned you, and only "her" is attested. There
-- is still no evidence for the rest of the set, and `(him|her|them)$` against
-- a set nobody has seen is a reflex that silently never fires: the worst
-- failure available here. The whitelist does the deciding; the pattern only
-- has to find the name.
--
-- The same capture supplies the two lines it must *not* fire on, which were
-- imagined before and are now known:
--
--   Aliapoe makes a beckoning motion.   (untargeted beckon, as onlookers see it)
--   Aliapoe beckons Vellis to her.      (targeted beckon, as onlookers see it)
--
-- Both are in the harness. `beckonlist test <line>` and `beckonlist pattern
-- <regex>` still take a correction in game without a rebuild, which is what
-- the tail being open is for.
--
-- The other thing is what is sent. HELP 6.4 GROUPS AND ENTOURAGES: you join a
-- group with FOLLOW, and you leave it by LOSE-ing "the person you are
-- following (or is following you), or simply walk away from the group". So a
-- LOSE aimed at the beckoner is aimed at the wrong person -- it names the one
-- you are about to follow rather than the one you are leaving -- and FOLLOW is
-- what actually moves you into the new group. Only the follow is sent.
--
-- Reads Orion if it is there, one-way and optionally, for the ally/city note
-- on the alert line. No Orion, no note, no error.

beckonlist = beckonlist or {}
local M = beckonlist

M.VERSION = "0.1.2"

-- Both filled in by build.py; see the same pair in AchaeaExplorer.lua.
M.COMMANDS = M.COMMANDS or {}
M.BUILD = M.BUILD or "source"

-- Hung off the module table rather than kept in a file-local, so a script
-- recompile finds the live trigger and handler ids and tears them down instead
-- of leaving a second copy running over the top. Mudlet clears
-- mAnonymousEventHandlerFunctions only in Host::resetProfile, and a temporary
-- trigger lives until something calls killTrigger on it.
M.state = M.state or {
    triggerId = nil,
    handlers  = {},
    recent    = {},   -- the last few beckons seen, newest last
    seen      = 0,    -- beckons matched since this script loaded
    followed  = 0,
    refused   = 0,
    name      = nil,  -- your own character name, from gmcp.Char.Name
    -- Where the saved list stood when this script last started: "fresh" (no
    -- file yet), "loaded", or "unreadable". `beckonlist status` prints it,
    -- because "is my list still there after that update?" is a question the
    -- package can answer and the player cannot.
    loaded      = "fresh",
    loadedCount = 0,
    savedAt     = nil,
}
local S = M.state

-- A recompile finds an M.state built by whichever version was installed
-- before, so a key that version had never heard of is still nil.
S.recent = S.recent or {}
S.loaded = S.loaded or "fresh"
S.loadedCount = S.loadedCount or 0

-- The half of the pattern that is actually known. See the header.
M.DEFAULT_PATTERN = [[^(\w+) beckons you]]

-- Nothing is pre-populated. The same rule as the Occultist kit's DEFENCE_OFF
-- and the Explorer's skip list: a list of names that can move you is not a
-- thing to fill in from memory.
M.trust = M.trust or {}   -- Titled name -> { since = os.time(), note = string }

local CONFIG_DEFAULTS = {
    armed   = true,               -- follow a trusted beckon; false alerts only
    follow  = "fol",              -- what gets sent: "<follow> <name>"
    pattern = M.DEFAULT_PATTERN,
    recent  = 10,                 -- how many `beckonlist last` remembers
}

M.config = M.config or {}
for key, value in pairs(CONFIG_DEFAULTS) do
    if M.config[key] == nil then
        M.config[key] = value
    end
end

M.file = nil   -- set in start(), so this file still loads under luajit

-- ---------------------------------------------------------------------------
-- helpers
-- ---------------------------------------------------------------------------

local function info(text)
    cecho("<ansi_light_cyan>[beckon] <reset>" .. text .. "\n")
end

local function warn(text)
    cecho("<ansi_light_cyan>[beckon] <ansi_yellow>" .. text .. "<reset>\n")
end

local function trim(s)
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- Mudlet hands an unmatched optional capture over as "" rather than nil.
local function given(value)
    value = trim(value or "")
    if value == "" then
        return nil
    end
    return value
end

--- Achaea names are Titlecase, and every table here is keyed that way so
--- `beckonlist add vellis` and a game line saying "Vellis" are the same person.
local function titled(name)
    name = trim(name or "")
    if name == "" then
        return ""
    end
    return name:sub(1, 1):upper() .. name:sub(2):lower()
end

local function count(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

local function names()
    local list = {}
    for name in pairs(M.trust) do list[#list + 1] = name end
    table.sort(list)
    return list
end

--- "  since 2026-09-09", or nothing for an entry with no date -- which is what
--- a hand-edited file gives you.
local function since(entry)
    return type(entry) == "table" and entry.since
        and os.date("%Y-%m-%d", entry.since) or nil
end

-- ---------------------------------------------------------------------------
-- persistence
-- ---------------------------------------------------------------------------
--
-- Written and read as one envelope with two named keys, adjacent, because the
-- Occultist kit lost a key the hard way: what is saved but not loaded comes
-- back empty and the next edit writes that emptiness over the file. Config is
-- filtered through CONFIG_DEFAULTS on the way in, so a setting dropped in a
-- later version does not come back to life out of an old file.

function M.save()
    if not M.file then
        return false
    end
    -- A file that would not parse is never written over. Whatever is in it is
    -- the only copy of a list that was typed in by hand, so it goes aside
    -- under .bad and the state in memory is written beside it. Silently
    -- overwriting is the one outcome that loses names for good.
    if S.loaded == "unreadable" then
        local kept = M.file .. ".bad"
        if pcall(os.rename, M.file, kept) then
            warn("kept the unreadable file as " .. kept)
        end
        S.loaded = "fresh"
    end
    local ok = pcall(table.save, M.file, { trust = M.trust, config = M.config })
    if not ok then
        warn("could not save the trusted list")
        return false
    end
    S.savedAt = os.time()
    return true
end

function M.load()
    if not M.file then
        return false
    end
    if not io.exists(M.file) then
        S.loaded, S.loadedCount = "fresh", 0
        return false
    end
    local stored = {}
    if not pcall(table.load, M.file, stored) or type(stored) ~= "table" then
        -- Saying nothing here would be the expensive kind of quiet: the next
        -- `beckonlist add` would write over a file that may still hold every
        -- name in it. save() moves it aside instead, and this says so while
        -- there is still time to go and look at it.
        S.loaded, S.loadedCount = "unreadable", 0
        warn("could not read " .. M.file .. " -- your trusted list is NOT "
            .. "loaded. It will be kept as " .. M.file
            .. ".bad rather than overwritten.")
        return false
    end
    if type(stored.trust) == "table" then
        M.trust = stored.trust
    end
    if type(stored.config) == "table" then
        for key, value in pairs(stored.config) do
            if CONFIG_DEFAULTS[key] ~= nil
                and type(value) == type(CONFIG_DEFAULTS[key]) then
                M.config[key] = value
            end
        end
    end
    S.loaded = "loaded"
    S.loadedCount = count(M.trust)
    return true
end

-- ---------------------------------------------------------------------------
-- Orion, read one-way and optionally
-- ---------------------------------------------------------------------------

--- "Blademaster, Mhaldor, enemy", or nil. The same lookup the Occultist kit
--- does for its target line -- duplicated rather than shared, because these
--- packages install separately and none of them may depend on another.
function M.describe(name)
    local ori = rawget(_G, "ori")
    if type(ori) ~= "table" then
        return nil
    end

    local key = titled(name)
    local parts = {}

    local ndb = ori.ndb
    if type(ndb) == "table" and type(ndb.db) == "table" then
        local entry = ndb.db[key]
        if type(entry) == "table" then
            if entry.class and entry.class ~= "" then
                parts[#parts + 1] = entry.class
            end
            if entry.city and entry.city ~= "" then
                parts[#parts + 1] = entry.city
            end
        end
    end

    -- Your in-game ALLY/ENEMY lists, which Orion mirrors from the game. They
    -- are shown, never obeyed: an ally list is a courtesy, and this list is
    -- about who is allowed to move you.
    if type(ori.allies) == "table" and ori.allies[key] then
        parts[#parts + 1] = "ALLY"
    elseif type(ori.enemies) == "table" and ori.enemies[key] then
        parts[#parts + 1] = "enemy"
    end

    if #parts == 0 then
        return nil
    end
    return table.concat(parts, ", ")
end

-- ---------------------------------------------------------------------------
-- the reflex
-- ---------------------------------------------------------------------------

local function remember(who, what)
    S.recent[#S.recent + 1] = { name = who, what = what, when = os.time() }
    local keep = tonumber(M.config.recent) or 10
    while #S.recent > keep do
        table.remove(S.recent, 1)
    end
end

--- The trigger's other end. Mudlet calls it with no arguments and leaves the
--- captures in the global `matches`; the harness passes a table instead.
function M.onBeckon(captured)
    captured = captured or rawget(_G, "matches") or {}
    local who = titled(captured[2] or "")
    if who == "" then
        return false
    end

    S.seen = S.seen + 1

    -- Nobody beckons themselves, but a reflex that can send `fol <you>` is
    -- worth one comparison to rule out.
    if S.name and who == S.name then
        return false
    end

    local note = M.describe(who)
    local tail = note and (" <ansi_light_black>(" .. note .. ")<reset>") or ""
    local entry = M.trust[who]

    if not entry then
        S.refused = S.refused + 1
        remember(who, "not trusted")
        cecho("<ansi_light_red>[BECKON] <reset>" .. who
            .. "<ansi_light_red> beckoned you and is NOT on your trusted list."
            .. "<reset>" .. tail .. "\n")
        return false
    end

    if not M.config.armed then
        remember(who, "trusted, disarmed")
        cecho("<ansi_light_cyan>[beckon] <reset>" .. who
            .. " beckoned you -- trusted, but `beckonlist off` is set."
            .. tail .. "\n")
        return false
    end

    S.followed = S.followed + 1
    remember(who, "followed")
    cecho("<ansi_light_green>[beckon] <reset>" .. who
        .. "<ansi_light_green> beckoned you -- trusted, following.<reset>"
        .. tail .. "\n")
    send(M.config.follow .. " " .. who)
    return true
end

-- ---------------------------------------------------------------------------
-- the pattern
-- ---------------------------------------------------------------------------
--
-- Mudlet loads lrexlib as `rex_pcre` (TLuaInterpreter.cpp tries rex_pcre2
-- first and aliases it to that name), but it warns rather than fails when the
-- module is missing, so every use of it is optional. It is the same engine the
-- trigger itself compiles with -- not the same flags -- which makes it good
-- enough to catch a regex that will not compile and a pattern that plainly
-- does not match the line you just pasted, and no substitute for typing at the
-- game and watching what happens.

--- "ok" plus the compiled pattern, "bad" plus the error, or "unknown".
local function compile(pattern)
    local rex = rawget(_G, "rex_pcre")
    if type(rex) ~= "table" or type(rex.new) ~= "function" then
        return "unknown"
    end
    local ok, compiled = pcall(rex.new, pattern)
    if not ok then
        return "bad", tostring(compiled)
    end
    return "ok", compiled
end

--- Who a line would name, or nil. nil means "no match" and also "could not
--- check"; the caller looks at the status to tell them apart.
function M.matchLine(text)
    local status, compiled = compile(M.config.pattern)
    if status ~= "ok" then
        return nil, status, compiled
    end
    local ok, capture = pcall(function() return compiled:match(text) end)
    if not ok or type(capture) ~= "string" then
        return nil, "ok"
    end
    return titled(capture), "ok"
end

function M.installTrigger()
    if S.triggerId then
        pcall(killTrigger, S.triggerId)
        S.triggerId = nil
    end
    if type(tempRegexTrigger) ~= "function" then
        return false
    end
    local status, err = compile(M.config.pattern)
    if status == "bad" then
        warn("that pattern will not compile: " .. tostring(err))
        return false
    end
    local ok, id = pcall(tempRegexTrigger, M.config.pattern, M.onBeckon)
    if not ok or not id then
        warn("could not install the beckon trigger")
        return false
    end
    S.triggerId = id
    return true
end

-- ---------------------------------------------------------------------------
-- commands
-- ---------------------------------------------------------------------------

function M.trustAdd(argument)
    argument = given(argument)
    if not argument then
        warn("who? `beckonlist add <name>`")
        return false
    end

    -- "Vellis: raids with me on Thursdays" -- the note is optional and the
    -- same shape the Explorer's `xpl block` uses.
    local who, note = argument:match("^([^:]+):%s*(.*)$")
    who = titled(who or argument)
    note = given(note)

    if who == "" then
        warn("who? `beckonlist add <name>`")
        return false
    end

    local entry = M.trust[who]
    if type(entry) ~= "table" then
        entry = { since = os.time() }
        M.trust[who] = entry
    end
    -- A re-add keeps the date and the reason recorded the first time, unless a
    -- new one was actually typed.
    if note then
        entry.note = note
    end

    M.save()
    info(who .. " can move you." .. (entry.note and (" (" .. entry.note .. ")") or ""))
    return true
end

function M.trustRemove(argument)
    local who = titled(given(argument) or "")
    if who == "" then
        warn("who? `beckonlist rm <name>`")
        return false
    end
    if not M.trust[who] then
        warn(who .. " was not on the list.")
        return false
    end
    M.trust[who] = nil
    M.save()
    info(who .. " can no longer move you.")
    return true
end

function M.trustList()
    local list = names()
    if #list == 0 then
        info("nobody is trusted -- every beckon gets a red line and nothing "
            .. "is sent. `beckonlist add <name>` to change that.")
        return true
    end
    cecho("<ansi_light_cyan>[beckon] <reset>" .. #list
        .. (#list == 1 and " name" or " names") .. " can move you:\n")
    for _, who in ipairs(list) do
        local entry = M.trust[who]
        local when = since(entry)
        local note = type(entry) == "table" and entry.note or nil
        cecho("  <ansi_light_green>" .. who .. "<reset>"
            .. (note and ("  " .. note) or "")
            .. (when and ("  <ansi_light_black>since " .. when .. "<reset>") or "")
            .. "\n")
    end
    return true
end

function M.arm(on)
    M.config.armed = on and true or false
    M.save()
    -- Reported through M.statusLine rather than in words of its own; the rest
    -- of the block is what `beckonlist status` is for.
    return M.statusLine()
end

function M.setFollow(argument)
    local command = given(argument)
    if not command then
        info("a trusted beckon sends `" .. M.config.follow .. " <name>`.")
        return true
    end
    M.config.follow = command
    M.save()
    info("a trusted beckon now sends `" .. command .. " <name>`.")
    return true
end

function M.setPattern(argument)
    local pattern = given(argument)
    if not pattern then
        info("pattern: " .. M.config.pattern)
        if M.config.pattern ~= M.DEFAULT_PATTERN then
            cecho("  <ansi_light_black>default: " .. M.DEFAULT_PATTERN
                .. "<reset>\n")
        end
        cecho("  <ansi_light_black>the capture is the name; "
            .. "`beckonlist pattern default` puts it back<reset>\n")
        return true
    end

    if pattern:lower() == "default" then
        pattern = M.DEFAULT_PATTERN
    end

    local status, err = compile(pattern)
    if status == "bad" then
        warn("that will not compile: " .. tostring(err))
        return false
    end
    if status == "unknown" then
        warn("rex_pcre is not loaded, so the pattern could not be checked "
            .. "before installing it -- watch a real beckon.")
    end

    M.config.pattern = pattern
    M.save()
    info("pattern: " .. pattern)
    return M.installTrigger()
end

--- Paste a line the game printed and see what the reflex would have made of
--- it. Sends nothing, whatever it decides.
function M.test(argument)
    local text = given(argument)
    if not text then
        warn("`beckonlist test <a line the game printed>`")
        return false
    end

    local who, status, err = M.matchLine(text)
    if status == "unknown" then
        warn("rex_pcre is not loaded, so this cannot be checked here.")
        return false
    end
    if status == "bad" then
        warn("the pattern will not compile: " .. tostring(err))
        return false
    end
    if not who then
        cecho("<ansi_light_cyan>[beckon] <ansi_yellow>no match<reset> -- that "
            .. "line would go past unnoticed.\n")
        cecho("  <ansi_light_black>pattern: " .. M.config.pattern
            .. "<reset>\n")
        return false
    end

    local trusted = M.trust[who] ~= nil
    cecho("<ansi_light_cyan>[beckon] <reset>matches, name is "
        .. "<ansi_light_yellow>" .. who .. "<reset>\n")
    if trusted and M.config.armed then
        cecho("  would send <ansi_light_green>" .. M.config.follow .. " "
            .. who .. "<reset>\n")
    elseif trusted then
        cecho("  trusted, but disarmed -- would send nothing\n")
    else
        cecho("  <ansi_light_red>not trusted<reset> -- would send nothing\n")
    end
    return true
end

function M.last()
    if #S.recent == 0 then
        info("no beckons seen since this script loaded.")
        return true
    end
    cecho("<ansi_light_cyan>[beckon] <reset>the last " .. #S.recent .. ":\n")
    for _, row in ipairs(S.recent) do
        cecho(string.format("  <ansi_light_black>%s<reset>  %-16s %s\n",
            os.date("%H:%M:%S", row.when), row.name, row.what))
    end
    return true
end

--- Where the list lives, and whether it was there when this script started.
--- The file is in the profile directory rather than inside the package, so
--- updating or reinstalling AchaeaBeckon does not touch it -- which is the
--- question this line exists to answer, in game, without taking anyone's word
--- for it.
function M.storage()
    if not M.file then
        return "<ansi_yellow>not saved<reset> -- no getMudletHomeDir here"
    end
    if S.loaded == "unreadable" then
        return "<ansi_light_red>UNREADABLE<reset>: " .. M.file
            .. " <ansi_light_black>(kept as .bad, not overwritten)<reset>"
    end
    local tail
    if S.loaded == "loaded" then
        tail = "loaded " .. S.loadedCount .. " "
            .. (S.loadedCount == 1 and "name" or "names") .. " at startup"
    elseif S.savedAt then
        tail = "written " .. os.date("%H:%M:%S", S.savedAt)
    else
        tail = "nothing saved yet"
    end
    return "saved to " .. M.file .. "\n    <ansi_light_black>" .. tail
        .. "; outside the package, so a package update keeps it<reset>"
end

--- "is this thing on?" on one line. Everything that reports the armed state
--- goes through here -- `beckonlist`, `beckonlist status`, `beckonlist on|off`
--- and `beckonlist diag` -- so none of them can word it differently, and
--- turning it on cannot answer differently from asking whether it is on.
function M.statusLine()
    if M.config.armed then
        cecho("<ansi_light_cyan>[beckon] <reset>status: "
            .. "<ansi_light_green>ON<reset> -- a trusted beckon sends `"
            .. M.config.follow .. " <name>`\n")
    else
        cecho("<ansi_light_cyan>[beckon] <reset>status: "
            .. "<ansi_light_red>OFF<reset> -- every beckon is reported, "
            .. "nothing is sent <ansi_light_black>(`beckonlist on` to arm)"
            .. "<reset>\n")
    end
    return true
end

--- That line, plus the state behind it. A toggle prints only the line above;
--- this is what you ask for when the answer is not the one you expected.
function M.status()
    M.statusLine()

    local n = count(M.trust)
    cecho("  trusted: " .. (n > 0
        and ("<ansi_light_green>" .. n .. "<reset> "
            .. (n == 1 and "name" or "names")
            .. " <ansi_light_black>(`beckonlist who`)<reset>")
        or "<ansi_yellow>nobody<reset> -- every beckon is refused") .. "\n")
    cecho("  watching: " .. M.config.pattern
        .. (S.triggerId and ""
            or "  <ansi_light_red>(no trigger installed)<reset>") .. "\n")
    cecho("  " .. M.storage() .. "\n")
    cecho("  seen this session: " .. S.seen .. " ("
        .. S.followed .. " followed, " .. S.refused .. " refused)\n")
    return true
end

function M.report()
    M.status()
    cecho("<ansi_light_black>AchaeaBeckon " .. M.VERSION
        .. " -- who is allowed to move you<reset>\n")
    for _, row in ipairs(M.COMMANDS) do
        cecho(string.format("  <ansi_light_green>%-34s<reset> %s\n",
            row.usage, row.help))
    end
    return true
end

function M.diag()
    cecho("<ansi_light_cyan>AchaeaBeckon " .. M.VERSION
        .. " build " .. M.BUILD .. "<reset>\n")
    M.status()
    cecho("  you: " .. (S.name or "<ansi_yellow>unknown<reset>"
        .. " (no gmcp.Char.Name yet)") .. "\n")
    cecho("  trigger: " .. (S.triggerId and ("id " .. tostring(S.triggerId))
        or "<ansi_light_red>not installed<reset>") .. "\n")
    local status, err = compile(M.config.pattern)
    if status == "unknown" then
        cecho("  <ansi_light_black>rex_pcre not loaded -- `beckonlist test` "
            .. "unavailable<reset>\n")
    elseif status == "bad" then
        cecho("  <ansi_light_red>pattern will not compile: <reset>"
            .. tostring(err) .. "\n")
    end
    cecho("  names: " .. (count(M.trust) > 0
        and table.concat(names(), ", ") or "nobody") .. "\n")
    local ori = rawget(_G, "ori")
    cecho("  orion: " .. (type(ori) == "table" and "loaded" or "not loaded")
        .. "\n")
    return true
end

-- ---------------------------------------------------------------------------
-- start / stop
-- ---------------------------------------------------------------------------

function M.onName()
    local char = gmcp and gmcp.Char and gmcp.Char.Name
    if type(char) == "table" and type(char.name) == "string" then
        S.name = titled(char.name)
    end
    return true
end

local function teardown()
    if S.triggerId then
        pcall(killTrigger, S.triggerId)
        S.triggerId = nil
    end
    for _, id in ipairs(S.handlers) do
        pcall(killAnonymousEventHandler, id)
    end
    S.handlers = {}
end

function M.start()
    teardown()
    -- Resolved here rather than at file scope so the module still loads under
    -- plain luajit, where getMudletHomeDir does not exist.
    if type(getMudletHomeDir) == "function" then
        M.file = getMudletHomeDir() .. "/achaea-beckon.lua"
        M.load()
    end
    S.handlers = {
        registerAnonymousEventHandler("gmcp.Char.Name", M.onName),
    }
    -- The frame usually landed long before this script was recompiled.
    M.onName()
    M.installTrigger()
    return true
end

function M.stop()
    teardown()
    return true
end

-- The script body re-runs whenever Mudlet recompiles it, so this also covers
-- editing and reinstalling without a profile restart.
M.start()

info("AchaeaBeckon " .. M.VERSION
    .. " loaded -- type `beckonlist` for commands")
