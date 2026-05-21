-- Dynamic MCCR startup for maincomputer. Bundled dynamic program.
-- Concrete instance is read from /mccr_device.dat.
local MCCR_PROGRAM = "maincomputer"
local MCCR_VERSION = "1.0.1"
local MCCR_ROLE = "main"
local MCCR_DEFAULT_NAME = "maincomputer"
local MCCR_ALLOWED_NAMES = {
  "maincomputer",
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

local function load_role_main()
local function copyDefaults(src)
  local out = {}
  for k, v in pairs(src) do out[k] = v end
  return out
end

local function asNumber(value)
  if type(value) == "number" then return value end
  if type(value) == "string" then return tonumber(value) end
  return nil
end

local function etaForRfTick(energy, capacity, flow)
  energy, capacity, flow = asNumber(energy), asNumber(capacity), asNumber(flow)
  if not energy or not capacity or not flow or math.abs(flow) < 0.0001 then return nil, "stable" end
  local seconds
  local mode
  if flow > 0 then
    seconds = math.max(0, (capacity - energy) / flow / 20)
    mode = "full"
  else
    seconds = math.max(0, energy / math.abs(flow) / 20)
    mode = "empty"
  end
  if seconds < 60 then return string.format("%0.0fs", seconds), mode end
  if seconds < 3600 then return string.format("%0.1fm", seconds / 60), mode end
  if seconds < 86400 then return string.format("%0.1fh", seconds / 3600), mode end
  return string.format("%0.1fd", seconds / 86400), mode
end

local function draconicSnapshot(peripherals)
  local cores = {}
  local totalEnergy, totalCapacity = 0, 0
  local input, output, net = 0, 0, 0
  for source, bundle in pairs(peripherals or {}) do
    for pname, item in pairs(bundle or {}) do
      if type(item) == "table" and item.kind == "draconic_energy_core" then
        local core = {}
        for k, v in pairs(item) do core[k] = v end
        core.source = source
        core.name = core.name or pname
        core.energy = asNumber(core.energy)
        core.maxEnergy = asNumber(core.maxEnergy)
        core.percent = asNumber(core.percent)
        core.inputRfPerTick = asNumber(core.inputRfPerTick)
        core.outputRfPerTick = asNumber(core.outputRfPerTick)
        core.netRfPerTick = asNumber(core.netRfPerTick)
        if core.energy then totalEnergy = totalEnergy + core.energy end
        if core.maxEnergy then totalCapacity = totalCapacity + core.maxEnergy end
        input = input + (core.inputRfPerTick or 0)
        output = output + (core.outputRfPerTick or 0)
        net = net + (core.netRfPerTick or 0)
        cores[#cores + 1] = core
      end
    end
  end
  table.sort(cores, function(a, b) return tostring(a.name) < tostring(b.name) end)
  local percent = totalCapacity > 0 and math.max(0, math.min(100, totalEnergy / totalCapacity * 100)) or nil
  local eta, etaMode = etaForRfTick(totalEnergy, totalCapacity, net)
  return {
    cores = cores,
    totalEnergy = totalEnergy,
    totalCapacity = totalCapacity,
    percent = percent,
    inputRfPerTick = input,
    outputRfPerTick = output,
    netRfPerTick = net,
    eta = eta,
    etaMode = etaMode,
    line = "1MV",
    voltage = 1000000,
  }
end

local function run(name, lib)
  local statePath = "/mccr_state/" .. name .. ".dat"
  local actionPath = "/mccr_state/actions.log"
  local defaultContexts = {
    presentation_screen_left = "overview",
    main_presentation_screen = "overview",
    presentation_screen_right = "overview",
    mon1 = "overview",
    mon2 = "overview",
    mon3 = "overview",
    mon4 = "overview",
    statsm1 = "all",
    statsm2 = "all",
    statsm3 = "all",
    statsm4 = "all",
    statsm5 = "all",
    statsm6 = "all",
  }
  local s = lib.state.read(statePath, {
    breakers = copyDefaults(lib.devices.breakers),
    batteries = { battery400 = 82, pmc1 = 100, pmc2 = 100, pmc3 = 100 },
    telemetry = {},
    peripherals = {},
    updateStatus = {},
    buses = {},
    alert = { level = 0, reason = "nominal" },
    mode = "normal",
    displayContexts = defaultContexts,
    screenStyle = { textColor = colors.white, bgColor = colors.black, theme = "default" },
    tempOffset = 0,
    cycle = 0,
  })
  s.breakers = s.breakers or copyDefaults(lib.devices.breakers)
  for k, v in pairs(lib.devices.breakers) do
    if s.breakers[k] == nil then s.breakers[k] = v end
  end
  s.batteries = s.batteries or { battery400 = 82, pmc1 = 100, pmc2 = 100, pmc3 = 100 }
  s.telemetry = s.telemetry or {}
  s.updateStatus = s.updateStatus or {}
  s.displayContexts = s.displayContexts or defaultContexts
  for k, v in pairs(defaultContexts) do
    if s.displayContexts[k] == nil then s.displayContexts[k] = v end
  end
  s.screenStyle = s.screenStyle or { textColor = colors.white, bgColor = colors.black, theme = "default" }
  s.draconic = s.draconic or draconicSnapshot(s.peripherals)

  local screen = lib.ui.target(lib.devices.spec(name))
  lib.ui.boot(screen, lib.devices.spec(name).label or name)
  lib.net.open()

  local function log(kind, source, text, severity)
    lib.state.appendLog(actionPath, {
      kind = kind,
      source = source,
      text = text,
      severity = severity or 1,
      time = os.time(),
      epoch = os.epoch and os.epoch("utc") or os.clock(),
    }, 80)
  end

  local function computeBuses(dt)
    s.draconic = draconicSnapshot(s.peripherals)
    local nuclear = s.breakers.plant_nuclear and 2500000 or 0
    local fusion = s.breakers.plant_fusion and 4000000 or 0
    local reserved = 0
    for k, closed in pairs(s.breakers) do
      if closed and k:find("^plant_reserved_") then reserved = reserved + 1500000 end
    end
    local generation = nuclear + fusion + reserved
    local t10ok = (s.breakers.t10_a or s.breakers.t10_b)
    local lvok = (s.breakers.lv_a or s.breakers.lv_b)
    local acAvailable = generation > 50000 and t10ok and lvok
    local emergency = s.breakers.emergency_inverter and s.batteries.battery400 > 2

    local activeDevices = { maincomputer = true, admin_control_panel = true }
    for dev in pairs(s.telemetry or {}) do activeDevices[dev] = true end
    local totalComputerW = 0
    for dev in pairs(activeDevices) do
      local spec = lib.devices.devices[dev]
      local display = spec and spec.display or ""
      if spec and not (s.breakers.main_computer == false and tostring(display):find("^presentation")) then
        totalComputerW = totalComputerW + (spec.watts or 0)
      end
    end
    local extraW = 0
    if s.breakers.lighting then extraW = extraW + lib.devices.loads.lighting_w end
    if s.breakers.transformer_fans then extraW = extraW + lib.devices.loads.transformer_fans_w end
    if s.breakers.facility_ac_1 then extraW = extraW + lib.devices.loads.facility_ac_each_w end
    if s.breakers.facility_ac_2 then extraW = extraW + lib.devices.loads.facility_ac_each_w end
    if s.breakers.noncritical_loads then extraW = extraW + lib.devices.loads.control_room_ac_w end
    if s.breakers.fake_load then extraW = extraW + lib.devices.loads.fake_load_w end
    if s.breakers.sound_device then extraW = extraW + lib.devices.loads.sound_device_w end
    local loadW = totalComputerW + extraW

    local acVoltage = 0
    local ac400 = 0
    if acAvailable then
      local margin = math.max(0, generation - loadW)
      local sag = loadW > 0 and math.min(0.35, math.max(0, (loadW - generation) / math.max(generation, 1))) or 0
      acVoltage = 230 * (1 - sag) + math.min(6, margin / 1000000)
      ac400 = 400 * (acVoltage / 230)
      if s.breakers.battery_400v_charger then
        s.batteries.battery400 = math.min(100, s.batteries.battery400 + dt * 0.0025)
      end
    elseif emergency then
      acVoltage = 226
      ac400 = 393
      s.batteries.battery400 = math.max(0, s.batteries.battery400 - dt * (loadW / lib.devices.loads.battery_400v_wh) * 100)
    end

    local dc12 = (s.breakers.buck_12v and (acVoltage > 0 or emergency)) and 12.4 or 0
    local roomTemp = 24 + math.min(52, loadW / 45000) + (s.tempOffset or 0)
    if s.breakers.noncritical_loads then roomTemp = roomTemp - 10 end
    roomTemp = math.max(-10, roomTemp)

    for _, key in ipairs({ "pmc1", "pmc2", "pmc3" }) do
      if acVoltage > 180 then
        s.batteries[key] = math.min(100, s.batteries[key] + dt * 0.015)
      else
        s.batteries[key] = math.max(0, s.batteries[key] - dt * (70 / 500) * 100 / 3600)
      end
    end

    local coreWatts = ((s.draconic or {}).netRfPerTick or 0) * 20
    s.buses = {
      mv1 = {
        voltage = 1000000,
        watts = coreWatts,
        current = coreWatts / 1000000,
        flowRfPerTick = (s.draconic or {}).netRfPerTick or 0,
        energy = (s.draconic or {}).totalEnergy or 0,
        capacity = (s.draconic or {}).totalCapacity or 0,
        percent = (s.draconic or {}).percent,
      },
      ac230 = { voltage = acVoltage, temp = roomTemp },
      ac400 = { voltage = ac400, temp = roomTemp },
      dc12 = { voltage = dc12, temp = roomTemp },
      pmc1 = { voltage = s.batteries.pmc1 > 2 and (8.2 + s.batteries.pmc1 / 100 * 4.7) or 0, temp = roomTemp },
      pmc2 = { voltage = s.batteries.pmc2 > 2 and (8.2 + s.batteries.pmc2 / 100 * 4.7) or 0, temp = roomTemp },
      pmc3 = { voltage = s.batteries.pmc3 > 2 and (8.2 + s.batteries.pmc3 / 100 * 4.7) or 0, temp = roomTemp },
      generation = { watts = generation },
      load = { watts = loadW },
    }

    local ownSpec = lib.devices.spec("maincomputer")
    s.telemetry.maincomputer = lib.power.evaluate(ownSpec, lib.power.inputFor(ownSpec, s), s.telemetry.maincomputer)
    s.telemetry.maincomputer.label = ownSpec.label
    s.telemetry.maincomputer.name = "maincomputer"
    s.telemetry.maincomputer.role = ownSpec.role

    local level, reason = lib.power.alertLevel(s.telemetry)
    s.alert = { level = level, reason = reason }
  end

  local function telemetrySnapshot()
    local out = {}
    for k, v in pairs(s.telemetry or {}) do out[k] = v end
    local spec = lib.devices.spec(name)
    out[name] = {
      name = name,
      label = spec.label or name,
      role = MCCR_ROLE,
      program = MCCR_PROGRAM,
      firmwareVersion = MCCR_VERSION,
      status = "nominal",
      severity = 0,
      reason = "supervisor online",
    }
    return out
  end

  local function snapshot()
    return {
      buses = s.buses,
      batteries = s.batteries,
      breakers = s.breakers,
      telemetry = telemetrySnapshot(),
      updateStatus = s.updateStatus,
      peripherals = s.peripherals,
      draconic = s.draconic,
      alert = s.alert,
      mode = s.mode,
      displayContexts = s.displayContexts,
      screenStyle = s.screenStyle,
      actions = lib.state.read(actionPath, {}),
      cycle = s.cycle,
    }
  end

  local function applyCommand(pkt)
    local p = pkt.payload or {}
    local source = pkt.source or "unknown"
    if p.command == "toggle_breaker" and s.breakers[p.breaker] ~= nil then
      s.breakers[p.breaker] = not s.breakers[p.breaker]
      log("OP", source, "Breaker " .. p.breaker .. " -> " .. tostring(s.breakers[p.breaker]), 2)
    elseif p.command == "set_breaker" and s.breakers[p.breaker] ~= nil then
      s.breakers[p.breaker] = p.value == true
      log(p.auto and "AU" or "OP", source, "Breaker " .. p.breaker .. " -> " .. tostring(s.breakers[p.breaker]), 2)
    elseif p.command == "scram" then
      for k in pairs(s.breakers) do
        if k:find("^plant_") then s.breakers[k] = false end
      end
      s.mode = "scram"
      log("OP", source, "Emergency SCRAM: plant line isolated", 4)
    elseif p.command == "shed" then
      s.breakers.noncritical_loads = false
      s.breakers.facility_ac_1 = false
      s.breakers.facility_ac_2 = false
      s.mode = "load_shed"
      log("OP", source, "Emergency load shed: noncritical loads opened", 3)
    elseif p.command == "restore" then
      for k in pairs(s.breakers) do
        if k:find("reserved") then s.breakers[k] = false else s.breakers[k] = true end
      end
      s.breakers.tie_10kv = false
      s.batteries.battery400 = 100
      s.batteries.pmc1, s.batteries.pmc2, s.batteries.pmc3 = 100, 100, 100
      for _, item in pairs(s.telemetry) do item.destroyed = false end
      s.mode = "normal"
      log("OP", source, "Full system restore requested", 1)
    elseif p.command == "reset_simulation" then
      s.breakers = copyDefaults(lib.devices.breakers)
      s.batteries = { battery400 = 100, pmc1 = 100, pmc2 = 100, pmc3 = 100 }
      s.telemetry = {}
      s.peripherals = {}
      s.tempOffset = 0
      s.mode = "normal"
      lib.state.write(actionPath, {})
      log("OP", source, "Simulation reset requested", 1)
    elseif p.command == "reset_breakers" then
      s.breakers = copyDefaults(lib.devices.breakers)
      log("OP", source, "Breakers reset to defaults", 1)
    elseif p.command == "reset_temperatures" then
      s.tempOffset = 0
      log("OP", source, "Temperature model reset", 1)
    elseif p.command == "reset_damage" then
      for _, item in pairs(s.telemetry) do
        item.destroyed = false
        item.glitch = nil
      end
      log("OP", source, "Damage state reset", 1)
    elseif p.command == "mode" and p.mode then
      s.mode = p.mode
      log("OP", source, "Display mode set to " .. tostring(p.mode), 1)
    elseif p.command == "display_context" and p.target and p.mode then
      s.displayContexts[tostring(p.target)] = tostring(p.mode)
      log("OP", source, "Display " .. tostring(p.target) .. " context -> " .. tostring(p.mode), 1)
    elseif p.command == "theme" then
      s.screenStyle = s.screenStyle or {}
      if p.textColor then s.screenStyle.textColor = p.textColor end
      if p.bgColor then s.screenStyle.bgColor = p.bgColor end
      if p.theme then s.screenStyle.theme = p.theme end
      log("OP", source, "Screen theme updated", 1)
    end
  end

  local function handle(pkt)
    if pkt.kind == "telemetry" then
      local p = pkt.payload or {}
      if p.name then
        p.lastSeen = os.epoch and os.epoch("utc") or os.clock()
        s.telemetry[p.name] = p
      end
    elseif pkt.kind == "update_status" then
      local p = pkt.payload or {}
      local key = tostring(p.device or pkt.source or pkt.id or "unknown")
      s.updateStatus = s.updateStatus or {}
      s.updateStatus[key] = {
        device = p.device or key,
        program = p.program,
        stage = p.stage,
        detail = p.detail,
        progress = p.progress,
        version = p.version or p.currentVersion,
        currentVersion = p.currentVersion or p.version,
        updateId = p.updateId,
        updateKind = p.updateKind,
        slot = p.slot,
        total = p.total,
        eta = p.eta,
        ts = p.ts,
        source = pkt.source,
        lastLocal = os.clock(),
      }
    elseif pkt.kind == "peripherals" then
      s.peripherals[pkt.source or tostring(pkt.id)] = pkt.payload or {}
    elseif pkt.kind == "command" then
      applyCommand(pkt)
    end
  end

  local function isFinalUpdateStage(stage)
    return stage == "done" or stage == "failed" or stage == "timeout" or stage == "rebooting"
  end

  local function pruneUpdateStatus()
    local now = os.clock()
    local any, allFinal = false, true
    for _, item in pairs(s.updateStatus or {}) do
      any = true
      if not isFinalUpdateStage(type(item) == "table" and item.stage or nil) then allFinal = false end
    end
    if not any then return end
    for key, item in pairs(s.updateStatus or {}) do
      local age = now - (tonumber(item.lastLocal) or now)
      if allFinal and age > 20 then
        s.updateStatus[key] = nil
      elseif (not allFinal) and age > 300 then
        item.stage = "timeout"
        item.detail = "supervisor timeout"
        item.progress = 100
        item.lastLocal = now
      end
    end
  end

  local function draw()
    lib.ui.clear(screen, colors.white, colors.black)
    lib.ui.center(screen, 1, "MCCR MAIN SUPERVISOR", colors.lightBlue)
    lib.ui.writeAt(screen, 1, 3, "Mode: " .. tostring(s.mode), colors.white)
    lib.ui.writeAt(screen, 1, 4, "Alert L" .. tostring(s.alert.level) .. " " .. tostring(s.alert.reason), lib.ui.statusColor(s.alert.level))
    lib.ui.writeAt(screen, 1, 6, string.format("AC 230V bus: %0.1f V", s.buses.ac230 and s.buses.ac230.voltage or 0), colors.green)
    lib.ui.writeAt(screen, 1, 7, string.format("AC 400V bus: %0.1f V", s.buses.ac400 and s.buses.ac400.voltage or 0), colors.green)
    lib.ui.writeAt(screen, 1, 8, string.format("12V bus: %0.1f V", s.buses.dc12 and s.buses.dc12.voltage or 0), colors.green)
    lib.ui.writeAt(screen, 1, 9, string.format("Load: %0.0f W", s.buses.load and s.buses.load.watts or 0), colors.white)
    lib.ui.writeAt(screen, 1, 10, string.format("Generation: %0.0f W", s.buses.generation and s.buses.generation.watts or 0), colors.white)
    lib.ui.writeAt(screen, 1, 11, string.format("1MV core flow: %0.0f RF/t", s.buses.mv1 and s.buses.mv1.flowRfPerTick or 0), colors.purple)
    lib.ui.writeAt(screen, 1, 12, string.format("400V battery: %0.1f%%", s.batteries.battery400), colors.yellow)
    lib.ui.writeAt(screen, 1, 13, string.format("PMC batteries: %0.0f%% / %0.0f%% / %0.0f%%", s.batteries.pmc1, s.batteries.pmc2, s.batteries.pmc3), colors.yellow)
    local nodeCount = 0
    for _ in pairs(s.telemetry or {}) do nodeCount = nodeCount + 1 end
    lib.ui.writeAt(screen, 1, 15, "Telemetry nodes: " .. tostring(nodeCount), colors.gray)
    lib.ui.writeAt(screen, 1, 16, "Cycle: " .. tostring(s.cycle), colors.gray)
  end

  local last = os.clock()
  while true do
    local now = os.clock()
    local dt = math.max(0.1, now - last)
    last = now
    s.cycle = (s.cycle or 0) + 1
    computeBuses(dt)

    while true do
      local _, pkt = lib.net.receive(0.01)
      if not pkt then break end
      handle(pkt)
    end
    pruneUpdateStatus()

    draw()
    lib.state.write(statePath, s)
    lib.net.broadcast(name, "snapshot", snapshot())
    sleep(1)
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
local run = load_role_main()

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
