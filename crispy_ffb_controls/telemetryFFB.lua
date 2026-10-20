-- Read-only FFB telemetry; rendering uses normalized CSP signals, not Nm.
local M = {}
local configCache, configAt = nil, -10
local samples, elapsed, clock = {}, 0, 0
local capacity, period = 300, 1 / 30
local head, count = 0, 0
local peak, sumSquares, saturated = 0, 0, 0
local function number(object, key)
  local ok, value = pcall(function() return object[key] end)
  if ok and type(value) == 'number' and value == value and math.abs(value) < math.huge then return value end
  return nil
end
local function reset()
  samples, elapsed, clock, head, count = {}, 0, 0, 0, 0
  peak, sumSquares, saturated = 0, 0, 0
end
function M.update(dt)
  local sim = ac.getSim()
  if sim.isPaused or sim.isReplayActive or sim.isReplayOnlyMode then return end
  local car = ac.getCar(0)
  if not car then return end
  local final, pure = number(car, 'ffbFinal'), number(car, 'ffbPure')
  if not final and not pure then return end
  dt = math.max(0, tonumber(dt) or 0)
  clock, elapsed = clock + dt, elapsed + dt
  if elapsed < period then return end
  elapsed = elapsed % period
  head, count = head % capacity + 1, math.min(capacity, count + 1)
  samples[head] = {time = clock, final = final, pure = pure}
  peak, sumSquares, saturated = 0, 0, 0
  local valid = 0
  for _, sample in pairs(samples) do
    if sample.final then
      valid = valid + 1
      peak = math.max(peak, math.abs(sample.final))
      sumSquares = sumSquares + sample.final * sample.final
      if math.abs(sample.final) >= 0.999 then saturated = saturated + 1 end
    end
  end
  M.rms, M.atLimit = valid > 0 and math.sqrt(sumSquares / valid) or 0, valid > 0 and 100 * saturated / valid or 0
end
local function row(label, value, format)
  ui.text(label .. ': ' .. (value ~= nil and string.format(format or '%.4f', value) or 'Unavailable'))
end
local function configRow(cfg, section, key, label, default, format)
  local v = cfg:get(section, key, default)
  if type(v) == 'boolean' then ui.text(label .. ': ' .. (v and 'On' or 'Off'))
  elseif type(v) == 'number' then row(label, v, format)
  else ui.text(label .. ': ' .. tostring(v or 'Unavailable')) end
end
function M.draw()
  local car = ac.getCar(0)
  if not car then ui.text('Waiting for player car...'); return end
  ui.header('Live FFB')
  row('Final FFB', number(car, 'ffbFinal'))
  row('Pure FFB', number(car, 'ffbPure'))
  local gain = number(car, 'ffbMultiplier')
  row('Car gain', gain and gain * 100, '%.1f%%')
  row('Car base multiplier (FFMULT)', number(car, 'ffbBase'))
  row('Car steer assist (STEER_ASSIST)', number(car, 'ffbSteerAssist'))
  row('Peak final magnitude (window)', peak)
  row('RMS final (window)', M.rms)
  row('Samples at output limit', M.atLimit, '%.1f%%')
  ui.textWrapped('Normalized signals. Output-limit samples indicate saturation, not a complete diagnosis of clipping upstream.')
  if ui.button('Clear graph history') then reset(); M.rms, M.atLimit = nil, nil end
  ui.header('FFB graph - last 10 seconds')
  ui.text('Cyan: final   Yellow: pure   Red: +/-100%')
  local p, width, height = ui.getCursor(), ui.availableSpaceX(), 200
  local range = 1.25
  for _, s in pairs(samples) do range = math.max(range, math.abs(s.final or 0) * 1.1, math.abs(s.pure or 0) * 1.1) end
  local function point(time, value)
    return vec2(p.x + width * math.max(0, math.min(1, (time - (clock - 10)) / 10)), p.y + height * (0.5 - value / (2 * range)))
  end
  ui.drawRectFilled(p, vec2(p.x + width, p.y + height), rgbm(0.06, 0.075, 0.07, 1))
  for _, value in ipairs({-1, 0, 1}) do
    ui.drawLine(point(clock - 10, value), point(clock, value), value == 0 and rgbm(0.3, 0.4, 0.3, 1) or rgbm(0.8, 0.2, 0.15, 1), 1)
  end
  for age = count - 1, 1, -1 do
    local a = samples[(head - age - 1) % capacity + 1]
    local b = samples[(head - age) % capacity + 1]
    if a and b and a.time >= clock - 10 then
      if a.final and b.final then ui.drawLine(point(a.time, a.final), point(b.time, b.final), rgbm(0.1, 0.85, 0.85, 1), 1) end
      if a.pure and b.pure then ui.drawLine(point(a.time, a.pure), point(b.time, b.pure), rgbm(0.95, 0.85, 0.1, 1), 1) end
    end
  end
  ui.dummy(vec2(width, height))
  ui.textWrapped(string.format('Vertical range: +/-%.2f. Center = Zero', range))
