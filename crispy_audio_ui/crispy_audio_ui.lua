-- Crispy Audio+Shortcut UI

local sim = ac.getSim()
local car = ac.getCar(0) or error()

local CRISPYAUDIODEFAULTS = {
    lastVolume = 0.5,
    -- carButtonsPlus = true,
    keepVisible = true,
    keepConVisible = true,
    bAudioAlpha = 0,
    muteVolume = 0,
    buttonsCount = 1,
    bConAlpha = 1,
    showTurbo = true,
    showBrakes = true,
    showWipers = true,
    showTurningLights = true,
    showLights = true,
    showHorn = true,
}

local st = ac.storage(CRISPYAUDIODEFAULTS)

local function setVolume(v)
    ac.setAudioVolume(v)
    st.lastVolume = v
end

local fadeAlphaAudio = 1.0
local fadeAlphaCon = 1.0
local fadeSpeed = 8.0 -- higher = faster fade

function script.windowHotShort()
    local dt = ui.deltaTime()
    ui.beginOutline()
    local hovered = ui.windowHovered()

    local targetAlphaCon = hovered and 1.0 or 0.0
    fadeAlphaCon = fadeAlphaCon + (targetAlphaCon - fadeAlphaCon) * math.min(1, dt * fadeSpeed)
    if st.keepConVisible then
        ui.pushStyleVarAlpha(1)
    else
        ui.pushStyleVarAlpha(fadeAlphaCon)
    end
    local colTurningLights = rgbm(0.5, 1, 0.5, 1)
    local colHazards = rgbm(1, 0.5, 0.5, 1)
    local w3 = (ui.availableSpaceX() - 2) / 3
    local controls = ac.overrideCarControls()
    if car.wiperModes > 1 and st.showWipers then
        ui.setNextItemWidth(156)
        local value = ui.slider('##wiper', car.wiperSelectedMode, 0, car.wiperModes - 1,
            car.wiperSelectedMode == 0 and 'Wipers: off' or 'Wipers: %d/%d' % { car.wiperMode, car.wiperModes - 1 })
        if ui.itemEdited() then
            ac.setWiperMode(math.round(value))
        end
    end
    if st.showLights then
        if car.headlightsAreHeadlights and car.hasLowBeams then
            ui.setNextItemWidth(156)
            local value = ui.slider('##lights', not car.headlightsActive and 0 or car.lowBeams and 1 or 2, 0, 2,
                not car.headlightsActive and 'No lights' or car.lowBeams and 'Low beams' or 'High beams')
            if ui.itemEdited() then
                value = math.round(value)
                ac.setHeadlights(value ~= 0)
                ac.setHighBeams(value == 2)
            end
        else
            if st.buttonsCount > 4 then
                ui.setNextItemWidth(156)
                if ui.checkbox('Lights', car.headlightsActive) then ac.setHeadlights(not car.headlightsActive) end
            end
        end
    end
    -- Turning lights & hazards
    if car.hasTurningLights and st.showTurningLights then
        if car.turningLightsActivePhase and car.turningLeftLights then
            ui.pushStyleColor(ui.StyleColor.Text, colTurningLights)
        end
        if ui.iconButton(ui.Icons.TurnSignalLeft, vec2(w3, 0), 4, true) then
            ac.setTurningLights(car.turningLeftOnly and ac.TurningLights.None or ac.TurningLights.Left)
        end
        if car.turningLightsActivePhase and car.turningLeftLights then ui.popStyleColor() end

        ui.sameLine(0, 4)
        if car.turningLightsActivePhase and car.hazardLights then ui.pushStyleColor(ui.StyleColor.Text, colHazards) end
        if ui.iconButton(ui.Icons.Hazard, vec2(w3, 0), 4, true) then
            ac.setTurningLights(car.hazardLights and ac.TurningLights.None or ac.TurningLights.Hazards)
        end
        if car.turningLightsActivePhase and car.hazardLights then ui.popStyleColor() end

        ui.sameLine(0, 4)
        if car.turningLightsActivePhase and car.turningRightLights then
            ui.pushStyleColor(ui.StyleColor.Text, colTurningLights)
        end
        if ui.iconButton(ui.Icons.TurnSignalRight, vec2(w3, 0), 4, true) then
            ac.setTurningLights(car.turningRightOnly and ac.TurningLights.None or ac.TurningLights.Right)
        end
        if car.turningLightsActivePhase and car.turningRightLights then ui.popStyleColor() end
    end
    if car.hasHornAudioEvent and st.showHorn then
        if car.sirenHorn then
            ui.setNextItemWidth(156)
            if ui.checkbox('Siren', car.hornActive) then
                controls.horn = true
                setTimeout(function()
                    controls.horn = false
                end, 0.1)
            end
        else
            ui.setNextItemIcon(ui.Icons.Speaker)
            ui.button('Horn', vec2(156, 0))
            controls.horn = ui.itemActive()
        end
    end
    if car.brakesCockpitBias and st.showBrakes then
        ui.setNextItemWidth(156)
        local value = ui.slider('##brakes', car.brakeBias * 100, car.brakesBiasLimitDown * 100,
            car.brakesBiasLimitUp * 100, 'Brakes: %.0f%%')
        if ui.itemEdited() then ac.setBrakeBias(value / 100) end
    end
    if car.adjustableTurbo and st.showTurbo then
        ui.setNextItemWidth(156)
        local value = ui.slider('##turbo', car.turboWastegates[0] * 10, 0, 10, 'Turbo: %.0f/10')
        if ui.itemEdited() then ac.setTurboWastegate(value / 10) end
    end
    ui.popStyleVar()
    ui.endOutline(rgbm(0, 0, 0, st.bConAlpha))
