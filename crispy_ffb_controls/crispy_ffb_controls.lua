-- Crispy FFB Controls 2.0: automatic native per-car default + global AC/CSP controls.
-- Layout, ranges and reset semantics follow x4fab's Controller Tweaks.
local telemetry = require('telemetryFFB')
local controllerFFB = require('controllerFFB')
local telemetryError = nil
local originalCarGain = nil
local prefs = ac.storage({ enabled = true, overwrite = false, target = 60 }, 'FirstDriveFFB:')
local state = { carID = nil, checked = false, message = 'Waiting for player car...', error = nil }
local configs = nil
local lastRefresh = -10
local nativePath = ac.getFolder(ac.FolderID.Cfg) .. '/user_ff.ini'

local function target()
  return math.floor(math.max(0, math.min(200, tonumber(prefs.target) or 60)) + 0.5)
end

local function startup(force)
  force = force == true
  local sim = ac.getSim()
  if sim.isReplayActive or sim.isReplayOnlyMode then return end
  local car, id = ac.getCar(0), ac.getCarID(0)
  if not car or not id or id == '' then return end
  state.carID = id
  if state.checked and not force then return end
  if type(car.ffbMultiplier) ~= 'number' or car.ffbMultiplier ~= car.ffbMultiplier then return end
  if originalCarGain == nil then originalCarGain = car.ffbMultiplier end
  state.checked = true -- Exactly once per AC launch; UI edits never reset this.
  if not prefs.enabled then
    state.message = 'Automatic defaults disabled at session start.'; return
  end
  local ini = ac.INIConfig.load(nativePath)
  local saved = ini:get(id, 'VALUE', ac.INIConfig.OptionalString)
  if not prefs.overwrite and saved ~= nil then
    state.message = 'Saved car gain preserved.'; return
  end
  if not prefs.overwrite and math.abs(car.ffbMultiplier - 1) > 0.0005 then
    state.message = 'Existing live car gain preserved.'; return
  end
  local value = target() / 100
  ac.setFFBMultiplier(value)
  ini:setAndSave(id, 'VALUE', string.format('%.3f', value))
  local verified = ac.INIConfig.load(nativePath):get(id, 'VALUE', ac.INIConfig.OptionalNumber)
  if not verified or math.abs(verified - value) > 0.0005 then error('Car gain applied, but saving user_ff.ini failed.') end
  state.message = string.format(prefs.overwrite and 'Overrode this car to %d%%.' or 'Initialised this car to %d%%.',
    target())
  ac.setMessage(string.format('Car FFB gain: %d%%', target()), 'Crispy FFB Controls')
end

function script.update(dt)
  local sampled, sampleError = pcall(telemetry.update, dt)
  telemetryError = not sampled and tostring(sampleError) or nil
  if state.error then return end
  local ok, err = pcall(startup)
  if not ok then
    state.error = tostring(err); ac.log('Crispy FFB Controls: ' .. state.error)
  end
end

-- Original values are captured when this app loads, not after every edit.
local function mapped(load, layout)
  local cfg = { load = load, layout = layout, original = {}, data = {}, refreshAfter = 0 }
  function cfg:refresh()
    -- Let control reloads settle before replacing the local edited values.
    if ui.time() < self.refreshAfter then return end
    self.ini = self.load()
    for section, keys in pairs(self.layout) do
      self.data[section] = self.data[section] or {}
      for key, default in pairs(keys) do self.data[section][key] = self.ini:get(section, key, default) end
    end
  end

  cfg:refresh()
  for section, keys in pairs(cfg.data) do
    cfg.original[section] = {}
    for key, value in pairs(keys) do cfg.original[section][key] = value end
  end
  function cfg:set(section, key, value)
    if self.data[section][key] == value then return end
    self.ini:setAndSave(section, key, value)
    self.data[section][key] = value
    self.refreshAfter = ui.time() + 4
    setTimeout(function() ac.reloadControlSettings() end, 0.02, 'FirstDriveFFB:reload')
  end

  return cfg
end

