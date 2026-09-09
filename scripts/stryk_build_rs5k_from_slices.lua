-- build_rs5k_from_slices.lua  (v2 - 2026-09-10)
-- Builds one track carrying one ReaSamplOmatic5000 per slice .wav in a folder.
-- slice n -> MIDI note 36+n-1, note-offs ignored.
-- Imports a .mid from the same folder if one is there.
--
-- The slice folder is taken from, in this order:
--   1. ExtState "build_rs5k"/"folder"   (set by another script; consumed and cleared)
--   2. a text box you paste the path into
--   3. leave that box empty -> falls back to the file browser
--
-- Every step is logged to the ReaScript console.

local BASE_NOTE = 36
local SEP = package.config:sub(1, 1)

local function log(fmt, ...)
  local s = select('#', ...) > 0 and string.format(fmt, ...) or fmt
  reaper.ShowConsoleMsg(s .. "\n")
end

local function normalise(p)
  if not p then return nil end
  p = p:gsub("^%s+", ""):gsub("%s+$", "")   -- surrounding whitespace
  p = (p:gsub('^"(.*)"$', "%1"))            -- Explorer "Copy as path" quotes
  p = (p:gsub("[/\\]+$", ""))               -- trailing separator
  return p
end

local function get_folder()
  local ext = reaper.GetExtState("build_rs5k", "folder")
  if ext and ext ~= "" then
    reaper.DeleteExtState("build_rs5k", "folder", false)
    log("folder from ExtState: %s", ext)
    return normalise(ext)
  end

  local last = reaper.GetExtState("build_rs5k", "lastfolder") or ""
  log("asking for the folder (text box)...")
  local ok, csv = reaper.GetUserInputs("build_rs5k - slice folder", 1,
    "Paste slice folder (blank = browse),extrawidth=460", last)
  if not ok then log("cancelled at the folder box."); return nil end

  local folder = normalise(csv)
  if folder == "" then
    log("blank -> opening the file browser...")
    local ok2, pick = reaper.GetUserFileNameForRead("", "Pick any slice wav in the folder", "wav")
    if not ok2 then log("cancelled at the browser."); return nil end
    folder = pick:match("^(.*)[/\\]")
    if not folder then log("ERROR: could not derive a folder from: %s", pick); return nil end
  end
  return folder
end

-- sort by the LAST number in the name, so 2 lands before 10
local function num(s)
  local last = 0
  for d in s:gmatch("(%d+)") do last = tonumber(d) end
  return last
end

local function main()
  reaper.ClearConsole()
  log("build_rs5k: started   (REAPER %s, %s)", reaper.GetAppVersion(), _VERSION)

  local folder = get_folder()
  if not folder or folder == "" then log("no folder - stopping."); return end
  log("folder = %s", folder)

  local files, mids, i = {}, {}, 0
  while true do
    local f = reaper.EnumerateFiles(folder, i)
    if not f then break end
    local lf = f:lower()
    if lf:match("%.wav$") then files[#files + 1] = f
    elseif lf:match("%.midi?$") then mids[#mids + 1] = f end
    i = i + 1
  end
  log("scanned %d entries -> %d wav, %d mid", i, #files, #mids)

  if i == 0 then
    log("ERROR: folder is empty or does not exist.")
    reaper.MB("Folder is empty or does not exist:\n" .. folder, "build_rs5k", 0)
    return
  end
  if #files == 0 then
    log("ERROR: no .wav in that folder.")
    reaper.MB("No .wav files in:\n" .. folder, "build_rs5k", 0)
    return
  end

  table.sort(files, function(a, b)
    local na, nb = num(a), num(b)
    if na ~= nb then return na < nb end
    return a:lower() < b:lower()
  end)

  local loopname = folder:match("([^/\\]+)$") or "slices"
  reaper.SetExtState("build_rs5k", "lastfolder", folder, true)

  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(1)

  local idx = reaper.CountTracks(0)
  reaper.InsertTrackAtIndex(idx, true)
  local tr = reaper.GetTrack(0, idx)
  if not tr then log("ERROR: track insert failed."); reaper.PreventUIRefresh(-1); return end
  reaper.GetSetMediaTrackInfo_String(tr, "P_NAME", loopname, true)
  log("track %d created: %s", idx, loopname)

  local function set_by_name(fx, pname, val)
    local n = reaper.TrackFX_GetNumParams(tr, fx)
    for p = 0, n - 1 do
      local _, name = reaper.TrackFX_GetParamName(tr, fx, p, "")
      if name == pname then reaper.TrackFX_SetParam(tr, fx, p, val); return true end
    end
    return false
  end

  local built, failed = 0, 0
  for n, f in ipairs(files) do
    local path = folder .. SEP .. f
    local fx = reaper.TrackFX_AddByName(tr, "ReaSamplOmatic5000", false, -1)
    if fx < 0 then
      log("  [%02d] ERROR: could not add ReaSamplOmatic5000 (is it installed?)", n)
      failed = failed + 1
      break
    end
    local note = BASE_NOTE + n - 1
    reaper.TrackFX_SetNamedConfigParm(tr, fx, "FILE0", path)
    reaper.TrackFX_SetNamedConfigParm(tr, fx, "DONE", "")

    local okS = set_by_name(fx, "Note range start", note / 127)
    local okE = set_by_name(fx, "Note range end",   note / 127)
    local okO = set_by_name(fx, "Obey note-offs",   0)
    if not (okS and okE and okO) then
      log("  [%02d] WARNING: param name miss (start=%s end=%s obey=%s)", n,
        tostring(okS), tostring(okE), tostring(okO))
    end

    reaper.TrackFX_SetNamedConfigParm(tr, fx, "renamed_name",
      string.format("%02d n%d %s", n, note, f))

    local _, loaded = reaper.TrackFX_GetNamedConfigParm(tr, fx, "FILE0")
    if loaded == nil or loaded == "" then
      log("  [%02d] WARNING: sample did not load: %s", n, f)
      failed = failed + 1
    else
      built = built + 1
    end
    log("  [%02d] note %3d  <- %s", n, note, f)
  end
  log("built %d RS5K instances (%d problems)", built, failed)

  if #mids > 0 then
    local midpath = folder .. SEP .. mids[1]
    log("importing MIDI: %s", midpath)
    log("  (if the script stops here, REAPER is showing a MIDI-import dialog behind this window)")
    reaper.SetOnlyTrackSelected(tr)
    reaper.SetEditCurPos(0, false, false)
    reaper.InsertMedia(midpath, 0)
    log("  MIDI import returned OK")
  else
    log("no .mid in the folder - skipping MIDI import")
  end

  reaper.PreventUIRefresh(-1)
  reaper.TrackList_AdjustWindows(false)
  reaper.UpdateArrange()
  reaper.Undo_EndBlock("Build RS5k instrument from " .. loopname, -1)

  log("build_rs5k: DONE")
  reaper.MB(string.format("%d slices on %s, notes %d-%d%s", #files, loopname,
    BASE_NOTE, BASE_NOTE + #files - 1,
    #mids > 0 and ("\nMIDI: " .. mids[1]) or "\nNo .mid found in folder"), "build_rs5k", 0)
end

local ok, err = pcall(main)
if not ok then
  reaper.PreventUIRefresh(-1)
  log("!! RUNTIME ERROR: %s", tostring(err))
  reaper.MB("build_rs5k hit an error:\n\n" .. tostring(err), "build_rs5k error", 0)
end
