-- verify_jsfx_render.lua -- prove a JSFX actually compiles AND processes audio.
--
-- WHY THIS EXISTS: a JSFX with a real EEL2 syntax error still instantiates in
-- REAPER, still returns a valid fx index from TrackFX_AddByName, and still
-- reports its full slider list from TrackFX_GetNumParams. Every cheap check
-- passes on a broken effect. The only thing that proves the code ran is
-- rendering audio through it and looking at the result.
--
-- What it does: inserts a wav on a new track, adds the JSFX, then runs
-- "Item: Apply track/take FX to items (mono output)" (40209), which bounces
-- the item through the FX chain into a NEW take backed by a new file on disk.
-- The path of that file is written to the report so an outside process can
-- analyse it.
--
-- Config comes from a plain key=value file, NOT ExtState. A persistent
-- SetExtState writes into reaper-extstate.ini in the shared resource path, so
-- the sandbox would be reaching into the live instance's state to configure
-- itself - and the live REAPER rewrites that file on exit anyway.
--
--   %TEMP%\reaper-sandbox\verify_jsfx.cfg
--     wav=<source wav to push through>
--     fx=<JSFX name as TrackFX_AddByName expects it>
--     report=<where to write the result>
--
-- Run it in the sandbox, never the live instance:
--   .\tools\Invoke-ReaperSandbox.ps1 -Script .\tools\verify_jsfx_render.lua -Headless

local CFG = (os.getenv("TEMP") or ".") .. "\\reaper-sandbox\\verify_jsfx.cfg"

local cfg = {}
do
  local f = io.open(CFG, "r")
  if f then
    for line in f:lines() do
      local k, v = line:match("^%s*([%w_]+)%s*=%s*(.-)%s*$")
      if k then cfg[k] = v end
    end
    f:close()
  end
end

local function get(key, dflt)
  local v = cfg[key]
  if v == nil or v == "" then return dflt end
  return v
end

local WAV    = get("wav",    "")
local FX     = get("fx",     "")
local REPORT = get("report", "")

local lines = {}
local function say(fmt, ...)
  local s = select('#', ...) > 0 and string.format(fmt, ...) or fmt
  lines[#lines + 1] = s
  reaper.ShowConsoleMsg(s .. "\n")
end

local function finish(ok)
  lines[#lines + 1] = ok and "RESULT: OK" or "RESULT: FAIL"
  if REPORT ~= "" then
    local f = io.open(REPORT, "w")
    if f then f:write(table.concat(lines, "\n") .. "\n"); f:close() end
  end
end

local function main()
  reaper.ClearConsole()
  say("verify_jsfx_render on REAPER %s", reaper.GetAppVersion())
  say("cfg = %s", CFG)
  -- -cfgfile moves REAPER's whole resource path, not just the ini, so an
  -- on-disk JSFX in the REAL profile is invisible unless it is staged in.
  local res = reaper.GetResourcePath()
  say("resource path = %s", res)
  local eff = res .. "/Effects/stryk"
  local probe_fx = reaper.EnumerateFiles(eff, 0)
  say("Effects/stryk first entry = %s", tostring(probe_fx))
  say("wav = %s", WAV)
  say("fx  = %s", FX)

  if WAV == "" or FX == "" then say("ERROR: wav and fx ExtState required"); return false end
  local probe = io.open(WAV, "rb")
  if not probe then say("ERROR: wav not readable: %s", WAV); return false end
  probe:close()

  reaper.InsertTrackAtIndex(0, true)
  local tr = reaper.GetTrack(0, 0)
  if not tr then say("ERROR: track insert failed"); return false end
  reaper.SetOnlyTrackSelected(tr)
  reaper.SetEditCurPos(0, false, false)

  reaper.InsertMedia(WAV, 0)
  local nitems = reaper.CountMediaItems(0)
  say("items after insert: %d", nitems)
  if nitems == 0 then say("ERROR: InsertMedia added nothing"); return false end

  -- TrackFX_AddByName resolves a JSFX by its path relative to the Effects
  -- folder, not by bare filename, and different REAPER versions also accept
  -- the "JS:" prefixed description. Try the forms rather than guessing one.
  local candidates = {
    FX,
    "stryk/" .. FX,
    "stryk\\" .. FX,
    "JS: " .. FX,
  }
  local fx, used = -1, nil
  for _, name in ipairs(candidates) do
    fx = reaper.TrackFX_AddByName(tr, name, false, -1)
    say("  TrackFX_AddByName(%q) -> %d", name, fx)
    if fx >= 0 then used = name; break end
  end
  if fx < 0 then
    say("ERROR: JSFX not found under any name form.")
    say("       Installed at %%APPDATA%%\\REAPER\\Effects\\stryk\\%s ?", FX)
    return false
  end
  say("resolved as: %s", used)

  -- Deliberately NOT treated as proof - recorded only so a broken build and a
  -- working one can be told apart in the report afterwards.
  local nparams = reaper.TrackFX_GetNumParams(tr, fx)
  say("TrackFX_GetNumParams -> %d  (NOT proof: a broken JSFX reports these too)", nparams)

  local item = reaper.GetMediaItem(0, 0)
  reaper.SelectAllMediaItems(0, false)
  reaper.SetMediaItemSelected(item, true)
  reaper.UpdateArrange()

  -- 40209 = Item: Apply track/take FX to items (mono output)
  reaper.Main_OnCommand(40209, 0)

  local take = reaper.GetActiveTake(item)
  if not take then say("ERROR: no active take after apply"); return false end
  local src = reaper.GetMediaItemTake_Source(take)
  if not src then say("ERROR: no source after apply"); return false end
  local path = reaper.GetMediaSourceFileName(src, "")
  say("rendered: %s", path)

  if path == WAV then
    say("ERROR: take still points at the input - apply FX did not render")
    return false
  end
  local chk = io.open(path, "rb")
  if not chk then say("ERROR: rendered file not readable"); return false end
  local sz = chk:seek("end"); chk:close()
  say("rendered size: %d bytes", sz)
  if sz < 1000 then say("ERROR: rendered file suspiciously small"); return false end

  return true
end

local ok, err = pcall(main)
if not ok then
  say("!! RUNTIME ERROR: %s", tostring(err))
  finish(false)
else
  finish(err)
end
