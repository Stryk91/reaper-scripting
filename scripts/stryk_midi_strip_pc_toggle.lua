-- midi_strip_pc_toggle.lua -- turn the always-on MIDI program-change stripper off / back on.
-- Actions > Show action list > New action > Load ReaScript, then bind a key if you want.
-- The setting persists across REAPER restarts.

local on = reaper.GetExtState("MidiStripPC", "enabled") ~= "0"
local now = not on
reaper.SetExtState("MidiStripPC", "enabled", now and "1" or "0", true)  -- true = persist

reaper.ShowConsoleMsg(string.format(
  "MIDI program-change stripper is now %s.\n%s\n",
  now and "ON" or "OFF",
  now and "Program changes and bank selects will be removed from every MIDI take on any project change."
       or "Nothing will be stripped until you toggle it back on. Existing takes are unaffected."))
