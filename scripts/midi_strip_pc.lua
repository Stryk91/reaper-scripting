--[[
  midi_strip_pc.lua -- always-on removal of MIDI Program Change + Bank Select in REAPER.

  WHY: a Program Change (status 0xCn) means "load patch N". REAPER feeds a track's whole MIDI
  stream into its FX chain, so any program change in an item overwrites the Spire / sforzando
  preset you picked by hand -- and REAPER's chase re-sends it on EVERY transport start.
  Guitar Pro 8 stamps one on every exported track; downloaded GM/console rips are full of them.
  Bank Select (CC 0 MSB / CC 32 LSB) is removed too: it is a separate event that pairs with the
  program change, and leaving it behind makes the Bank/Program lane still draw a marker.

  WHAT IT DOES: runs continuously from REAPER startup. Whenever any open project changes
  (import, paste, record, undo) it scans every MIDI take in that project and deletes those
  events. Notes, every other CC, pitch bend, aftertouch and sysex are untouched.

  IT NEVER TOUCHES: a take whose source is a .mid file on disk (a "reference" import rather than
  an in-project copy) -- editing one of those makes REAPER rewrite your .mid when you save.
  Cleaning those files is strip_pc.py's job, where there are backups and a dry run. It also
  waits rather than sweeping while REAPER is recording.

  OPT OUT:
    * per track  -- put [keepPC] anywhere in the track name; that track is skipped entirely.
    * globally   -- run the action "midi_strip_pc_toggle.lua" (it flips a persistent setting).
  Every removal is logged to strip_log.txt next to this script's source, and creates a normal
  undo point, so Ctrl+Z puts the events back.

  KNOW THIS: it strips on project OPEN as well as on import. Opening an old project that
  contains program changes will clean it and mark the project modified -- the change is only
  permanent if you then save. That is deliberate (your old projects are the contaminated ones),
  but it is the one behaviour to be aware of.

  Installed by tools/install_midi_strip_pc.py in the reaper-scripting repo.
  Verified end-to-end in an isolated REAPER 7.78 sandbox on 2026-08-29.
]]

-- Log next to REAPER's own resources rather than at a hardcoded G:\ path. The
-- old absolute path pointed into the source tree, so moving the repo silently
-- broke logging in the INSTALLED copy - which is a different file, in a
-- different place, that nobody thinks to re-check. GetResourcePath is
-- self-locating and cannot go stale.
local LOG      = reaper.GetResourcePath() .. "/midi_strip_pc_log.txt"
local LOG_CAP  = 200000       -- bytes; truncated when it grows past this
local SKIP_TAG = "%[keeppc%]" -- Lua pattern: a track whose name contains [keepPC] is left alone
local DEBUG    = false        -- true = log every take considered, including skips

-- ---------------------------------------------------------------- logging
local function log(s)
  local f = io.open(LOG, "a")
  if not f then return end
  f:write(os.date("%Y-%m-%d %H:%M:%S  ") .. tostring(s) .. "\n")
  local size = f:seek()
  f:close()
  if size and size > LOG_CAP then
    local r = io.open(LOG, "r"); if r then
      local all = r:read("*a"); r:close()
      local w = io.open(LOG, "w"); if w then w:write(all:sub(-LOG_CAP // 2)); w:close() end
    end
  end
end

-- ---------------------------------------------------------------- single instance
if reaper.GetExtState("MidiStripPC", "running") == "1" then return end
reaper.SetExtState("MidiStripPC", "running", "1", false)
reaper.atexit(function() reaper.DeleteExtState("MidiStripPC", "running", false) end)

local function enabled()
  return reaper.GetExtState("MidiStripPC", "enabled") ~= "0"   -- default ON
end

-- ---------------------------------------------------------------- the surgery
-- Program change reaches the CC API as chanmsg 0xC0; bank select as 0xB0 with CC# 0 or 32.
-- Iterate BACKWARDS -- deleting index i shifts every later index down by one.
local function strip_take(take)
  local ok, _, ccs = reaper.MIDI_CountEvts(take)
  if not ok or ccs == 0 then return 0 end
  local removed = 0
  for i = ccs - 1, 0, -1 do
    local got, _, _, _, chanmsg, _, msg2 = reaper.MIDI_GetCC(take, i)
    if got and (chanmsg == 0xC0 or (chanmsg == 0xB0 and (msg2 == 0 or msg2 == 32))) then
      reaper.MIDI_DeleteCC(take, i)
      removed = removed + 1
    end
  end
  if removed > 0 then reaper.MIDI_Sort(take) end
  return removed
end

-- A take whose source has a filename is NOT in-project MIDI -- it is a reference to a .mid on
-- disk, and editing it makes REAPER rewrite that file when the project is saved. Never touch
-- those: cleaning them is strip_pc.py's job, where there are backups and a dry run.
-- Walk parent sources so section/reversed wrappers cannot hide the filename.
local function source_file(take)
  local src = reaper.GetMediaItemTake_Source(take)
  if not src then return "" end
  for _ = 1, 8 do
    local parent = reaper.GetMediaSourceParent(src)
    if not parent then break end
    src = parent
  end
  return reaper.GetMediaSourceFileName(src) or ""
end

local function sweep(proj)
  local total = 0
  local projname = reaper.GetProjectName(proj)
  if not projname or projname == "" then projname = "(unsaved)" end
  for i = 0, reaper.CountMediaItems(proj) - 1 do
    local item = reaper.GetMediaItem(proj, i)
    if item then
      local track = reaper.GetMediaItem_Track(item)
      local _, tname = reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
      if not tname:lower():find(SKIP_TAG) then
        for t = 0, reaper.CountTakes(item) - 1 do
          local take = reaper.GetTake(item, t)
          if take and reaper.TakeIsMIDI(take) then
            local fn = source_file(take)
            if DEBUG then log(("  take on '%s': srcfile=%q"):format(tname, fn)) end
            local n = (fn == "") and strip_take(take) or 0
            if fn ~= "" and DEBUG then log("  SKIPPED file-backed take: " .. fn) end
            if n > 0 then
              local _, iname = reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
              local pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
              log(string.format("%s | track '%s' | item '%s' @%.2fs -- removed %d",
                projname, tname, iname, pos, n))
              total = total + n
            end
          end
        end
      end
    end
  end
  return total
end

-- ---------------------------------------------------------------- the loop
local seen = {}   -- project pointer -> last state-change count

local function loop()
  if enabled() then
    local pi = 0
    while true do
      local proj = reaper.EnumProjects(pi)
      if not proj then break end
      -- NEVER rewrite a take's events while the recorder is appending to it (&4 = recording).
      -- The sweep is simply deferred until the pass ends; the state counter will still differ.
      local recording = (reaper.GetPlayStateEx(proj) & 4) ~= 0
      -- fires on ANY project edit -- import, paste, record, undo -- not merely item count changing
      local state = reaper.GetProjectStateChangeCount(proj)
      if seen[proj] ~= state and not recording then
        local removed = sweep(proj)
        if removed > 0 then
          reaper.Undo_OnStateChange2(proj, "Auto-strip MIDI program change / bank select")
        end
        seen[proj] = reaper.GetProjectStateChangeCount(proj)
      end
      pi = pi + 1
    end
  end
  reaper.defer(loop)
end

log("=== midi_strip_pc started (" .. reaper.GetAppVersion() .. ") ===")
loop()
