-- Dynamic MCCR startup for emergency_controls_screen. Bundled dynamic program.
-- Concrete instance is read from /mccr_device.dat.
local MCCR_PROGRAM = "emergency_controls_screen"
local MCCR_VERSION = "1.0.1"
local MCCR_ROLE = "emergency"
local MCCR_DEFAULT_NAME = "emergency_controls_screen"
local MCCR_ALLOWED_NAMES = {
  "emergency_controls_screen",
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

local function load_role_emergency()
local function run(name, lib)
  local statePath = "/mccr_state/" .. name .. ".dat"
  local s = lib.state.read(statePath, { snapshot = {}, eval = {} })
  local screen = lib.ui.target(lib.devices.spec(name))
  lib.ui.boot(screen, lib.devices.spec(name).label or name)
  mccrDrawConsoleStatus(name, "running")
  lib.net.open()
  local buttons = {}

  local function send(payload)
    lib.net.broadcast(name, "command", payload)
  end

  local function drawVersions()
    local _, h = lib.ui.size(screen)
    lib.ui.clear(screen, colors.white, colors.black)
    lib.ui.center(screen, 1, "MCCR FIRMWARE", colors.lightBlue)
    lib.ui.writeAt(screen, 1, 2, "Version " .. MCCR_VERSION, colors.yellow)
    local rows = {}
    local seen = {}
    for key, item in pairs((s.snapshot or {}).telemetry or {}) do
      local dev = tostring(item.name or key)
      seen[dev] = true
      rows[#rows + 1] = {
        name = dev,
        program = tostring(item.program or item.role or "unknown"),
        version = tostring(item.firmwareVersion or item.version or "unknown"),
        severity = tonumber(item.severity) or 0,
      }
    end
    if not seen[name] then
      rows[#rows + 1] = { name = name, program = MCCR_PROGRAM, version = MCCR_VERSION, severity = 0 }
    end
    table.sort(rows, function(a, b) return tostring(a.name) < tostring(b.name) end)
    local y = 4
    for _, row in ipairs(rows) do
      if y > h then break end
      lib.ui.writeAt(screen, 1, y, row.name .. "  " .. row.program .. "  v" .. row.version, row.name == name and colors.lime or lib.ui.statusColor(row.severity))
      y = y + 1
    end
  end

  local function draw()
    local spec = lib.devices.spec(name)
    s.snapshot = s.snapshot or {}
    local eval = lib.power.evaluate(spec, lib.power.inputFor(spec, s.snapshot), s.eval)
    eval.name, eval.label, eval.role = name, spec.label, spec.role
    eval.program, eval.firmwareVersion = MCCR_PROGRAM, MCCR_VERSION
    s.eval = eval
    buttons = {}
    if s.showVersionsUntil and os.clock() < s.showVersionsUntil then
      drawVersions()
      return
    end
    lib.ui.clear(screen, colors.white, colors.black)
    local w, h = lib.ui.size(screen)
    lib.ui.center(screen, 1, "EMERGENCY CONTROLS", colors.red)
    local alert = s.snapshot.alert or { level = 0, reason = "nominal" }
    lib.ui.writeAt(screen, 1, 3, "Alert L" .. alert.level .. ": " .. tostring(alert.reason), lib.ui.statusColor(alert.level))
    lib.ui.writeAt(screen, 1, 4, "Self " .. eval.status .. string.format(" %0.1fV", eval.voltage), lib.ui.statusColor(eval.severity))
    local bw = math.max(8, math.floor((w - 2) / 2))
    local y1 = math.min(h, 6)
    local y2 = math.min(h, 8)
    buttons[#buttons + 1] = lib.ui.button(screen, "scram", 1, y1, bw, "PLANT SCRAM", colors.white, colors.red)
    buttons[#buttons + 1] = lib.ui.button(screen, "shed", bw + 2, y1, bw, "LOAD SHED", colors.white, colors.orange)
    buttons[#buttons + 1] = lib.ui.button(screen, "auto_off", 1, y2, bw, "AUTO OFF", colors.white, colors.gray)
    buttons[#buttons + 1] = lib.ui.button(screen, "restore", bw + 2, y2, bw, "RESTORE", colors.white, colors.green)
  end

  local function click(id)
    if id == "scram" then send({ command = "scram" })
    elseif id == "shed" then send({ command = "shed" })
    elseif id == "restore" then send({ command = "restore" })
    elseif id == "auto_off" then send({ command = "mode", mode = "manual_emergency" }) end
  end

  while true do
    draw()
    lib.net.broadcast(name, "telemetry", s.eval)
    lib.state.write(statePath, s)
    local timer = os.startTimer(1)
    while true do
      local ev = { os.pullEvent() }
      if ev[1] == "timer" and ev[2] == timer then break end
      if ev[1] == "rednet_message" then
        local pkt = ev[3]
        if type(pkt) == "table" and pkt.system == "mccr" and pkt.kind == "snapshot" then
          s.snapshot = pkt.payload or s.snapshot
        elseif type(pkt) == "table" and pkt.system == "mccr" and pkt.kind == "command" and pkt.payload then
          local p = pkt.payload
          if p.command == "show_versions" and (not p.target or p.target == "all" or p.target == name) then
            s.showVersionsUntil = os.clock() + math.max(5, tonumber(p.duration) or 20)
          end
        end
      elseif ev[1] == "monitor_touch" then
        click(lib.ui.hit(buttons, ev[3], ev[4]))
      elseif ev[1] == "mouse_click" then
        click(lib.ui.hit(buttons, ev[3], ev[4]))
      end
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
local run = load_role_emergency()

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