local function initConfigs()
  if configs then return end
  configs = {
    controls = mapped(function() return ac.INIConfig.load(ac.getFolder(ac.FolderID.Cfg) .. '/controls.ini') end, {
      STEER = { FF_GAIN = 0.8, FILTER_FF = 0 },
      FF_SKIP_STEPS = { VALUE = 1 },
      FF_TWEAKS = { MIN_FF = 0.03, CENTER_BOOST_GAIN = 0, CENTER_BOOST_RANGE = 0.1 },
      FF_ENHANCEMENT = { CURBS = 0.3, ROAD = 0.3, SLIPS = 0.15, ABS = 0.2 },
      FF_ENHANCEMENT_2 = { UNDERSTEER = 0 }
    }),
    system = mapped(
      function() return ac.INIConfig.load(ac.getFolder(ac.FolderID.Root) .. '/system/cfg/assetto_corsa.ini') end, {
        FF_EXPERIMENTAL = { ENABLE_GYRO = false, DAMPER_GAIN = 1, DAMPER_MIN_LEVEL = 0 }, LOW_SPEED_FF = { SPEED_KMH = 3, MIN_VALUE = 0.01 } }),
    post = mapped(function() return ac.INIConfig.load(ac.getFolder(ac.FolderID.Cfg) .. '/ff_post_process.ini') end, {
      HEADER = { ENABLED = false, TYPE = 'GAMMA' }, GAMMA = { VALUE = 1 }, LUT = { CURVE = '' } }),
    tweaks = mapped(function() return ac.INIConfig.load(ac.getFolder(ac.FolderID.ExtCfgUser) .. '/ffb_tweaks.ini') end, {
      BASIC = { ENABLED = true }, GYRO2 = { ENABLED = false, STRENGTH = 0.25 }, POSTPROCESSING = { RANGE_COMPRESSION = 1, RANGE_COMPRESSION_ASSIST = false } })
  }
end
local configOK, configError = pcall(initConfigs)
if not configOK then
  configs = nil; state.error = 'Config load: ' .. tostring(configError)
end

local function resetButton(id, changed, tooltip)
  ui.sameLine(0, 4)
  local pressed = ui.button('##reset' .. id, vec2(20, 20), changed and ui.ButtonFlags.None or ui.ButtonFlags.Disabled)
  ui.addIcon(ui.Icons.Restart, 10, 0.5, nil, 0)
  if ui.itemHovered() then ui.setTooltip(tooltip) end
  return pressed and changed
end

local function slider(cfg, section, key, low, high, scale, format, tooltip)
  local old, original = cfg.data[section][key], cfg.original[section][key]
  ui.setNextItemWidth(ui.availableSpaceX() - 24)
  local displayed = ui.slider('##' .. section .. key, old * scale, low, high, format)
  if ui.itemHovered() then ui.setTooltip(tooltip) end
  local value = old
  -- Avoid rounding or writing existing config merely because UI was opened.
  if math.abs(displayed - old * scale) > 0.0001 then value = math.floor(displayed + 0.5) / scale end
  if resetButton(section .. key, math.abs(original - value) > 0.0001,
        string.format('Restore session-start value: ' .. format, original * scale)) then
    value = original
  end
  cfg:set(section, key, value)
end

local function globalCheckbox(cfg, section, key, label)
  local value = cfg.data[section][key]
  if ui.checkbox(label, value) then value = not value end
  cfg:set(section, key, value)
end

local function gyroMode(original)
  local t = original and configs.tweaks.original or configs.tweaks.data
  local s = original and configs.system.original or configs.system.data
  return t.BASIC.ENABLED and t.GYRO2.ENABLED and 3 or s.FF_EXPERIMENTAL.ENABLE_GYRO and 2 or 1
end
local function gyroUI(includeDamping)
  ui.offsetCursorY(8); ui.header('FFB gyro:')
  local mode, original = gyroMode(false), gyroMode(true)
  ui.setNextItemWidth(ui.availableSpaceX() - 24)
  local selected, changed = ui.combo('##gyro', mode, ui.ComboFlags.None, { 'None', 'Standard', 'FFB Tweaks' })
  if resetButton('gyro', selected ~= original, 'Restore session-start gyro mode') then selected, changed = original, true end
  if changed then
    configs.system:set('FF_EXPERIMENTAL', 'ENABLE_GYRO', selected == 2)
    configs.tweaks:set('GYRO2', 'ENABLED', selected == 3)
    -- Selecting the CSP implementation requires the parent module to be active.
    if selected == 3 then configs.tweaks:set('BASIC', 'ENABLED', true) end
    mode = selected
  end
  if mode == 3 then
    -- Explicitly requested legacy control: uncommented from Controller Tweaks.
    slider(configs.tweaks, 'GYRO2', 'STRENGTH', 0, 100, 100, 'Gyro strength: %.0f%%',
      'Legacy GYRO2 strength setting; whether it affects forces depends on your CSP build.')
  elseif mode == 2 and includeDamping ~= false then
  end
  ui.offsetCursorY(8); ui.header('FFB damper:')
  slider(configs.system, 'FF_EXPERIMENTAL', 'DAMPER_GAIN', 0, 200, 100, 'Gain: %.0f%%',
    'Damping gain, not gyro strength')
  slider(configs.system, 'FF_EXPERIMENTAL', 'DAMPER_MIN_LEVEL', 0, 200, 100, 'Min level: %.0f%%',
    'Minimum damping remaining at speed')
end

