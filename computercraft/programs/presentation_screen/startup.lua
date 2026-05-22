-- Dynamic MCCR startup for presentation_screen. Bundled dynamic program.
-- Concrete instance is read from /mccr_device.dat.
local MCCR_PROGRAM = "presentation_screen"
local MCCR_VERSION = "1.0.1"
local MCCR_ROLE = "display"
local MCCR_DEFAULT_NAME = "presentation_screen_left"
local MCCR_ALLOWED_NAMES = {
  "presentation_screen_left",
  "main_presentation_screen",
  "presentation_screen_right",
}
local function load_state()
local M = {}

local function parent(path)
  return string.match(path, "^(.*)/[^/]+$") or "/"
end

function M.ensureDir(path)
  if path and path ~= "" and not fs.exists(path) then
    fs.makeDir(path)
  end
end

function M.read(path, default)
  if not fs.exists(path) then return default end
  local h = fs.open(path, "r")
  if not h then return default end
  local text = h.readAll()
  h.close()
  local ok, value = pcall(textutils.unserialize, text)
  if ok and value ~= nil then return value end
  return default
end

function M.sanitize(value, pathSeen, depth)
  local tv = type(value)
  if tv == "nil" or tv == "boolean" or tv == "number" or tv == "string" then return value end
  if tv ~= "table" then return tostring(value) end
  depth = depth or 0
  if depth > 24 then return "<max-depth>" end
  pathSeen = pathSeen or {}
  if pathSeen[value] then return "<cycle>" end
  pathSeen[value] = true
  local out = {}
  for k, v in pairs(value) do
    local tk = type(k)
    if tk == "string" or tk == "number" or tk == "boolean" then
      out[k] = M.sanitize(v, pathSeen, depth + 1)
    end
  end
  pathSeen[value] = nil
  return out
end

function M.write(path, value)
  M.ensureDir(parent(path))
  local tmp = path .. ".tmp"
  local h = fs.open(tmp, "w")
  if not h then return false end
  local ok, text = pcall(textutils.serialize, value)
  if not ok then
    ok, text = pcall(textutils.serialize, M.sanitize(value))
  end
  if not ok then
    h.close()
    if fs.exists(tmp) then fs.delete(tmp) end
    return false
  end
  h.write(text)
  h.close()
  if fs.exists(path) then fs.delete(path) end
  fs.move(tmp, path)
  return true
end

function M.appendLog(path, entry, limit)
  local log = M.read(path, {})
  table.insert(log, 1, entry)
  limit = limit or 80
  while #log > limit do table.remove(log) end
  M.write(path, log)
  return log
end

return M


end

local function load_net()
local M = {}
M.protocol = "mccr.v1"

function M.open()
  local opened = {}
  for _, side in ipairs(peripheral.getNames()) do
    if peripheral.getType(side) == "modem" and not rednet.isOpen(side) then
      rednet.open(side)
      table.insert(opened, side)
    end
  end
  return opened
end

function M.packet(name, kind, payload)
  return {
    system = "mccr",
    version = 1,
    source = name,
    id = os.getComputerID(),
    kind = kind,
    payload = payload or {},
    ts = os.epoch and os.epoch("utc") or os.clock(),
  }
end

function M.safePayload(value, pathSeen, depth)
  local tv = type(value)
  if tv == "nil" or tv == "boolean" or tv == "number" or tv == "string" then return value end
  if tv ~= "table" then return tostring(value) end
  depth = depth or 0
  if depth > 16 then return "<max-depth>" end
  pathSeen = pathSeen or {}
  if pathSeen[value] then return "<cycle>" end
  pathSeen[value] = true
  local out = {}
  for k, v in pairs(value) do
    local tk = type(k)
    if tk == "string" or tk == "number" or tk == "boolean" then
      out[k] = M.safePayload(v, pathSeen, depth + 1)
    end
  end
  pathSeen[value] = nil
  return out
end

function M.broadcast(name, kind, payload)
  M.open()
  local pkt = M.packet(name, kind, M.safePayload and M.safePayload(payload) or payload)
  local ok = pcall(rednet.broadcast, pkt, M.protocol)
  if not ok then
    pcall(rednet.broadcast, M.packet(name, kind, {}), M.protocol)
  end
end

function M.send(target, name, kind, payload)
  M.open()
  rednet.send(target, M.packet(name, kind, payload), M.protocol)
end

function M.receive(timeout)
  M.open()
  local id, msg = rednet.receive(M.protocol, timeout)
  if type(msg) == "table" and msg.system == "mccr" then
    return id, msg
  end
  return nil, nil
end

return M


end

local function load_devices()
local M = {}

M.colorCode = {
  none = colors.white,
  info = colors.lightBlue,
  nominal = colors.green,
  caution = colors.yellow,
  attention = colors.orange,
  critical = colors.red,
  beyond = colors.purple,
  destroyed = colors.black,
}

M.devices = {
  maincomputer = {
    label = "Main Computer", role = "main", watts = 200, activeWatts = 700,
    supply = "ac230", backup = "dc12", vMin = 100, vLow = 110, vNom = 230, vMax = 320,
    dcMin = 10.5, dcLow = 11.5, dcMax = 15, tempMin = -50, tempWarn = 80, tempTrip = 99, tempFatal = 130,
  },
  admin_control_panel = {
    label = "Admin Control Panel", role = "admin", watts = 68,
    supply = "dc12", vMin = 7, vLow = 10, vNom = 12, vMax = 15, onboardWh = 200,
    screenW = 8, screenH = 1,
  },
  emergency_controls_screen = {
    label = "Emergency Controls Screen", role = "emergency", watts = 50,
    supply = "dc12", vMin = 6.5, vLow = 8, vNom = 12, vMax = 26, tempMin = -30, tempWarn = 67, tempTrip = 78,
    screenW = 4, screenH = 1,
  },
  action_screen = {
    label = "Action Screen", role = "display", display = "action", watts = 30,
    supply = "dc12", vMin = 7, vLow = 7.4, vNom = 12, vMax = 16,
    screenW = 3, screenH = 1,
  },
  alert_level_screen = {
    label = "Alert Level Screen", role = "display", display = "alert", watts = 25,
    supply = "dc12", vMin = 7.8, vLow = 8.8, vNom = 12, vMax = 18, tempMin = -30, tempWarn = 86, tempFatal = 122,
    screenW = 3, screenH = 1,
  },
  clock = {
    label = "Clock", role = "display", display = "clock", watts = 30,
    supply = "dc12", vMin = 4.6, vLow = 6, vNom = 12, vMax = 16, tempMin = -40, tempWarn = 84, tempTrip = 90,
    screenW = 3, screenH = 1,
  },
  mon1 = { label = "Mon1", role = "display", display = "monitor", watts = 20, supply = "dc12", vMin = 5, vLow = 7, vNom = 12, vMax = 19, screenW = 1, screenH = 1 },
  mon2 = { label = "Mon2", role = "display", display = "monitor", watts = 20, supply = "dc12", vMin = 5, vLow = 7, vNom = 12, vMax = 19, screenW = 1, screenH = 1 },
  mon3 = { label = "Mon3", role = "display", display = "monitor", watts = 20, supply = "dc12", vMin = 5, vLow = 7, vNom = 12, vMax = 19, screenW = 1, screenH = 1 },
  mon4 = { label = "Mon4", role = "display", display = "monitor", watts = 20, supply = "dc12", vMin = 5, vLow = 7, vNom = 12, vMax = 19, screenW = 1, screenH = 1 },
  statsm1 = { label = "StatsM1", role = "display", display = "stats", watts = 46, supply = "dual", vMin = 100, vLow = 110, vNom = 230, vMax = 300, dcMin = 7.1, dcLow = 9, dcMax = 17, tempMin = -24, tempWarn = 74, screenW = 3, screenH = 2 },
  statsm2 = { label = "StatsM2", role = "display", display = "stats", watts = 46, supply = "dual", vMin = 100, vLow = 110, vNom = 230, vMax = 300, dcMin = 7.1, dcLow = 9, dcMax = 17, tempMin = -24, tempWarn = 74, screenW = 3, screenH = 2 },
  statsm3 = { label = "StatsM3", role = "display", display = "stats", watts = 46, supply = "ac230", vMin = 100, vLow = 110, vNom = 230, vMax = 300, tempMin = -24, tempWarn = 74, screenW = 3, screenH = 2 },
  statsm4 = { label = "StatsM4", role = "display", display = "stats", watts = 46, supply = "ac230", vMin = 100, vLow = 110, vNom = 230, vMax = 300, tempMin = -24, tempWarn = 74, screenW = 3, screenH = 2 },
  statsm5 = { label = "StatsM5", role = "display", display = "stats", watts = 46, supply = "ac230", vMin = 100, vLow = 110, vNom = 230, vMax = 300, tempMin = -24, tempWarn = 74, screenW = 3, screenH = 2 },
  statsm6 = { label = "StatsM6", role = "display", display = "stats", watts = 46, supply = "ac230", vMin = 100, vLow = 110, vNom = 230, vMax = 300, tempMin = -24, tempWarn = 74, screenW = 3, screenH = 2 },
  presentation_screen_left = { label = "Presentation Left", role = "display", display = "presentation_left", watts = 410, supply = "ac230", vMin = 90, vLow = 97, vNom = 230, vMax = 320, tempMin = -20, tempWarn = 67, tempFatal = 68, screenW = 2, screenH = 4 },
  main_presentation_screen = { label = "Main Presentation", role = "display", display = "presentation_main", watts = 410, supply = "ac230", vMin = 90, vLow = 97, vNom = 230, vMax = 320, tempMin = -20, tempWarn = 67, tempFatal = 68, screenW = 8, screenH = 4 },
  presentation_screen_right = { label = "Presentation Right", role = "display", display = "presentation_right", watts = 410, supply = "ac230", vMin = 90, vLow = 97, vNom = 230, vMax = 320, tempMin = -20, tempWarn = 67, tempFatal = 68, screenW = 2, screenH = 4 },
  PMC1 = { label = "PMC1", role = "pmc", watts = 70, supply = "pmc1", vMin = 8.2, vLow = 9, vNom = 12, vMax = 18, batteryWh = 500, screenW = 1, screenH = 1 },
  PMC2 = { label = "PMC2", role = "pmc", watts = 70, supply = "pmc2", vMin = 8.2, vLow = 9, vNom = 12, vMax = 18, batteryWh = 500, screenW = 1, screenH = 1 },
  PMC3 = { label = "PMC3", role = "pmc", watts = 70, supply = "pmc3", vMin = 8.2, vLow = 9, vNom = 12, vMax = 18, batteryWh = 500, screenW = 1, screenH = 1 },
  peripheral1_draconic = { label = "Peripheral Draconic", role = "peripheral", watts = 35, supply = "ac230", vMin = 100, vLow = 110, vNom = 230, vMax = 300 },
  peripheral2_mekanism = { label = "Peripheral Mekanism", role = "peripheral", watts = 35, supply = "ac230", vMin = 100, vLow = 110, vNom = 230, vMax = 300 },
  peripheral3_ae2 = { label = "Peripheral AE2", role = "peripheral", watts = 35, supply = "ac230", vMin = 100, vLow = 110, vNom = 230, vMax = 300 },
  peripheral4_spare = { label = "Peripheral Spare", role = "peripheral", watts = 35, supply = "ac230", vMin = 100, vLow = 110, vNom = 230, vMax = 300 },
  peripheral5_fake_load = { label = "Fake Load", role = "peripheral", watts = 50, supply = "ac230", vMin = 100, vLow = 110, vNom = 230, vMax = 300 },
  peripheral6_sound = { label = "Sound Device", role = "peripheral", watts = 25, supply = "dc12", vMin = 7, vLow = 8, vNom = 12, vMax = 16 },
}

