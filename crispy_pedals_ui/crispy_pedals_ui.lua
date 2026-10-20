---Crispy Pedals UI

local sim = ac.getSim()
local car = ac.getCar(sim.focusedCar) or error()

local CRISPYPEDALSDEFAULTS = {
  scale             = 1.0,
  barW              = 26,
  barH              = 80,
  bAlpha            = 3.5,
  gap               = 1,
  smoothing         = 0.20,
  showNumbers       = false,
  showLabels        = false,
  showHandbrakeBar  = false,
  showHandbrakeIcon = true,
  handbrakeText     = '🅿️',
  showFFBBar        = true,
  labelRotation     = 180, -- 90° Horizontal (left → right), 180° Vertical (bottom ↑ top)
  ffbMode           = 1,   -- 1=abs, 2=signed center
  showffbDebug      = false,
  showSteeringIcon  = false,
}

local default_colors = {
  throttleColor  = rgbm(0.20, 0.90, 0.25, 0.90),
  brakeColor     = rgbm(0.95, 0.25, 0.25, 0.90),
  clutchColor    = rgbm(0.25, 0.60, 1.00, 0.90),
  handbrakeColor = rgbm(1.00, 0.70, 0.20, 0.90),
  ffbColorPos    = rgbm(0.75, 0.80, 1.00, 0.90),
  ffbColorNeg    = rgbm(1.00, 0.80, 0.75, 0.90),
}

local st = ac.storage(CRISPYPEDALSDEFAULTS)
local dc = ac.storage(default_colors)

local function ResetColors()
  for k, v in pairs(default_colors) do
    dc[k] = v
  end
  dc.throttleColor  = rgbm(0.20, 0.90, 0.25, 0.90)
  dc.brakeColor     = rgbm(0.95, 0.25, 0.25, 0.90)
  dc.clutchColor    = rgbm(0.25, 0.60, 1.00, 0.90)
  dc.handbrakeColor = rgbm(1.00, 0.70, 0.20, 0.90)
  dc.ffbColorPos    = rgbm(0.75, 0.80, 1.00, 0.90)
  dc.ffbColorNeg    = rgbm(1.00, 0.80, 0.75, 0.90)
end

local function clamp01(x)
  if x < 0.0001 then return 0 end
  if x > 1 then return 1 end
  return x
end

local function lerp(a, b, t) return a + (b - a) * t end

local sm = { t = 0, b = 0, c = 0, h = 0, f = 0 }
local function smooth(key, target)
  local k = sm[key] or 0
  local t = st.smoothing
  if t <= 0 then
    sm[key] = target; return target
  end
  k = lerp(k, target, clamp01(t))
  sm[key] = k
  return clamp01(k)
end

local function fontScalerText()
  if st.scale < 1.4 then
    ui.pushFont(ui.Font.SmallItalic)
  elseif st.scale > 2.25 then
    ui.pushFont(ui.Font.Title)
  else
    ui.pushFont(ui.Font.Main)
  end
end

local function fontScalerNumber()
  if st.scale < 1.35 then
    ui.pushFont(ui.Font.Small)
  elseif st.scale > 2.25 then
    ui.pushFont(ui.Font.Title)
  else
    ui.pushFont(ui.Font.Main)
  end
end

local function drawSteerWheel(size)
  local steerTexture = 'icons/steering.png'

  local p0 = ui.getCursor() + 2
  local p1 = vec2(p0.x + size, p0.y + size) - 2

  ui.beginRotation()
  ui.drawImage(steerTexture, p0, p1)
  ui.endRotation(90 - car.steer)

  ui.dummy(vec2(size, size))
  return p0, p1
end

local function drawHandbrakeIconOverBar(p0, p1, handbrakeValue)
  if handbrakeValue < 0.001 then return end
  local cx   = (p0.x + p1.x) * 0.5
  local y    = (p0.y + p1.y) * 0.2
  local text = st.handbrakeText
  local size = ui.measureText(text)
  local pad  = 3
  local a0   = vec2(cx - size.x * 0.5 - pad, y)
  local a1   = vec2(cx + size.x * 0.5 + pad, y + size.y + pad)
  ui.drawRectFilled(a0, a1, rgbm(0, 0, 0, 0.25), 3)
  ui.drawText(text, vec2(cx - size.x * 0.5, y + 1), rgbm(1, 0.3, 0.3, 0.9))
end