end

function M.drawInformation()
  ui.header('Global FFB configuration')
  if not configCache or ui.time() - configAt >= 1 then
    configCache = {
      ac.INIConfig.load(ac.getFolder(ac.FolderID.Cfg) .. '/controls.ini'),
      ac.INIConfig.load(ac.getFolder(ac.FolderID.ExtCfgUser) .. '/ffb_tweaks.ini'),
      ac.INIConfig.load(ac.getFolder(ac.FolderID.Root) .. '/system/cfg/assetto_corsa.ini'),
      ac.INIConfig.load(ac.getFolder(ac.FolderID.Cfg) .. '/ff_post_process.ini')}
    configAt = ui.time()
  end
  local controls, tweaks, system, post = configCache[1], configCache[2], configCache[3], configCache[4]
  -- Values below are config ratios; 1.0 means 100% unless labelled otherwise.
  ui.text('Configuration ratios: 1.0 = 100%')
  for _, item in ipairs({
    {'STEER','FF_GAIN','Overall gain',0.8}, {'STEER','FILTER_FF','Filter',0},
    {'FF_SKIP_STEPS','VALUE','Skip steps',1}, {'FF_TWEAKS','MIN_FF','Minimum force',0.03},
    {'FF_TWEAKS','CENTER_BOOST_GAIN','Center boost gain',0}, {'FF_TWEAKS','CENTER_BOOST_RANGE','Center boost range',0.1},
    {'FF_ENHANCEMENT','CURBS','Kerb effects',0}, {'FF_ENHANCEMENT','ROAD','Road effects',0},
    {'FF_ENHANCEMENT','SLIPS','Slip effects',0}, {'FF_ENHANCEMENT','ABS','ABS effects',0},
    {'FF_ENHANCEMENT_2','UNDERSTEER','Understeer effect',0}}) do configRow(controls,item[1],item[2],item[3],item[4]) end
  for _, item in ipairs({
    {'BASIC','ENABLED','FFB Tweaks',true}, {'GYRO2','ENABLED','CSP gyro',false}, {'GYRO2','STRENGTH','Legacy gyro strength',0.25},
    {'POSTPROCESSING','RANGE_COMPRESSION','Range compression',1}, {'POSTPROCESSING','RANGE_COMPRESSION_ASSIST','Range compression assist',false},
    {'POSTPROCESSING','DIRT_VIBRATION','Dirt vibration',0}, {'CUSTOM_SOFT_LOCK','ENABLED','Custom soft lock',true},
    {'REAL_FEEL','ENABLED','Real steering forces',false}, {'REAL_FEEL','WHEEL_MAX_NM','Configured wheel peak Nm',35},
    {'REAL_FEEL','ENABLE_FOR_ALL','Force real steering on all cars',false}}) do configRow(tweaks,item[1],item[2],item[3],item[4]) end
  for _, item in ipairs({
    {'FF_EXPERIMENTAL','ENABLE_GYRO','Standard gyro',false}, {'FF_EXPERIMENTAL','DAMPER_GAIN','Damper gain',1},
    {'FF_EXPERIMENTAL','DAMPER_MIN_LEVEL','Minimum damping',0}, {'LOW_SPEED_FF','SPEED_KMH','Low-speed threshold km/h',3},
    {'LOW_SPEED_FF','MIN_VALUE','Low-speed force multiplier',0.01}}) do configRow(system,item[1],item[2],item[3],item[4]) end
  configRow(post,'HEADER','ENABLED','AC post-processing',false)
  configRow(post,'HEADER','TYPE','Post-processing type','GAMMA')
  configRow(post,'GAMMA','VALUE','Post-processing gamma',1)
  configRow(post,'LUT','CURVE','LUT file','')
  ui.textWrapped('Configured values do not prove a feature is active for this car. Physical wheel torque and separate gyro/damper force signals are not exposed by these car fields.')
end
return M