local function liveCarGainSlider()
  local car = ac.getCar(0)
  if not car or originalCarGain == nil then return end
  ui.setNextItemWidth(ui.availableSpaceX() - 48)
  local value = ui.slider('##carGain', car.ffbMultiplier * 100, 0, 200, 'Car FFB gain: %.0f%%') / 100
  ui.sameLine(0, 4)
  local changed = math.abs(value - 1) > 0.0001
  if ui.button('##carGain100', vec2(20, 20), changed and ui.ButtonFlags.None or ui.ButtonFlags.Disabled) then value = 1 end
  ui.addIcon(ui.Icons.Cancel, 10, 0.5, nil, 0)
  if ui.itemHovered() then ui.setTooltip('Set car gain to 100%') end
  if resetButton('carGainOriginal', math.abs(value - originalCarGain) > 0.0001, string.format('Restore original car gain: %.0f%%', originalCarGain * 100)) then
    value =
        originalCarGain
  end
  if math.abs(value - car.ffbMultiplier) > 0.0001 then
    ac.setFFBMultiplier(value)
    ac.setMessage(string.format('Car FFB gain: %.0f%%', value * 100), 'Crispy FFB Controls')
  end
end

local function window()
  ui.text('Crispy FFB Controls 2.2.1')
  ui.textWrapped('Car: ' .. (state.carID or 'Waiting...'))
  local car = ac.getCar(0)
  if car then ui.text(string.format('Current car gain: %.0f%%', car.ffbMultiplier * 100)) end
  ui.textWrapped(state.error or state.message)
  liveCarGainSlider()
  ui.separator()
  if ui.checkbox('Enable automatic defaults', prefs.enabled) then
    prefs.enabled = not prefs.enabled
    if prefs.enabled and prefs.overwrite then startup(true) end
  end
  if ui.checkbox('Override car gain', prefs.overwrite) then
    prefs.overwrite = not prefs.overwrite
    if prefs.enabled and prefs.overwrite then startup(true) end
  end
  ui.setNextItemWidth(ui.availableSpaceX())
  local default = ui.slider('##defaultGain', target(), 0, 200, 'Default car gain: %.0f%%')
  if default ~= target() then
    prefs.target = math.floor(default + 0.5)
    if prefs.enabled and prefs.overwrite then startup(true) end
  end
  ui.textWrapped('Override applies at startup and when enabled or its target changes.')
  initConfigs()
  if ui.time() - lastRefresh > 1 then
    for _, cfg in pairs(configs) do cfg:refresh() end
    lastRefresh = ui.time()
  end
  ui.offsetCursorY(8); ui.header('FFB:')
  slider(configs.controls, 'STEER', 'FF_GAIN', 0, 200, 100, 'Gain: %.0f%%', 'Overall AC FFB intensity (global)')
  slider(configs.controls, 'STEER', 'FILTER_FF', 0, 100, 100, 'Filter: %.0f%%', 'Increase to smooth out FFB')
  slider(configs.controls, 'FF_SKIP_STEPS', 'VALUE', 0, 10, 1, 'Skip steps: %.0f',
    string.format('Resulting FFB refresh rate: %.0f Hz',
      333 / (1 + math.max(0, configs.controls.data.FF_SKIP_STEPS.VALUE))))
  ui.offsetCursorY(8); ui.header('FFB tweaks:')
  slider(configs.controls, 'FF_TWEAKS', 'MIN_FF', 0, 100, 100, 'Minimum force: %.0f%%', 'Minimum force sent to the wheel')
  gyroUI()
  ui.offsetCursorY(8); ui.header('FFB post-processing:')
  globalCheckbox(configs.tweaks, 'POSTPROCESSING', 'RANGE_COMPRESSION_ASSIST', 'Range compression assist')
  if not configs.tweaks.data.BASIC.ENABLED then ui.textWrapped('FFB Tweaks module disabled: assist is inactive.') end
end
function script.windowMain()
  local ok, err = pcall(function()
    initConfigs()
    if ui.time() - lastRefresh > 1 then
      for _, cfg in pairs(configs) do cfg:refresh() end
      lastRefresh = ui.time()
    end
    ui.tabBar('CrispyFFBTabs', function()
      ui.tabItem('Quick Settings', window)
      ui.tabItem('Graph', function()
        if telemetryError then ui.textWrapped('Telemetry error: ' .. telemetryError) end
        telemetry.draw()
      end)
      ui.tabItem('Controls', function()
        initConfigs()
        controllerFFB.draw({
          configs = configs,
          slider = slider,
          gyro = gyroUI,
          reset = resetButton,
          checkbox =
              globalCheckbox,
          carGain = liveCarGainSlider
        })
      end)
      ui.tabItem('Info', telemetry.drawInformation)
    end)
  end)
  if not ok then ui.textWrapped('UI error: ' .. tostring(err)) end
end