M.breakers = {
  plant_nuclear = true,
  plant_fusion = true,
  plant_reserved_3 = false,
  plant_reserved_4 = false,
  plant_reserved_5 = false,
  plant_reserved_6 = false,
  plant_reserved_7 = false,
  plant_reserved_8 = false,
  supercap = true,
  t10_a = true,
  t10_b = true,
  tie_10kv = false,
  lv_a = true,
  lv_b = true,
  emergency_inverter = true,
  battery_400v_charger = true,
  buck_12v = true,
  noncritical_loads = true,
  facility_ac_1 = true,
  facility_ac_2 = true,
  transformer_fans = true,
  lighting = true,
  main_computer = true,
  fake_load = true,
  sound_device = true,
}

M.loads = {
  lighting_w = 81 * 32,
  lighting_startup_w = 81 * 130,
  transformer_fans_w = 10000,
  main_computer_fan_w = 70,
  fake_load_w = 250000,
  sound_device_w = 150,
  control_room_ac_w = 1700,
  control_room_ac_capacity_w = 5000,
  facility_ac_each_w = 333000,
  facility_ac_total_capacity_w = 1000000,
  battery_400v_wh = 500000,
  battery_400v_max_w = 1000000,
  buck_12v_w = 1000,
  buck_12v_start_w = 3000,
}

function M.spec(name)
  return M.devices[name] or {
    label = name,
    role = "unknown",
    watts = 20,
    supply = "dc12",
    vMin = 7,
    vLow = 8,
    vNom = 12,
    vMax = 16,
  }
end

function M.allDeviceNames()
  local names = {}
  for name in pairs(M.devices) do table.insert(names, name) end
  table.sort(names)
  return names
end

return M

end

local function load_power()
local M = {}

local function clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

function M.inputFor(spec, snapshot)
  snapshot = snapshot or {}
  local buses = snapshot.buses or {}
  local supply = spec.supply or "dc12"
  if supply == "ac230" then
    local ac = buses.ac230 or { voltage = 230, temp = 24 }
    if spec.backup == "dc12" and (ac.voltage or 0) < (spec.vMin or 100) then
      return buses.dc12 or { voltage = 12, temp = ac.temp or 24, backup = true }
    end
    return ac
  end
  if supply == "ac400" then return buses.ac400 or { voltage = 400, temp = 24 } end
  if supply == "pmc1" then return buses.pmc1 or { voltage = 12.6, temp = 24 } end
  if supply == "pmc2" then return buses.pmc2 or { voltage = 12.6, temp = 24 } end
  if supply == "pmc3" then return buses.pmc3 or { voltage = 12.6, temp = 24 } end
  if supply == "dual" then
    local ac = buses.ac230 or { voltage = 230, temp = 24 }
    if ac.voltage and ac.voltage >= (spec.vMin or 100) then return ac end
    return buses.dc12 or { voltage = 12, temp = 24 }
  end
  return buses.dc12 or { voltage = 12, temp = 24 }
end

function M.evaluate(spec, input, state)
  input = input or { voltage = spec.vNom or 12, temp = 24 }
  state = state or {}
  local voltage = tonumber(input.voltage) or spec.vNom or 12
  local temp = tonumber(input.temp) or 24
  local watts = spec.activeWatts or spec.watts or 20
  local vMin = spec.vMin or spec.dcMin or 0
  local vLow = spec.vLow or spec.dcLow or vMin
  local vMax = spec.vMax or spec.dcMax or voltage * 2

  if (spec.supply == "dual" or spec.supply == "dc12" or spec.backup == "dc12") and voltage < 40 and spec.dcMin then
    vMin, vLow, vMax = spec.dcMin, spec.dcLow or spec.dcMin, spec.dcMax or spec.vMax or 18
  end

  local status = "nominal"
  local severity = 0
  local reason = "nominal"
  local glitch = false
  local online = true
  local destroyed = state.destroyed == true

  if spec.tempFatal and temp >= spec.tempFatal then
    destroyed = true
    online = false
    status = "destroyed"
    severity = 5
    reason = "fatal temperature"
  elseif voltage <= 0.1 then
    online = false
    status = "offline"
    severity = 4
    reason = "no power"
  elseif voltage < vMin then
    online = false
    glitch = true
    status = "undervoltage_trip"
    severity = 3
    reason = "undervoltage trip"
  elseif voltage < vLow then
    glitch = true
    status = "undervoltage"
    severity = 2
    reason = "low voltage"
  elseif voltage > vMax * 1.25 then
    destroyed = true
    online = false
    status = "destroyed"
    severity = 5
    reason = "severe overvoltage"
  elseif voltage > vMax then
    glitch = true
    status = "overvoltage"
    severity = 3
    reason = "overvoltage"
  elseif spec.tempTrip and temp >= spec.tempTrip then
    online = false
    glitch = true
    status = "thermal_trip"
    severity = 4
    reason = "thermal trip"
  elseif spec.tempWarn and temp >= spec.tempWarn then
    glitch = true
    status = "thermal_warning"
    severity = 2
    reason = "hot"
  elseif spec.tempMin and temp <= spec.tempMin then
    glitch = true
    status = "cold_warning"
    severity = 1
    reason = "cold"
  end

  if destroyed then
    watts = 0
    online = false
  elseif glitch then
    watts = watts * 1.25
  end

  local current = 0
  if voltage > 0.1 and online then current = watts / voltage end

  return {
    online = online,
    destroyed = destroyed,
    glitch = glitch,
    status = status,
    severity = severity,
    reason = reason,
    voltage = voltage,
    temp = temp,
    watts = watts,
    amps = current,
    health = destroyed and 0 or clamp(100 - severity * 18, 0, 100),
  }
end

function M.alertLevel(telemetry)
  local level = 0
  local reason = "nominal"
  for name, item in pairs(telemetry or {}) do
    local sev = tonumber(item.severity) or 0
    if sev > level then
      level = sev
      reason = name .. ": " .. tostring(item.reason or item.status)
    end
  end
  if level > 5 then level = 5 end
  return level, reason
end

return M

end

local function load_ui()
local M = {}

function M.target(spec)
  local mon = peripheral.find("monitor")
  if mon then
    mon.setTextScale((spec and spec.textScale) or 0.5)
    return mon
  end
  return term.current()
end

function M.size(t)
  t = t or term.current()
  local w, h = t.getSize()
  return w or 1, h or 1
end

function M.maxRows(t, firstY)
  local _, h = M.size(t)
  return math.max(0, h - (firstY or 1) + 1)
end