local function drawFFBClipIconOverBar(p0, p1, ffbValue, ffbMax)
  if ffbMax <= 0 then return end
  if math.abs(ffbValue) < ffbMax then return end
  local text = "⚠️"
  local cx   = (p0.x + p1.x) * 0.5
  local y    = (p0.y + p1.y) * 0.2
  fontScalerText()
  local size = ui.measureText(text)
  local pad = 3
  local bg0 = vec2(cx - size.x * 0.5 - pad, y)
  local bg1 = vec2(cx + size.x * 0.5 + pad, y + size.y + pad)
  ui.drawRectFilled(bg0, bg1, rgbm(0, 0, 0, 0.45), 4)
  ui.drawText(text, vec2(cx - size.x * 0.5, y + 1), rgbm(1, 0.3, 0.3, 0.9))
  ui.popFont()
end

local function drawRotatedLabelInBar(label, p0, p1, fillTopY, rotationDeg)
  fontScalerText()
  local pad = 20
  local t0 = vec2(p0.x - pad, p0.y - pad)
  local t1 = vec2(p1.x + pad, p1.y + pad)
  ui.beginRotation()
  ui.drawTextClipped(label, t0, t1, rgbm.colors.white, 0.5)
  if fillTopY < p1.y then
    ui.pushClipRect(vec2(p0.x, fillTopY), p1, false)
    ui.drawTextClipped(label, t0, t1, rgbm.colors.black, 0.5)
    ui.popClipRect()
  end
  ui.endRotation(rotationDeg)
  ui.popFont()
end

local function drawBar(label, v, w, h, fillColor, backColor)
  local p0 = ui.getCursor()
  local p1 = vec2(p0.x + w, p0.y + h)
  ui.drawRectFilled(p0, p1, backColor)
  local fillH = math.floor(h * v + 0.5)
  local fillTopY = p1.y
  if fillH > 0 then
    fillTopY = p1.y - fillH
    ui.drawRectFilled(vec2(p0.x, fillTopY), p1, fillColor)
  end
  if st.showLabels then
    drawRotatedLabelInBar(label, p0, p1, fillTopY, st.labelRotation)
  end
  if st.showNumbers then
    fontScalerNumber()
    ui.drawTextClipped(string.format("%0.0f%%", v * 100), p0, p1, rgbm(1, 1, 1, 0.9), vec2(0.5, 0))
    ui.popFont()
  end
  ui.drawRect(p0, p1, rgbm(1, 1, 1, st.bAlpha / 30))
  ui.dummy(vec2(w, h))
  return p0, p1, fillTopY
end

local function drawSignedBar(label, signedValue, w, h, posColor, negColor, backColor)
  -- signedValue in [-1..1], center = 0
  local p0 = ui.getCursor()
  local p1 = vec2(p0.x + w, p0.y + h)
  ui.drawRectFilled(p0, p1, backColor)
  local cx = p0.x + w * 0.5
  ui.drawLine(vec2(cx, p0.y), vec2(cx, p1.y), rgbm(1, 1, 1, 0.25), 1)
  local v = math.max(-1, math.min(1, signedValue))
  local fillTopY = p1.y
  if v ~= 0 then
    local dx = math.floor((w * 0.5) * math.abs(v) + 0.5)
    if v > 0 then
      ui.drawRectFilled(vec2(cx, p0.y), vec2(cx + dx, p1.y), posColor)
    else
      ui.drawRectFilled(vec2(cx - dx, p0.y), vec2(cx, p1.y), negColor)
    end
  end
  if st.showLabels then
    drawRotatedLabelInBar(label, p0, p1, fillTopY, st.labelRotation)
  end
  if st.showNumbers then
    fontScalerNumber()
    ui.drawTextClipped(
      string.format("%+.2f", v), p0, p1, rgbm(1, 1, 1, 0.9), vec2(0.5, 0))
    ui.popFont()
  end
  ui.drawRect(p0, p1, rgbm(1, 1, 1, st.bAlpha / 30))
  ui.dummy(vec2(w, h))
  return p0, p1
end

