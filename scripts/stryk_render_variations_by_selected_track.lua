--[[
  render_variations_by_selected_track.lua
  ----------------------------------------
  Renders EVERY track that has media items as an individual stem, with all of
  them playing through the instrument/FX chain of the SELECTED ("source") track.

  Use case: you have N tracks, each with its own MIDI. You want them all
  rendered once as "piano", once as "<some lead>", etc. Load the sound you want
  on ONE track, select it, run this script, give it an output folder name.

  How it works (and cleans up after itself):
    - copies the selected track's FULL fx chain onto every other track-with-items
    - bypasses each target track's ORIGINAL fx so only the copied sound plays
    - solos + renders each track to <project media dir>/renders/<subfolder>/<track>.wav
      (WAV, project sample rate, stereo, entire-project bounds so stems line up)
    - then deletes the copied fx and un-bypasses the originals -> project restored

  IMPORTANT: set the selected track so it already sounds EXACTLY as you want
  (e.g. only the piano enabled on it). The script copies its chain verbatim.

  This avoids the reapy socket bridge entirely (which crashes on FX-insert and
  can't fire a render). Native in-REAPER Lua render works.
]]--

local r = reaper

local function msg(s) r.ShowMessageBox(s, "Render variations", 0) end

local function sanitize(name)
  name = name or "track"
  name = name:gsub('[<>:"/\\|%?%*]', '_'):gsub('%s+$',''):gsub('^%s+','')
  if name == "" then name = "track" end
  return name
end

-- ---- source track ----
local src = r.GetSelectedTrack(0, 0)
if not src then msg("Select the track that has the sound you want (the 'source' track), then run again.") return end

-- ---- ask for output subfolder ----
local ok, sub = r.GetUserInputs("Render variations", 1, "Output subfolder name:,extrawidth=120", "piano")
if not ok then return end
sub = sanitize(sub)

-- ---- output dir: <project media path>/renders/<sub> ----
local projpath = r.GetProjectPath("")           -- media/record dir of current project
local outdir = projpath .. "\\renders\\" .. sub
r.RecursiveCreateDirectory(outdir, 0)

-- ---- gather target tracks (those with media items) ----
local ntr = r.CountTracks(0)
local targets = {}
for i = 0, ntr-1 do
  local tr = r.GetTrack(0, i)
  if r.CountTrackMediaItems(tr) > 0 then targets[#targets+1] = tr end
end
if #targets == 0 then msg("No tracks with media items to render.") return end

-- ---- snapshot solos ----
local solo_snap = {}
for i = 0, ntr-1 do
  local tr = r.GetTrack(0, i)
  solo_snap[tr] = r.GetMediaTrackInfo_Value(tr, "I_SOLO")
end

r.Undo_BeginBlock()
r.PreventUIRefresh(1)

-- ---- copy source chain onto each OTHER target; bypass their originals ----
local src_fx_count = r.TrackFX_GetCount(src)
local restore = {}   -- per target: {track=, origCount=, origEnabled={...}}
for _, tr in ipairs(targets) do
  if tr ~= src then
    local origCount = r.TrackFX_GetCount(tr)
    local origEnabled = {}
    for fi = 0, origCount-1 do origEnabled[fi] = r.TrackFX_GetEnabled(tr, fi) end
    -- append a copy of every source fx
    for sfi = 0, src_fx_count-1 do
      local destPos = r.TrackFX_GetCount(tr)
      r.TrackFX_CopyToTrack(src, sfi, tr, destPos, false)
    end
    -- bypass the originals so only the copied sound plays
    for fi = 0, origCount-1 do r.TrackFX_SetEnabled(tr, fi, false) end
    restore[#restore+1] = {track=tr, origCount=origCount, origEnabled=origEnabled}
  end
end

-- ---- render settings (once) ----
r.GetSetProjectInfo(0, "RENDER_BOUNDSFLAG", 1, true)  -- entire project (stems align)
r.GetSetProjectInfo(0, "RENDER_SETTINGS", 0, true)    -- master mix (with 1 track soloed = that track)
r.GetSetProjectInfo(0, "RENDER_SRATE", 0, true)       -- 0 = follow project sample rate
r.GetSetProjectInfo(0, "RENDER_CHANNELS", 2, true)    -- stereo
r.GetSetProjectInfo(0, "RENDER_ADDTOPROJ", 0, true)   -- don't import result back

-- ---- render loop: one soloed stem per track ----
local rendered = 0
for _, tr in ipairs(targets) do
  for i = 0, ntr-1 do r.SetMediaTrackInfo_Value(r.GetTrack(0,i), "I_SOLO", 0) end
  r.SetMediaTrackInfo_Value(tr, "I_SOLO", 2)  -- solo in place

  local _, tname = r.GetSetMediaTrackInfo_String(tr, "P_NAME", "", false)
  -- PROVEN combo: RENDER_FILE = directory, RENDER_PATTERN = filename.
  -- (Setting RENDER_FILE to a full name with empty pattern makes REAPER create
  --  a *folder* named "<name>.wav" with mis-named audio inside — avoid that.)
  r.GetSetProjectInfo_String(0, "RENDER_FILE", outdir, true)
  r.GetSetProjectInfo_String(0, "RENDER_PATTERN", sanitize(tname), true)
  r.Main_OnCommand(41824, 0)  -- Render, most recent settings, no dialog (in-context = works)
  rendered = rendered + 1
end

-- ---- restore: delete copied fx, re-enable originals, restore solos ----
for _, rec in ipairs(restore) do
  local tr = rec.track
  -- delete everything we appended (indices origCount .. end), high to low
  local now = r.TrackFX_GetCount(tr)
  for fi = now-1, rec.origCount, -1 do r.TrackFX_Delete(tr, fi) end
  for fi = 0, rec.origCount-1 do r.TrackFX_SetEnabled(tr, fi, rec.origEnabled[fi]) end
end
for tr, sv in pairs(solo_snap) do r.SetMediaTrackInfo_Value(tr, "I_SOLO", sv) end

r.PreventUIRefresh(-1)
r.UpdateArrange()
r.Undo_EndBlock("Render variations (" .. sub .. ")", -1)

msg(string.format("Rendered %d stems to:\n%s\n\nProject restored (copied FX removed, originals re-enabled).", rendered, outdir))