function M.short(text, maxWidth)
  text = tostring(text or "")
  maxWidth = math.max(0, maxWidth or #text)
  if #text <= maxWidth then return text end
  if maxWidth <= 0 then return "" end
  if maxWidth == 1 then return text:sub(1, 1) end
  return text:sub(1, maxWidth - 1) .. "."
end

function M.clear(t, fg, bg)
  t = t or term.current()
  M.currentBg = bg or colors.black
  if bg then t.setBackgroundColor(bg) else t.setBackgroundColor(colors.black) end
  if fg then t.setTextColor(fg) else t.setTextColor(colors.white) end
  t.clear()
  t.setCursorPos(1, 1)
end

function M.writeAt(t, x, y, text, fg, bg)
  local w, h = M.size(t)
  if y < 1 or y > h or x > w then return end
  x = math.max(1, x)
  text = M.short(text, w - x + 1)
  if text == "" then return end
  if fg then t.setTextColor(fg) end
  if bg then t.setBackgroundColor(bg) elseif M.currentBg then t.setBackgroundColor(M.currentBg) end
  t.setCursorPos(x, y)
  t.write(text)
end

function M.center(t, y, text, fg, bg)
  local w = t.getSize()
  text = M.short(text, w)
  local x = math.max(1, math.floor((w - #text) / 2) + 1)
  M.writeAt(t, x, y, text, fg, bg)
end

function M.boot(t, title)
  t = t or term.current()
  title = M.short(title or "MCCR", 18)
  local w, h = M.size(t)
  for i = 1, 4 do
    M.clear(t, colors.white, colors.black)
    if h <= 3 then
      M.center(t, 1, "BOOT " .. tostring(i), colors.lightBlue)
      if h >= 2 then M.bar(t, 1, h, w, i, 4, colors.green) end
    else
      M.center(t, 2, title, colors.lightBlue)
      M.center(t, math.max(3, math.floor(h / 2)), "BOOTING" .. string.rep(".", i), colors.white)
      M.bar(t, 2, math.min(h - 1, math.floor(h / 2) + 2), math.max(1, w - 2), i, 4, colors.green)
    end
    sleep(0.12)
  end
  M.clear(t, colors.white, colors.black)
end

function M.bar(t, x, y, w, value, maxValue, fg)
  local sw, h = M.size(t)
  if y < 1 or y > h or x > sw then return end
  x = math.max(1, x)
  w = math.max(0, math.min(w or 0, sw - x + 1))
  if w <= 0 then return end
  maxValue = maxValue or 100
  value = math.max(0, math.min(maxValue, value or 0))
  local fill = math.floor((value / maxValue) * w)
  t.setCursorPos(x, y)
  t.setBackgroundColor(colors.gray)
  t.write(string.rep(" ", w))
  t.setCursorPos(x, y)
  t.setBackgroundColor(fg or colors.green)
  t.write(string.rep(" ", fill))
  t.setBackgroundColor(M.currentBg or colors.black)
end

function M.button(t, id, x, y, w, label, fg, bg)
  local sw, h = M.size(t)
  if y < 1 or y > h or x > sw then return { id = id, x = x, y = y, w = 0, h = 0 } end
  x = math.max(1, x)
  w = math.max(0, math.min(w or 0, sw - x + 1))
  if w <= 0 then return { id = id, x = x, y = y, w = 0, h = 0 } end
  label = M.short(label, w)
  M.writeAt(t, x, y, string.rep(" ", w), fg or colors.white, bg or colors.gray)
  local lx = x + math.max(0, math.floor((w - #label) / 2))
  M.writeAt(t, lx, y, label, fg or colors.white, bg or colors.gray)
  return { id = id, x = x, y = y, w = w, h = 1 }
end

function M.hit(buttons, x, y)
  for _, b in ipairs(buttons or {}) do
    if x >= b.x and x < b.x + b.w and y >= b.y and y < b.y + (b.h or 1) then
      return b.id
    end
  end
  return nil
end

function M.statusColor(level)
  level = level or 0
  if level >= 5 then return colors.purple end
  if level == 4 then return colors.red end
  if level == 3 then return colors.orange end
  if level == 2 then return colors.yellow end
  if level == 1 then return colors.lightBlue end
  return colors.green
end

return M

end

local function load_role_display()
local function firstLines(items, max)
  local out = {}
  for _, item in ipairs(items or {}) do
    out[#out + 1] = item
    if #out >= max then break end
  end
  return out
end

local function sortedTelemetry(t)
  local out = {}
  for name, item in pairs(t or {}) do
    item.name = item.name or name
    out[#out + 1] = item
  end
  table.sort(out, function(a, b)
    if (a.severity or 0) == (b.severity or 0) then return tostring(a.name) < tostring(b.name) end
    return (a.severity or 0) > (b.severity or 0)
  end)
  return out
end

local function drawAction(t, lib, snap)
  local _, h = lib.ui.size(t)
  lib.ui.center(t, 1, "ACTION LOG", colors.lightBlue)
  local y = 3
  for _, a in ipairs(firstLines(snap.actions or {}, lib.ui.maxRows(t, y))) do
    local c = lib.ui.statusColor(a.severity or 0)
    lib.ui.writeAt(t, 1, y, tostring(a.kind or "AU") .. ": " .. tostring(a.text or ""), c)
    y = y + 1
    if y > h then break end
  end
  if y == 3 then lib.ui.writeAt(t, 1, y, "No commands logged yet", colors.gray) end
end

local function alertTextColor(bg)
  if bg == colors.yellow or bg == colors.lightBlue then return colors.black end
  return colors.white
end

local function drawAlert(t, lib, snap)
  local _, h = lib.ui.size(t)
  local alert = snap.alert or { level = 0, reason = "nominal" }
  local level = alert.level or 0
  local c = lib.ui.statusColor(level)
  t.setBackgroundColor(c)
  t.clear()
  t.setTextColor(alertTextColor(c))
  if h <= 5 then
    lib.ui.center(t, 1, "ALERT L" .. tostring(level), alertTextColor(c), c)
    lib.ui.center(t, 3, tostring(alert.reason or "nominal"), alertTextColor(c), c)
  else
    lib.ui.center(t, 2, "ALERT LEVEL", alertTextColor(c), c)
    lib.ui.center(t, math.max(3, math.floor(h / 2)), tostring(level), alertTextColor(c), c)
    lib.ui.center(t, math.min(h, math.floor(h / 2) + 3), tostring(alert.reason or "nominal"), alertTextColor(c), c)
  end
end
local function sevenSegmentRows(text)
  local glyphs = {
    ["0"] = { " _ ", "| |", "|_|" },
    ["1"] = { "   ", "  |", "  |" },
    ["2"] = { " _ ", " _|", "|_ " },
    ["3"] = { " _ ", " _|", " _|" },
    ["4"] = { "   ", "|_|", "  |" },
    ["5"] = { " _ ", "|_ ", " _|" },
    ["6"] = { " _ ", "|_ ", "|_|" },
    ["7"] = { " _ ", "  |", "  |" },
    ["8"] = { " _ ", "|_|", "|_|" },
    ["9"] = { " _ ", "|_|", " _|" },
    [":"] = { "   ", " . ", " . " },
    [" "] = { "   ", "   ", "   " },
  }
  local rows = { "", "", "" }
  for i = 1, #text do
    local g = glyphs[text:sub(i, i)] or glyphs[" "]
    for row = 1, 3 do
      rows[row] = rows[row] .. g[row] .. " "
    end
  end
  return rows
end

local function drawClock(t, lib, snap)
  local w, h = lib.ui.size(t)
  local day = os.day()
  local mc = textutils.formatTime(os.time(), true)
  local epoch = os.epoch and math.floor(os.epoch("utc") / 1000) or 0
  local function hms(seconds)
    local daySeconds = seconds % 86400
    local hh = math.floor(daySeconds / 3600)
    local mm = math.floor((daySeconds % 3600) / 60)
    local ss = daySeconds % 60
    return string.format("%02d:%02d:%02d", hh, mm, ss)
  end
  local parisTime = epoch > 0 and hms(epoch + 7200) or hms(math.floor(os.clock()))
  local utc = epoch > 0 and (hms(epoch) .. " UTC") or "UTC unavailable"
  local temp = (((snap.buses or {}).dc12 or {}).temp or ((snap.buses or {}).ac230 or {}).temp or 24)
  lib.ui.center(t, 1, "CLOCK", colors.lightBlue)

  local rows = sevenSegmentRows(parisTime)
  if h >= 7 and #rows[1] <= w then
    for i, row in ipairs(rows) do
      lib.ui.center(t, 2 + i, row, colors.lime)
    end
    lib.ui.center(t, 6, "UTC+2", colors.green)
    if h >= 8 then lib.ui.writeAt(t, 1, 8, "MC " .. mc .. "  DAY " .. tostring(day), colors.white) end
    if h >= 9 then lib.ui.writeAt(t, 1, 9, utc, colors.green) end
    if h >= 10 then lib.ui.writeAt(t, 1, 10, string.format("ROOM %0.1f C", temp), temp > 60 and colors.red or colors.yellow) end
  else
    local rowsCompact = {
      { parisTime .. " UTC+2", colors.lime },
      { "MC day: " .. tostring(day), colors.white },
      { "MC time: " .. mc, colors.white },
      { utc, colors.green },
      { string.format("Room temp: %0.1f C", temp), temp > 60 and colors.red or colors.yellow },
    }
    local y = 3
    for _, row in ipairs(rowsCompact) do
      lib.ui.writeAt(t, 1, y, row[1], row[2])
      y = y + 1
    end
  end
end
local function displayMode(snap, name, fallback)
  local contexts = snap.displayContexts or {}
  return contexts[name] or snap.mode or fallback or "overview"
end

local function styledClear(t, lib, snap)
  local style = snap.screenStyle or {}
  lib.ui.clear(t, style.textColor or colors.white, style.bgColor or colors.black)
end

local function telemetryFresh(item)
  if type(item) ~= "table" then return true end
  local lastSeen = tonumber(item.lastSeen)
  if not lastSeen then return true end
  if lastSeen < 9999999999 then
    return (os.clock() - lastSeen) <= 30
  end
  local now = os.epoch and os.epoch("utc") or os.clock()
  return (now - lastSeen) <= 30000
end

local function telemetryWithMandatory(snap)
  local src = snap.telemetry or {}
  local out = {}
  for name, item in pairs(src) do
    if telemetryFresh(item) then out[name] = item end
  end
  return out, not not out.maincomputer
end

local function drawDeviceList(t, lib, snap, title, matcher)
  local w = lib.ui.size(t)
  lib.ui.center(t, 1, string.upper(title), colors.lightBlue)
  local y = 3
  local items, hasMaincomputer = telemetryWithMandatory(snap)
  if not hasMaincomputer then
    lib.ui.writeAt(t, 1, y, "Warning: main computer missing", colors.red)
    y = y + 1
  end
  local matchedAny = false
  for _, item in ipairs(sortedTelemetry(items)) do
    local name = tostring(item.name or "")
    local label = tostring(item.label or name)
    if not matcher or matcher(name, label, item) then
      matchedAny = true
      local labelW = math.max(4, math.min(18, w - 9))
      lib.ui.writeAt(t, 1, y, string.format("%-" .. tostring(labelW) .. "s %s", label:sub(1, labelW), tostring(item.status or "unknown")), lib.ui.statusColor(item.severity or 0))
      y = y + 1
      if y > lib.ui.maxRows(t, 1) then break end
    end
  end
  if not matchedAny then lib.ui.writeAt(t, 1, y, "No matching devices", colors.gray) end
end

local function fmtEnergy(value)
  value = tonumber(value)
  if not value then return "-- RF" end
  local units = { "RF", "KRF", "MRF", "GRF", "TRF", "PRF" }
  local n, unit = math.abs(value), 1
  while n >= 1000 and unit < #units do n = n / 1000; unit = unit + 1 end
  if unit == 1 then return string.format("%0.0f %s", value, units[unit]) end
  local scaled = value / (1000 ^ (unit - 1))
  return string.format("%0.2f %s", scaled, units[unit])
end

local function fmtFlow(value)
  value = tonumber(value)
  if not value then return "-- RF/t" end
  local sign = value > 0 and "+" or (value < 0 and "-" or "")
  return sign .. fmtEnergy(math.abs(value)) .. "/t"
end

local function draconicCores(snap)
  if snap.draconic and type(snap.draconic.cores) == "table" then return snap.draconic.cores end
  local cores = {}
  for source, bundle in pairs((snap or {}).peripherals or {}) do
    for pname, item in pairs(bundle or {}) do
      if type(item) == "table" and item.kind == "draconic_energy_core" then
        item.source = item.source or source
        item.name = item.name or pname
        cores[#cores + 1] = item
      end
    end
  end
  table.sort(cores, function(a, b) return tostring(a.name) < tostring(b.name) end)
  return cores
end

local function draconicSummary(snap)
  if snap.draconic then return snap.draconic end
  local cores = draconicCores(snap)
  local energy, capacity, input, output, net = 0, 0, 0, 0, 0
  for _, core in ipairs(cores) do
    energy = energy + (tonumber(core.energy) or 0)
    capacity = capacity + (tonumber(core.maxEnergy) or 0)
    input = input + (tonumber(core.inputRfPerTick) or 0)
    output = output + (tonumber(core.outputRfPerTick) or 0)
    net = net + (tonumber(core.netRfPerTick) or 0)
  end
  return {
    cores = cores,
    totalEnergy = energy,
    totalCapacity = capacity,
    percent = capacity > 0 and energy / capacity * 100 or nil,
    inputRfPerTick = input,
    outputRfPerTick = output,
    netRfPerTick = net,
    eta = cores[1] and cores[1].eta or nil,
    etaMode = cores[1] and cores[1].etaMode or "stable",
    line = "1MV",
  }
end

local function writeClip(t, lib, x, y, text, fg, bg)
  local w, h = lib.ui.size(t)
  if y < 1 or y > h or x > w then return end
  if x < 1 then
    text = tostring(text or ""):sub(2 - x)
    x = 1
  end
  lib.ui.writeAt(t, x, y, lib.ui.short(tostring(text or ""), w - x + 1), fg, bg)
end

local function drawTracer(t, lib, x1, y, x2, label, value, color, phase)
  local w = lib.ui.size(t)
  if y < 1 or x1 > w then return end
  x1 = math.max(1, x1)
  x2 = math.max(x1 + 2, math.min(w - 8, x2))
  local lineW = math.max(1, x2 - x1)
  local chars = { "-", "=", "-", "~" }
  local ch = chars[(phase % #chars) + 1]
  writeClip(t, lib, x1, y, string.rep(ch, lineW - 1) .. ">", color)
  writeClip(t, lib, x2 + 1, y, label, color)
  writeClip(t, lib, x2 + 1, y + 1, value, colors.white)
end

local function drawCoreArt(t, lib, x, y, w, h, percent, phase)
  if w < 12 or h < 7 then return end
  local pct = math.max(0, math.min(100, tonumber(percent) or 0))
  phase = tonumber(phase) or 0
  local cx = x + math.floor(w / 2)
  local cy = y + math.floor(h / 2)
  local radiusY = math.max(2, math.floor(h / 2))
  local pulse = phase % 4
  local patterns = { "/\\/\\/\\/\\/\\", "\\/\\/\\/\\/\\/", "XX/XX/XX/XX", "\\\\//\\\\//\\\\" }
  for row = 0, h - 1 do
    local yy = y + row
    local dy = math.abs(yy - cy) / radiusY
    local span = math.floor(math.sqrt(math.max(0, 1 - dy * dy)) * (w / 2))
    if span > 0 then
      local xx = cx - span
      local ww = math.min(w, span * 2)
      local edge = dy > 0.78
      local fillColor = edge and colors.red or ((row + pulse) % 3 == 0 and colors.orange or colors.red)
      writeClip(t, lib, xx, yy, string.rep(" ", ww), colors.black, fillColor)
      if ww > 5 then
        local pattern = patterns[((row + pulse) % #patterns) + 1]
        local reps = math.ceil((ww - 2) / #pattern)
        local fg = (row + pulse) % 4 == 0 and colors.yellow or colors.black
        writeClip(t, lib, xx + 1, yy, string.rep(pattern, reps):sub(1, ww - 2), fg, fillColor)
      end
      if ww > 2 then
        writeClip(t, lib, xx, yy, "<", colors.yellow, fillColor)
        writeClip(t, lib, xx + ww - 1, yy, ">", colors.yellow, fillColor)
      end
    end
  end
  local ringY = math.max(y + 1, math.min(y + h - 2, cy + ((phase % 3) - 1)))
  writeClip(t, lib, x + 2, ringY, string.rep("-", math.max(1, w - 4)), colors.yellow)
  writeClip(t, lib, math.max(1, cx - 8), cy, string.format("CORE %0.1f%%", pct), colors.white, colors.red)
  if h >= 10 then writeClip(t, lib, math.max(1, cx - 5), cy + 2, "1MV LINK", colors.yellow, colors.red) end
end

local function drawDraconicStats(t, lib, snap)
  local w, h = lib.ui.size(t)
  local d = draconicSummary(snap or {})
  local cores = draconicCores(snap or {})
  lib.ui.center(t, 1, "DRACONIC CORE STATUS", colors.lightBlue)
  if #cores == 0 then
    lib.ui.writeAt(t, 1, 3, "No Draconic Energy Core detected", colors.yellow)
    return
  end
  lib.ui.writeAt(t, 1, 3, "1MV line " .. fmtFlow(d.netRfPerTick), colors.purple)
  lib.ui.writeAt(t, 1, 4, fmtEnergy(d.totalEnergy) .. " / " .. fmtEnergy(d.totalCapacity), colors.white)
  lib.ui.writeAt(t, 1, 5, string.format("Stored %0.1f%%  ETA %s %s", tonumber(d.percent) or 0, tostring(d.etaMode or "stable"), tostring(d.eta or "--")), colors.yellow)
  local y = 7
  for _, core in ipairs(cores) do
    if y > h then break end
    local line = string.format("%s T%s %0.1f%% %s", tostring(core.label or core.name), tostring(core.tier or "?"), tonumber(core.percent) or 0, fmtFlow(core.netRfPerTick))
    lib.ui.writeAt(t, 1, y, lib.ui.short(line, w), colors.green)
    y = y + 1
    if y > h then break end
    lib.ui.writeAt(t, 1, y, lib.ui.short(tostring(core.status or "online") .. " " .. fmtEnergy(core.energy) .. " / " .. fmtEnergy(core.maxEnergy), w), colors.gray)
    y = y + 1
  end
end

local function drawDraconicGraph(t, lib, snap, x, y, w, h)
  local cores = draconicCores(snap or {})
  local history = cores[1] and cores[1].history or {}
  if #history < 2 then
    lib.ui.writeAt(t, x, y + math.floor(h / 2), "waiting for graph data", colors.gray)
    return
  end
  for col = 1, w do
    local idx = math.max(1, math.min(#history, math.floor((col - 1) / math.max(1, w - 1) * (#history - 1)) + 1))
    local pct = tonumber(history[idx].pct) or 0
    local level = math.floor(math.max(0, math.min(100, pct)) / 100 * h)
    for row = 0, h - 1 do
      local bg = row >= h - level and colors.purple or colors.black
      lib.ui.writeAt(t, x + col - 1, y + row, " ", colors.white, bg)
    end
  end
end

local function drawDraconicMonitor(t, lib, snap, graphMode)
  local w, h = lib.ui.size(t)
  local d = draconicSummary(snap or {})
  if graphMode then
    lib.ui.center(t, 1, "CORE GRAPH", colors.lightBlue)
    drawDraconicGraph(t, lib, snap, 1, 2, w, math.max(2, h - 2))
    return
  end
  lib.ui.center(t, 1, "DRAC CORE", colors.lightBlue)
  if #(d.cores or {}) == 0 then
    lib.ui.writeAt(t, 1, 3, "NO CORE", colors.yellow)
    return
  end
  lib.ui.writeAt(t, 1, 3, string.format("%0.1f%%", tonumber(d.percent) or 0), colors.purple)
  lib.ui.bar(t, 1, 4, w, tonumber(d.percent) or 0, 100, colors.purple)
  if h >= 5 then lib.ui.writeAt(t, 1, 5, fmtFlow(d.netRfPerTick), colors.yellow) end
  if h >= 6 then lib.ui.writeAt(t, 1, 6, "ETA " .. tostring(d.eta or "--") .. " " .. tostring(d.etaMode or ""), colors.white) end
  if h >= 7 then lib.ui.writeAt(t, 1, 7, "1MV " .. string.format("%0.2fA", ((((snap.buses or {}).mv1 or {}).current) or 0)), colors.green) end
  if h >= 8 then lib.ui.writeAt(t, 1, h, "GRAPH", colors.gray) end
end

local function drawDraconicCard(t, lib, x, y, w, label, value, accent, note, progress)
  local sw, sh = lib.ui.size(t)
  if y > sh or x > sw then return end
  w = math.max(1, math.min(w or 0, sw - x + 1))
  if w <= 0 then return end
  accent = accent or colors.lightBlue

  lib.ui.writeAt(t, x, y, string.rep(" ", w), colors.white, colors.gray)
  lib.ui.writeAt(t, x, y, "> " .. string.upper(tostring(label or "CARD")), accent, colors.gray)

  if y + 1 <= sh then
    lib.ui.writeAt(t, x, y + 1, string.rep(" ", w), colors.white, colors.black)
    lib.ui.writeAt(t, x, y + 1, lib.ui.short(tostring(value or "--"), w), colors.white, colors.black)
  end

  if progress ~= nil and y + 2 <= sh then
    lib.ui.writeAt(t, x, y + 2, string.rep(" ", w), colors.white, colors.black)
    lib.ui.bar(t, x, y + 2, w, math.max(0, math.min(100, tonumber(progress) or 0)), 100, accent)
    if note and y + 3 <= sh then
      lib.ui.writeAt(t, x, y + 3, string.rep(" ", w), colors.white, colors.black)
      lib.ui.writeAt(t, x, y + 3, lib.ui.short(tostring(note), w), colors.gray, colors.black)
    end
  elseif note and y + 2 <= sh then
    lib.ui.writeAt(t, x, y + 2, string.rep(" ", w), colors.white, colors.black)
    lib.ui.writeAt(t, x, y + 2, lib.ui.short(tostring(note), w), colors.gray, colors.black)
  end
end

local function drawDraconicBubble(t, lib, x, y, w, label, value, accent, note, progress)
  local sw, sh = lib.ui.size(t)
  if y > sh or x > sw then return end
  w = math.max(8, math.min(w or 8, sw - x + 1))
  accent = accent or colors.lightBlue
  lib.ui.writeAt(t, x, y, string.rep(" ", w), colors.white, colors.gray)
  lib.ui.writeAt(t, x, y, " " .. string.upper(tostring(label or "")), accent, colors.gray)
  if y + 1 <= sh then
    lib.ui.writeAt(t, x, y + 1, string.rep(" ", w), colors.white, colors.black)
    lib.ui.writeAt(t, x + 1, y + 1, lib.ui.short(tostring(value or "--"), math.max(1, w - 2)), colors.white, colors.black)
  end
  if progress ~= nil and y + 2 <= sh then
    lib.ui.writeAt(t, x, y + 2, string.rep(" ", w), colors.white, colors.black)
    lib.ui.bar(t, x + 1, y + 2, math.max(1, w - 2), math.max(0, math.min(100, tonumber(progress) or 0)), 100, accent)
  elseif note and y + 2 <= sh then
    lib.ui.writeAt(t, x, y + 2, string.rep(" ", w), colors.white, colors.black)
    lib.ui.writeAt(t, x + 1, y + 2, lib.ui.short(tostring(note), math.max(1, w - 2)), colors.gray, colors.black)
  end
  if progress ~= nil and note and y + 3 <= sh then
    lib.ui.writeAt(t, x, y + 3, string.rep(" ", w), colors.white, colors.black)
    lib.ui.writeAt(t, x + 1, y + 3, lib.ui.short(tostring(note), math.max(1, w - 2)), colors.gray, colors.black)
  end
end

local function drawCoreLink(t, lib, x1, y, x2, color, phase)
  local w, h = lib.ui.size(t)
  if y < 1 or y > h then return end
  x1 = math.max(1, math.min(w, x1))
  x2 = math.max(1, math.min(w, x2))
  if math.abs(x2 - x1) < 2 then return end
  local chars = { "-", "=", "~", "=" }
  local ch = chars[((tonumber(phase) or 0) % #chars) + 1]
  if x1 < x2 then
    writeClip(t, lib, x1, y, string.rep(ch, math.max(1, x2 - x1 - 1)) .. ">", color)
  else
    writeClip(t, lib, x2, y, "<" .. string.rep(ch, math.max(1, x1 - x2 - 1)), color)
  end
end

local function drawFrameBox(t, lib, x, y, w, h, color)
  local sw, sh = lib.ui.size(t)
  if w < 3 or h < 3 or x > sw or y > sh then return end
  w = math.min(w, sw - x + 1)
  h = math.min(h, sh - y + 1)
  color = color or colors.gray
  local fill = colors.black
  writeClip(t, lib, x, y, string.rep(" ", w), color, color)
  for yy = y + 1, y + h - 2 do
    writeClip(t, lib, x, yy, " ", color, color)
    writeClip(t, lib, x + 1, yy, string.rep(" ", math.max(1, w - 2)), colors.white, fill)
    writeClip(t, lib, x + w - 1, yy, " ", color, color)
  end
  writeClip(t, lib, x, y + h - 1, string.rep(" ", w), color, color)
end

local function drawMeter(t, lib, x, y, w, pct, color)
  pct = math.max(0, math.min(100, tonumber(pct) or 0))
  w = math.max(1, w or 1)
  local filled = math.floor((pct / 100) * w)
  local text = string.rep("|", filled) .. string.rep(".", math.max(0, w - filled))
  writeClip(t, lib, x, y, text, color or colors.green)
end

local function drawMetric(t, lib, x, y, label, value, color)
  writeClip(t, lib, x, y, string.upper(tostring(label or "")), colors.gray)
  writeClip(t, lib, x, y + 1, tostring(value or "--"), color or colors.white)
end

local function drawRightPanel(t, lib, x, y, w, title, value, color, line1, line2, pct, panelH)
  panelH = math.max(3, tonumber(panelH) or 5)
  drawFrameBox(t, lib, x, y, w, panelH, colors.gray)
  writeClip(t, lib, x + 2, y + 1, string.upper(tostring(title or "")), color or colors.lightBlue)
  writeClip(t, lib, math.max(x + 2, x + w - #tostring(value or "") - 1), y + 1, tostring(value or "--"), color or colors.white)
  if pct ~= nil and panelH >= 4 then
    drawMeter(t, lib, x + 2, y + 2, math.max(1, w - 4), pct, color or colors.green)
  elseif line1 then
    writeClip(t, lib, x + 2, y + 2, lib.ui.short(tostring(line1), math.max(1, w - 4)), colors.white)
  end
  if pct ~= nil and line1 and panelH >= 5 then writeClip(t, lib, x + 2, y + 3, lib.ui.short(tostring(line1), math.max(1, w - 4)), colors.gray) end
  if line2 and panelH >= 5 then writeClip(t, lib, x + 2, y + panelH - 1, lib.ui.short(tostring(line2), math.max(1, w - 4)), colors.gray) end
end

local function drawCoreInfoPanel(t, lib, x, y, w, h, title, color, rows, pct)
  if w < 12 or h < 4 then return end
  drawFrameBox(t, lib, x, y, w, h, colors.gray)
  local innerX = x + 2
  local innerW = math.max(1, w - 4)
  local innerH = math.max(1, h - 2)
  local maxRows = math.max(0, innerH - 1 - (pct ~= nil and 1 or 0))
  local rowCount = math.min(maxRows, #(rows or {}))
  local contentH = 1 + (pct ~= nil and 1 or 0) + rowCount
  local yy = y + 1 + math.max(0, math.floor((innerH - contentH) / 2))
  local function writeCentered(yy, text, fg)
    text = lib.ui.short(tostring(text or ""), innerW)
    local tx = innerX + math.max(0, math.floor((innerW - #text) / 2))
    writeClip(t, lib, tx, yy, text, fg)
  end
  writeCentered(yy, string.upper(tostring(title or "")), color or colors.white)
  yy = yy + 1
  if pct ~= nil and yy < y + h - 1 then
    drawMeter(t, lib, innerX, yy, innerW, pct, color or colors.green)
    yy = yy + 1
  end
  local drawn = 0
  for _, row in ipairs(rows or {}) do
    if drawn >= rowCount then break end
    if yy >= y + h - 1 then break end
    local text = row.text or row[1] or ""
    local rowColor = row.color or row[2] or colors.white
    writeCentered(yy, text, rowColor)
    yy = yy + 1
    drawn = drawn + 1
  end
end

local function drawDashboardCoreArt(t, lib, x, y, w, h, percent, phase)
  if w < 24 or h < 9 then return end
  local pct = math.max(0, math.min(100, tonumber(percent) or 0))
  phase = tonumber(phase) or 0
  local cx = x + math.floor(w / 2)
  local cy = y + math.floor(h / 2)
  local maxY = math.max(4, math.floor((h - 7) / 2))
  local radiusY = math.min(maxY, math.max(4, math.floor((w - 18) / 4)))
  local radiusX = math.max(10, math.min(math.floor((w - 10) / 2), radiusY * 2))
  local pulse = (phase or 0) % 4

  local function plot(px, py, ch, color)
    if px >= x and px <= x + w - 1 and py >= y and py <= y + h - 1 then
      writeClip(t, lib, px, py, ch, color)
    end
  end

  local function ring(rScale, color, chars, offset, step)
    local ry = math.max(2, math.floor(radiusY * rScale))
    local rx = math.max(4, math.floor(radiusX * rScale))
    step = step or 2
    for row = -ry, ry, step do
      local yy = cy + row
      local norm = math.abs(row) / ry
      local span = math.floor(math.sqrt(math.max(0, 1 - norm * norm)) * rx)
      if span > 0 then
        local idx = math.abs(row + phase + (offset or 0)) % #chars + 1
        local ch = chars[idx]
        plot(cx - span, yy, ch, color)
        plot(cx + span, yy, ch, color)
        local inner = math.max(1, span - math.floor(rx * 0.16))
        plot(cx - inner, yy, ".", color)
        plot(cx + inner, yy, ".", color)
      end
    end
    for col = -rx, rx, 4 do
      local norm = math.abs(col) / rx
      local span = math.floor(math.sqrt(math.max(0, 1 - norm * norm)) * ry)
      if span > 0 then
        local idx = math.abs(col + pulse + (offset or 0)) % #chars + 1
        local ch = chars[idx]
        plot(cx + col, cy - span, ch, color)
        plot(cx + col, cy + span, ch, color)
      end
    end
  end

  local bracketW = math.min(radiusX + 8, math.floor(w / 2) - 2)
  local bracketH = math.min(radiusY + 4, math.floor(h / 2) - 1)
  plot(cx - bracketW, cy - bracketH, "+", colors.red)
  plot(cx - bracketW + 1, cy - bracketH, "-", colors.red)
  plot(cx - bracketW, cy - bracketH + 1, "|", colors.red)
  plot(cx + bracketW, cy - bracketH, "+", colors.red)
  plot(cx + bracketW - 1, cy - bracketH, "-", colors.red)
  plot(cx + bracketW, cy - bracketH + 1, "|", colors.red)
  plot(cx - bracketW, cy + bracketH, "+", colors.red)
  plot(cx - bracketW + 1, cy + bracketH, "-", colors.red)
  plot(cx - bracketW, cy + bracketH - 1, "|", colors.red)
  plot(cx + bracketW, cy + bracketH, "+", colors.red)
  plot(cx + bracketW - 1, cy + bracketH, "-", colors.red)
  plot(cx + bracketW, cy + bracketH - 1, "|", colors.red)

  ring(1.00, colors.red, { ">", "^", "<", "v" }, 0, 1)
  ring(0.82, colors.orange, { ">", ">", "<", "<" }, 1, 1)
  ring(0.64, colors.yellow, { "^", ">", "v", "<" }, 2, 1)
  ring(0.46, colors.orange, { ">", "^", "<", "v" }, 3, 1)
  ring(0.30, colors.red, { ".", ".", "o", "." }, 0, 1)

  for row = -radiusY + 1, radiusY - 1 do
    local spread = math.floor((1 - math.abs(row) / radiusY) * radiusX * 0.72)
    local color = math.abs(row) < radiusY * 0.25 and colors.yellow or colors.orange
    if spread > 1 and row % 2 == (phase % 2) then
      plot(cx - spread, cy + row, ">", color)
      plot(cx + spread, cy + row, "<", color)
    end
  end

  local beamW = math.max(8, math.floor(radiusX * 1.25))
  writeClip(t, lib, cx - math.floor(beamW / 2), cy, string.rep("=", beamW), colors.orange)
  writeClip(t, lib, cx - 4, cy - 1, "CORE", colors.red)
  writeClip(t, lib, cx - 5, cy + 1, string.format("%0.1f%%", pct), colors.red)
end

local function drawDraconicPresentation(t, lib, snap)
  local w, h = lib.ui.size(t)
  local d = draconicSummary(snap or {})
  local cores = d.cores or {}
  local phase = math.floor((os.clock() or 0) * 2) % 8
  if #cores == 0 then
    lib.ui.center(t, math.max(3, math.floor(h / 2)), "NO ENERGY CORE DETECTED", colors.yellow)
    return
  end
  if w < 80 or h < 20 then
    drawDraconicStats(t, lib, snap)
    return
  end

  local pct = tonumber(d.percent) or 0
  local bus = ((snap or {}).buses or {}).mv1 or {}
  local net = tonumber(d.netRfPerTick) or 0
  local inFlow = tonumber(d.inputRfPerTick) or 0
  local outFlow = tonumber(d.outputRfPerTick) or 0
  local busVolts = tonumber(bus.voltage) or 1000000
  local busCurrent = tonumber(bus.current) or 0
  local busMW = (tonumber(bus.watts) or 0) / 1000000
  local statusText = pct >= 99.9 and "FULL" or (net >= 0 and "CHARGING" or "DISCHARGING")
  local coreStatus = cores[1] and tostring(cores[1].status or "online"):upper() or "ONLINE"
  local terminal = cores[1] and tostring(cores[1].terminal or cores[1].name or "T?") or "T?"
  local maxFlow = math.max(math.abs(inFlow), math.abs(outFlow), math.abs(net))
  local flowPct = math.min(100, math.abs(net) / math.max(1, math.abs(inFlow) + math.abs(outFlow)) * 100)

  drawFrameBox(t, lib, 1, 1, w, h, colors.gray)
  drawFrameBox(t, lib, 2, 1, w - 2, 3, colors.gray)
  local titleA = "DRACONIC ENERGY "
  local titleB = "CORE"
  local titleX = math.max(2, math.floor((w - (#titleA + #titleB)) / 2) + 1)
  writeClip(t, lib, titleX, 2, titleA, colors.red)
  writeClip(t, lib, titleX + #titleA, 2, titleB, colors.lightBlue)

  local bodyY = 5
  local bodyBottom = h - 2
  local bodyH = math.max(10, bodyBottom - bodyY + 1)
  local sideW = math.max(22, math.min(40, math.floor(w * 0.25)))
  local gap = 2
  local leftX = 3
  local rightX = w - sideW - 2
  local coreX = leftX + sideW + gap
  local coreW = math.max(24, rightX - coreX - gap)

  local pGap = 1
  local pH = math.max(5, math.floor((bodyH - (2 * pGap)) / 3))
  local p1 = bodyY
  local p2 = p1 + pH + pGap
  local p3 = p2 + pH + pGap
  local p3H = math.max(5, bodyBottom - p3 + 1)

  drawCoreInfoPanel(t, lib, leftX, p1, sideW, pH, "storage", colors.red, {
    { text = string.format("%0.1f%%", pct), color = colors.white },
    { text = fmtEnergy(d.totalEnergy) .. " / " .. fmtEnergy(d.totalCapacity), color = colors.gray },
  }, pct)
  drawCoreInfoPanel(t, lib, leftX, p2, sideW, pH, "flow", net >= 0 and colors.green or colors.orange, {
    { text = fmtFlow(d.netRfPerTick), color = net >= 0 and colors.white or colors.orange },
    { text = "IN  " .. fmtEnergy(inFlow) .. "/t", color = colors.green },
    { text = "OUT " .. fmtEnergy(outFlow) .. "/t", color = colors.gray },
  }, flowPct)
  drawCoreInfoPanel(t, lib, leftX, p3, sideW, p3H, "bus", colors.yellow, {
    { text = string.format("%0.0fV", busVolts), color = colors.white },
    { text = string.format("%0.3fM / %0.3fM", busCurrent, busCurrent), color = colors.gray },
    { text = string.format("%0.1fMW", busMW), color = colors.gray },
  }, nil)

  drawDashboardCoreArt(t, lib, coreX, bodyY, coreW, bodyH, pct, phase)

  drawCoreInfoPanel(t, lib, rightX, p1, sideW, pH, "status", colors.lightBlue, {
    { text = statusText, color = colors.white },
    { text = "ETA " .. tostring(d.eta or "--"), color = colors.gray },
    { text = tostring(#cores) .. " core " .. coreStatus, color = colors.gray },
  }, nil)
  drawCoreInfoPanel(t, lib, rightX, p2, sideW, pH, "flow limits", colors.green, {
    { text = "-----------", color = colors.gray },
    { text = "MAX FLOW", color = colors.yellow },
    { text = fmtEnergy(maxFlow) .. "/t", color = colors.white },
    { text = "MIN FLOW", color = colors.yellow },
    { text = "0 RF/t", color = colors.white },
  }, nil)
  drawCoreInfoPanel(t, lib, rightX, p3, sideW, p3H, "flow stats", colors.lightBlue, {
    { text = "MAX", color = colors.green },
    { text = fmtEnergy(inFlow) .. "/t", color = colors.white },
    { text = "MIN", color = colors.green },
    { text = fmtEnergy(outFlow) .. "/t", color = colors.white },
    { text = "AVERAGE", color = colors.green },
    { text = fmtEnergy(net) .. "/t", color = colors.white },
  }, nil)
end

local function ae2Devices(snap)
  local devices = {}
  for source, bundle in pairs((snap or {}).peripherals or {}) do
    for pname, item in pairs(bundle or {}) do
      local label = tostring(pname or "")
      local hay = string.lower(label .. " " .. tostring((item or {}).kind or "") .. " " .. tostring((item or {}).type or ""))
      if type(item) == "table" and (item.kind == "ae2_network" or hay:find("ae2") or hay:find("applied") or hay:find("mebridge")) then
        local copy = {}
        for k, v in pairs(item) do copy[k] = v end
        copy.source = source
        copy.name = copy.name or pname
        devices[#devices + 1] = copy
      end
    end
  end
  table.sort(devices, function(a, b) return tostring(a.name) < tostring(b.name) end)
  return devices
end

local function nestedNumber(value, names)
  if type(value) ~= "table" then return nil end
  for _, key in ipairs(names or {}) do
    local v = value[key]
    if type(v) == "number" then return v end
    if type(v) == "string" and tonumber(v) then return tonumber(v) end
  end
  for _, child in pairs(value) do
    if type(child) == "table" then
      local found = nestedNumber(child, names)
      if found then return found end
    end
  end
  return nil
end

local function fmtAeCount(value)
  value = tonumber(value)
  if not value then return "--" end
  local units = { "", "k", "M", "G", "T" }
  local n, unit = math.abs(value), 1
  while n >= 1000 and unit < #units do n = n / 1000; unit = unit + 1 end
  local scaled = value / (1000 ^ (unit - 1))
  if unit == 1 then return string.format("%0.0f", scaled) end
  return string.format("%0.1f%s", scaled, units[unit])
end

local function ae2Summary(snap)
  local devices = ae2Devices(snap)
  local used = 0
  local capacity = 0
  local inRate = nil
  local outRate = nil
  local powerUsage = nil
  local powerCapacity = nil
  local channels = nil
  local p2p = nil
  local jobs = nil
  local cpus = nil
  local fluids = nil
  local tanks = nil
  for _, item in ipairs(devices) do
    local attrs = item.attrs or item
    used = used + (nestedNumber(attrs, { "usedItemStorage", "itemCount", "items", "storedItems", "usedBytes", "energy" }) or 0)
    capacity = capacity + (nestedNumber(attrs, { "totalItemStorage", "itemCapacity", "maxItems", "totalBytes", "capacity", "maxEnergy" }) or 0)
    inRate = inRate or nestedNumber(attrs, { "itemsInPerTick", "inputRate", "inRate", "input" })
    outRate = outRate or nestedNumber(attrs, { "itemsOutPerTick", "outputRate", "outRate", "output" })
    powerUsage = powerUsage or nestedNumber(attrs, { "energyUsage", "powerUsage", "usage", "getEnergyUsage" })
    powerCapacity = powerCapacity or nestedNumber(attrs, { "maxEnergyUsage", "powerCapacity", "capacity", "getMaxEnergy" })
    channels = channels or nestedNumber(attrs, { "channels", "usedChannels", "channelCount" })
    p2p = p2p or nestedNumber(attrs, { "p2p", "p2pTunnels", "tunnels" })
    jobs = jobs or nestedNumber(attrs, { "craftingJobs", "jobs", "queuedJobs" })
    cpus = cpus or nestedNumber(attrs, { "craftingCpus", "cpus", "busyCpus" })
    fluids = fluids or nestedNumber(attrs, { "fluids", "fluidCount", "storedFluids" })
    tanks = tanks or nestedNumber(attrs, { "tanks", "fluidTanks" })
  end
  local percent = capacity > 0 and math.max(0, math.min(100, used / capacity * 100)) or (#devices > 0 and 0 or nil)
  local inValue = inRate or 0
  local outValue = outRate or 0
  return {
    devices = devices,
    online = #devices > 0,
    used = used > 0 and used or nil,
    capacity = capacity > 0 and capacity or nil,
    percent = percent,
    input = inValue,
    output = outValue,
    net = inValue - outValue,
    powerUsage = powerUsage,
    powerCapacity = powerCapacity,
    channels = channels,
    p2p = p2p,
    jobs = jobs,
    cpus = cpus,
    fluids = fluids,
    tanks = tanks,
  }
end

local function drawAppliedPanel(t, lib, x, y, w, h, title, color, rows, pct)
  if w < 14 or h < 4 then return end
  drawFrameBox(t, lib, x, y, w, h, colors.gray)
  writeClip(t, lib, x + 2, y + 1, string.upper(tostring(title or "")), color or colors.lightBlue)
  local yy = y + 2
  if pct ~= nil and yy < y + h - 1 then
    lib.ui.bar(t, x + 2, yy, math.max(1, w - 4), pct, 100, color or colors.lightBlue)
    yy = yy + 1
  end
  for _, row in ipairs(rows or {}) do
    if yy >= y + h - 1 then break end
    if row.sep then
      writeClip(t, lib, x + 2, yy, string.rep("-", math.max(1, w - 4)), colors.gray)
    else
      local label = tostring(row.label or row[1] or "")
      local value = tostring(row.value or row[2] or "")
      local rowColor = row.color or row[3] or colors.white
      local valueX = x + w - #value - 2
      writeClip(t, lib, x + 2, yy, lib.ui.short(label, math.max(1, valueX - x - 3)), rowColor)
      writeClip(t, lib, math.max(x + 2, valueX), yy, value, row.valueColor or rowColor)
    end
    yy = yy + 1
  end
end

local function drawAppliedNode(t, lib, x, y, label, color)
  writeClip(t, lib, x - 1, y - 1, "/\\", color)
  writeClip(t, lib, x - 2, y, "<" .. lib.ui.short(label or "[]", 2) .. ">", color)
  writeClip(t, lib, x - 1, y + 1, "\\/", color)
end

local function drawAppliedNetworkArt(t, lib, x, y, w, h, phase)
  if w < 28 or h < 12 then return end
  local cx = x + math.floor(w / 2)
  local cy = y + math.floor(h / 2)
  phase = tonumber(phase) or 0
  local rx = math.max(10, math.floor(w * 0.34))
  local ry = math.max(4, math.floor(h * 0.28))
  local pulse = phase % 4
  local function safe(px, py, text, color)
    if px >= x and py >= y and px <= x + w - 1 and py <= y + h - 1 then writeClip(t, lib, px, py, text, color) end
  end
  for i = -rx, rx, 2 do
    local top = cy - math.floor((1 - math.abs(i) / rx) * ry)
    local bot = cy + math.floor((1 - math.abs(i) / rx) * ry)
    local color = (i + pulse) % 4 == 0 and colors.purple or colors.lightBlue
    safe(cx + i, top, ".", color)
    safe(cx + i, bot, ".", color)
  end
  for i = -ry, ry do
    local span = math.floor((1 - math.abs(i) / ry) * rx)
    local color = (i + pulse) % 3 == 0 and colors.purple or colors.cyan
    safe(cx - span, cy + i, ".", color)
    safe(cx + span, cy + i, ".", color)
  end
  safe(cx - rx, cy, string.rep("-", math.max(1, rx * 2)), colors.lightBlue)
  safe(cx, cy - ry, "|", colors.lightBlue)
  safe(cx, cy + ry, "|", colors.lightBlue)
  for i = 1, ry - 1 do
    safe(cx - i * 2, cy - i, "/", colors.cyan)
    safe(cx + i * 2, cy - i, "\\", colors.cyan)
    safe(cx - i * 2, cy + i, "\\", colors.purple)
    safe(cx + i * 2, cy + i, "/", colors.purple)
  end
  drawAppliedNode(t, lib, cx, cy - ry - 2, "[]", colors.lightBlue)
  drawAppliedNode(t, lib, cx, cy + ry + 2, "[]", colors.lightBlue)
  drawAppliedNode(t, lib, cx - rx, cy, "[]", colors.cyan)
  drawAppliedNode(t, lib, cx + rx, cy, "[]", colors.cyan)
  drawAppliedNode(t, lib, cx - math.floor(rx * 0.55), cy - math.floor(ry * 0.8), "[]", colors.purple)
  drawAppliedNode(t, lib, cx + math.floor(rx * 0.55), cy - math.floor(ry * 0.8), "[]", colors.purple)
  drawAppliedNode(t, lib, cx - math.floor(rx * 0.55), cy + math.floor(ry * 0.8), "[]", colors.lightBlue)
  drawAppliedNode(t, lib, cx + math.floor(rx * 0.55), cy + math.floor(ry * 0.8), "[]", colors.lightBlue)
  writeClip(t, lib, cx - 4, cy - 2, " /\\ ", colors.purple)
  writeClip(t, lib, cx - 5, cy - 1, "/  \\", colors.purple)
  writeClip(t, lib, cx - 5, cy, "\\  /", colors.purple)
  writeClip(t, lib, cx - 4, cy + 1, " \\/ ", colors.purple)
  writeClip(t, lib, cx - 3, cy, "CORE", colors.white)
end

local function drawAppliedTopology(t, lib, x, y, w, h, summary)
  drawFrameBox(t, lib, x, y, w, h, colors.gray)
  lib.ui.center(t, y + 1, "NETWORK TOPOLOGY", colors.cyan)
  local labels = {
    { "DRIVES", tostring(#(summary.devices or {})), colors.cyan },
    { "INTERFACES", tostring(math.max(0, #(summary.devices or {}) - 1)), colors.lightBlue },
    { "CHANNELS", tostring(summary.channels or "--"), colors.purple },
    { "P2P LINKS", tostring(summary.p2p or "--"), colors.purple },
  }
  local cell = math.max(10, math.floor((w - 4) / #labels))
  for i, item in ipairs(labels) do
    local xx = x + 2 + (i - 1) * cell
    writeClip(t, lib, xx, y + 3, "<>", item[3])
    writeClip(t, lib, xx + 3, y + 3, item[1], item[3])
    writeClip(t, lib, xx + 3, y + 4, item[2], colors.white)
  end
end

local function drawAppliedPresentation(t, lib, snap)
  local w, h = lib.ui.size(t)
  if w < 80 or h < 20 then
    drawDeviceList(t, lib, snap, "AE2", function(n, l) return n:find("ae2") or l:lower():find("ae2") end)
    return
  end
  local sAe = ae2Summary(snap or {})
  local pct = tonumber(sAe.percent) or 0
  local phase = math.floor((os.clock() or 0) * 2) % 8
  local sideW = math.max(24, math.min(34, math.floor(w * 0.25)))
  local leftX = 3
  local rightX = w - sideW - 2
  local centerX = leftX + sideW + 3
  local centerW = math.max(24, rightX - centerX - 3)
  local titleY = 2
  local bodyY = 4
  local bottomY = h - 2
  local topH = math.max(5, math.floor((bottomY - bodyY - 2) / 3))
  local p1 = bodyY
  local p2 = p1 + topH + 1
  local p3 = p2 + topH + 1
  local p3H = math.max(5, bottomY - p3 + 1)
  local rightH = math.max(4, math.floor((bottomY - bodyY - 3) / 4))
  local r1 = bodyY
  local r2 = r1 + rightH + 1
  local r3 = r2 + rightH + 1
  local r4 = r3 + rightH + 1
  local r4H = math.max(4, bottomY - r4 + 1)
  local topoH = math.min(5, math.max(4, math.floor(h * 0.18)))
  local topoY = bottomY - topoH + 1
  local artH = math.max(10, topoY - bodyY - 1)

  drawFrameBox(t, lib, 1, 1, w, h, colors.gray)
  lib.ui.center(t, titleY, "APPLIED", colors.white)
  drawAppliedPanel(t, lib, leftX, p1, sideW, topH, "storage", colors.cyan, {
    { label = string.format("%0.1f%%", pct), value = "", color = colors.white },
    { label = fmtAeCount(sAe.used), value = "/ " .. fmtAeCount(sAe.capacity) .. " ITEMS", color = colors.gray },
    { sep = true },
    { label = "IN", value = fmtAeCount(sAe.input) .. "/t", color = colors.green },
    { label = "OUT", value = "-" .. fmtAeCount(sAe.output) .. "/t", color = colors.lightBlue },
    { sep = true },
    { label = "NET", value = fmtAeCount(sAe.net) .. "/t", color = colors.purple },
  }, pct)
  drawAppliedPanel(t, lib, leftX, p2, sideW, topH, "flow", colors.cyan, {
    { label = "IN", value = fmtAeCount(sAe.input) .. "/t", color = colors.green },
    { label = "OUT", value = fmtAeCount(sAe.output) .. "/t", color = colors.lightBlue },
    { sep = true },
    { label = "BALANCE", value = fmtAeCount(sAe.net) .. "/t", color = colors.purple },
    { sep = true },
    { label = "THROUGHPUT", value = pct > 0 and string.format("%0.0f%%", math.min(100, pct)) or "--", color = colors.gray },
    { label = "CHANNELS", value = tostring(sAe.channels or "--"), color = colors.gray },
  }, nil)
  drawAppliedPanel(t, lib, leftX, p3, sideW, p3H, "power", colors.yellow, {
    { label = "USAGE", value = sAe.powerUsage and (fmtAeCount(sAe.powerUsage) .. " AE/t") or "--", color = colors.gray },
    { label = "CAPACITY", value = sAe.powerCapacity and (fmtAeCount(sAe.powerCapacity) .. " AE/t") or "--", color = colors.gray },
    { sep = true },
    { label = "BUFFER", value = string.format("%0.0f%%", pct), color = colors.yellow },
  }, pct)

  drawAppliedNetworkArt(t, lib, centerX, bodyY, centerW, artH, phase)
  drawAppliedTopology(t, lib, centerX, topoY, centerW, topoH, sAe)

  drawAppliedPanel(t, lib, rightX, r1, sideW, rightH, "status", colors.cyan, {
    { label = sAe.online and "ONLINE" or "OFFLINE", value = "", color = sAe.online and colors.green or colors.red },
    { sep = true },
    { label = "UPTIME", value = tostring((snap or {}).cycle or 0) .. " cyc", color = colors.gray },
    { label = "MEMORY", value = pct > 0 and string.format("%0.0f%%", pct) or "--", color = colors.gray },
  }, nil)
  drawAppliedPanel(t, lib, rightX, r2, sideW, rightH, "crafting", colors.purple, {
    { label = "JOBS", value = tostring(sAe.jobs or "--"), color = colors.gray },
    { label = "CPU BUSY", value = tostring(sAe.cpus or "--"), color = colors.gray },
    { sep = true },
    { label = "QUEUE", value = "--", color = colors.gray },
    { label = "STORAGE", value = pct > 0 and string.format("%0.0f%%", pct) or "--", color = colors.gray },
  }, nil)
  drawAppliedPanel(t, lib, rightX, r3, sideW, rightH, "fluids", colors.cyan, {
    { label = "TANKS", value = tostring(sAe.tanks or "--"), color = colors.gray },
    { label = "FLUIDS", value = tostring(sAe.fluids or "--"), color = colors.gray },
    { sep = true },
    { label = "STORED", value = "-- mB", color = colors.gray },
  }, nil)
  drawAppliedPanel(t, lib, rightX, r4, sideW, r4H, "time to full", colors.yellow, {
    { label = "ETA", value = sAe.net > 0 and "--" or "stable", color = colors.white },
  }, nil)
end

local function drawStats(t, lib, snap, name)
  local mode = displayMode(snap, name, "all")
  if mode == "alarms" or mode == "warnings" then
    drawDeviceList(t, lib, snap, name .. " alarms", function(_, _, item) return (item.severity or 0) > 0 end)
  elseif mode == "draconic" then
    drawDraconicStats(t, lib, snap)
  elseif mode == "power" or mode == "breakers" then
    local y = 1
    lib.ui.center(t, y, string.upper(name) .. " POWER", colors.lightBlue)
    y = y + 2
    for k, closed in pairs(snap.breakers or {}) do
      lib.ui.writeAt(t, 1, y, k .. " " .. (closed and "CLOSED" or "OPEN"), closed and colors.green or colors.red)
      y = y + 1
      if y > lib.ui.maxRows(t, 1) then break end
    end
  elseif mode == "peripherals" or mode == "devices" then
    drawDeviceList(t, lib, snap, name .. " devices")
  else
    drawDeviceList(t, lib, snap, name)
  end
end

local function drawMonitor(t, lib, snap, name, graphMode)
  local w = lib.ui.size(t)
  local mode = displayMode(snap, name, "overview")
  local barW = math.max(4, w)
  local alert = snap.alert or { level = 0, reason = "nominal" }
  if mode == "ae2" then
    drawDeviceList(t, lib, snap, "AE2", function(n, l) return n:find("ae2") or l:lower():find("ae2") end)
    return
  elseif mode == "draconic" then
    drawDraconicMonitor(t, lib, snap, graphMode)
    return
  elseif mode == "computers" then
    drawDeviceList(t, lib, snap, "Computers", function(n) return not n:find("peripheral") end)
    return
  elseif mode == "alarms" then
    drawDeviceList(t, lib, snap, "Alarms", function(_, _, item) return (item.severity or 0) > 0 end)
    return
  end
  lib.ui.center(t, 1, string.upper(name), colors.lightBlue)
  lib.ui.writeAt(t, 1, 2, "Alert L" .. tostring(alert.level) .. " " .. tostring(alert.reason), lib.ui.statusColor(alert.level or 0))
  local load = (((snap.buses or {}).load or {}).watts or 0)
  local gen = (((snap.buses or {}).generation or {}).watts or 0)
  lib.ui.writeAt(t, 1, 4, string.format("GEN %0.1fMW", gen / 1000000), colors.green)
  lib.ui.bar(t, 1, 5, barW, math.min(100, gen / 65000), 100, colors.green)
  lib.ui.writeAt(t, 1, 6, string.format("LOAD %0.1fMW", load / 1000000), colors.yellow)
  lib.ui.bar(t, 1, 7, barW, math.min(100, load / 65000), 100, colors.yellow)
  lib.ui.writeAt(t, 1, 8, string.format("BAT %0.1f%%", (snap.batteries or {}).battery400 or 0), colors.white)
  lib.ui.bar(t, 1, 9, barW, (snap.batteries or {}).battery400 or 0, 100, colors.orange)
end

local function drawPresentation(t, lib, snap, name)
  local w = lib.ui.size(t)
  local barW = math.max(4, w)
  local mode = displayMode(snap, name, "overview")
  lib.ui.center(t, 1, string.upper(name:gsub("_", " ")), colors.lightBlue)
  lib.ui.center(t, 2, "CTX " .. string.upper(mode), colors.gray)
  local buses = snap.buses or {}
  local gen = ((buses.generation or {}).watts or 0)
  local load = ((buses.load or {}).watts or 0)
  local alert = snap.alert or {}
  if mode == "ae2" then
    drawAppliedPresentation(t, lib, snap)
  elseif mode == "draconic" then
    drawDraconicPresentation(t, lib, snap)
  elseif mode == "computers" then
    drawDeviceList(t, lib, snap, "Computers", function(n) return not n:find("peripheral") end)
  elseif mode == "alarms" then
    drawDeviceList(t, lib, snap, "Alarms", function(_, _, item) return (item.severity or 0) > 0 end)
  elseif mode == "battery" then
    lib.ui.writeAt(t, 1, 4, string.format("400V BAT %0.1f%%", (snap.batteries or {}).battery400 or 0), colors.yellow)
    lib.ui.bar(t, 1, 5, math.min(34, barW), (snap.batteries or {}).battery400 or 0, 100, colors.orange)
    lib.ui.writeAt(t, 1, 7, string.format("PMC %0.0f / %0.0f / %0.0f%%", (snap.batteries or {}).pmc1 or 0, (snap.batteries or {}).pmc2 or 0, (snap.batteries or {}).pmc3 or 0), colors.yellow)
  elseif mode == "fission" or mode == "fusion" or mode == "power" then
    lib.ui.writeAt(t, 1, 4, string.format("Generation %0.2f MW", gen / 1000000), colors.green)
    lib.ui.bar(t, 1, 5, math.min(34, barW), math.min(100, (gen / 6500000) * 100), 100, colors.green)
    lib.ui.writeAt(t, 1, 7, string.format("Load %0.2f MW", load / 1000000), colors.yellow)
    lib.ui.bar(t, 1, 8, math.min(34, barW), math.min(100, (load / 6500000) * 100), 100, colors.yellow)
  elseif name == "presentation_screen_left" then
    lib.ui.writeAt(t, 1, 4, string.format("GEN %0.2f MW", gen / 1000000), colors.green)
    lib.ui.bar(t, 1, 5, barW, math.min(100, (gen / 6500000) * 100), 100, colors.green)
    lib.ui.writeAt(t, 1, 7, string.format("230V %0.1f", (buses.ac230 or {}).voltage or 0), colors.green)
    lib.ui.writeAt(t, 1, 8, string.format("400V %0.1f", (buses.ac400 or {}).voltage or 0), colors.green)
    lib.ui.writeAt(t, 1, 9, string.format("12V  %0.1f", (buses.dc12 or {}).voltage or 0), colors.green)
  elseif name == "presentation_screen_right" then
    lib.ui.writeAt(t, 1, 4, "Alert L" .. tostring(alert.level or 0), lib.ui.statusColor(alert.level or 0))
    lib.ui.writeAt(t, 1, 5, tostring(alert.reason or "nominal"), lib.ui.statusColor(alert.level or 0))
    lib.ui.writeAt(t, 1, 7, string.format("LOAD %0.2f MW", load / 1000000), colors.yellow)
    lib.ui.bar(t, 1, 8, barW, math.min(100, (load / 6500000) * 100), 100, colors.yellow)
  else
    local y = 4
    lib.ui.writeAt(t, 1, y, "1MVDCSPC -> 10KV A/B -> LV -> 400/230VAC", colors.white)
    y = y + 2
    lib.ui.writeAt(t, 1, y, string.format("230VAC %0.1fV", (buses.ac230 or {}).voltage or 0), colors.green)
    lib.ui.writeAt(t, 1, y + 1, string.format("400VAC %0.1fV", (buses.ac400 or {}).voltage or 0), colors.green)
    lib.ui.writeAt(t, 1, y + 2, string.format("12V BUS %0.1fV", (buses.dc12 or {}).voltage or 0), colors.green)
    y = y + 4
    lib.ui.writeAt(t, 1, y, string.format("Generation %0.2f MW", gen / 1000000), colors.green)
    lib.ui.bar(t, 1, y + 1, math.min(34, barW), math.min(100, (gen / 6500000) * 100), 100, colors.green)
    y = y + 3
    lib.ui.writeAt(t, 1, y, string.format("Load %0.2f MW", load / 1000000), colors.yellow)
    lib.ui.bar(t, 1, y + 1, math.min(34, barW), math.min(100, (load / 6500000) * 100), 100, colors.yellow)
    y = y + 3
    lib.ui.writeAt(t, 1, y, "Alert L" .. tostring(alert.level or 0) .. " " .. tostring(alert.reason or "nominal"), lib.ui.statusColor(alert.level or 0))
  end
end
local function targetMatches(target, name, spec)
  if not target or target == "all" or target == name then return true end
  target = tostring(target)
  local display = tostring((spec or {}).display or "")
  local label = tostring((spec or {}).label or "")
  if target == display or target == label then return true end
  return false
end

local function updateTerminal(status)
  local any = false
  for _, item in pairs(status or {}) do
    any = true
    local stage = type(item) == "table" and item.stage or nil
    if stage ~= "done" and stage ~= "failed" and stage ~= "rebooting" and stage ~= "timeout" then return false end
  end
  return any
end

local function updateHasRows(status)
  for _, item in pairs(status or {}) do
    if type(item) == "table" then return true end
  end
  return false
end
local function updateHoldSeconds(status)
  return updateTerminal(status) and 8 or 90
end

local function setUpdateStatus(s, status)
  s.updateStatus = status or {}
  if not updateHasRows(s.updateStatus) then
    s.updateTerminalSince = nil
    s.updateUntil = 0
    return
  end
  if updateTerminal(s.updateStatus) then
    s.updateTerminalSince = s.updateTerminalSince or os.clock()
    local remaining = 8 - (os.clock() - s.updateTerminalSince)
    if remaining > 0 then
      s.updateUntil = os.clock() + math.min(remaining, 1.5)
    else
      s.updateUntil = 0
    end
  else
    s.updateTerminalSince = nil
    s.updateUntil = os.clock() + 90
  end
end

local function drawUpdateBanner(t, lib, s)
  if not (s.updateUntil and os.clock() < s.updateUntil) then return end
  if not updateHasRows(s.updateStatus) then return end
  local w, h = lib.ui.size(t)
  if h < 1 then return end
  local rows = {}
  local sum, done, failed, nodes = 0, 0, 0, 0
  local kind = "update"
  for key, item in pairs(s.updateStatus or {}) do
    if type(item) == "table" then
      item.key = key
      rows[#rows + 1] = item
      nodes = nodes + 1
      kind = tostring(item.updateKind or item.kind or kind)
      local p = tonumber(item.progress) or 0
      if item.stage == "done" or item.stage == "rebooting" then p = 100; done = done + 1 end
      if item.stage == "failed" or item.stage == "timeout" then p = 100; failed = failed + 1 end
      sum = sum + math.max(0, math.min(100, p))
    end
  end
  if nodes <= 0 then return end
  table.sort(rows, function(a, b)
    local as, bs = tonumber(a.slot) or 999, tonumber(b.slot) or 999
    if as == bs then return tostring(a.device or a.key) < tostring(b.device or b.key) end
    return as < bs
  end)
  local current = nil
  for _, item in ipairs(rows) do
    local stage = tostring(item.stage or "queued")
    if stage ~= "done" and stage ~= "rebooting" and stage ~= "failed" and stage ~= "timeout" then
      current = item
      if stage ~= "queued" and stage ~= "scheduled" and stage ~= "countdown" then break end
    end
  end
  current = current or rows[#rows]
  local pct = math.floor(sum / nodes)
  local upperKind = string.upper(kind == "program" and "firmware" or kind)
  local bg = kind == "bootloader" and colors.blue or colors.green
  if failed > 0 then bg = colors.red end
  local fg = bg == colors.green and colors.black or colors.white
  local device = current and tostring(current.device or current.key or "waiting") or "waiting"
  local stage = current and tostring(current.stage or "queued") or "queued"
  local eta = current and tonumber(current.eta) or nil
  local etaText = eta and eta > 0 and (" T-" .. tostring(math.ceil(eta)) .. "s") or ""
  local text = string.format(" %s %d%%  %s %s%s  done %d/%d  fail %d", upperKind, pct, device, stage, etaText, done, nodes, failed)
  lib.ui.writeAt(t, 1, h, string.rep(" ", w), fg, bg)
  lib.ui.writeAt(t, 1, h, text:sub(1, w), fg, bg)
end
local function drawVersions(t, lib, snap, name)
  local w, h = lib.ui.size(t)
  lib.ui.clear(t, colors.white, colors.black)
  lib.ui.center(t, 1, "MCCR FIRMWARE", colors.lightBlue)
  lib.ui.writeAt(t, 1, 2, "Version " .. MCCR_VERSION, colors.yellow)
  local rows = {}
  local seen = {}
  for key, item in pairs((snap or {}).telemetry or {}) do
    local dev = tostring(item.name or key)
    seen[dev] = true
    rows[#rows + 1] = {
      name = dev,
      label = tostring(item.label or dev),
      program = tostring(item.program or item.role or "unknown"),
      version = tostring(item.firmwareVersion or item.version or "unknown"),
      severity = tonumber(item.severity) or 0,
    }
  end
  if not seen[name] then
    rows[#rows + 1] = {
      name = name,
      label = name,
      program = MCCR_PROGRAM,
      version = MCCR_VERSION,
      severity = 0,
    }
  end
  table.sort(rows, function(a, b) return tostring(a.name) < tostring(b.name) end)
  local y = 4
  for _, row in ipairs(rows) do
    if y > h then break end
    local text = row.name .. "  " .. row.program .. "  v" .. row.version
    lib.ui.writeAt(t, 1, y, text, row.name == name and colors.lime or lib.ui.statusColor(row.severity))
    y = y + 1
  end
  if y == 4 then lib.ui.writeAt(t, 1, y, "Waiting for version telemetry", colors.gray) end
  if h >= 2 then lib.ui.writeAt(t, math.max(1, w - 7), h, "20s", colors.gray) end
end

local function run(name, lib)
  local statePath = "/mccr_state/" .. name .. ".dat"
  local s = lib.state.read(statePath, { snapshot = {}, eval = {}, cycle = 0 })
  s.updateStatus = {}
  s.updateUntil = nil
  s.updateTerminalSince = nil
  s.showVersionsUntil = nil
  local screen = lib.ui.target(lib.devices.spec(name))
  lib.ui.boot(screen, lib.devices.spec(name).label or name)
  mccrDrawConsoleStatus(name, "running")
  lib.net.open()

  local function drawFrame()
    local spec = lib.devices.spec(name)
    s.snapshot = s.snapshot or {}
    local eval = lib.power.evaluate(spec, lib.power.inputFor(spec, s.snapshot), s.eval)
    eval.name, eval.label, eval.role = name, spec.label, spec.role
    eval.program, eval.firmwareVersion = MCCR_PROGRAM, MCCR_VERSION
    s.eval = eval

    styledClear(screen, lib, s.snapshot)
    local presentationFeedOff = (s.snapshot.breakers or {}).main_computer == false and tostring(spec.display or ""):find("^presentation")
    if s.showVersionsUntil and os.clock() < s.showVersionsUntil then
      drawVersions(screen, lib, s.snapshot, name)
    elseif presentationFeedOff then
      s.sleepTick = (s.sleepTick or 0) + 1
      if s.sleepTick == 1 then
        lib.ui.clear(screen, colors.black, colors.white)
      elseif s.sleepTick <= 4 then
        lib.ui.clear(screen, colors.white, colors.blue)
        lib.ui.center(screen, 2, "NO SIGNAL", colors.white, colors.blue)
        lib.ui.center(screen, 4, "DISPLAY FEED OFF", colors.white, colors.blue)
      else
        lib.ui.clear(screen, colors.gray, colors.black)
      end
    elseif not eval.online then
      s.sleepTick = 0
      lib.ui.center(screen, 2, spec.label, colors.red)
      lib.ui.center(screen, 5, eval.destroyed and "DESTROYED" or "OFFLINE")
      lib.ui.center(screen, 7, eval.reason)
    elseif spec.display == "action" then s.sleepTick = 0; drawAction(screen, lib, s.snapshot)
    elseif spec.display == "alert" then s.sleepTick = 0; drawAlert(screen, lib, s.snapshot)
    elseif spec.display == "clock" then s.sleepTick = 0; drawClock(screen, lib, s.snapshot)
    elseif spec.display == "stats" then s.sleepTick = 0; drawStats(screen, lib, s.snapshot, name)
    elseif spec.display == "monitor" then s.sleepTick = 0; drawMonitor(screen, lib, s.snapshot, name, s.graphMode)
    else s.sleepTick = 0; drawPresentation(screen, lib, s.snapshot, name) end
    drawUpdateBanner(screen, lib, s)
  end

  local function publishTelemetry()
    if s.eval then lib.net.broadcast(name, "telemetry", s.eval) end
  end

  local function saveState()
    lib.state.write(statePath, {
      eval = s.eval,
      cycle = s.cycle,
      sleepTick = s.sleepTick,
      localContexts = s.localContexts,
      localStyle = s.localStyle,
      graphMode = s.graphMode,
    })
  end

  local function handlePacket(pkt)
    if pkt and pkt.kind == "snapshot" then
      s.snapshot = pkt.payload or s.snapshot
      setUpdateStatus(s, s.snapshot.updateStatus or {})
      if s.localContexts then
        s.snapshot.displayContexts = s.snapshot.displayContexts or {}
        for k, v in pairs(s.localContexts) do s.snapshot.displayContexts[k] = v end
      end
      if s.localStyle then
        s.snapshot.screenStyle = s.snapshot.screenStyle or {}
        for k, v in pairs(s.localStyle) do s.snapshot.screenStyle[k] = v end
      end
      return true
    elseif pkt and pkt.kind == "command" and pkt.payload then
      local spec = lib.devices.spec(name)
      local p = pkt.payload
      if p.command == "restore" then
        s.eval = {}
        return true
      elseif p.command == "show_versions" then
        if targetMatches(p.target, name, spec) then
          s.showVersionsUntil = os.clock() + math.max(5, tonumber(p.duration) or 20)
          return true
        end
      elseif p.command == "display_context" and p.mode then
        if targetMatches(p.target, name, spec) then
          s.localContexts = s.localContexts or {}
          s.localContexts[name] = tostring(p.mode)
          s.snapshot.displayContexts = s.snapshot.displayContexts or {}
          s.snapshot.displayContexts[name] = tostring(p.mode)
          return true
        end
      elseif p.command == "theme" then
        s.localStyle = s.localStyle or {}
        s.snapshot.screenStyle = s.snapshot.screenStyle or {}
        if p.textColor then s.localStyle.textColor = p.textColor; s.snapshot.screenStyle.textColor = p.textColor end
        if p.bgColor then s.localStyle.bgColor = p.bgColor; s.snapshot.screenStyle.bgColor = p.bgColor end
        if p.theme then s.localStyle.theme = p.theme; s.snapshot.screenStyle.theme = p.theme end
        return true
      end
    end
    return false
  end

  drawFrame()
  publishTelemetry()
  local redrawTimer = os.startTimer(0.25)
  local telemetryTimer = os.startTimer(1)
  local saveTimer = os.startTimer(5)
  local dirty = false

  while true do
    local ev = { os.pullEvent() }
    if ev[1] == "rednet_message" then
      local pkt, protocol = ev[3], ev[4]
      if protocol == lib.net.protocol and type(pkt) == "table" and pkt.system == "mccr" then
        dirty = handlePacket(pkt) or dirty
      end
    elseif ev[1] == "timer" and ev[2] == redrawTimer then
      dirty = true
      redrawTimer = os.startTimer(0.25)
    elseif ev[1] == "timer" and ev[2] == telemetryTimer then
      publishTelemetry()
      telemetryTimer = os.startTimer(1)
    elseif ev[1] == "timer" and ev[2] == saveTimer then
      saveState()
      saveTimer = os.startTimer(5)
    elseif ev[1] == "monitor_touch" or ev[1] == "mouse_click" then
      local spec = lib.devices.spec(name)
      if spec.display == "monitor" and displayMode(s.snapshot, name, "overview") == "draconic" then
        s.graphMode = not s.graphMode
        dirty = true
      end
    end

    if dirty then
      drawFrame()
      dirty = false
    end
  end
end

return run

end

local lib = {
  state = load_state(),
  net = load_net(),
  devices = load_devices(),
  power = load_power(),
  ui = load_ui(),
}

function mccrBootloaderVersion(path)
  path = path or "/startup.lua"
  if not fs.exists(path) then return "missing" end
  local h = fs.open(path, "r")
  if not h then return "unknown" end
  local text = h.readAll()
  h.close()
  return text:match("%-%-version([%w%._%-]+)") or "unknown"
end

function mccrDrawConsoleStatus(name, state)
  local t = term.native and term.native() or term.current()
  if not t then return end
  local hasMonitor = false
  if peripheral and peripheral.find then
    local ok, mon = pcall(peripheral.find, "monitor")
    hasMonitor = ok and mon ~= nil
  end
  pcall(t.setBackgroundColor, colors.black)
  pcall(t.setTextColor, colors.white)
  pcall(t.clear)
  pcall(t.setCursorPos, 1, 1)
  pcall(t.setTextColor, colors.lightBlue)
  pcall(t.write, "MCCR ONLINE")
  pcall(t.setCursorPos, 1, 3)
  pcall(t.setTextColor, colors.white)
  pcall(t.write, "Device: " .. tostring(name or MCCR_DEFAULT_NAME or "unknown"))
  pcall(t.setCursorPos, 1, 4)
  pcall(t.write, "Program: " .. tostring(MCCR_PROGRAM or "unknown"))
  pcall(t.setCursorPos, 1, 5)
  pcall(t.write, "Firmware: v" .. tostring(MCCR_VERSION or "unknown"))
  pcall(t.setCursorPos, 1, 6)
  pcall(t.write, "Bootloader: v" .. tostring(mccrBootloaderVersion()))
  pcall(t.setCursorPos, 1, 8)
  pcall(t.setTextColor, colors.gray)
  pcall(t.write, "State: " .. tostring(state or "running"))
  pcall(t.setCursorPos, 1, 9)
  pcall(t.write, "UI: " .. (hasMonitor and "external monitor" or "console fallback"))
end
local CONFIG_PATH = "/mccr_device.dat"

local function allowed(name)
  for _, item in ipairs(MCCR_ALLOWED_NAMES) do
    if item == name then return true end
  end
  return false
end

local function readConfigName()
  if not fs.exists(CONFIG_PATH) then return nil end
  local h = fs.open(CONFIG_PATH, "r")
  if not h then return nil end
  local text = h.readAll()
  h.close()
  local ok, cfg = pcall(textutils.unserialize, text)
  if ok and type(cfg) == "table" and type(cfg.name) == "string" and allowed(cfg.name) then
    return cfg.name
  end
  return nil
end

local function writeConfigName(name)
  local h = fs.open(CONFIG_PATH, "w")
  if not h then return end
  h.write(textutils.serialize({ name = name, program = MCCR_PROGRAM }))
  h.close()
end

local function chooseName()
  local configured = readConfigName()
  if configured then return configured end
  writeConfigName(MCCR_DEFAULT_NAME)
  if os.setComputerLabel then pcall(os.setComputerLabel, MCCR_DEFAULT_NAME) end
  return MCCR_DEFAULT_NAME
end

local MCCR_NAME = chooseName()
local run = load_role_display()

while true do
  local ok, err = pcall(run, MCCR_NAME, lib)
  if ok then return end
  if tostring(err) == "local update requested" or tostring(err) == "local bootloader update requested" then return end

  local crashPath = "/mccr_state/" .. MCCR_NAME .. "_crash.log"
  lib.state.write(crashPath, {
    time = os.epoch and os.epoch("utc") or os.clock(),
    role = MCCR_ROLE,
    name = MCCR_NAME,
    program = MCCR_PROGRAM,
    version = MCCR_VERSION,
    error = tostring(err),
  })

  term.setBackgroundColor(colors.black)
  term.setTextColor(colors.red)
  term.clear()
  term.setCursorPos(1, 1)
  print("MCCR program crashed")
  print(tostring(err))
  print("Restarting in 5 seconds")
  sleep(5)
end
