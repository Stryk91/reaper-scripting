-- __startup.lua -- REAPER runs this automatically at launch (native feature, no SWS needed).
-- If you already had a __startup.lua, install.py appended to it instead of replacing it.
dofile(reaper.GetResourcePath() .. "/Scripts/stryk_midi_strip_pc.lua")
