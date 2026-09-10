-- Drives AchaeaBeckon.lua under plain luajit against a stubbed Mudlet.
--
--   luajit test_harness.lua        (it resolves its own directory, so
--                                   either directory works)
--
-- The question this package has to get right is small and one-sided: a line
-- arrives, and either it moves you or it does not. So most of what is below
-- drives that decision -- trusted, not trusted, disarmed, yourself -- through
-- the trigger rather than by calling the handler directly, because the trigger
-- is where the captures come from and `matches[2]` is the easy thing to get
-- wrong.
--
-- The rex_pcre stub is a translator, not a regex engine. Mudlet loads lrexlib
-- under that name and the package uses it to check a pattern before installing
-- it; here it understands the handful of constructs these patterns use and
-- refuses an unbalanced one, which is enough to drive both paths.

local HERE = (arg and arg[0] or ""):match("^(.*)[/\\]") or "."

local ECHOED = {}
function cecho(text) ECHOED[#ECHOED + 1] = (text:gsub("\n$", "")) end
function echo(text) ECHOED[#ECHOED + 1] = (text:gsub("\n$", "")) end

local SENT = {}
function send(command) SENT[#SENT + 1] = command end

local function clear() ECHOED, SENT = {}, {} end
local function echoed(fragment)
  for _, line in ipairs(ECHOED) do
    if line:find(fragment, 1, true) then return true end
  end
  return false
end
local function sent(command)
  for _, line in ipairs(SENT) do
    if line == command then return true end
  end
  return false
end

HANDLERS = {}
local seq = 0
function registerAnonymousEventHandler(event, fn)
  seq = seq + 1
  HANDLERS[seq] = { event = event, fn = fn }
  return seq
end
function killAnonymousEventHandler(id) HANDLERS[id] = nil end
local function liveHandlers()
  local n = 0
  for _ in pairs(HANDLERS) do n = n + 1 end
  return n
end

-- ---- a fake profile directory --------------------------------------------
-- table.save/table.load are Mudlet's pickling pair; what the package depends
-- on is their shape -- save takes the whole table, load populates the table it
-- is handed -- so the stub keeps that and holds the bytes in memory.
local DISK = {}
local function deepcopy(value)
  if type(value) ~= "table" then return value end
  local copy = {}
  for k, v in pairs(value) do copy[k] = deepcopy(v) end
  return copy
end
table.save = function(path, t) DISK[path] = deepcopy(t) end
table.load = function(path, into)
  local stored = DISK[path]
  -- Mudlet's table.load runs the file as Lua, so a half-written one raises
  -- rather than returning nothing. CORRUPT stands in for that.
  if stored == "CORRUPT" then error("unexpected symbol near '<eof>'", 0) end
  for k, v in pairs(deepcopy(stored) or {}) do into[k] = v end
end
os.rename = function(from, to)
  if DISK[from] == nil then return nil, "no such file" end
  DISK[to], DISK[from] = DISK[from], nil
  return true
end
io.exists = function(path) return DISK[path] ~= nil end
function getMudletHomeDir() return "/harness" end

-- ---- rex_pcre, translated -------------------------------------------------
local function translate(regex)
  local depth = 0
  for char in regex:gmatch("[()]") do
    depth = depth + (char == "(" and 1 or -1)
    if depth < 0 then error("unmatched ) in pattern", 0) end
  end
  if depth ~= 0 then error("missing ) in pattern", 0) end
  return (regex
    :gsub("%%", "%%%%")
    :gsub("\\w", "%%w")
    :gsub("\\s", "%%s")
    :gsub("\\d", "%%d")
    :gsub("\\%.", "%%."))
end

rex_pcre = {
  new = function(pattern)
    local lua = translate(pattern)
    return {
      match = function(_, subject) return subject:match(lua) end,
    }
  end,
}

-- ---- triggers -------------------------------------------------------------
TRIGGERS = {}
local tseq = 0
function tempRegexTrigger(pattern, fn)
  tseq = tseq + 1
  TRIGGERS[tseq] = { pattern = pattern, fn = fn }
  return tseq
end
function killTrigger(id) TRIGGERS[id] = nil end
local function liveTriggers()
  local n = 0
  for _ in pairs(TRIGGERS) do n = n + 1 end
  return n
end

--- What Mudlet does with a line: match, fill the global `matches` with the
--- whole match followed by the captures, call the handler.
local function feed(text)
  local fired = false
  for _, trigger in pairs(TRIGGERS) do
    local lua = translate(trigger.pattern)
    local found = { text:find(lua) }
    if found[1] then
      local m = { text:sub(found[1], found[2]) }
      for i = 3, #found do m[#m + 1] = found[i] end
      matches = m
      trigger.fn()
      fired = true
    end
  end
  return fired
end

gmcp = { Char = { Name = { name = "Thoth" } } }

-- ---------------------------------------------------------------------------

assert(loadfile(HERE .. "/AchaeaBeckon.lua"))()
local M = beckonlist

assert(liveTriggers() == 1, "the beckon trigger is installed on load")
assert(liveHandlers() == 1, "and one handler, for gmcp.Char.Name")
assert(M.state.name == "Thoth", "your own name is read at start, not awaited")

-- ---- a recompile replaces, it does not double -----------------------------
-- The state table hangs off the module for this reason: a file-local would be
-- fresh on every recompile and the live trigger would be left running.
assert(loadfile(HERE .. "/AchaeaBeckon.lua"))()
assert(liveTriggers() == 1, "a recompile leaves one trigger, not two")
assert(liveHandlers() == 1, "and one handler")

-- ---- nobody is trusted out of the box -------------------------------------
clear()
assert(feed("Vellis beckons you to him."), "the default pattern matches")
assert(echoed("NOT on your trusted list"), "an unknown name is called out")
assert(#SENT == 0, "and nothing is sent")

clear()
M.trustList()
assert(echoed("nobody is trusted"), "the empty list says so plainly")

-- ---- a trusted name moves you ---------------------------------------------
M.trustAdd("vellis: raids on Thursdays")
clear()
assert(feed("Vellis beckons you to him."))
assert(echoed("trusted, following"), "a trusted beckon says so")
assert(sent("fol Vellis"), "and follows -- FOLLOW joins the group, HELP 6.4")
assert(#SENT == 1, "one command, not two: LOSE would name the wrong person")

-- Typed lowercase, printed Titlecase, same person.
assert(M.trust["Vellis"], "names are stored Titlecase whatever you typed")

-- ---- the tail of the line is not anchored ---------------------------------
-- The pronoun and the punctuation are guesses; the default pattern deliberately
-- stops before them, so all of these still fire.
for _, line in ipairs({
  "Vellis beckons you to her.",
  "Vellis beckons you to them.",
  "Vellis beckons you",
  "Vellis beckons you to his side!",
}) do
  clear()
  assert(feed(line), "unanchored tail: " .. line)
  assert(sent("fol Vellis"), "followed on: " .. line)
end

-- ...but the name has to be at the start of the line, so chat about a beckon
-- is not a beckon.
clear()
assert(not feed("Vellis says, \"Slangen beckons you to her.\""),
  "a say quoting the line is not the line")
assert(#SENT == 0, "and moves nobody")

-- ---- the other two lines a real beckon prints -----------------------------
-- Both out of SHOWEMOTE BECKON, which prints all three perspectives at once.
-- They are the reason that capture was worth more than being beckoned would
-- have been: waiting for a beckon shows the line that must fire and leaves
-- the two that must not as guesses.
--
-- An untargeted BECKON does not contain "beckons" at all, and the onlooker's
-- copy of a targeted one puts the target's name where the pattern needs "you".
clear()
assert(not feed("Vellis makes a beckoning motion."),
  "an untargeted beckon names nobody, so it moves nobody")
assert(#SENT == 0)

clear()
assert(not feed("Vellis beckons Slangen to her."),
  "watching somebody else get beckoned must not move you")
assert(#SENT == 0)

-- ---- yourself -------------------------------------------------------------
clear()
assert(not M.onBeckon({ "Thoth beckons you", "Thoth" }),
  "you cannot beckon yourself, and must not be able to follow yourself")
assert(#SENT == 0)

-- ---- disarmed -------------------------------------------------------------
M.arm(false)
clear()
feed("Vellis beckons you to him.")
assert(echoed("`beckonlist off` is set"),
  "a disarmed trusted beckon still reports")
assert(#SENT == 0, "and sends nothing")
M.arm(true)

-- ---- taking a name off ----------------------------------------------------
M.trustAdd("Slangen")
assert(M.trust["Slangen"], "added")
M.trustRemove("slangen")
assert(not M.trust["Slangen"], "and removed, case regardless")
clear()
feed("Slangen beckons you to her.")
assert(echoed("NOT on your trusted list"), "removal takes effect immediately")
assert(#SENT == 0)

-- ---- a re-add keeps the reason and the date -------------------------------
local before = M.trust["Vellis"].since
M.trustAdd("Vellis")
assert(M.trust["Vellis"].note == "raids on Thursdays",
  "a bare re-add does not erase the reason")
assert(M.trust["Vellis"].since == before, "nor the date")
M.trustAdd("Vellis: also runs Dragon hunts")
assert(M.trust["Vellis"].note == "also runs Dragon hunts", "a new one replaces")

-- ---- the pattern is a setting ---------------------------------------------
clear()
M.setPattern("^(\\w+) gestures for you to follow")
assert(liveTriggers() == 1, "changing the pattern replaces the trigger")
clear()
assert(feed("Vellis gestures for you to follow"), "the new pattern is live")
assert(sent("fol Vellis"))
clear()
assert(not feed("Vellis beckons you to him."), "and the old one is not")

clear()
M.setPattern("^(\\w+ beckons")
assert(echoed("will not compile"), "a broken pattern is refused")
assert(M.config.pattern == "^(\\w+) gestures for you to follow",
  "and the working one is kept")

M.setPattern("default")
assert(M.config.pattern == M.DEFAULT_PATTERN, "`default` puts it back")
clear()
assert(feed("Vellis beckons you to him."))
assert(sent("fol Vellis"))

-- ---- `beckonlist test` sends nothing, whatever it decides ----------------
clear()
M.test("Vellis beckons you to him.")
assert(echoed("would send"), "test says what it would do")
assert(#SENT == 0, "and does not do it")

clear()
M.test("Aliapoe beckons you to her.")
assert(echoed("not trusted"), "test reports an untrusted name too")
assert(#SENT == 0)

clear()
M.test("The sun rises.")
assert(echoed("no match"), "and a line that does not match at all")

-- ---- what a trusted beckon sends is a setting too --------------------------
M.setFollow("follow")
clear()
feed("Vellis beckons you to him.")
assert(sent("follow Vellis"), "the follow command can be changed")
M.setFollow("fol")

-- ---- the recent list is bounded -------------------------------------------
M.config.recent = 3
for _ = 1, 5 do feed("Vellis beckons you to him.") end
assert(#M.state.recent == 3, "the recent list is trimmed to its setting")
clear()
M.last()
assert(echoed("Vellis"), "and prints")

-- ---- status ---------------------------------------------------------------
-- The one thing this package is asked at a glance is whether it is on, so the
-- words are checked rather than the state behind them: ON and OFF, not
-- "armed", and the same renderer everywhere -- `beckonlist`, `beckonlist
-- status`, and turning it on or off -- so none of them can drift.
clear()
M.status()
assert(echoed("status: "), "status says status:")
assert(echoed("ON"), "and ON when it is armed")
assert(echoed("survives") or echoed("a package update keeps it"),
  "and where the list is kept, which is the other question asked of it")

clear()
M.arm(false)
assert(echoed("status: ") and echoed("OFF"),
  "turning it off answers in the same words as asking")
assert(#ECHOED == 1, "but a toggle prints the line, not the whole block")
clear()
M.report()
assert(echoed("status: ") and echoed("OFF"),
  "and a bare `beckonlist` leads with it rather than burying it in a header")
-- COMMANDS is generated by build.py, so under luajit the help table is empty
-- and the version line is what proves report() got past the status block.
assert(echoed("AchaeaBeckon " .. M.VERSION), "and still names itself")
M.arm(true)

-- ---- diag and help --------------------------------------------------------
clear()
M.diag()
assert(echoed("Thoth"), "diag says who it thinks you are")
assert(echoed("fol <name>"), "and what it would send")
assert(echoed("status: "), "and does not have its own opinion about on/off")
M.report()

-- ---- the list survives a restart ------------------------------------------
-- Everything save writes, load has to read back. The Occultist package lost its
-- gear list to exactly this asymmetry: the next edit after a restart wrote the
-- unloaded keys back as empty. Here that is two keys, trust and config, and
-- both are checked.
M.arm(false)
M.setFollow("fol Vellis")   -- deliberately odd, to prove it is what came back
M.stop()
assert(liveHandlers() == 0 and liveTriggers() == 0, "stop leaves nothing live")

beckonlist = nil
assert(loadfile(HERE .. "/AchaeaBeckon.lua"))()
M = beckonlist
assert(M.trust["Vellis"], "the trusted list came back")
assert(M.trust["Vellis"].note == "also runs Dragon hunts", "with its reason")
assert(M.config.armed == false, "and the settings")
assert(M.config.follow == "fol Vellis", "all of them")

M.setFollow("fol")
M.arm(true)
M.stop()
beckonlist = nil
assert(loadfile(HERE .. "/AchaeaBeckon.lua"))()
M = beckonlist
assert(M.config.follow == "fol", "a later save did not flatten the list")
assert(M.trust["Vellis"], "which is the failure mode being tested")

-- A setting the package no longer has must not come back out of an old file.
DISK["/harness/achaea-beckon.lua"].config.obsolete = true
M.stop()   -- a real restart empties Mudlet's tables; these stubs' persist
beckonlist = nil
assert(loadfile(HERE .. "/AchaeaBeckon.lua"))()
M = beckonlist
assert(M.config.obsolete == nil, "unknown settings are dropped on load")

-- ---- an unreadable file is kept, never written over ------------------------
-- The failure this guards against is quiet and total: a file that will not
-- parse loads nothing, and the next `beckonlist add` saves an empty list over
-- the only copy of the names. It goes aside under .bad instead.
DISK["/harness/achaea-beckon.lua"] = "CORRUPT"
M.stop()
beckonlist = nil
clear()
assert(loadfile(HERE .. "/AchaeaBeckon.lua"))()
M = beckonlist
assert(echoed("could not read"), "an unreadable file is reported, not ignored")
assert(M.state.loaded == "unreadable", "and recorded")
clear()
M.status()
assert(echoed("UNREADABLE"), "status says so too")

M.trustAdd("Slangen")
assert(DISK["/harness/achaea-beckon.lua.bad"] == "CORRUPT",
  "the unreadable file is kept rather than overwritten")
assert(type(DISK["/harness/achaea-beckon.lua"]) == "table",
  "and the new state is saved beside it")
assert(DISK["/harness/achaea-beckon.lua"].trust["Slangen"], "with the new name")

M.stop()
assert(liveHandlers() == 0 and liveTriggers() == 0, "stop unregisters everything")

print("all harness checks passed (" .. #ECHOED .. " echoes)")
