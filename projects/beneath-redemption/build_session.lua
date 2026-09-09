-- Beneath Redemption: Gothenburg session builder
-- Run in REAPER: Actions -> Show action list -> New action -> Load ReaScript -> this file
local BASE = "G:\\pipelines\\audio-midi-music\\stems-tabs-music-notes-intrument-midi-musicarrangment\\beneath-redemption\\"
local RP = BASE .. "reaper\\"

local function addfx(tr, candidates)
  for _, name in ipairs(candidates) do
    local i = reaper.TrackFX_AddByName(tr, name, false, -1)
    if i >= 0 then return i end
    i = reaper.TrackFX_AddByName(tr, name, false, -1000)
    if i >= 0 then return i end
  end
  return -1
end

local SFZ = { "VST3:sforzando", "sforzando" }
local NAM = { "VST3:NeuralAmpModeler", "VST3:Neural Amp Modeler", "NeuralAmpModeler" }

local function mktrack(idx, name, pan, midifile)
  reaper.InsertTrackAtIndex(idx, true)
  local tr = reaper.GetTrack(0, idx)
  reaper.GetSetMediaTrackInfo_String(tr, "P_NAME", name, true)
  reaper.SetMediaTrackInfo_Value(tr, "D_PAN", pan)
  if midifile then
    reaper.SetOnlyTrackSelected(tr)
    reaper.SetEditCurPos(0, false, false)
    reaper.InsertMedia(midifile, 0)
  end
  return tr
end

reaper.Undo_BeginBlock()
reaper.SetCurrentBPM(0, 120, false)

local rhyL = mktrack(0, "RHY L  [5150 Boosted + 5150cab]", -0.8, RP.."midi\\guitar_rhythm.mid")
addfx(rhyL, SFZ); addfx(rhyL, NAM)

local rhyR = mktrack(1, "RHY R  [JCM2000 805 + V30_SM57]", 0.8, RP.."midi\\guitar_rhythm.mid")
addfx(rhyR, SFZ); addfx(rhyR, NAM)
-- nudge R take 15ms for double-track width
local item = reaper.GetTrackMediaItem(rhyR, 0)
if item then reaper.SetMediaItemInfo_Value(item, "D_POSITION",
  reaper.GetMediaItemInfo_Value(item, "D_POSITION") + 0.015) end

local lead = mktrack(2, "LEAD   [6505+ Red + V30_SM57]", 0.0, RP.."midi\\guitar_lead.mid")
addfx(lead, SFZ); addfx(lead, NAM)

local bass = mktrack(3, "BASS   [HM2 Swede optional]", 0.0, RP.."midi\\bass.mid")
addfx(bass, SFZ); addfx(bass, NAM)

local ref = mktrack(4, "REF 2007 recording (muted)", 0.0, nil)
reaper.SetOnlyTrackSelected(ref)
reaper.SetEditCurPos(0, false, false)
reaper.InsertMedia("D:\\Downloading\\Beneath Redemption.mp3", 0)
reaper.SetMediaTrackInfo_Value(ref, "B_MUTE", 1)

reaper.Undo_EndBlock("Build Beneath Redemption session", -1)
reaper.Main_SaveProjectEx(0, RP.."BeneathRedemption.rpp", 0)
reaper.ShowMessageBox(
  "Session built.\n\nPer track: open sforzando -> load Metal GTX .sfz from reaper\\instruments\\,\n" ..
  "open Neural Amp Modeler -> load the .nam from reaper\\models\\ and IR from reaper\\irs\\\n" ..
  "named in each track's label.\n\nTempo 120 = the tab's notated tempo.", "Beneath Redemption", 0)