function script.windowMain()
  local s         = st.scale
  local w         = math.floor(st.barW * s)
  local h         = math.floor(st.barH * s)
  local throttle  = clamp01(car.gas)
  local brake     = clamp01(car.brake)
  local clutch    = 1 - clamp01(car.clutch)
  local handbrake = clamp01(car.handbrake)

  throttle        = smooth("t", throttle)
  brake           = smooth("b", brake)
  clutch          = smooth("c", clutch)
  handbrake       = smooth("h", handbrake)

  local ffb       = 0
  if car then
    ffb = tonumber(car.ffbFinal) or 0
  end

  local back = rgbm(0, 0, 0, st.bAlpha / 10)
  local cGas = dc.throttleColor
  local cBrake = dc.brakeColor
  local cClutch = dc.clutchColor
  local cHand = dc.handbrakeColor

  if st.showSteeringIcon then
    drawSteerWheel(82 * s)
    ui.sameLine(0, st.gap)
  end
  drawBar("Clutch", clutch, w, h, cClutch, back)
  ui.sameLine(0, st.gap)
  if st.showHandbrakeIcon then
    local bp0, bp1 = drawBar("Brake", brake, w, h, cBrake, back)
    drawHandbrakeIconOverBar(bp0, bp1, handbrake)
  else
    drawBar("Brake", brake, w, h, cBrake, back)
  end
  ui.sameLine(0, st.gap)
  drawBar("Throttle", throttle, w, h, cGas, back)
  if st.showHandbrakeBar then
    ui.sameLine(0, st.gap)
    drawBar("Handbrake", handbrake, w, h, cHand, back)
  end
  if st.showFFBBar then
    if st.ffbMode == 1 then
      ui.sameLine(0, st.gap)
      local clipcolor
      if math.abs(ffb) > 1 then clipcolor = rgbm.colors.red else clipcolor = dc.ffbColorPos end
      local fp0, fp1 = drawBar("FFB", math.abs(ffb), w, h, clipcolor, back)
      drawFFBClipIconOverBar(fp0, fp1, ffb, 1)
    else
      ui.sameLine(0, st.gap)
      local clipcolorpos
      local clipcolorneg
      if ffb > 1 then clipcolorpos = rgbm.colors.red else clipcolorpos = dc.ffbColorPos end
      if ffb < (-1) then clipcolorneg = rgbm.colors.red else clipcolorneg = dc.ffbColorNeg end
      local fp0, fp1 = drawSignedBar("FFB signed", ffb, w, h, clipcolorpos, clipcolorneg,
        back)
      drawFFBClipIconOverBar(fp0, fp1, ffb, 1)
    end
  end
end

