-- Crispy Quick Teleport - CSP Lua app
-- Teleports ONLY via destinations explicitly provided by the online server.
-- Relevant Comfy Map reference: https://github.com/Tuttertep/comfy_map

local sim = ac.getSim()
local settings = ac.storage({
  lastFriend = '',
  maxForwardDistance = 300,
  aheadThreshold = 50,
  preferAhead = true,
  rangeVersion = 0
})
-- Upgrade the previous 300 m default once; preserve other custom ranges.
if settings.rangeVersion < 1 then
  if settings.maxForwardDistance == 300 then settings.maxForwardDistance = 600 end
  settings.rangeVersion = 1
end
-- CSP saves bindings in controls.ini; leave unassigned until the user chooses one.
local lastFriendBind = ac.ControlButton
    and ac.ControlButton('app.crispy_teleport_to_friend/Teleport to last friend') or nil
local teleportPointsLoaded = false
local teleportPoints = {}
local loadError = nil
local status = 'Select a friend to teleport.'
local statusTimer = 0

local function setStatus(message)
  status = message
  statusTimer = 8
end

-- Reproduce Comfy Map's ordering of server teleport destinations.
-- CSP uses zero-based indices when calling teleportToServerPoint().
local function loadServerPoints()
  teleportPoints = {}
  if not sim.isOnlineRace then
    loadError = 'Join an online server first.'
    return
  end
  if not ac.INIConfig.onlineExtras then
    loadError = 'This CSP build cannot read online extras.'
    return
  end

  local ok, config = pcall(ac.INIConfig.onlineExtras)
  if not ok or not config then
    loadError = 'Failed to read server teleport points.'
    return
  end

  local entries = {}
  -- Use the same ordered POINT keys approach as Comfy Map.
  for _, key in config:iterateValues('TELEPORT_DESTINATIONS', 'POINT') do
    local id = key:match('^POINT_(%d+)$')
    if id then
      local number = tonumber(id)
      local pos = config:get('TELEPORT_DESTINATIONS', key .. '_POS', vec3())
      entries[#entries + 1] = {
        number = number,
        name = config:get('TELEPORT_DESTINATIONS', key, 'Point ' .. id),
        group = config:get('TELEPORT_DESTINATIONS', key .. '_GROUP', ''),
        pos = pos
      }
    end
  end

  table.sort(entries, function(a, b) return a.number < b.number end)
  for i, entry in ipairs(entries) do
    entry.index = i - 1
    teleportPoints[#teleportPoints + 1] = entry
  end
  loadError = #teleportPoints == 0 and 'No server teleport points configured.' or nil
end

local function tagged(name)
  -- "Tagged as friend" matches Comfy Map's dedicated friend highlighting.
  return ac.isTaggedAsFriend and ac.isTaggedAsFriend(name) or false
end

local function getFriends()
  local friends = {}
  for i = 1, sim.carsCount - 1 do
    local car = ac.getCar(i)
    if car and car.isConnected and not car.isHidingLabels then
      local name = ac.getDriverName(i)
      if name and name ~= '' and tagged(name) then
        friends[#friends + 1] = { index = i, name = name, car = car }
      end
    end
  end
  table.sort(friends, function(a, b)
    return a.name:lower() < b.name:lower()
  end)
  return friends
end

-- Use the nearest permitted point within the threshold (including points behind).
-- Only beyond that threshold prefer the closest point ahead within the radius.
-- All distances are straight-line distances, not distances along the road.

local function getPreferredPoint(car)
  local position = car.position
  local direction = car.look
  -- During drifting, velocity describes where the friend is actually going
  -- more reliably than the direction their car is facing.
  local velocity = car.velocity
  if velocity and velocity.x * velocity.x + velocity.z * velocity.z > 25 then
    direction = velocity
  end

  local dx, dz = 0, 0
  if direction then
    local magnitude = math.sqrt(direction.x * direction.x + direction.z * direction.z)
    if magnitude > 0.001 then
      dx, dz = direction.x / magnitude, direction.z / magnitude
    end
  end

  local nearest, nearestDistanceSq = nil, math.huge
  local ahead, aheadDistanceSq = nil, math.huge
  for _, point in ipairs(teleportPoints) do
    if ac.canTeleportToServerPoint(point.index) then
      local d = position:distanceSquared(point.pos)
      if d < nearestDistanceSq then
        nearest, nearestDistanceSq = point, d
      end
      local px, pz = point.pos.x - position.x, point.pos.z - position.z
      local forward = px * dx + pz * dz
      if forward > 0.001 and d <= settings.maxForwardDistance * settings.maxForwardDistance
          and d < aheadDistanceSq then
        ahead, aheadDistanceSq = point, d
      end
    end
  end
  if not settings.preferAhead
      or nearestDistanceSq <= settings.aheadThreshold * settings.aheadThreshold then
    return nearest, math.sqrt(nearestDistanceSq), false
  end
  if ahead then return ahead, math.sqrt(aheadDistanceSq), true end
  return nearest, math.sqrt(nearestDistanceSq), false
end

local function teleportToFriend(friend, rememberTarget)
  if not ac.teleportToServerPoint or not ac.canTeleportToServerPoint then
    setStatus('Your CSP build does not support server teleporting.')
    return
  end
  if not sim.isOnlineRace then
    setStatus('Join an online server first.')
    return
  end
  if #teleportPoints == 0 then
    setStatus(loadError or 'No server teleport points found.')
    return
  end
  -- Resolve the car position at click time: do not cache a teleport destination.
  local car = ac.getCar(friend.index)
  if not car or not car.isConnected or ac.getDriverName(friend.index) ~= friend.name then
    setStatus('Friend disconnected. Refreshing the list may help.')
    return
  end
  local point, distance, ahead = getPreferredPoint(car)
  if not point then
    setStatus('No teleport point is currently permitted or available.')
    return
  end
  local ok, err = pcall(ac.teleportToServerPoint, point.index)
  if not ok then
    setStatus('Teleport call failed: ' .. tostring(err))
    return
  end
  if rememberTarget ~= false then settings.lastFriend = friend.name end
  local label = point.group ~= '' and (point.group .. ' / ' .. point.name) or point.name
  setStatus(string.format('Requested teleport %s %s: %s [%.0f m away].', ahead and 'ahead of' or 'near', friend.name,
    label, distance))
  return true
end

local refreshTime = 0
local friendsCache = {}

-- Fallback cycling does not set a fixed last friend. Clicking a friend's own
-- button chooses a fixed target and switches quick teleport back to last mode.
local cycleAfterName = nil
local function nextCycleFriend(friends)
  if #friends == 0 then return nil end
  for i, friend in ipairs(friends) do
    if friend.name == cycleAfterName then return friends[i % #friends + 1] end
  end
  return friends[1]
end

-- Both the UI button and binding use a fresh lobby lookup, avoiding stale slots.
local function teleportToLastFriend()
  local friends = getFriends()
  for _, friend in ipairs(friends) do
    if friend.name == settings.lastFriend then
      teleportToFriend(friend)
      return
    end
  end
  -- Missing, disconnected or untagged last targets use the same cycle fallback.
  -- Keep the saved target so quick teleport resumes targeting them on return.
  local friend = nextCycleFriend(friends)
  if not friend then
    setStatus('No tagged friends are online.')
    return
  end
  if teleportToFriend(friend, false) then cycleAfterName = friend.name end
end

function script.update(dt)
  -- Load destinations even if the window has never been opened this session.
  if sim.isOnlineRace and not teleportPointsLoaded then
    teleportPointsLoaded = true
    loadServerPoints()
  end
  if lastFriendBind and lastFriendBind:pressed() then teleportToLastFriend() end
  refreshTime = refreshTime - dt
  if refreshTime <= 0 then
    refreshTime = 1
    friendsCache = getFriends()
  end
  if statusTimer > 0 then statusTimer = statusTimer - dt end
end

function script.windowMain(dt)
  if not ac.teleportToServerPoint or not ac.canTeleportToServerPoint then
    ui.text('Teleport API not supported by this CSP version.')
    return
  end
  if not sim.isOnlineRace then
    ui.text('Join an online server to use this app.')
    return
  end
  if not teleportPointsLoaded then
    teleportPointsLoaded = true
    loadServerPoints()
  end
  if loadError then ui.textColored(loadError, rgbm(1, 0.5, 0.4, 1)) end

  local function friendRow(friend, title, id)
    local row = ui.getCursor()
    local width = ui.availableSpaceX()
    local point, dist, ahead = nil, nil, false
    if friend and #teleportPoints > 0 then
      point, dist, ahead = getPreferredPoint(friend.car)
    end
    -- Reserve a fixed right column for the button, matching the compact layout.
    ui.text(title)
    if point then
      local location = point.group ~= ''
          and (point.group .. ' / ' .. point.name)
          or point.name
      ui.text(string.format('%s: %s [%.0f m]', ahead and 'Ahead' or 'Nearest', location, dist))
    elseif friend then
      ui.text('No available teleport point')
    else
      ui.text(settings.lastFriend == '' and 'No tagged friends online' or 'Offline')
    end
    local nextRow = ui.getCursor()
    ui.setCursor(vec2(row.x + math.max(0, width - 108), row.y))
    if ui.button('Teleport##' .. id, vec2(108, 36)) then
      if id == 'last' then
        teleportToLastFriend()
      elseif friend then
        teleportToFriend(friend)
      end
    end
    ui.setCursor(vec2(row.x, math.max(nextRow.y, row.y + 44)))
  end

  ui.text('QUICK TELEPORT')
  local last = nil
  for _, friend in ipairs(friendsCache) do
    if friend.name == settings.lastFriend then
      last = friend
      break
    end
  end
  if not last then
    local nextFriend = nextCycleFriend(friendsCache)
    friendRow(nextFriend, nextFriend and ('Next friend: ' .. nextFriend.name)
      or 'Cycle tagged friends', 'last')
  else
    friendRow(last, 'Last target: ' .. settings.lastFriend, 'last')
  end

  ui.text('Teleport to last friend keybind')
  if lastFriendBind then
    lastFriendBind:control(vec2(ui.availableSpaceX(), 24),
      ui.ControlButtonControlFlags.AlterRealConfig)
  else
    ui.text('Custom bindings are unavailable in this CSP build.')
  end

  ui.separator()
  ui.text(string.format('TAGGED FRIENDS ONLINE [%d]', #friendsCache))
  if #friendsCache == 0 then
    ui.text('No tagged friends found in this lobby.')
    ui.text('Tag players as friends in Content Manager.')
  else
    ui.childWindow('##friends', vec2(ui.availableSpaceX(), 182), function()
      for _, friend in ipairs(friendsCache) do
        friendRow(friend, friend.name, 'friend' .. friend.index)
        ui.separator()
      end
    end)
  end

  ui.separator()
  ui.text('TELEPORT SETTINGS')
  if ui.checkbox('Prefer teleport points ahead', settings.preferAhead) then
    settings.preferAhead = not settings.preferAhead
  end
  if settings.preferAhead then
    settings.aheadThreshold = math.floor(ui.slider('##aheadThreshold',
      settings.aheadThreshold, 0, 300, 'Prefer ahead beyond: %.0f m') + 0.5)
    settings.maxForwardDistance = math.floor(ui.slider('##maxForwardDistance',
      settings.maxForwardDistance, 50, 2000, 'Max ahead distance: %.0f m') + 0.5)
    ui.text('Uses nearest within threshold; otherwise prefers ahead.')
  else
    ui.text('Always uses the closest available teleport point.')
  end
  if statusTimer > 0 then
    ui.separator()
    ui.text(status)
  end
end
