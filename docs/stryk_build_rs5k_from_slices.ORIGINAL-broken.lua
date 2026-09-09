-- build_rs5k_from_slices.lua
-- Pick any slice .wav in a folder. Builds one track, one ReaSamplOmatic5000 per slice,
-- slice n -> MIDI note 36+n, note-offs ignored. Imports a .mid from the same folder if present.

local BASE_NOTE = 36

local ok, pick = reaper.GetUserFileNameForRead("", "Pick any slice wav in the folder", "wav")
if not ok then return end

local sep = package.config:sub(1, 1)
local folder = pick:match("^(.*)" .. sep)
local loopname = folder:match("([^" .. sep .. "]+)$") or "slices"

-- collect wavs, sort by trailing number so 2 comes before 10
local files, mids = {}, {}
local i = 0
while true do
  local f = reaper.EnumerateFiles(folder, i)
  if not f then break end
  local lf = f:lower()
  if lf:match("%.wav$") then files[#files + 1] = f
  elseif lf:match("%.mid$") then mids[#mids + 1] = f end
  i = i + 1
end
local function num(s) return tonumber(s:match("(%d+)%.wav$") or s:match("(%d+)[^%d]*%.wav$")) or 0 end
table.sort(files, function(a, b)
  local na, nb = num(a), num(b)
  if na ~= nb then return na < nb end
  return a < b
end)
if #files == 0 then reaper.MB("No wavs in " .. folder, "build_rs5k", 0) return end

reaper.Undo_BeginBlock()
reaper.PreventUIRefresh(1)

local idx = reaper.CountTracks(0)
reaper.InsertTrackAtIndex(idx, true)
local tr = reaper.GetTrack(0, idx)
reaper.GetSetMediaTrackInfo_String(tr, "P_NAME", loopname, true)

local function set_by_name(fx, pname, val)
  local n = reaper.TrackFX_GetNumParams(tr, fx)
  for p = 0, n - 1 do
    local _, name = reaper.TrackFX_GetParamName(tr, fx, p, "")
    if name == pname then reaper.TrackFX_SetParam(tr, fx, p, val) return true end
  end
  return false
end

for n, f in ipairs(files) do
  local fx = reaper.TrackFX_AddByName(tr, "ReaSamplOmatic5000", false, -1)
  local note = BASE_NOTE + n - 1
  reaper.TrackFX_SetNamedConfigParm(tr, fx, "FILE0", folder .. sep .. f)
  reaper.TrackFX_SetNamedConfigParm(tr, fx, "DONE", "")
  set_by_name(fx, "Note range start", note / 127)
  set_by_name(fx, "Note range end", note / 127)
  set_by_name(fx, "Obey note-offs", 0)
  reaper.TrackFX_SetNamedConfigParm(tr, fx, "renamed_name", string.format("%02d n%d %s", n, note, f))
end

if #mids > 0 then
  reaper.SetOnlyTrackSelected(tr)
  reaper.SetEditCurPos(0, false, false)
  reaper.InsertMedia(folder .. sep .. mids[1], 0)
end

reaper.PreventUIRefresh(-1)
reaper.TrackSelectionChanged(tr)
reaper.Undo_EndBlock("Build RS5k instrument from " .. loopname, -1)
reaper.MB(string.format("%d slices on %s, notes %d-%d%s", #files, loopname, BASE_NOTE, BASE_NOTE + #files - 1,
  #mids > 0 and ("\nMIDI: " .. mids[1]) or "\nNo .mid found in folder"), "build_rs5k", 0)