end

function script.windowMain()
    local dt = ui.deltaTime()
    ui.beginOutline()
    local hovered = ui.windowHovered()

    local targetAlphaAudio = hovered and 1.0 or 0.0
    fadeAlphaAudio = fadeAlphaAudio + (targetAlphaAudio - fadeAlphaAudio) * math.min(1, dt * fadeSpeed)
    if st.keepVisible then
        ui.pushStyleVarAlpha(1)
    else
        ui.pushStyleVarAlpha(fadeAlphaAudio)
    end
    local current = ac.getAudioVolume(ac.AudioChannel.Main)
    if ui.button("🔈") then
        if current < 0.19 then
            setVolume(0.2)
        else
            setVolume(0.1)
        end
    end
    if ui.itemHovered() then
        ui.setTooltip('10/20')
    end
    ui.sameLine()
    if ui.button("🔉") then
        if current < 0.49 then
            setVolume(0.5)
        else
            setVolume(0.30)
        end
    end
    if ui.itemHovered() then
        ui.setTooltip('30/50')
    end
    ui.sameLine()
    if ui.button("🔊") then
        if current < 0.98 then
            setVolume(0.99)
        else
            setVolume(0.8)
        end
    end
    if ui.itemHovered() then
        ui.setTooltip('99/80')
    end
    ui.sameLine()
    local muteIcon = "%.0f%%"
    if current < 0.001 then
        muteIcon = ' 🔇  '
    else
        muteIcon = "%.0f%%"
    end
    if ui.button(string.format(muteIcon, current * 100)) then
        if current > 0 then
            st.muteVolume = current
            setVolume(0.0)
        else
            setVolume(st.muteVolume > 0 and st.muteVolume or 0.5)
        end
    end
    if ui.itemHovered() then
        ui.setTooltip('Mute/Unmute')
    end
    ui.popStyleVar()
    ui.endOutline(rgbm(0, 0, 0, st.bAudioAlpha))
end

function script.windowASettings()
    ui.beginOutline()
    ui.setNextItemWidth(150)
    if ui.checkbox('Disable fading for audio', st.keepVisible) then
        st.keepVisible = not st.keepVisible
    end
    ui.setNextItemWidth(180)
    local value = ui.slider('##Contrast', st.bAudioAlpha, 0, 1, 'Background Contrast %.2f')
    if ui.itemEdited() then st.bAudioAlpha = value end
    ui.textColored('made by SavageBulldogOG', rgbm(0.7, 0.7, 1, 1))
    if ui.itemHovered() then
        ui.setTooltip(
            'Imagine putting a patreon link here and telling people to check you out. The Audacity! Whatever I will do it anyway 🤡. You can find and punish me by joining the free tier at → patreon.com/SB618 ← much love 🫶')
    end
    ui.endOutline(rgbm.colors.black)
end

function script.windowSSettings()
    ui.beginOutline()
    ui.setNextItemWidth(150)
    if ui.checkbox('Disable fading for controls', st.keepConVisible) then
        st.keepConVisible = not st.keepConVisible
    end
    ui.setNextItemWidth(180)
    local value = ui.slider('##Contrast', st.bConAlpha, 0, 1, 'Background Contrast %.2f')
    if ui.itemEdited() then st.bConAlpha = value end
    ui.newLine(-5)
    if ui.checkbox('Show Turbo', st.showTurbo) then
        st.showTurbo = not st.showTurbo
    end
    if ui.itemHovered() then
        ui.setTooltip('Only available controls will show up.')
    end
    if ui.checkbox('Show Brakes', st.showBrakes) then
        st.showBrakes = not st.showBrakes
    end
    if ui.checkbox(' Show Wipers', st.showWipers) then
        st.showWipers = not st.showWipers
    end
    if ui.checkbox('Show Turning lights', st.showTurningLights) then
        st.showTurningLights = not st.showTurningLights
    end
    if ui.checkbox('Show Lights', st.showLights) then
        st.showLights = not st.showLights
    end
    if ui.checkbox('Show Horn / Siren', st.showHorn) then
        st.showHorn = not st.showHorn
    end

    ui.textColored('made by SavageBulldogOG', rgbm(0.7, 0.7, 1, 1))
    if ui.itemHovered() then
        ui.setTooltip(
            'Imagine putting a patreon link here and telling people to check you out. The Audacity! Whatever I will do it anyway 🤡. You can find and punish me by joining the free tier at → patreon.com/SB618 ← much love 🫶')
    end
    ui.endOutline(rgbm.colors.black)
end
