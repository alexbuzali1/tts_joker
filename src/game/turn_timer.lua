-- game/turn_timer.lua  (Global script)
-- The turn timer (user, 11-17): on a person's turn the edge of THEIR screen glows in their marble colour until they
-- play a card, and it gets harder to ignore the longer they take:
--   0-25 s   a slow, gentle glow
--   25 s     it flashes
--   40 s     it flashes faster and ticks
--   55 s     all out: a thick border flashing between their colour and white, "YOUR TURN!" down both sides, faster ticks
-- It never covers the table (a border only, and clicks go through it), stops the moment a card is played, holds
-- while the game is paused, and only shows on the player's own screen. The ticks play through TTS's music player:
-- TTS has no way to play a sound to one player, so everyone hears them. The host can switch the timer and the sounds
-- off in the settings (ui/settings.lua).

TURN_TIMER_STAGES = {                 -- from `at` seconds: border thickness, seconds per flash half, sound
    { at = 0,  thick = 10, half = 1.0,  sound = nil },
    { at = 25, thick = 16, half = 0.45, sound = nil },       -- (user, 11-18: glow 10 -> 15 -> 25 s, flashing 5 -> 15 s)
    { at = 40, thick = 22, half = 0.25, sound = "tick" },
    { at = 55, thick = 36, half = 0.15, sound = "alarm", wild = true },
}
TURN_TIMER = nil                      -- { color, gen, t, stage, lit }
TURN_TIMER_SOUND = nil                -- which clip the music player has on

local function stageAt(t)
    local k = 1
    for i, s in ipairs(TURN_TIMER_STAGES) do if t >= s.at then k = i end end
    return k
end

local function hexOf(color, a)
    return "#" .. colorHex(nameColorOnDark(color)) .. string.format("%02X", math.floor(a * 255 + 0.5))
end

function turnTimerXml()
    local tt = TURN_TIMER
    if not tt then return "" end
    local st = TURN_TIMER_STAGES[tt.stage]
    local c = (st.wild and tt.white) and "#FFFFFFE6" or hexOf(tt.color, st.wild and 0.95 or 0.75)
    local edge = 'raycastTarget="false" color="' .. c .. '"'
    local x = string.format('<Panel id="turnFlash" visibility="%s" active="false" raycastTarget="false" width="100%%" height="100%%" '
        .. 'showAnimation="FadeIn" hideAnimation="FadeOut" animationDuration="%.2f">', tt.color, st.half)
    x = x .. string.format('<Panel id="turnFlashT" %s rectAlignment="UpperCenter" width="100%%" height="%d"/>', edge, st.thick)
    x = x .. string.format('<Panel id="turnFlashB" %s rectAlignment="LowerCenter" width="100%%" height="%d"/>', edge, st.thick)
    x = x .. string.format('<Panel id="turnFlashL" %s rectAlignment="MiddleLeft" width="%d" height="100%%"/>', edge, st.thick)
    x = x .. string.format('<Panel id="turnFlashR" %s rectAlignment="MiddleRight" width="%d" height="100%%"/>', edge, st.thick)
    if st.wild then
        for _, side in ipairs({ { "MiddleLeft", 70 }, { "MiddleRight", -70 } }) do
            x = x .. string.format('<Text raycastTarget="false" rectAlignment="%s" offsetXY="%d 0" width="60" height="420" fontSize="34" '
                .. 'fontStyle="Bold" color="%s" outline="#000000" outlineSize="2 2" text="Y&#10;O&#10;U&#10;R&#10; &#10;T&#10;U&#10;R&#10;N"/>',
                side[1], side[2], hexOf(tt.color, 1))
        end
    end
    return x .. '</Panel>'
end

-- the music player: "tick", "alarm" or nil (stop)
TURN_TIMER_CLIPS = { tick = "sounds/tick.wav", alarm = "sounds/alarm.wav" }
function turnTimerSound(which)
    if which and not SETTINGS.sound then which = nil end
    if which == TURN_TIMER_SOUND then return end
    TURN_TIMER_SOUND = which
    pcall(function()
        if which then
            MusicPlayer.repeat_track = true
            MusicPlayer.setCurrentAudioclip({ url = ASSET_BASE .. TURN_TIMER_CLIPS[which], title = "Turn timer" })
            MusicPlayer.play()
        else
            MusicPlayer.pause()
        end
    end)
end

function turnTimerStop()
    if not TURN_TIMER then return end
    TURN_TIMER = nil
    turnTimerSound(nil)
    pcall(function() UI.hide("turnFlash") end)
end

local function stillOn(tt)
    if TURN_TIMER ~= tt or not SETTINGS.timer then return false end
    if not (TURN_STATE and TURN_STATE.active) or TURN_STATE.gen ~= tt.gen then return false end
    if GAME_STATS and GAME_STATS.card_played then return false end
    return true
end

-- a person's turn started (game/turns.lua turnBegin)
function turnTimerStart(color, gen)
    turnTimerStop()
    if not SETTINGS.timer or not color then return end
    local tt = { color = color, gen = gen, t = 0, stage = 1, lit = false }
    TURN_TIMER = tt
    refreshGameUI()
    local function step()
        if not stillOn(tt) then if TURN_TIMER == tt then turnTimerStop() end return end
        local half = TURN_TIMER_STAGES[tt.stage].half
        if not TURN_STATE.paused then tt.t = tt.t + half end
        local k = stageAt(tt.t)
        if k ~= tt.stage then
            tt.stage = k
            turnTimerSound(TURN_TIMER_STAGES[k].sound)
            refreshGameUI()                   -- thicker border, faster flashing
        end
        tt.lit = not tt.lit
        if TURN_TIMER_STAGES[tt.stage].wild and tt.lit then
            tt.white = not tt.white          -- all out: alternate their colour and white
            local c = tt.white and "#FFFFFFE6" or hexOf(tt.color, 0.95)
            for _, e in ipairs({ "T", "B", "L", "R" }) do pcall(function() UI.setAttribute("turnFlash" .. e, "color", c) end) end
        end
        pcall(function() if tt.lit then UI.show("turnFlash") else UI.hide("turnFlash") end end)
        Wait.time(step, TURN_TIMER_STAGES[tt.stage].half)
    end
    Wait.time(step, 0.4)                       -- the rebuilt UI exists a moment later
end
