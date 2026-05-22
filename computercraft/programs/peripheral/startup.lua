-- Dynamic MCCR startup for peripheral. Bundled dynamic program.
-- Concrete instance is read from /mccr_device.dat.
local MCCR_PROGRAM = "peripheral"
local MCCR_VERSION = "1.0.1"
local MCCR_ROLE = "peripheral"
local MCCR_DEFAULT_NAME = "peripheral1_draconic"
local MCCR_ALLOWED_NAMES = {
  "peripheral1_draconic",
  "peripheral2_mekanism",
  "peripheral3_ae2",
  "peripheral4_spare",
  "peripheral5_fake_load",
  "peripheral6_sound",
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

local function load_role_peripheral()
local function classify(name, ptype, methods)
  local hay = string.lower((name or "") .. " " .. (ptype or "") .. " " .. table.concat(methods or {}, " "))
  if hay:find("draconic") or hay:find("energycore") or hay:find("energy_core") then return "draconic_energy_core" end
  if hay:find("fission") then return "mekanism_fission_reactor" end
  if hay:find("fusion") then return "mekanism_fusion_reactor" end
  if hay:find("turbine") then return "mekanism_turbine" end
  if hay:find("resistive") or hay:find("heater") then return "mekanism_resistive_heater" end
  if hay:find("speaker") then return "speaker" end
  if hay:find("mekanism") then return "mekanism_device" end
  if hay:find("ae2") or hay:find("applied") or hay:find("mebridge") or hay:find("me_bridge") or hay:find("me bridge") or hay:find("crafting") then return "ae2_network" end
  if hay:find("monitor") then return "monitor" end
  if hay:find("redstone") then return "redstone_io" end
  return "unknown"
end

local function tryCall(obj, method)
  if not obj or type(obj[method]) ~= "function" then return nil end
  local ok, value = pcall(obj[method])
  if ok then return value end
  return nil
end

local function tryCallStatus(obj, method)
  if not obj or type(obj[method]) ~= "function" then return nil, "missing" end
  local ok, value, err = pcall(obj[method])
  if ok then return value, err end
  return nil, tostring(value or "call failed")
end

local function firstCallNumber(obj, attrs, names)
  for _, method in ipairs(names or {}) do
    local value = attrs and attrs[method] or nil
    if type(value) == "number" then return value end
    if type(value) == "string" and tonumber(value) then return tonumber(value) end
    value = tryCall(obj, method)
    if type(value) == "number" then return value end
    if type(value) == "string" and tonumber(value) then return tonumber(value) end
  end
  return nil
end

local function firstCallTable(obj, names, diagnostics)
  for _, method in ipairs(names or {}) do
    local value, err = tryCallStatus(obj, method)
    if type(value) == "table" then
      if diagnostics then diagnostics[method] = "ok" end
      return value
    end
    if diagnostics and err ~= "missing" then diagnostics[method] = tostring(err or "nil") end
  end
  return nil
end

local function tryTableCall(obj, method)
  local value = tryCall(obj, method)
  if type(value) == "table" then return value end
  return nil
end

local function compactValue(value, depth)
  local tv = type(value)
  if tv == "nil" or tv == "boolean" or tv == "number" or tv == "string" then return value end
  if tv ~= "table" then return tostring(value) end
  depth = depth or 0
  if depth > 2 then return "<table>" end
  local out = {}
  local n = 0
  for k, v in pairs(value) do
    n = n + 1
    if n > 24 then out.more = true; break end
    local tk = type(k)
    if tk == "string" or tk == "number" or tk == "boolean" then out[k] = compactValue(v, depth + 1) end
  end
  return out
end

local function isSafeAttributeMethod(method)
  local m = string.lower(tostring(method or ""))
  if m == "listitems" or m == "listfluid" or m == "listfluids" or m == "listgas" or m == "listcells"
    or m == "listcraftableitems" or m == "listcraftablefluid" or m == "listcraftablefluids" then
    return false
  end
  return m:find("^get")
    or m:find("^is")
    or m:find("^has")
    or m:find("^can")
end

local function callAllAttributes(obj, methods)
  local attrs = {}
  for _, method in ipairs(methods or {}) do
    if type(method) == "string" and isSafeAttributeMethod(method) and type(obj[method]) == "function" then
      local ok, value = pcall(obj[method])
      if ok and value ~= nil then attrs[method] = compactValue(value) end
    end
  end
  return attrs
end

local function firstNumber(attrs, names)
  for _, key in ipairs(names) do
    local value = attrs[key]
    if type(value) == "number" then return value end
    if type(value) == "string" then
      local n = tonumber(value)
      if n then return n end
    end
  end
  return nil
end

local function firstValue(attrs, names)
  for _, key in ipairs(names) do
    if attrs[key] ~= nil then return attrs[key] end
  end
  return nil
end

local function tableCount(t)
  local n = 0
  if type(t) ~= "table" then return 0 end
  for _ in pairs(t) do n = n + 1 end
  return n
end

local function tableAmount(t)
  local total = 0
  if type(t) ~= "table" then return 0 end
  for _, item in pairs(t) do
    if type(item) == "table" then
      total = total + (tonumber(item.amount) or tonumber(item.count) or tonumber(item.size) or 0)
    end
  end
  return total
end

local function summarizeCraftingCpus(cpus)
  local out = { count = 0, busy = 0, coprocessors = 0, storage = 0 }
  if type(cpus) ~= "table" then return out end
  for _, cpu in pairs(cpus) do
    if type(cpu) == "table" then
      out.count = out.count + 1
      if cpu.isBusy or cpu.busy then out.busy = out.busy + 1 end
      out.coprocessors = out.coprocessors + (tonumber(cpu.coProcessors) or tonumber(cpu.coprocessors) or 0)
      out.storage = out.storage + (tonumber(cpu.storage) or 0)
    end
  end
  return out
end

local function summarizeCells(cells)
  local out = { count = 0, item = 0, fluid = 0, bytes = 0, bytesPerType = 0 }
  if type(cells) ~= "table" then return out end
  for _, cell in pairs(cells) do
    if type(cell) == "table" then
      local cellType = string.lower(tostring(cell.cellType or cell.type or "item"))
      out.count = out.count + 1
      if cellType:find("fluid") then out.fluid = out.fluid + 1 else out.item = out.item + 1 end
      out.bytes = out.bytes + (tonumber(cell.totalBytes) or tonumber(cell.bytes) or 0)
      out.bytesPerType = out.bytesPerType + (tonumber(cell.bytesPerType) or 0)
    end
  end
  return out
end

local function formatEtaTicks(energy, capacity, netRfPerTick)
  energy, capacity, netRfPerTick = tonumber(energy), tonumber(capacity), tonumber(netRfPerTick)
  if not energy or not capacity or not netRfPerTick or math.abs(netRfPerTick) < 0.0001 then return nil, "stable" end
  local ticks
  local label
  if netRfPerTick > 0 then
    ticks = (capacity - energy) / netRfPerTick
    label = "full"
  else
    ticks = energy / math.abs(netRfPerTick)
    label = "empty"
  end
  local seconds = math.max(0, ticks / 20)
  if seconds < 60 then return string.format("%0.0fs", seconds), label end
  if seconds < 3600 then return string.format("%0.1fm", seconds / 60), label end
  if seconds < 86400 then return string.format("%0.1fh", seconds / 3600), label end
  return string.format("%0.1fd", seconds / 86400), label
end

local function normalizeDraconic(pname, ptype, attrs, previous, now)
  local energy = firstNumber(attrs, { "getEnergyStored", "getEnergy", "getStoredEnergy", "getExtendedStorage", "energy", "storedEnergy" })
  local capacity = firstNumber(attrs, { "getMaxEnergyStored", "getMaxEnergy", "getCapacity", "getExtendedCapacity", "capacity", "maxEnergy" })
  local input = firstNumber(attrs, { "getInputPerTick", "getInputRate", "getLastInput", "getInput", "input" })
  local output = firstNumber(attrs, { "getOutputPerTick", "getOutputRate", "getLastOutput", "getOutput", "output" })
  local transfer = firstNumber(attrs, { "getTransferPerTick", "getTransferRate", "getEnergyTransfer", "getTransfer", "transfer" })
  local computed = nil
  if previous and previous.energy and energy and previous.time and now > previous.time then
    computed = (energy - previous.energy) / math.max(0.05, (now - previous.time) * 20)
  end
  local net = nil
  if input or output then net = (input or 0) - (output or 0) end
  if not net then net = transfer or computed end
  if not input and net and net > 0 then input = net end
  if not output and net and net < 0 then output = math.abs(net) end
  local percent = (energy and capacity and capacity > 0) and math.max(0, math.min(100, energy / capacity * 100)) or nil
  local eta, etaMode = formatEtaTicks(energy, capacity, net)
  return {
    name = pname,
    type = ptype,
    kind = "draconic_energy_core",
    label = tostring(firstValue(attrs, { "getName", "getCoreName", "getOwnerName" }) or pname),
    tier = firstValue(attrs, { "getTier", "getCoreTier", "tier" }),
    status = tostring(firstValue(attrs, { "getStatus", "getCoreStatus", "isActive", "active" }) or "online"),
    energy = energy,
    maxEnergy = capacity,
    percent = percent,
    inputRfPerTick = input,
    outputRfPerTick = output,
    transferRfPerTick = transfer,
    computedRfPerTick = computed,
    netRfPerTick = net,
    eta = eta,
    etaMode = etaMode,
    voltage = 1000000,
    line = "1MV",
    attrs = attrs,
  }
end

local function normalizeAe2(pname, ptype, attrs, previous, now, obj)
  local diagnostics = { methods = 0, ok = 0, errors = {} }
  if peripheral and peripheral.getMethods then
    local okMethods, methods = pcall(peripheral.getMethods, pname)
    if okMethods and type(methods) == "table" then diagnostics.methods = #methods end
  end
  local function diagTable(names)
    local before = tableCount(diagnostics.errors)
    local result = firstCallTable(obj, names, diagnostics.errors)
    if result then diagnostics.ok = diagnostics.ok + 1 end
    if not result and tableCount(diagnostics.errors) == before then diagnostics.errors[names[1] or "list"] = "missing" end
    return result or {}
  end
  local items = diagTable({ "listItems" })
  local fluids = diagTable({ "listFluid", "listFluids" })
  local gases = diagTable({ "listGas" })
  local cells = summarizeCells(diagTable({ "listCells" }))
  local cpus = summarizeCraftingCpus(diagTable({ "getCraftingCPUs" }))
  local itemCount = tableAmount(items)
  local fluidAmount = tableAmount(fluids)
  local gasAmount = tableAmount(gases)
  local itemStorageUsed = firstCallNumber(obj, attrs, { "getUsedItemStorage", "usedItemStorage", "usedItems" })
  local itemStorageTotal = firstCallNumber(obj, attrs, { "getTotalItemStorage", "totalItemStorage", "totalItems" })
  local itemStorageAvailable = firstCallNumber(obj, attrs, { "getAvailableItemStorage", "availableItemStorage" })
  local fluidStorageUsed = firstCallNumber(obj, attrs, { "getUsedFluidStorage", "usedFluidStorage" })
  local fluidStorageTotal = firstCallNumber(obj, attrs, { "getTotalFluidStorage", "totalFluidStorage" })
  local fluidStorageAvailable = firstCallNumber(obj, attrs, { "getAvailableFluidStorage", "availableFluidStorage" })
  local energyStored = firstCallNumber(obj, attrs, { "getEnergyStorage", "getEnergyStored", "getEnergy" })
  local energyCapacity = firstCallNumber(obj, attrs, { "getMaxEnergyStorage", "getMaxEnergyStored", "getMaxEnergy" })
  local energyUsage = firstCallNumber(obj, attrs, { "getEnergyUsage", "energyUsage" })
  local scalarOk = 0
  for _, value in ipairs({ itemStorageUsed, itemStorageTotal, itemStorageAvailable, fluidStorageUsed, fluidStorageTotal, fluidStorageAvailable, energyStored, energyCapacity, energyUsage }) do
    if value ~= nil then scalarOk = scalarOk + 1 end
  end
  diagnostics.ok = diagnostics.ok + scalarOk
  local itemNet, itemStorageNet, fluidNet = nil, nil, nil
  if previous and previous.time and now > previous.time then
    local ticks = math.max(0.05, (now - previous.time) * 20)
    if previous.itemCount and itemCount then itemNet = (itemCount - previous.itemCount) / ticks end
    if previous.itemStorageUsed and itemStorageUsed then itemStorageNet = (itemStorageUsed - previous.itemStorageUsed) / ticks end
    if previous.fluidAmount and fluidAmount then fluidNet = (fluidAmount - previous.fluidAmount) / ticks end
  end
  local eta, etaMode = nil, "stable"
  if itemStorageUsed and itemStorageTotal and itemStorageNet and math.abs(itemStorageNet) > 0.0001 then
    eta, etaMode = formatEtaTicks(itemStorageUsed, itemStorageTotal, itemStorageNet)
  end
  return {
    name = pname,
    type = ptype,
    kind = "ae2_network",
    label = tostring(firstValue(attrs, { "getName", "getSystemName" }) or pname),
    status = "online",
    itemTypes = tableCount(items),
    itemCount = itemCount,
    itemStorageUsed = itemStorageUsed,
    itemStorageTotal = itemStorageTotal,
    itemStorageAvailable = itemStorageAvailable,
    itemStoragePercent = (itemStorageUsed and itemStorageTotal and itemStorageTotal > 0) and math.max(0, math.min(100, itemStorageUsed / itemStorageTotal * 100)) or nil,
    itemInputPerTick = itemNet and math.max(0, itemNet) or 0,
    itemOutputPerTick = itemNet and math.max(0, -itemNet) or 0,
    itemNetPerTick = itemNet or 0,
    itemStorageNetPerTick = itemStorageNet or 0,
    itemEta = eta,
    itemEtaMode = etaMode,
    fluidTypes = tableCount(fluids),
    fluidAmount = fluidAmount,
    fluidStorageUsed = fluidStorageUsed,
    fluidStorageTotal = fluidStorageTotal,
    fluidStorageAvailable = fluidStorageAvailable,
    fluidStoragePercent = (fluidStorageUsed and fluidStorageTotal and fluidStorageTotal > 0) and math.max(0, math.min(100, fluidStorageUsed / fluidStorageTotal * 100)) or nil,
    fluidNetPerTick = fluidNet or 0,
    gasTypes = tableCount(gases),
    gasAmount = gasAmount,
    energyStored = energyStored,
    energyCapacity = energyCapacity,
    energyUsage = energyUsage,
    energyPercent = (energyStored and energyCapacity and energyCapacity > 0) and math.max(0, math.min(100, energyStored / energyCapacity * 100)) or nil,
    craftingCpuCount = cpus.count,
    craftingCpuBusy = cpus.busy,
    craftingCoProcessors = cpus.coprocessors,
    craftingStorage = cpus.storage,
    craftableItems = tableCount(firstCallTable(obj, { "listCraftableItems" }, diagnostics.errors)),
    craftableFluids = tableCount(firstCallTable(obj, { "listCraftableFluid", "listCraftableFluids" }, diagnostics.errors)),
    cellCount = cells.count,
    itemCellCount = cells.item,
    fluidCellCount = cells.fluid,
    cellBytes = cells.bytes,
    cellBytesPerType = cells.bytesPerType,
    usedChannels = 1,
    diagnostics = diagnostics,
    attrs = attrs,
  }
end

local function compactNumber(value, suffix)
  value = tonumber(value)
  if not value then return "--" .. (suffix or "") end
  local units = { "", "k", "M", "G", "T" }
  local n, unit = math.abs(value), 1
  while n >= 1000 and unit < #units do n = n / 1000; unit = unit + 1 end
  local scaled = value / (1000 ^ (unit - 1))
  local text = unit == 1 and string.format("%0.0f", scaled) or string.format("%0.1f%s", scaled, units[unit])
  return text .. (suffix or "")
end

local function firstAe2Device(discovered)
  for pname, item in pairs(discovered or {}) do
    if type(item) == "table" and item.kind == "ae2_network" then
      return pname, item
    end
  end
  return nil, nil
end

local function callMethod(obj, method, ...)
  if not obj or type(obj[method]) ~= "function" then return false end
  local ok = pcall(obj[method], ...)
  return ok == true
end

local function run(name, lib)
  local statePath = "/mccr_state/" .. name .. ".dat"
  local s = lib.state.read(statePath, { discovered = {}, snapshot = {}, cycle = 0, channel = "fans" })
  s.draconicPrev = s.draconicPrev or {}
  s.draconicHistory = s.draconicHistory or {}
  s.ae2Prev = s.ae2Prev or {}
  local screen = lib.ui.target(lib.devices.spec(name))
  lib.ui.boot(screen, lib.devices.spec(name).label or name)
  mccrDrawConsoleStatus(name, "running")
  lib.net.open()

  local function scan()
    local found = {}
    local now = os.clock()
    for _, pname in ipairs(peripheral.getNames()) do
      local ptype = peripheral.getType(pname)
      if ptype ~= "modem" and ptype ~= "monitor" then
        local obj = peripheral.wrap(pname)
        local methods = peripheral.getMethods(pname) or {}
        table.sort(methods)
        local kind = classify(pname, ptype, methods)
        local attrs = callAllAttributes(obj, methods)
        if kind == "draconic_energy_core" then
          found[pname] = normalizeDraconic(pname, ptype, attrs, s.draconicPrev[pname], now)
          s.draconicPrev[pname] = { energy = found[pname].energy, time = now }
          s.draconicHistory[pname] = s.draconicHistory[pname] or {}
          local history = s.draconicHistory[pname]
          history[#history + 1] = {
            pct = found[pname].percent,
            flow = found[pname].netRfPerTick,
            energy = found[pname].energy,
            time = os.epoch and os.epoch("utc") or now,
          }
          while #history > 48 do table.remove(history, 1) end
          found[pname].history = history
        elseif kind == "ae2_network" then
          found[pname] = normalizeAe2(pname, ptype, attrs, s.ae2Prev[pname], now, obj)
          s.ae2Prev[pname] = {
            itemCount = found[pname].itemCount,
            itemStorageUsed = found[pname].itemStorageUsed,
            fluidAmount = found[pname].fluidAmount,
            time = now,
          }
        else
          found[pname] = {
          name = pname,
          type = ptype,
          kind = kind,
          methods = methods,
          energy = tryCall(obj, "getEnergy") or tryCall(obj, "getEnergyStored") or tryCall(obj, "getStoredEnergy"),
          maxEnergy = tryCall(obj, "getMaxEnergy") or tryCall(obj, "getMaxEnergyStored") or tryCall(obj, "getCapacity"),
          temp = tryCall(obj, "getTemperature") or tryCall(obj, "getTemp"),
          burnRate = tryCall(obj, "getBurnRate"),
          status = tryCall(obj, "getStatus"),
        }
        end
      end
    end
    s.discovered = found
  end

  local function applyFakeLoad(eval)
    if name ~= "peripheral5_fake_load" then return end
    local loadW = (((s.snapshot or {}).buses or {}).load or {}).watts or 0
    eval.loadWatts = loadW
    eval.loadMW = loadW / 1000000
    eval.heaterCommanded = false
    for pname, item in pairs(s.discovered or {}) do
      if item.kind == "mekanism_resistive_heater" then
        local obj = peripheral.wrap(pname)
        local target = math.max(0, math.floor(loadW))
        eval.heaterCommanded = callMethod(obj, "setHeat", target)
          or callMethod(obj, "setHeatRate", target)
          or callMethod(obj, "setEnergyUsage", target)
          or callMethod(obj, "setPower", target)
      end
    end
  end

  local function updateSound(eval)
    if name ~= "peripheral6_sound" then return end
    eval.channel = s.channel or "fans"
    local speaker = peripheral.find and peripheral.find("speaker") or nil
    if not speaker or eval.channel == "off" then return end
    if (s.cycle or 0) % 3 ~= 0 then return end
    local alert = (((s.snapshot or {}).alert or {}).level or 0)
    if eval.channel == "alarm" or alert >= 4 then
      callMethod(speaker, "playNote", "bell", 1, 12)
    elseif eval.channel == "warning" or alert >= 2 then
      callMethod(speaker, "playNote", "hat", 0.7, 8)
    elseif eval.channel == "ac" then
      callMethod(speaker, "playNote", "bass", 0.35, 3)
    else
      callMethod(speaker, "playNote", "bass", 0.25, 1)
    end
  end

  local function draw(eval)
    lib.ui.clear(screen, colors.white, colors.black)
    lib.ui.center(screen, 1, string.upper(name), colors.lightBlue)
    lib.ui.writeAt(screen, 1, 3, "Power: " .. eval.status .. " " .. string.format("%0.1fV %0.2fA", eval.voltage, eval.amps), lib.ui.statusColor(eval.severity))
    local y = 4
    local aeName, ae = firstAe2Device(s.discovered)
    if ae then
      local pct = tonumber(ae.itemStoragePercent or ae.energyPercent) or 0
      lib.ui.writeAt(screen, 1, y, "AE2: " .. tostring(aeName), colors.cyan)
      y = y + 1
      lib.ui.writeAt(screen, 1, y, string.format("Storage %0.1f%%", pct), colors.white)
      y = y + 1
      lib.ui.bar(screen, 1, y, select(1, lib.ui.size(screen)), pct, 100, colors.cyan)
      y = y + 1
      lib.ui.writeAt(screen, 1, y, "Items " .. compactNumber(ae.itemCount) .. " types " .. tostring(ae.itemTypes or 0), colors.green)
      y = y + 1
      lib.ui.writeAt(screen, 1, y, "Bytes " .. compactNumber(ae.itemStorageUsed) .. "/" .. compactNumber(ae.itemStorageTotal), colors.gray)
      y = y + 1
      lib.ui.writeAt(screen, 1, y, "Flow " .. compactNumber(ae.itemNetPerTick, "/t"), colors.purple)
      y = y + 1
      lib.ui.writeAt(screen, 1, y, "Energy " .. compactNumber(ae.energyStored) .. "/" .. compactNumber(ae.energyCapacity) .. " AE", colors.yellow)
      y = y + 1
      lib.ui.writeAt(screen, 1, y, "Usage " .. compactNumber(ae.energyUsage, " AE/t"), colors.yellow)
      y = y + 1
      lib.ui.writeAt(screen, 1, y, "CPU " .. tostring(ae.craftingCpuBusy or 0) .. "/" .. tostring(ae.craftingCpuCount or 0) .. " cells " .. tostring(ae.cellCount or 0), colors.purple)
      y = y + 1
      lib.ui.writeAt(screen, 1, y, "Fluids " .. tostring(ae.fluidTypes or 0) .. " " .. compactNumber(ae.fluidAmount, " mB"), colors.lightBlue)
      y = y + 1
      local diag = ae.diagnostics or {}
      lib.ui.writeAt(screen, 1, y, "Poll ok " .. tostring(diag.ok or 0) .. " methods " .. tostring(diag.methods or 0), (diag.ok or 0) > 0 and colors.green or colors.red)
      y = y + 1
      for method, err in pairs(diag.errors or {}) do
        if y > select(2, lib.ui.size(screen)) then break end
        lib.ui.writeAt(screen, 1, y, lib.ui.short(tostring(method) .. ": " .. tostring(err), select(1, lib.ui.size(screen))), colors.gray)
        y = y + 1
      end
      return
    end
    if name == "peripheral5_fake_load" then
      lib.ui.writeAt(screen, 1, y, string.format("Load signal: %0.2f MW", (eval.loadWatts or 0) / 1000000), colors.yellow)
      y = y + 1
    elseif name == "peripheral6_sound" then
      lib.ui.writeAt(screen, 1, y, "Sound channel: " .. tostring(eval.channel or s.channel or "fans"), colors.yellow)
      y = y + 1
    end
    lib.ui.writeAt(screen, 1, y, "Discovered peripherals:", colors.white)
    y = y + 1
    for pname, item in pairs(s.discovered or {}) do
      if y < 18 then
        lib.ui.writeAt(screen, 1, y, pname .. " -> " .. item.kind, colors.green)
        y = y + 1
      end
    end
    if y == 5 then lib.ui.writeAt(screen, 1, y, "No wired devices yet", colors.yellow) end
  end

  while true do
    s.cycle = (s.cycle or 0) + 1
    local spec = lib.devices.spec(name)
    s.snapshot = s.snapshot or {}
    local input = lib.power.inputFor(spec, s.snapshot)
    local eval = lib.power.evaluate(spec, input, s.eval)
    eval.name = name
    eval.label = spec.label
    eval.role = spec.role
    eval.program = MCCR_PROGRAM
    eval.firmwareVersion = MCCR_VERSION
    scan()
    applyFakeLoad(eval)
    updateSound(eval)
    s.eval = eval
    draw(eval)
    lib.net.broadcast(name, "telemetry", eval)
    lib.net.broadcast(name, "peripherals", s.discovered)
    lib.state.write(statePath, s)

    local endTime = os.clock() + 2
    repeat
      local _, pkt = lib.net.receive(math.max(0.01, endTime - os.clock()))
      if pkt and pkt.kind == "snapshot" then
        s.snapshot = pkt.payload or s.snapshot
      elseif pkt and pkt.kind == "command" and pkt.payload and pkt.payload.command == "restore" then
        s.eval = {}
      elseif pkt and pkt.kind == "command" and pkt.payload and pkt.payload.command == "sound_channel" then
        local p = pkt.payload
        if not p.target or p.target == name or p.target == "all" then
          s.channel = p.channel or s.channel
        end
      end
    until os.clock() >= endTime
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
local run = load_role_peripheral()

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
