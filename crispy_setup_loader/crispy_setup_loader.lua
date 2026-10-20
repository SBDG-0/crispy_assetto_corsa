-- Crispy Setup Loader v0.2.5
-- Setup loading is supported by CSP only while the setup menu is open.
-- All remembered preferences are per car, independent of track.
local config = ac.storage({ autoRestore = true, useLast = false, tryImmediately = true })
local carID = ac.getCarID(0)
local root = ac.getFolder(ac.FolderID.UserSetups) .. '/' .. carID .. '/'
local lastPath = root .. 'generic/last.ini'
local memory = ac.storage({ preferred = '' }, 'car_' .. carID .. '_')
local preferred = memory.preferred
local entries, selected = {}, 1
local status = 'Waiting for startup'
local elapsed = 0
local startupAttempted = false
local autoFinished = false
local setupScreenSeen = false
local setupOpenedAt = nil
local setupFallbackAttempts = 0
local setupFallbackNext = 0
local setupFallbackDeadline = nil
local lastRequested = nil
local loadingFromApp = false

local function samePath(a, b)
  return type(a) == 'string' and type(b) == 'string'
    and a:gsub('\\', '/'):lower() == b:gsub('\\', '/'):lower()
end

local function scan()
  local result, seen = {}, {}
  local function add(folder, title)
    if not io.dirExists(folder) then return end
    for _, file in ipairs(io.scanDir(folder, '*.ini') or {}) do
      local path = folder .. '/' .. file
      if not seen[path] then
        seen[path] = true
        result[#result + 1] = { path = path, name = title .. ' / ' .. file }
      end
    end
  end
  add(root .. 'generic', 'generic')
  if io.dirExists(root) then
    for _, dir in ipairs(io.scanDir(root, '*') or {}) do
      if dir ~= 'generic' and io.dirExists(root .. dir) then
        add(root .. dir, dir)
      end
    end
  end
  table.sort(result, function(a,b) return a.name:lower() < b.name:lower() end)
  entries = result
  selected = 1
  for i, entry in ipairs(entries) do
    if samePath(entry.path, preferred) then selected = i; break end
  end
end

local function remember(path)
  preferred = path
  memory.preferred = path
end

local function load(path, isAuto)
  if not path or path == '' or not io.fileExists(path) then
    status = 'Setup file missing (refresh list or choose another)'
    return false
  end
  if not ac.isSetupAvailableToEdit() then
    status = 'Setup editing unavailable (fixed setup or not in pits)'
    return false
  end
  -- For experimental immediate mode, let CSP decide whether an off-menu load is possible.
  -- Do not use a main-menu guard here: it would prevent an actual attempt.

  loadingFromApp = true
  local ok, loaded = pcall(ac.loadSetup, path)
  loadingFromApp = false
  if not ok then status = 'CSP error: ' .. tostring(loaded); return false end
  if loaded ~= true then status = 'CSP rejected setup load'; return false end
  lastRequested = path
  if not samePath(path, lastPath) then remember(path) end
  status = (isAuto and 'Auto-loaded: ' or 'Loaded: ') .. (path:match('[^/\\]+$') or path)
  return true
end

scan()

local function setupOpened()
  if setupScreenSeen then return end
  setupScreenSeen = true
  setupOpenedAt = elapsed
  setupFallbackNext = elapsed
  setupFallbackDeadline = elapsed + 1.0
end

ac.onOpenMainMenu(function(section)
  if section == 'setup' then setupOpened() end
end)

-- Track setups loaded or saved in the original AC setup interface too.
ac.onSetupFile(function(operation, filename)
  -- A manual setup load/save means the driver has made a choice: do not overwrite it.
  -- Ignore events raised synchronously by our own ac.loadSetup call.
  if not loadingFromApp and (operation == 'load' or operation == 'save') then
    autoFinished = true
  end
  if (operation == 'load' or operation == 'save') and type(filename) == 'string' and filename ~= '' then
    -- Never replace an explicitly remembered setup with the generic last.ini snapshot.
    if not samePath(filename, lastPath) and not filename:lower():match('[/\\]last%.ini$') then
      remember(filename)
    end
    scan()
    if not samePath(filename, lastRequested) then
      status = (operation == 'load' and 'Game loaded: ' or 'Game saved: ') .. (filename:match('[^/\\]+$') or filename)
    end
    lastRequested = nil
  end
end)
ac.onSetupsListRefresh(function() scan() end)

local function targetPath()
  return config.useLast and lastPath or preferred
end

local function automaticAttempt()
  local target = targetPath()
  if not target or target == '' then
    status = 'No remembered setup for this car'
    autoFinished = true
    return false
  end
  if not io.fileExists(target) then
    status = 'Remembered setup file is missing'
    autoFinished = true
    return false
  end
  if not ac.isSetupAvailableToEdit() then
    status = 'Setup editing unavailable; awaiting setup screen'
    return false
  end
  if load(target, true) then
    autoFinished = true
    return true
  end
  return false
end

function script.update(dt)
  elapsed = elapsed + dt
  if autoFinished then return end
  if not config.autoRestore then
    autoFinished = true
    status = 'Auto-load disabled for this join'
    return
  end

  -- Experimental pre-menu attempt. The documented CSP API normally rejects it.
  -- Unlike 0.2.4, failure does not consume the first setup-screen attempt.
  if config.tryImmediately and not startupAttempted and elapsed >= 1.5 then
    startupAttempted = true
    if automaticAttempt() then return end
    if not autoFinished then
      status = 'Pre-menu load not accepted; waiting for setup screen'
    end
  end

  -- If the immediate option is off, still wait until the setup screen opens.
  if not setupScreenSeen then return end
  if setupFallbackDeadline and elapsed > setupFallbackDeadline then
    autoFinished = true
    status = 'Auto-load failed on first setup opening; use Force load'
    return
  end
  if setupFallbackAttempts >= 3 or elapsed < setupFallbackNext then return end

  setupFallbackAttempts = setupFallbackAttempts + 1
  setupFallbackNext = elapsed + 0.25
  if automaticAttempt() then return end
  if setupFallbackAttempts >= 3 then
    autoFinished = true
    status = 'Auto-load failed on first setup opening; use Force load'
  end
end

function script.windowMain()
  setupOpened()
  ui.text('Car: ' .. carID)
  ui.textWrapped(status)
  ui.separator()
  if ui.checkbox('Auto-load once per join', config.autoRestore) then
    config.autoRestore = not config.autoRestore
  end
  if ui.checkbox('Try loading immediately after joining (experimental)', config.tryImmediately) then
    config.tryImmediately = not config.tryImmediately
  end
  if ui.checkbox('Use last.ini (latest car setup)', config.useLast) then
    config.useLast = not config.useLast
  end
  ui.textWrapped('Immediate mode tries after joining. If CSP rejects it, the first opening of the setup screen gets a brief fallback attempt. After that, automatic loading stops. Changes here take effect next join.')
  ui.separator()
  if #entries > 0 then
    local names = {}
    for i, entry in ipairs(entries) do names[i] = entry.name end
    ui.setNextItemWidth(ui.availableSpaceX())
    selected = ui.combo('##setupList', selected, ui.ComboFlags.None, names)
    if ui.button('Force load selected') then load(entries[selected].path, false) end
    ui.sameLine()
    if ui.button('Remember selected') then
      remember(entries[selected].path)
      status = 'Remembered: ' .. entries[selected].name
    end
  else
    ui.textWrapped('No saved setups found for this car.')
  end
  if ui.button('Force load remembered') then load(preferred, false) end
  ui.sameLine()
  if ui.button('Refresh list') then scan(); status = 'Setup list refreshed' end
  if ui.button('Force load last.ini') then load(lastPath, false) end
  ui.separator()
  ui.textWrapped('CSP documents ac.loadSetup() as setup-menu-only. Pre-Drive loading is not guaranteed. Auto-load never runs again after the first setup opening.')
end
