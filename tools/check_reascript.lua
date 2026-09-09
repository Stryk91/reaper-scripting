-- check_reascript.lua
-- Static sanity check for a ReaScript Lua file, run inside REAPER so it sees the real API table.
--
-- Catches the two failure modes that REAPER reports badly:
--   1. a syntax error (the script never runs, and you get no useful message)
--   2. a call to a reaper.* function that DOES NOT EXIST
--      -> "attempt to call a nil value", thrown at runtime, often near the end,
--         after the script has already done its work. Looks like "it did nothing".
--
-- It COMPILES the target but never RUNS it, so it is safe against any script.
--
-- Target is taken from ExtState "check_reascript"/"target", else the environment variable
-- CHECK_REASCRIPT_TARGET (so the sandbox launcher can drive it headlessly), else a file browser.
-- Results go to the ReaScript console and to <target>.check.txt next to the target.

local function main()
  reaper.ClearConsole()
  local function log(f, ...)
    local s = select('#', ...) > 0 and string.format(f, ...) or f
    reaper.ShowConsoleMsg(s .. "\n")
  end

  local target = reaper.GetExtState("check_reascript", "target")
  if target and target ~= "" then
    reaper.DeleteExtState("check_reascript", "target", false)
  elseif os.getenv("CHECK_REASCRIPT_TARGET") then
    -- lets the sandbox launcher drive this headlessly
    target = os.getenv("CHECK_REASCRIPT_TARGET")
  else
    local ok, pick = reaper.GetUserFileNameForRead("", "Pick a ReaScript .lua to check", "lua")
    if not ok then return end
    target = pick
  end

  local out = {}
  local function emit(f, ...)
    local s = select('#', ...) > 0 and string.format(f, ...) or f
    out[#out + 1] = s
    log(s)
  end

  emit("check_reascript: %s", target)
  local fh = io.open(target, "rb")
  if not fh then emit("!! cannot open the file"); return end
  local src = fh:read("a"); fh:close()

  emit("bytes = %d | CRLF = %s | BOM = %s", #src,
    tostring(src:find("\r\n") ~= nil),
    tostring(src:byte(1) == 0xEF and src:byte(2) == 0xBB and src:byte(3) == 0xBF))

  local chunk, err = load(src, "@" .. target)
  if chunk then emit("SYNTAX: OK") else emit("SYNTAX ERROR: %s", tostring(err)) end

  emit("--- reaper.* symbols referenced ---")
  local seen, bad = {}, 0
  for name in src:gmatch("reaper%.([%w_]+)") do
    if not seen[name] then
      seen[name] = true
      local v = reaper[name]
      if v == nil then
        bad = bad + 1
        emit("  %-34s *** NIL - DOES NOT EXIST ***", name)
      else
        emit("  %-34s %s", name, type(v))
      end
    end
  end
  emit("--- %d symbols, %d missing ---", (function() local n = 0 for _ in pairs(seen) do n = n + 1 end return n end)(), bad)
  emit(bad == 0 and "RESULT: clean" or "RESULT: %d BROKEN CALL(S) - this script will throw at runtime", bad)

  local o = io.open(target .. ".check.txt", "w")
  if o then o:write(table.concat(out, "\n")) o:close() end
end

local ok, err = pcall(main)
if not ok then reaper.ShowConsoleMsg("check_reascript failed: " .. tostring(err) .. "\n") end