function script.windowSettings()
  local w2 = (ui.availableSpaceX() - 4) / 2
  ui.beginOutline()
  ui.textColored('Pedals app settings', rgbm(0.9, 0.9, 1, 1))
  ui.sameLine(0, w2 - 5)
  if ui.button('Reset') then
    for k, v in pairs(CRISPYPEDALSDEFAULTS) do
      st[k] = v
    end
    ResetColors()
  end
  ui.tabBar('CrispyPedalTabsID', function()
    ui.tabItem('General', function() --[[ Contents of Tab 1 ]]
      ui.text('Select options')
      if ui.checkbox("Show handbrake icon", st.showHandbrakeIcon) then
        st.showHandbrakeIcon = not st.showHandbrakeIcon
      end
      if ui.checkbox("Show handbrake bar", st.showHandbrakeBar) then
        st.showHandbrakeBar = not st.showHandbrakeBar
      end
      if ui.checkbox("Show FFB Bar", st.showFFBBar) then
        st.showFFBBar = not st.showFFBBar
      end
      if ui.checkbox("Show labels", st.showLabels) then
        st.showLabels = not st.showLabels
      end
      if ui.checkbox("Show numbers", st.showNumbers) then
        st.showNumbers = not st.showNumbers
      end
      if ui.checkbox("Show steering", st.showSteeringIcon) then
        st.showSteeringIcon = not st.showSteeringIcon
      end
    end)
    ui.tabItem('Customization', function() --[[ Contents of Tab 2 ]]
      ui.text('Change appearence')
      st.scale = ui.slider("##Scale", st.scale, 0.8, 3.0, "Scale: %.2f")
      ui.newLine(1)
      st.barW   = ui.slider("##Bar width", st.barW, 14, 100, " Bar Width: %.0fpx")
      st.barH   = ui.slider("##Bar height", st.barH, 48, 200, "Bar Height: %.0fpx")
      st.bAlpha = ui.slider("##Background", st.bAlpha, 0, 5, "Background Opacity: %.1f")
      ui.newLine(1)
      st.gap       = ui.slider("##Spacing", st.gap, 0, 20, "Spacing: %.0f")
      st.smoothing = ui.slider("##Smoothing", st.smoothing, 0.1, 0.5, "Smoothing: %.2f")
      ui.newLine(1)
      ui.text("Bar Colors")
      if ui.button('Reset') then
        ResetColors()
      end
      ui.sameLine(0, 7)
      ui.colorButton("Throttle", dc.throttleColor,
        bit.bor(ui.ColorPickerFlags.AlphaBar, ui.ColorPickerFlags.AlphaPreview, ui.ColorPickerFlags.PickerHueBar))
      ui.sameLine(0, 7)
      ui.colorButton("Brake", dc.brakeColor,
        bit.bor(ui.ColorPickerFlags.AlphaBar, ui.ColorPickerFlags.AlphaPreview, ui.ColorPickerFlags.PickerHueBar))
      ui.sameLine(0, 7)
      ui.colorButton("Clutch", dc.clutchColor,
        bit.bor(ui.ColorPickerFlags.AlphaBar, ui.ColorPickerFlags.AlphaPreview, ui.ColorPickerFlags.PickerHueBar))
      ui.sameLine(0, 7)
      ui.colorButton("Handbrake", dc.handbrakeColor,
        bit.bor(ui.ColorPickerFlags.AlphaBar, ui.ColorPickerFlags.AlphaPreview, ui.ColorPickerFlags.PickerHueBar))
      ui.sameLine(0, 7)
      ui.colorButton("FFB+", dc.ffbColorPos,
        bit.bor(ui.ColorPickerFlags.AlphaBar, ui.ColorPickerFlags.AlphaPreview, ui.ColorPickerFlags.PickerHueBar))
      ui.sameLine(0, 7)
      ui.colorButton("FFB-", dc.ffbColorNeg,
        bit.bor(ui.ColorPickerFlags.AlphaBar, ui.ColorPickerFlags.AlphaPreview, ui.ColorPickerFlags.PickerHueBar))
      ui.newLine(1)
      ui.setNextItemWidth(w2 - 98)
      st.handbrakeText = ui.inputText(' ← Set Handbrake Icon here', st.handbrakeText)
      if ui.itemHovered() then
        ui.setTooltip(
          'I left some emojis to copy/paste below, but you can put any text or symbol in here theoretically.')
      end
      ui.inputText('##HandbrakeIcon-A', "🐗🅿️🛑☠️💀🤡⛔🚫🖐️🐌🧠🦾🫁👀🐢", ui.InputTextFlags.ReadOnly)
    end)
    ui.tabItem('Misc', function() --[[ Contents of Tab 3 ]]
      ui.text('Additional settings')
      local rotIdx     = ui.combo("Text rotation", (st.labelRotation == 90) and 2 or 1, ui.ComboFlags.None,
        { "Vertical (bottom ↑ top)", "Horizontal (left → right)" })
      st.labelRotation = (rotIdx == 2) and 90 or 180
      st.ffbMode       = ui.combo("FFB display", st.ffbMode, ui.ComboFlags.None, { "Absolute", "Signed (centered)" })
      if ui.checkbox('Additional force feedback info', st.showffbDebug) then
        st.showffbDebug = not st.showffbDebug
      end
      if st.showffbDebug then
        local car = ac.getCar(ac.getSim().focusedCar)
        if car then
          ui.text(string.format("ffbFinal: %.3f", tonumber(car.ffbFinal) or 0))
          ui.text(string.format("ffbPure: %.3f", tonumber(car.ffbPure) or 0))
          ui.text(string.format("ffbBase: %.3f", tonumber(car.ffbBase) or 0))
          ui.text(string.format("ffbMultiplier: %.3f", tonumber(car.ffbMultiplier) or 0))
          ui.text(string.format("ffbAssist: %.3f", tonumber(car.ffbSteerAssist) or 0))
        end
      end
      ui.textColored('made by SavageBulldogOG', rgbm(0.7, 0.7, 1, 1))
      if ui.itemHovered() then
        ui.setTooltip(
          'Imagine putting a patreon link here and telling people to check you out. The Audacity! Whatever I will do it anyway 🤡. You can find and punish me by joining the free tier at → patreon.com/SB618 ← much love 🫶')
      end
    end)
  end)
  ui.endOutline(rgbm.colors.black)
end
