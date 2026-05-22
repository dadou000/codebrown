-- Dynamic MCCR startup for admin_control_panel. Bundled dynamic program.
-- Concrete instance is read from /mccr_device.dat.
local MCCR_PROGRAM = "admin_control_panel"
local MCCR_VERSION = "1.0.1"
local MCCR_ROLE = "admin"
local MCCR_DEFAULT_NAME = "admin_control_panel"
local BOOTLOADER_PAYLOAD = [====[
--version1
-- MCCR mapped GitHub bootloader.
-- Install this file as /startup.lua on every ComputerCraft computer.

local BOOT_CONFIG = "/mccr_boot.dat"
local DEVICE_CONFIG = "/mccr_device.dat"
local STARTUP_PATH = "/startup.lua"
local STARTUP_TMP = "/startup.lua.tmp"
local STARTUP_BACKUP = "/startup.lua.bak"
local PROGRAM_PATH = "/mccr_program.lua"
local PROGRAM_TMP = "/mccr_program.lua.tmp"
local PROGRAM_BACKUP = "/mccr_program.lua.bak"
local CRASH_LOG = "/mccr_boot_crash.log"
local UPDATE_REQUEST = "/mccr_update_request.dat"
local REDNET_PROTOCOL = "mccr.v1"
local UPDATE_REQUEST_MAX_AGE_SECONDS = 120
local BOOT_STARTED_CLOCK = os.clock()
local BOOT_STARTED_EPOCH = nil
local updateMeta = {}
if os.epoch then
  local ok, value = pcall(os.epoch, "utc")
  if ok then BOOT_STARTED_EPOCH = value end
end

local SOURCE_BASE_URL = "https://raw.githubusercontent.com/dadou000/codebrown/main/computercraft"
local CDN_SOURCE_BASE_URL = "https://cdn.jsdelivr.net/gh/dadou000/codebrown@main/computercraft"
local API_SOURCE_BASE_URL = "https://api.github.com/repos/dadou000/codebrown/contents/computercraft"
local BOOTLOADER_URLS = {
  SOURCE_BASE_URL .. "/bootloader_startup.lua",
  CDN_SOURCE_BASE_URL .. "/bootloader_startup.lua",
  API_SOURCE_BASE_URL .. "/bootloader_startup.lua?ref=main",
}

local PROGRAM_URLS = {
  maincomputer = { SOURCE_BASE_URL .. "/programs/maincomputer/startup.lua", CDN_SOURCE_BASE_URL .. "/programs/maincomputer/startup.lua", API_SOURCE_BASE_URL .. "/programs/maincomputer/startup.lua?ref=main" },
  admin_control_panel = { SOURCE_BASE_URL .. "/programs/admin_control_panel/startup.lua", CDN_SOURCE_BASE_URL .. "/programs/admin_control_panel/startup.lua", API_SOURCE_BASE_URL .. "/programs/admin_control_panel/startup.lua?ref=main" },
  emergency_controls_screen = { SOURCE_BASE_URL .. "/programs/emergency_controls_screen/startup.lua", CDN_SOURCE_BASE_URL .. "/programs/emergency_controls_screen/startup.lua", API_SOURCE_BASE_URL .. "/programs/emergency_controls_screen/startup.lua?ref=main" },
  action_screen = { SOURCE_BASE_URL .. "/programs/action_screen/startup.lua", CDN_SOURCE_BASE_URL .. "/programs/action_screen/startup.lua", API_SOURCE_BASE_URL .. "/programs/action_screen/startup.lua?ref=main" },
  alert_level_screen = { SOURCE_BASE_URL .. "/programs/alert_level_screen/startup.lua", CDN_SOURCE_BASE_URL .. "/programs/alert_level_screen/startup.lua", API_SOURCE_BASE_URL .. "/programs/alert_level_screen/startup.lua?ref=main" },
  clock = { SOURCE_BASE_URL .. "/programs/clock/startup.lua", CDN_SOURCE_BASE_URL .. "/programs/clock/startup.lua", API_SOURCE_BASE_URL .. "/programs/clock/startup.lua?ref=main" },
  mon = { SOURCE_BASE_URL .. "/programs/mon/startup.lua", CDN_SOURCE_BASE_URL .. "/programs/mon/startup.lua", API_SOURCE_BASE_URL .. "/programs/mon/startup.lua?ref=main" },
  statsm = { SOURCE_BASE_URL .. "/programs/statsm/startup.lua", CDN_SOURCE_BASE_URL .. "/programs/statsm/startup.lua", API_SOURCE_BASE_URL .. "/programs/statsm/startup.lua?ref=main" },
  presentation_screen = { SOURCE_BASE_URL .. "/programs/presentation_screen/startup.lua", CDN_SOURCE_BASE_URL .. "/programs/presentation_screen/startup.lua", API_SOURCE_BASE_URL .. "/programs/presentation_screen/startup.lua?ref=main" },
  PMC = { SOURCE_BASE_URL .. "/programs/PMC/startup.lua", CDN_SOURCE_BASE_URL .. "/programs/PMC/startup.lua", API_SOURCE_BASE_URL .. "/programs/PMC/startup.lua?ref=main" },
  peripheral = { SOURCE_BASE_URL .. "/programs/peripheral/startup.lua", CDN_SOURCE_BASE_URL .. "/programs/peripheral/startup.lua", API_SOURCE_BASE_URL .. "/programs/peripheral/startup.lua?ref=main" },
}

local programTypes = {
  { key = "maincomputer", label = "Main Computer", instances = { { name = "maincomputer", label = "Main Computer" } } },
  { key = "admin_control_panel", label = "Admin Control Panel", instances = { { name = "admin_control_panel", label = "Admin Control Panel" } } },
  { key = "emergency_controls_screen", label = "Emergency Controls", instances = { { name = "emergency_controls_screen", label = "Emergency Controls" } } },
  { key = "action_screen", label = "Action Screen", instances = { { name = "action_screen", label = "Action Screen" } } },
  { key = "alert_level_screen", label = "Alert Level Screen", instances = { { name = "alert_level_screen", label = "Alert Level Screen" } } },
  { key = "clock", label = "Clock", instances = { { name = "clock", label = "Clock" } } },
  { key = "mon", label = "Monitor", instances = {
    { name = "mon1", label = "Monitor 1" },
    { name = "mon2", label = "Monitor 2" },
    { name = "mon3", label = "Monitor 3" },
    { name = "mon4", label = "Monitor 4" },
  } },
  { key = "statsm", label = "StatsM", instances = {
    { name = "statsm1", label = "StatsM 1" },
    { name = "statsm2", label = "StatsM 2" },
    { name = "statsm3", label = "StatsM 3" },
    { name = "statsm4", label = "StatsM 4" },
    { name = "statsm5", label = "StatsM 5" },
    { name = "statsm6", label = "StatsM 6" },
  } },
  { key = "presentation_screen", label = "Presentation Screen", instances = {
    { name = "presentation_screen_left", label = "Left" },
    { name = "main_presentation_screen", label = "Main" },
    { name = "presentation_screen_right", label = "Right" },
  } },
  { key = "PMC", label = "PMC", instances = {
    { name = "PMC1", label = "PMC 1" },
    { name = "PMC2", label = "PMC 2" },
    { name = "PMC3", label = "PMC 3" },
  } },
  { key = "peripheral", label = "Peripheral Computer", instances = {
    { name = "peripheral1_draconic", label = "Draconic" },
    { name = "peripheral2_mekanism", label = "Mekanism" },
    { name = "peripheral3_ae2", label = "AE2" },
    { name = "peripheral4_spare", label = "Spare" },
    { name = "peripheral5_fake_load", label = "Fake Load" },
    { name = "peripheral6_sound", label = "Sound Device" },
  } },
}

function clear()
  term.setBackgroundColor(colors.black)
  term.setTextColor(colors.white)
  term.clear()
  term.setCursorPos(1, 1)
end

function readTable(path, default)
  if not fs.exists(path) then return default end
  local h = fs.open(path, "r")
  if not h then return default end
  local text = h.readAll()
  h.close()
  local ok, value = pcall(textutils.unserialize, text)
  if ok and type(value) == "table" then return value end
  return default
end

function writeTable(path, value)
  local h = fs.open(path, "w")
  if not h then return false end
  local ok, text = pcall(textutils.serialize, value)
  if not ok then
    h.close()
    return false
  end
  h.write(text)
  h.close()
  return true
end

function appendCrash(text)
  local h = fs.open(CRASH_LOG, "a")
  if h then
    h.writeLine("[" .. tostring(os.epoch and os.epoch("utc") or os.clock()) .. "] " .. tostring(text))
    h.close()
  end
end

function openModems()
  if not peripheral or not rednet then return end
  for _, side in ipairs(peripheral.getNames()) do
    if peripheral.getType(side) == "modem" and not rednet.isOpen(side) then
      rednet.open(side)
    end
  end
end

function broadcastUpdateStatus(program, instance, stage, detail, progress, extra)
  if not rednet then return end
  openModems()
  extra = extra or {}
  local pkt = {
    system = "mccr",
    version = 1,
    source = instance and instance.name or "bootloader",
    id = os.getComputerID and os.getComputerID() or 0,
    kind = "update_status",
    payload = {
      program = program and program.key or nil,
      device = instance and instance.name or nil,
      currentVersion = programVersion(),
      updateId = extra.updateId or updateMeta.updateId,
      updateKind = extra.updateKind or updateMeta.updateKind,
      slot = extra.slot or updateMeta.slot,
      total = extra.total or updateMeta.total,
      scheduledDelay = extra.scheduledDelay or updateMeta.scheduledDelay,
      eta = extra.eta,
      stage = stage,
      detail = detail,
      progress = progress,
      ts = os.epoch and os.epoch("utc") or os.clock(),
    },
  }
  local ok = pcall(rednet.broadcast, pkt, REDNET_PROTOCOL)
  if not ok then appendCrash("update_status broadcast failed: " .. tostring(stage)) end
end

function attachedDisplays()
  local out = {}
  if peripheral then
    for _, side in ipairs(peripheral.getNames()) do
      if peripheral.getType(side) == "monitor" then
        local mon = peripheral.wrap(side)
        if mon then out[#out + 1] = mon end
      end
    end
  end
  return out
end

function displaySize(t)
  local ok, w, h = pcall(t.getSize)
  if ok then return w, h end
  return 51, 19
end

function writeCenter(t, y, text, fg, bg)
  local w, h = displaySize(t)
  if y < 1 or y > h then return end
  text = tostring(text or "")
  if #text > w then text = text:sub(1, w) end
  pcall(t.setBackgroundColor, bg or colors.black)
  pcall(t.setTextColor, fg or colors.white)
  pcall(t.setCursorPos, math.max(1, math.floor((w - #text) / 2) + 1), y)
  pcall(t.write, text)
end

function clearDisplay(t, fg, bg)
  pcall(t.setBackgroundColor, bg or colors.black)
  pcall(t.setTextColor, fg or colors.white)
  pcall(t.clear)
end

function drawBootCountdown(seconds, program, instance)
  seconds = math.max(0, math.floor(tonumber(seconds) or 0))
  for remaining = seconds, 1, -1 do
    for _, t in ipairs(attachedDisplays()) do
      clearDisplay(t, colors.white, colors.blue)
      local _, h = displaySize(t)
      local mid = math.max(2, math.floor(h / 2) - 1)
      writeCenter(t, mid, "BOOTLOADER UPDATE", colors.white, colors.blue)
      writeCenter(t, mid + 2, "RESTART IN " .. tostring(remaining) .. "s", colors.white, colors.blue)
      writeCenter(t, mid + 4, tostring(instance and instance.name or "device"), colors.lightBlue, colors.blue)
    end
    broadcastUpdateStatus(program, instance, "countdown", tostring(remaining) .. "s", 5, { eta = remaining })
    sleep(1)
  end
end

function programVersion(path)
  path = path or PROGRAM_PATH
  if not fs.exists(path) then return "not installed" end
  local h = fs.open(path, "r")
  if not h then return "unknown" end
  local text = h.readAll()
  h.close()
  local version = text:match('local%s+MCCR_VERSION%s*=%s*"([^"]+)"')
  return version or "unknown"
end

function bootloaderVersion(path)
  path = path or STARTUP_PATH
  if not fs.exists(path) then return "missing" end
  local h = fs.open(path, "r")
  if not h then return "unknown" end
  local text = h.readAll()
  h.close()
  return text:match("%-%-version([%w%._%-]+)") or "unknown"
end

function drawConsoleStatus(program, instance, stage, detail)
  local t = term.native and term.native() or term.current()
  if not t then return end
  pcall(t.setBackgroundColor, colors.black)
  pcall(t.setTextColor, colors.white)
  pcall(t.clear)
  pcall(t.setCursorPos, 1, 1)
  pcall(t.setTextColor, colors.lightBlue)
  pcall(t.write, "MCCR COMPUTER")
  pcall(t.setCursorPos, 1, 3)
  pcall(t.setTextColor, colors.white)
  pcall(t.write, "Device: " .. tostring(instance and instance.name or "unknown"))
  pcall(t.setCursorPos, 1, 4)
  pcall(t.write, "Program: " .. tostring(program and program.key or "unknown"))
  pcall(t.setCursorPos, 1, 5)
  pcall(t.write, "Firmware: v" .. tostring(programVersion()))
  pcall(t.setCursorPos, 1, 6)
  pcall(t.write, "Bootloader: v" .. tostring(bootloaderVersion()))
  pcall(t.setCursorPos, 1, 8)
  pcall(t.setTextColor, colors.gray)
  pcall(t.write, "State: " .. tostring(stage or "running"))
  if detail then
    pcall(t.setCursorPos, 1, 9)
    pcall(t.write, tostring(detail))
  end
end

function drawBootUpdate(stage, detail, program, instance)
  drawConsoleStatus(program, instance, tostring(stage or "update"):lower(), detail)
  local headline = tostring(stage or "UPDATE")
  if headline == "FIRMWARE" then headline = "FIRMWARE UPDATE"
  elseif headline == "BOOTLOADER" then headline = "BOOTLOADER UPDATE"
  else headline = headline .. " UPDATE" end
  local sub = tostring(detail or "")
  if program and instance then
    sub = tostring(program.key) .. " " .. tostring(instance.name) .. " v" .. programVersion() .. "  " .. sub
  end
  for _, t in ipairs(attachedDisplays()) do
    clearDisplay(t, colors.white, colors.blue)
    local _, h = displaySize(t)
    local mid = math.max(2, math.floor(h / 2) - 1)
    writeCenter(t, mid, headline, colors.white, colors.blue)
    writeCenter(t, mid + 2, sub, colors.lightBlue, colors.blue)
  end
end

function typeForKey(key)
  for _, item in ipairs(programTypes) do
    if item.key == key then return item end
  end
  return nil
end

function typeForDevice(device)
  for _, item in ipairs(programTypes) do
    for _, inst in ipairs(item.instances) do
      if inst.name == device then return item, inst end
    end
  end
  return nil, nil
end

function labelDevice()
  if not os.getComputerLabel then return nil end
  local label = os.getComputerLabel()
  if not label then return nil end
  local exactType = typeForKey(label)
  if exactType and #exactType.instances == 1 then return exactType, exactType.instances[1] end
  return typeForDevice(label)
end

function drawMenu(title, subtitle, items, selected, top)
  clear()
  local w, h = term.getSize()
  term.setTextColor(colors.lightBlue)
  print(title)
  term.setTextColor(colors.white)
  print(subtitle)
  print("")

  local rows = h - 4
  for line = 1, rows do
    local i = top + line - 1
    local item = items[i]
    if not item then break end

    if i == selected then
      term.setBackgroundColor(colors.blue)
      term.setTextColor(colors.white)
    else
      term.setBackgroundColor(colors.black)
      term.setTextColor(colors.gray)
    end

    local text = string.format("%2d  %-24s %s", i, item.name or item.key, item.label or "")
    term.setCursorPos(1, line + 3)
    term.write(text:sub(1, w))
    term.setBackgroundColor(colors.black)
  end
end

function chooseFromMenu(title, subtitle, items)
  local selected, top = 1, 1
  while true do
    local _, h = term.getSize()
    local rows = h - 4
    if selected < top then top = selected end
    if selected >= top + rows then top = selected - rows + 1 end
    drawMenu(title, subtitle, items, selected, top)

    local ev = { os.pullEvent() }
    if ev[1] == "key" then
      if ev[2] == keys.up then
        selected = math.max(1, selected - 1)
      elseif ev[2] == keys.down then
        selected = math.min(#items, selected + 1)
      elseif ev[2] == keys.pageUp then
        selected = math.max(1, selected - rows)
      elseif ev[2] == keys.pageDown then
        selected = math.min(#items, selected + rows)
      elseif ev[2] == keys.enter then
        return items[selected]
      end
    elseif ev[1] == "char" then
      local n = tonumber(ev[2])
      if n then
        term.setCursorPos(1, h)
        term.clearLine()
        write("Number: " .. ev[2])
        local rest = read()
        n = tonumber(ev[2] .. (rest or ""))
        if n and items[n] then return items[n] end
      end
    elseif ev[1] == "mouse_click" or ev[1] == "monitor_touch" then
      local row = ev[4] - 3
      local n = top + row - 1
      if items[n] then return items[n] end
    end
  end
end

function chooseMapping(cfg)
  local configuredType = cfg.program and typeForKey(cfg.program)
  local configuredInstance = nil
  if configuredType and cfg.device then
    local deviceType, deviceInstance = typeForDevice(cfg.device)
    if deviceType == configuredType then configuredInstance = deviceInstance end
  end
  if configuredType and configuredInstance then
    return configuredType, configuredInstance
  end

  local labelType, labelInstance = labelDevice()
  if labelType and labelInstance then
    cfg.program = labelType.key
    cfg.device = labelInstance.name
    writeTable(BOOT_CONFIG, cfg)
    writeTable(DEVICE_CONFIG, { name = cfg.device, program = cfg.program })
    return labelType, labelInstance
  end

  local program = chooseFromMenu("MCCR program setup", "Touch/click a program type.", programTypes)
  local instance = program.instances[1]
  if #program.instances > 1 then
    instance = chooseFromMenu("MCCR instance setup", "Touch/click the physical instance.", program.instances)
  end

  cfg.program = program.key
  cfg.device = instance.name
  writeTable(BOOT_CONFIG, cfg)
  writeTable(DEVICE_CONFIG, { name = cfg.device, program = cfg.program })
  if os.setComputerLabel then pcall(os.setComputerLabel, cfg.device) end
  return program, instance
end

function urlsFor(program)
  local urls = PROGRAM_URLS[program.key]
  if type(urls) == "string" then urls = { urls } end
  if type(urls) == "table" and #urls > 0 then return urls end
  error("missing GitHub raw URL in bootloader PROGRAM_URLS for " .. program.key, 0)
end

function firstBytes(text)
  text = tostring(text or ""):gsub("[\r\n\t]+", " ")
  if #text > 96 then return text:sub(1, 96) .. "..." end
  return text
end

function looksLikeHtml(text)
  text = tostring(text or ""):gsub("^%s+", ""):lower()
  return text:sub(1, 9) == "<!doctype" or text:sub(1, 5) == "<html"
end

function verifyProgram(program, instance, path)
  path = path or PROGRAM_PATH
  local h = fs.open(path, "r")
  if not h then error("downloaded program could not be opened", 0) end
  local text = h.readAll()
  h.close()

  if looksLikeHtml(text) then
    fs.delete(path)
    error("downloaded a web page, not raw Lua: " .. firstBytes(text), 0)
  end

  local expectedProgram = 'local MCCR_PROGRAM = "' .. program.key .. '"'
  if not text:find(expectedProgram, 1, true) then
    fs.delete(path)
    error("download does not match selected program: expected " .. program.key, 0)
  end

  if not text:find('"' .. instance.name .. '"', 1, true) then
    fs.delete(path)
    error("downloaded program does not include instance " .. instance.name, 0)
  end

  if not text:find("local lib = {", 1, true) then
    fs.delete(path)
    error("downloaded program is incomplete or not an MCCR startup", 0)
  end
end

function verifyBootloader(path)
  path = path or STARTUP_TMP
  local h = fs.open(path, "r")
  if not h then error("downloaded bootloader could not be opened", 0) end
  local text = h.readAll()
  h.close()

  if looksLikeHtml(text) then
    fs.delete(path)
    error("downloaded a web page, not raw Lua: " .. firstBytes(text), 0)
  end

  if not text:find("MCCR mapped GitHub bootloader", 1, true) then
    fs.delete(path)
    error("downloaded file is not the MCCR bootloader", 0)
  end

  if not text:find("local PROGRAM_URLS = {", 1, true) or not text:find("function chooseMapping", 1, true) then
    fs.delete(path)
    error("downloaded bootloader is incomplete", 0)
  end

  local loader = loadstring or load
  if type(loader) == "function" then
    local fn, syntaxErr = loader(text, "@startup.lua")
    if not fn then
      fs.delete(path)
      error("downloaded bootloader syntax error: " .. tostring(syntaxErr), 0)
    end
  end
end

function replaceProgram()
  if fs.exists(PROGRAM_TMP) then
    if fs.exists(PROGRAM_BACKUP) then fs.delete(PROGRAM_BACKUP) end
    if fs.exists(PROGRAM_PATH) then fs.move(PROGRAM_PATH, PROGRAM_BACKUP) end
    local ok, err = pcall(fs.move, PROGRAM_TMP, PROGRAM_PATH)
    if not ok then
      if fs.exists(PROGRAM_BACKUP) and not fs.exists(PROGRAM_PATH) then fs.move(PROGRAM_BACKUP, PROGRAM_PATH) end
      error("program replace failed: " .. tostring(err), 0)
    end
  end
end

function restoreProgramBackup(reason)
  if not fs.exists(PROGRAM_BACKUP) then return false end
  if fs.exists(PROGRAM_PATH) then fs.delete(PROGRAM_PATH) end
  fs.move(PROGRAM_BACKUP, PROGRAM_PATH)
  appendCrash("rolled back program: " .. tostring(reason or "instant crash"))
  return true
end

function downloadUrlTo(url, path)
  if fs.exists(path) then fs.delete(path) end
  local ok = false
  if http and http.get then
    local headers = { ["User-Agent"] = "MCCR-ComputerCraft/1.0", ["Accept"] = "application/vnd.github.raw, text/plain, application/octet-stream" }
    local httpOk, response, err, failResponse = pcall(http.get, { url = url, headers = headers, redirect = true, timeout = 20 })
    if (not httpOk or not response) and http and http.get then
      httpOk, response, err, failResponse = pcall(http.get, url, headers)
    end
    if not response and failResponse then response = failResponse end
    if not httpOk then response = nil end
    if response then
      local code, message = 200, "OK"
      if type(response.getResponseCode) == "function" then
        local codeOk, c, m = pcall(response.getResponseCode)
        if codeOk and c then code, message = c, m or message end
      end
      if code < 200 or code >= 300 then
        pcall(response.close)
        error("download failed: HTTP " .. tostring(code) .. " " .. tostring(message), 0)
      else
        local h = fs.open(path, "w")
        if h then
          local readOk, body = pcall(response.readAll)
          if readOk then h.write(body or "") end
          h.close()
          ok = readOk
        end
        pcall(response.close)
      end
    elseif err then
      error("download failed: " .. tostring(err), 0)
    end
  end
  if not ok or not fs.exists(path) then
    error("download failed; check GitHub raw URL and HTTP access", 0)
  end
end

function downloadFirstUrlTo(urls, path)
  local lastErr = nil
  for _, url in ipairs(urls or {}) do
    local ok, err = pcall(downloadUrlTo, url, path)
    if ok then return url end
    lastErr = err
    if fs.exists(path) then fs.delete(path) end
  end
  error(lastErr or "all download sources failed", 0)
end

function writeText(path, text)
  if fs.exists(path) then fs.delete(path) end
  local h = fs.open(path, "w")
  if not h then error("could not write " .. tostring(path), 0) end
  h.write(text or "")
  h.close()
end

function requestBootloaderPayload(url, path, program, instance)
  if not rednet then return false, "rednet unavailable" end
  openModems()
  local requestId = tostring(os.getComputerID and os.getComputerID() or 0) .. "-" .. tostring(math.floor(os.clock() * 1000))
  local req = {
    system = "mccr",
    version = 1,
    source = instance and instance.name or "bootloader",
    id = os.getComputerID and os.getComputerID() or 0,
    kind = "payload_request",
    payload = {
      requestId = requestId,
      target = instance and instance.name or nil,
      kind = "bootloader",
      updateId = updateMeta.updateId,
      url = url,
    },
    ts = os.epoch and os.epoch("utc") or os.clock(),
  }
  pcall(rednet.broadcast, req, REDNET_PROTOCOL)

  local chunks = {}
  local total = nil
  local deadline = os.clock() + 30
  while os.clock() < deadline do
    local timeout = math.max(0.05, deadline - os.clock())
    local _, pkt = rednet.receive(REDNET_PROTOCOL, timeout)
    if type(pkt) == "table" and pkt.system == "mccr" and pkt.kind == "payload_chunk" then
      local p = pkt.payload or {}
      if p.requestId == requestId and p.kind == "bootloader" then
        if p.error then return false, tostring(p.error) end
        local index = tonumber(p.index)
        total = tonumber(p.total) or total
        if index and p.data then chunks[index] = tostring(p.data) end
        if total and total > 0 then
          local complete = true
          for i = 1, total do
            if not chunks[i] then complete = false; break end
          end
          if complete then
            local parts = {}
            for i = 1, total do parts[i] = chunks[i] end
            writeText(path, table.concat(parts))
            verifyBootloader(path)
            return true
          end
        end
      end
    end
  end
  return false, "no LAN bootloader payload"
end

function downloadProgramOnce(program, instance, attempt)
  local urls = urlsFor(program)
  if fs.exists(PROGRAM_TMP) then fs.delete(PROGRAM_TMP) end
  clear()
  drawBootUpdate("FIRMWARE", "download attempt " .. tostring(attempt or 1), program, instance)
  broadcastUpdateStatus(program, instance, "downloading", "attempt " .. tostring(attempt or 1), 25)
  print("Downloading MCCR " .. program.key .. " program...")
  print("Instance: " .. instance.name)
  print("Sources: " .. tostring(#urls))

  local usedUrl = downloadFirstUrlTo(urls, PROGRAM_TMP)
  print("Used: " .. tostring(usedUrl))
  drawBootUpdate("FIRMWARE", "verifying", program, instance)
  verifyProgram(program, instance, PROGRAM_TMP)
  broadcastUpdateStatus(program, instance, "verifying", "ok", 85)
  drawBootUpdate("FIRMWARE", "installing", program, instance)
  replaceProgram()
  broadcastUpdateStatus(program, instance, "done", "installed", 100)
end

function bootloaderUrl()
  if type(BOOTLOADER_URLS) == "table" and #BOOTLOADER_URLS > 0 then return BOOTLOADER_URLS[1] end
  error("missing BOOTLOADER_URLS in /startup.lua", 0)
end

function bootloaderUrls()
  if type(BOOTLOADER_URLS) == "table" and #BOOTLOADER_URLS > 0 then return BOOTLOADER_URLS end
  error("missing BOOTLOADER_URLS in /startup.lua", 0)
end

function replaceBootloader()
  if fs.exists(STARTUP_TMP) then
    if fs.exists(STARTUP_BACKUP) then fs.delete(STARTUP_BACKUP) end
    if fs.exists(STARTUP_PATH) then fs.move(STARTUP_PATH, STARTUP_BACKUP) end
    local ok, err = pcall(fs.move, STARTUP_TMP, STARTUP_PATH)
    if not ok then
      if fs.exists(STARTUP_BACKUP) and not fs.exists(STARTUP_PATH) then fs.move(STARTUP_BACKUP, STARTUP_PATH) end
      error("bootloader replace failed: " .. tostring(err), 0)
    end
  end
end

function downloadBootloaderOnce(program, instance, attempt)
  local urls = bootloaderUrls()
  local url = urls[1]
  clear()
  drawBootUpdate("BOOTLOADER", "starting", program, instance)
  broadcastUpdateStatus(program, instance, "starting", "bootloader attempt " .. tostring(attempt or 1), 10)
  print("Downloading MCCR bootloader...")
  print("Instance: " .. instance.name)
  print("Source: " .. tostring(url))

  if attempt == 1 then
    drawBootUpdate("BOOTLOADER", "lan_cache", program, instance)
    broadcastUpdateStatus(program, instance, "lan_cache", "requesting LAN cache", 28)
    print("Trying LAN bootloader cache first...")
    local lanOk, lanErr = requestBootloaderPayload(url, STARTUP_TMP, program, instance)
    if lanOk then
      drawBootUpdate("BOOTLOADER", "verifying LAN payload", program, instance)
      broadcastUpdateStatus(program, instance, "verifying", "LAN payload", 80)
    else
      drawBootUpdate("BOOTLOADER", "downloading", program, instance)
      broadcastUpdateStatus(program, instance, "downloading", "fallback GitHub", 35)
      print("LAN cache unavailable: " .. tostring(lanErr))
      print("Falling back to GitHub...")
      local usedUrl = downloadFirstUrlTo(urls, STARTUP_TMP)
      print("Used: " .. tostring(usedUrl))
      broadcastUpdateStatus(program, instance, "downloading", "GitHub source", 80)
    end
  else
    drawBootUpdate("BOOTLOADER", "downloading", program, instance)
    local usedUrl = downloadFirstUrlTo(urls, STARTUP_TMP)
    print("Used: " .. tostring(usedUrl))
    broadcastUpdateStatus(program, instance, "downloading", "GitHub source", 80)
  end
  drawBootUpdate("BOOTLOADER", "verifying", program, instance)
  verifyBootloader(STARTUP_TMP)
  broadcastUpdateStatus(program, instance, "verifying", "verified", 85)
  drawBootUpdate("BOOTLOADER", "installing", program, instance)
  broadcastUpdateStatus(program, instance, "installing", "bootloader", 92)
  replaceBootloader()
  broadcastUpdateStatus(program, instance, "done", "bootloader installed", 100)
end

function retryDelay(attempt)
  local base = ({ 8, 20, 45, 90 })[attempt] or 120
  local id = os.getComputerID and os.getComputerID() or 0
  local jitter = (id * 17 + attempt * 13) % 19
  return base + jitter
end

function downloadProgram(program, instance)
  local lastErr = nil
  for attempt = 1, 4 do
    local ok, err = pcall(downloadProgramOnce, program, instance, attempt)
    if ok then return true end
    lastErr = err
    clear()
    term.setTextColor(colors.red)
    print("Download attempt " .. tostring(attempt) .. " failed")
    print(tostring(err))
    term.setTextColor(colors.white)
    if attempt < 4 then
      local wait = retryDelay(attempt)
      broadcastUpdateStatus(program, instance, "retrying", tostring(wait) .. "s", attempt * 20)
      print("")
      print("Retrying in " .. tostring(wait) .. " seconds.")
      sleep(wait)
    end
  end

  if fs.exists(PROGRAM_PATH) then
    broadcastUpdateStatus(program, instance, "failed", "kept old program", 100)
    term.setTextColor(colors.yellow)
    print("")
    print("Keeping existing installed program.")
    term.setTextColor(colors.white)
    sleep(3)
    return false
  end

  broadcastUpdateStatus(program, instance, "failed", tostring(lastErr or "download failed"), 100)
  error(lastErr or "download failed; no installed program is available", 0)
end

function downloadBootloader(program, instance)
  local lastErr = nil
  for attempt = 1, 4 do
    local ok, err = pcall(downloadBootloaderOnce, program, instance, attempt)
    if ok then return true end
    lastErr = err
    clear()
    term.setTextColor(colors.red)
    print("Bootloader attempt " .. tostring(attempt) .. " failed")
    print(tostring(err))
    term.setTextColor(colors.white)
    if attempt < 4 then
      local wait = retryDelay(attempt)
      broadcastUpdateStatus(program, instance, "retrying", "boot " .. tostring(wait) .. "s", attempt * 20)
      print("")
      print("Retrying in " .. tostring(wait) .. " seconds.")
      sleep(wait)
    end
  end

  broadcastUpdateStatus(program, instance, "failed", "bootloader kept old", 100)
  error(lastErr or "bootloader update failed", 0)
end

function ensureProgram(cfg, program, instance)
  if not fs.exists(PROGRAM_PATH) or cfg.forceUpdate then
    cfg.forceUpdate = nil
    writeTable(BOOT_CONFIG, cfg)
    downloadProgram(program, instance)
  else
    local ok = pcall(verifyProgram, program, instance)
    if not ok then downloadProgram(program, instance) end
  end
end

function updateStaggerSeconds(source, instance, payload)
  payload = payload or {}
  local explicit = tonumber(payload.delay or payload.scheduleDelay or payload.stagger)
  if explicit then return math.max(0, math.min(600, explicit)) end
  return 0
end

function isLocalUpdateEscape(err)
  local text = tostring(err)
  return text == "local update requested" or text == "local bootloader update requested"
end

function runProgram(program, instance)
  local started = os.clock()
  local fn, loadErr = loadfile(PROGRAM_PATH)
  if not fn then error(loadErr, 0) end
  local ok, err = pcall(fn)
  if not ok then
    if isLocalUpdateEscape(err) then return nil, err end
    if os.clock() - started < 10 and restoreProgramBackup("instant crash: " .. tostring(err)) then
      broadcastUpdateStatus(program, instance, "failed", "rolled back after instant crash", 100)
      return
    end
    error(err, 0)
  end
  return err
end

function ensureUpdatePacketMetadata(source, payload)
  payload = payload or {}
  if not payload.updateId then
    local id = os.getComputerID and os.getComputerID() or 0
    payload.updateId = tostring(source or "local") .. "-" .. tostring(id) .. "-" .. tostring(math.floor(os.clock() * 1000))
  end
  payload.slot = tonumber(payload.slot) or 1
  payload.total = tonumber(payload.total) or 1
  return payload
end

function waitForScheduledUpdate(delay, program, instance, kind)
  delay = math.max(0, math.floor(tonumber(delay) or 0))
  broadcastUpdateStatus(program, instance, "scheduled", "T-" .. tostring(delay) .. "s", 0, { eta = delay })
  if delay <= 0 then return end
  for remaining = delay, 1, -1 do
    if kind == "bootloader" then
      for _, t in ipairs(attachedDisplays()) do
        clearDisplay(t, colors.white, colors.blue)
        local _, h = displaySize(t)
        local mid = math.max(2, math.floor(h / 2) - 1)
        writeCenter(t, mid, "BOOTLOADER UPDATE", colors.white, colors.blue)
        writeCenter(t, mid + 2, "RESTART IN " .. tostring(remaining) .. "s", colors.white, colors.blue)
        writeCenter(t, mid + 4, tostring(instance and instance.name or "device"), colors.lightBlue, colors.blue)
      end
    end
    broadcastUpdateStatus(program, instance, "scheduled", "T-" .. tostring(remaining) .. "s", 0, { eta = remaining })
    sleep(1)
  end
end

function currentEpoch()
  if not os.epoch then return nil end
  local ok, value = pcall(os.epoch, "utc")
  if ok then return value end
  return nil
end

function validUpdateCommand(command)
  return command == "update_program"
    or command == "update"
    or command == "update_bootloader"
    or command == "bootloader_update"
end

function isUpdatePacket(pkt, program, instance)
  if type(pkt) ~= "table" or pkt.system ~= "mccr" or pkt.kind ~= "command" then return false end
  local payload = pkt.payload or {}
  local command = payload.command
  if not validUpdateCommand(command) then return false end
  if payload.confirm ~= true then return false end

  local target = payload.target or payload.device
  local targetProgram = payload.program
  local exclude = payload.exclude or payload.excludeDevice
  if type(exclude) == "string" and (exclude == instance.name or exclude == program.key) then return false end
  if type(exclude) == "table" then
    for _, item in ipairs(exclude) do
      if item == instance.name or item == program.key then return false end
    end
  end
  if target and target ~= "all" and target ~= instance.name then return false end
  if targetProgram and targetProgram ~= "all" and targetProgram ~= program.key then return false end
  if not payload.updateId or not payload.slot or not payload.total then return false end
  if command == "update_bootloader" or command == "bootloader_update" then return "bootloader" end
  return "program"
end

function updateWatcher(program, instance)
  openModems()
  local typed = ""
  while true do
    local ev = { os.pullEvent() }
    if ev[1] == "rednet_message" then
      local pkt = ev[3]
      local updateType = isUpdatePacket(pkt, program, instance)
      if updateType then
        return "remote", updateType, pkt.payload or {}
      end
    elseif ev[1] == "char" then
      typed = (typed .. tostring(ev[2] or "")):sub(-24)
    elseif ev[1] == "key" then
      if ev[2] == keys.enter then
        local command = string.lower(typed:gsub("^%s+", ""):gsub("%s+$", ""))
        if command == "update" then
          return "local", "program", {}
        elseif command == "update bootloader" or command == "bootloader update" then
          return "local", "bootloader", {}
        end
        typed = ""
      elseif ev[2] == keys.backspace then
        typed = typed:sub(1, math.max(0, #typed - 1))
      end
    end
  end
end

function consumeUpdateRequest()
  if not fs.exists(UPDATE_REQUEST) then return nil end
  local request = readTable(UPDATE_REQUEST, {})
  fs.delete(UPDATE_REQUEST)
  if type(request) ~= "table" or not validUpdateCommand(request.command) then return nil end

  local nowEpoch = currentEpoch()
  if type(request.epoch) == "number" and nowEpoch then
    local bootEpoch = BOOT_STARTED_EPOCH or nowEpoch
    if request.epoch < bootEpoch - 10000 then return nil end
    if request.epoch > nowEpoch + 10000 then return nil end
    if nowEpoch - request.epoch > (UPDATE_REQUEST_MAX_AGE_SECONDS * 1000) then return nil end
    return request
  end

  if type(request.time) == "number" then
    local nowClock = os.clock()
    if request.time < BOOT_STARTED_CLOCK - 5 then return nil end
    if request.time > nowClock + 5 then return nil end
    if nowClock - request.time > UPDATE_REQUEST_MAX_AGE_SECONDS then return nil end
    return request
  end

  return nil
end

local cfg = readTable(BOOT_CONFIG, {})
local program, instance = chooseMapping(cfg)
drawConsoleStatus(program, instance, "starting firmware")
ensureProgram(cfg, program, instance)

local updateRequested = false
local updateSource = nil
local updateKind = "program"
local updatePayload = {}

while true do
  updateRequested = false
  updateSource = nil
  updateKind = "program"
  updatePayload = {}
  local ok, err = pcall(function()
    parallel.waitForAny(
      function() return runProgram(program, instance) end,
      function()
        updateSource, updateKind, updatePayload = updateWatcher(program, instance)
        updateRequested = true
      end
    )
  end)

  local localRequest = consumeUpdateRequest()
  if localRequest then
    updateRequested = true
    updateSource = localRequest.source or "local_request"
    updatePayload = localRequest
    local command = localRequest.command
    if command == "update_bootloader" or command == "bootloader_update" then
      updateKind = "bootloader"
    else
      updateKind = "program"
    end
  end

  if updateRequested then
    updatePayload = ensureUpdatePacketMetadata(updateSource, updatePayload)
    clear()
    term.setTextColor(colors.yellow)
    print("MCCR update requested")
    term.setTextColor(colors.white)
    print("Source: " .. tostring(updateSource or "unknown"))
    print("Kind: " .. tostring(updateKind or "program"))
    print("Program: " .. tostring(program.key))
    print("Instance: " .. tostring(instance.name))
    print("Current version: " .. tostring(programVersion()))
    print("")
    updateMeta = {
      updateId = updatePayload and updatePayload.updateId or nil,
      updateKind = updateKind,
      slot = updatePayload and updatePayload.slot or nil,
      total = updatePayload and updatePayload.total or nil,
    }
    local stagger = updateStaggerSeconds(updateSource, instance, updatePayload)
    updateMeta.scheduledDelay = stagger
    print("Scheduled delay: " .. tostring(stagger) .. " seconds")
    waitForScheduledUpdate(stagger, program, instance, updateKind)
    if stagger > 0 then
      clear()
      term.setTextColor(colors.yellow)
      print("MCCR update requested")
      term.setTextColor(colors.white)
      print("Kind: " .. tostring(updateKind or "program"))
      print("Program: " .. tostring(program.key))
      print("Instance: " .. tostring(instance.name))
      print("Current version: " .. tostring(programVersion()))
      print("")
    end
    if updateKind == "bootloader" then
      print("Downloading current bootloader...")
      drawConsoleStatus(program, instance, "bootloader update", "starting")
      broadcastUpdateStatus(program, instance, "starting", "bootloader", 10)
      drawBootUpdate("BOOTLOADER", "starting", program, instance)
      sleep(1)
      downloadBootloader(program, instance)
      print("Rebooting to new bootloader...")
      drawConsoleStatus(program, instance, "rebooting", "bootloader installed")
      drawBootUpdate("BOOTLOADER", "rebooting", program, instance)
      broadcastUpdateStatus(program, instance, "rebooting", "rebooting", 100)
      sleep(1)
      os.reboot()
    else
      print("Downloading current GitHub version...")
      broadcastUpdateStatus(program, instance, "starting", "download", 10)
      cfg.forceUpdate = true
      writeTable(BOOT_CONFIG, cfg)
      sleep(1)
      ensureProgram(cfg, program, instance)
      drawBootUpdate("FIRMWARE", "installed, starting", program, instance)
      drawConsoleStatus(program, instance, "rebooting", "program installed")
      for _ = 1, 3 do
        broadcastUpdateStatus(program, instance, "done", "program installed", 100)
        sleep(0.2)
      end
    end
  elseif ok then
    sleep(1)
  else
    appendCrash(err)
    clear()
    term.setTextColor(colors.red)
    print("MCCR program crashed")
    print(tostring(err))
    term.setTextColor(colors.gray)
    print("")
    print("Retrying in 5 seconds.")
    print("Hold Ctrl+T to stop.")
    sleep(5)
    if not fs.exists(PROGRAM_PATH) then
      ensureProgram(cfg, program, instance)
    end
  end
end
]====]
local MCCR_ALLOWED_NAMES = {
  "admin_control_panel",
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

local function load_role_admin()
local tabs = { "Power", "Screens", "Settings" }
local powerGroups = {
  { key = "control", label = "Control", breakers = { "main_computer", "lighting", "noncritical_loads", "transformer_fans", "facility_ac_1", "facility_ac_2", "fake_load", "sound_device" } },
  { key = "grid", label = "Grid", breakers = { "t10_a", "t10_b", "tie_10kv", "lv_a", "lv_b", "emergency_inverter", "battery_400v_charger", "buck_12v", "supercap" } },
  { key = "plants", label = "Plants", breakers = { "plant_nuclear", "plant_fusion", "plant_reserved_3", "plant_reserved_4", "plant_reserved_5", "plant_reserved_6", "plant_reserved_7", "plant_reserved_8" } },
}
local screenTargets = {
  { key = "main_presentation_screen", label = "Main" },
  { key = "presentation_screen_left", label = "Left" },
  { key = "presentation_screen_right", label = "Right" },
  { key = "mon1", label = "Mon1" },
  { key = "mon2", label = "Mon2" },
  { key = "mon3", label = "Mon3" },
  { key = "mon4", label = "Mon4" },
  { key = "statsm1", label = "S1" },
  { key = "statsm2", label = "S2" },
  { key = "statsm3", label = "S3" },
  { key = "statsm4", label = "S4" },
  { key = "statsm5", label = "S5" },
  { key = "statsm6", label = "S6" },
}
local presentationContexts = { "overview", "power", "ae2", "draconic", "battery", "computers", "alarms", "fission", "fusion", "updates" }
local statsContexts = { "all", "devices", "peripherals", "power", "breakers", "alarms", "draconic", "updates" }
local colorOptions = {
  { key = "white", label = "W", value = colors.white },
  { key = "green", label = "G", value = colors.green },
  { key = "yellow", label = "Y", value = colors.yellow },
  { key = "orange", label = "O", value = colors.orange },
  { key = "red", label = "R", value = colors.red },
  { key = "cyan", label = "C", value = colors.cyan },
  { key = "blue", label = "B", value = colors.blue },
  { key = "black", label = "K", value = colors.black },
}
local themes = {
  { key = "default", label = "Default", fg = colors.white, bg = colors.black },
  { key = "green", label = "Green", fg = colors.lime, bg = colors.black },
  { key = "amber", label = "Amber", fg = colors.yellow, bg = colors.black },
  { key = "blue", label = "Blue", fg = colors.white, bg = colors.blue },
}
local soundChannels = { "fans", "ac", "warning", "alarm", "off" }

local function mccrValidBootloaderText(text)
  if type(text) ~= "string" then return false end
  if not text:find("MCCR mapped GitHub bootloader", 1, true) then return false end
  if not text:find("local PROGRAM_URLS = {", 1, true) then return false end
  if not text:find("function chooseMapping", 1, true) then return false end
  local loader = loadstring or load
  if type(loader) == "function" then
    local fn = loader(text, "@startup.lua")
    if not fn then return false end
  end
  return true
end

local function run(name, lib)
  local statePath = "/mccr_state/" .. name .. ".dat"
  local updatePlanPath = "/mccr_state/update_plan.dat"
  local s = lib.state.read(statePath, { tab = 1, powerGroup = "control", target = "main_presentation_screen", displayMode = "overview", textColor = colors.white, bgColor = colors.black, theme = "default" })
  s.snapshot = {}
  s.eval = {}
  s.updateStatus = {}
  s.updateUntil = nil
  local persistedPlan = lib.state.read(updatePlanPath, nil)
  if type(persistedPlan) == "table" and persistedPlan.id and persistedPlan.targets then
    s.updatePlan = persistedPlan
    s.updateStatus = s.updateStatus or {}
    for dev, target in pairs(persistedPlan.targets) do s.updateStatus[dev] = s.updateStatus[dev] or target end
  end
  s.pendingBreakers = s.pendingBreakers or {}
  local screen = lib.ui.target(lib.devices.spec(name))
  lib.ui.boot(screen, lib.devices.spec(name).label or name)
  mccrDrawConsoleStatus(name, "running")
  lib.net.open()
  local buttons = {}

  local function send(payload, repeats)
    repeats = repeats or 1
    for _ = 1, repeats do
      lib.net.broadcast(name, "command", payload)
      if repeats > 1 then sleep(0.05) end
    end
  end

  local function button(id, x, y, w, label, fg, bg)
    table.insert(buttons, lib.ui.button(screen, id, x, y, w, label, fg, bg))
  end

  local function hitButton(x, y)
    local exact = lib.ui.hit(buttons, x, y)
    if exact then return exact end
    for _, b in ipairs(buttons or {}) do
      if b.w and b.w > 0 and x >= b.x and x < b.x + b.w and math.abs(y - b.y) <= 1 then
        return b.id
      end
    end
    return nil
  end

  local function drawRow(items, y, prefix, activeKey, minW)
    local w = lib.ui.size(screen)
    local x = 1
    minW = minW or 7
    for _, item in ipairs(items) do
      local key = item.key or item
      local label = item.label or item
      local bw = math.max(minW, #label + 2)
      if x + bw - 1 > w then
        x = 1
        y = y + 1
      end
      button(prefix .. ":" .. key, x, y, bw, label, colors.white, key == activeKey and colors.blue or colors.gray)
      x = x + bw + 1
    end
    return y + 1
  end

  local function activePowerGroup()
    for _, group in ipairs(powerGroups) do
      if group.key == s.powerGroup then return group end
    end
    return powerGroups[1]
  end

  local function currentStyle()
    local remote = (s.snapshot or {}).screenStyle or {}
    return {
      textColor = s.textColor or remote.textColor or colors.white,
      bgColor = s.bgColor or remote.bgColor or colors.black,
      theme = s.theme or remote.theme or "default",
    }
  end

  local function nowMs()
    return os.epoch and os.epoch("utc") or math.floor(os.clock() * 1000)
  end

  local function telemetryFresh(lastSeen, now)
    if not lastSeen then return true end
    if lastSeen < 9999999999 then
      local clockNow = os.clock()
      return lastSeen <= clockNow + 5 and (clockNow - lastSeen) <= 30
    end
    return (now - lastSeen) <= 30000
  end

  local function liveUpdateTargets()
    local rows = {}
    local seen = {}
    local now = nowMs()
    for key, item in pairs((s.snapshot or {}).telemetry or {}) do
      local dev = tostring((type(item) == "table" and item.name) or key)
      if dev ~= name and not seen[dev] then
        local lastSeen = type(item) == "table" and tonumber(item.lastSeen) or nil
        local fresh = telemetryFresh(lastSeen, now)
        if fresh then
          seen[dev] = true
          rows[#rows + 1] = {
            device = dev,
            program = tostring((type(item) == "table" and item.program) or "all"),
            label = tostring((type(item) == "table" and item.label) or dev),
            version = tostring((type(item) == "table" and item.firmwareVersion) or "unknown"),
          }
        end
      end
    end
    if not seen.maincomputer and (s.snapshot or {}).buses then
      rows[#rows + 1] = { device = "maincomputer", program = "maincomputer", label = "Main Computer", version = "unknown" }
      seen.maincomputer = true
    end
    table.sort(rows, function(a, b) return tostring(a.device) < tostring(b.device) end)
    return rows
  end

  local function updateStageColor(stage)
    if stage == "done" or stage == "rebooting" then return colors.green end
    if stage == "failed" or stage == "timeout" then return colors.red end
    if stage == "scheduled" or stage == "countdown" or stage == "queued" or stage == "starting" or stage == "retrying" or stage == "lan_cache" or stage == "downloading" or stage == "verifying" or stage == "installing" or stage == "bootloader" then
      return colors.yellow
    end
    return colors.lightBlue
  end

  local function isFinalUpdateStage(stage)
    return stage == "done" or stage == "failed" or stage == "timeout" or stage == "rebooting"
  end

  local function saveUpdatePlan()
    if s.updatePlan and s.updatePlan.id then
      lib.state.write(updatePlanPath, s.updatePlan)
    elseif fs.exists(updatePlanPath) then
      fs.delete(updatePlanPath)
    end
  end

  local function updateExpected()
    local out = {}
    if s.updatePlan and s.updatePlan.targets then
      for dev in pairs(s.updatePlan.targets) do out[dev] = true end
    end
    local count = 0
    for _ in pairs(out) do count = count + 1 end
    return out, math.max(1, count)
  end

  local function smoothProgress(item)
    local raw = tonumber(item.progress) or 0
    if isFinalUpdateStage(item.stage) then raw = 100 end
    item.displayProgress = tonumber(item.displayProgress) or raw
    local delta = raw - item.displayProgress
    if math.abs(delta) <= 1 then
      item.displayProgress = raw
    else
      item.displayProgress = item.displayProgress + math.max(-8, math.min(8, delta * 0.35))
    end
    return math.max(0, math.min(100, item.displayProgress))
  end

  local function updateProgress()
    local expected, total = updateExpected()
    local sum, done, failed, ack = 0, 0, 0, 0
    for dev in pairs(expected) do
      local item = s.updatePlan and s.updatePlan.targets and s.updatePlan.targets[dev]
      if item then
        if item.lastStatus then ack = ack + 1 end
        if item.stage == "done" or item.stage == "rebooting" then done = done + 1 end
        if item.stage == "failed" or item.stage == "timeout" then failed = failed + 1 end
        sum = sum + smoothProgress(item)
      end
    end
    return math.floor(sum / total), done, failed, ack, total
  end

  local function refreshUpdatePlan()
    if not s.updatePlan or not s.updatePlan.targets then return end
    local now = os.clock()
    s.updatePlan.phase = s.updatePlan.phase or "active"
    local allFinished = true
    for dev, target in pairs(s.updatePlan.targets) do
      if not isFinalUpdateStage(target.stage) then
        allFinished = false
        if now > (s.updatePlan.startedAt or now) + 300 then
          target.stage = "timeout"
          target.detail = "global timeout"
          target.progress = 100
        elseif now > (target.scheduledAt or s.updatePlan.startedAt or now) + 180 and not target.lastStatus then
          target.stage = "timeout"
          target.detail = "no response"
          target.progress = 100
        elseif target.lastStatus and now - target.lastStatus > 120 then
          target.stage = "timeout"
          target.detail = "status lost"
          target.progress = 100
        elseif now < (target.scheduledAt or now) then
          target.stage = "queued"
          target.detail = "T-" .. tostring(math.ceil((target.scheduledAt or now) - now)) .. "s"
          target.progress = 0
        end
      end
    end
    if allFinished and s.updatePlan.phase == "active" then
      s.updatePlan.phase = "summary"
      s.updatePlan.summaryUntil = now + 12
    elseif s.updatePlan.phase == "summary" and now >= (s.updatePlan.summaryUntil or now) then
      if s.updatePlan.kind == "bootloader" and s.updatePlan.id then
        s.payloadGrace = { id = s.updatePlan.id, untilTime = now + 30 }
      end
      s.updatePlan = nil
      s.updateStatus = {}
      s.updateUntil = nil
    elseif s.updateUntil and now > s.updateUntil then
      for _, target in pairs(s.updatePlan.targets or {}) do
        if not isFinalUpdateStage(target.stage) then
          target.stage = "timeout"
          target.detail = "admin timeout"
          target.progress = 100
        end
      end
      s.updatePlan.phase = "summary"
      s.updatePlan.summaryUntil = now + 12
    end
    saveUpdatePlan()
  end

  local function updateFinished()
    if not s.updatePlan or not s.updatePlan.targets then return false end
    local any = false
    for _, target in pairs(s.updatePlan.targets) do
      any = true
      if not isFinalUpdateStage(target.stage) then return false end
    end
    return any
  end

  local function resolveUpdateTargetKey(payload, pkt)
    if not (s.updatePlan and s.updatePlan.targets) then return nil end
    payload = payload or {}
    local candidates = {
      payload.device,
      pkt and pkt.source,
      pkt and pkt.id,
    }
    for _, candidate in ipairs(candidates) do
      local key = tostring(candidate or "")
      if key ~= "" and s.updatePlan.targets[key] then return key end
    end
    for _, candidate in ipairs(candidates) do
      local key = string.lower(tostring(candidate or ""))
      if key ~= "" then
        for targetKey, target in pairs(s.updatePlan.targets) do
          if string.lower(tostring(targetKey)) == key or string.lower(tostring(target.device or "")) == key then
            return targetKey
          end
        end
      end
    end
    local slot = tonumber(payload.slot)
    if slot then
      for targetKey, target in pairs(s.updatePlan.targets) do
        if tonumber(target.slot) == slot then return targetKey end
      end
    end
    return nil
  end

  local function savePanelState()
    lib.state.write(statePath, {
      tab = s.tab,
      powerGroup = s.powerGroup,
      target = s.target,
      displayMode = s.displayMode,
      textColor = s.textColor,
      bgColor = s.bgColor,
      theme = s.theme,
    })
  end

  local function readWholeFile(path)
    if not fs.exists(path) then return nil end
    local h = fs.open(path, "r")
    if not h then return nil end
    local text = h.readAll()
    h.close()
    return text
  end

  local function bootloaderPayload()
    if mccrValidBootloaderText(BOOTLOADER_PAYLOAD) then return BOOTLOADER_PAYLOAD end
    return readWholeFile("/startup.lua")
  end

  local function serveBootloaderPayload(request)
    request = request or {}
    if request.kind ~= "bootloader" then return end
    local activeId = s.updatePlan and s.updatePlan.id
    local graceId = s.payloadGrace and s.payloadGrace.untilTime and os.clock() < s.payloadGrace.untilTime and s.payloadGrace.id or nil
    if not activeId and not graceId then return end
    if request.updateId ~= activeId and request.updateId ~= graceId then return end
    local text = bootloaderPayload()
    local chunkSize = 6000
    if not text or not text:find("MCCR mapped GitHub bootloader", 1, true) then
      lib.net.broadcast(name, "payload_chunk", {
        requestId = request.requestId,
        target = request.target,
        kind = "bootloader",
        updateId = request.updateId,
        error = "admin has no valid bootloader payload",
      })
      return
    end
    local total = math.max(1, math.ceil(#text / chunkSize))
    for i = 1, total do
      lib.net.broadcast(name, "payload_chunk", {
        requestId = request.requestId,
        target = request.target,
        kind = "bootloader",
        updateId = request.updateId,
        index = i,
        total = total,
        data = text:sub(((i - 1) * chunkSize) + 1, i * chunkSize),
      })
      sleep(0.05)
    end
  end

  local function scheduleFleetUpdate(kind)
    local targets = liveUpdateTargets()
    if #targets == 0 then
      local updateId = tostring(os.getComputerID()) .. "-empty-" .. tostring(math.floor(os.clock() * 1000))
      local now = os.clock()
      s.updatePlan = {
        id = updateId,
        kind = kind,
        phase = "summary",
        startedAt = now,
        summaryUntil = now + 12,
        count = 1,
        targets = {
          none = {
            device = "none",
            program = "none",
            slot = 1,
            total = 1,
            stage = "failed",
            detail = "no live devices",
            progress = 100,
            scheduledAt = now,
            lastStatus = now,
          },
        },
      }
      s.updateStatus = s.updatePlan.targets
      s.updateUntil = now + 20
      saveUpdatePlan()
      return
    end

    local updateId = tostring(os.getComputerID()) .. "-" .. tostring(math.floor(os.clock() * 1000))
    local command = kind == "bootloader" and "update_bootloader" or "update_program"
    local baseDelay = 1
    local stepDelay = kind == "bootloader" and 2 or 0.5
    local bootText = kind == "bootloader" and bootloaderPayload() or nil
    if kind == "bootloader" and not mccrValidBootloaderText(bootText) then
      local now = os.clock()
      local updateId = tostring(os.getComputerID()) .. "-boot-invalid-" .. tostring(math.floor(now * 1000))
      s.updatePlan = {
        id = updateId,
        kind = "bootloader",
        phase = "summary",
        startedAt = now,
        summaryUntil = now + 12,
        count = 1,
        targets = {
          admin_control_panel = {
            device = "admin_control_panel",
            program = "admin_control_panel",
            slot = 1,
            total = 1,
            stage = "failed",
            detail = "no valid embedded bootloader",
            progress = 100,
            scheduledAt = now,
            lastStatus = now,
          },
        },
      }
      s.updateStatus = s.updatePlan.targets
      s.updateUntil = now + 20
      saveUpdatePlan()
      return
    end
    s.updateStatus = {}
    s.updatePlan = {
      id = updateId,
      kind = kind,
      phase = "active",
      startedAt = os.clock(),
      targets = {},
      count = #targets,
    }
    s.updateUntil = os.clock() + 300

    for i, target in ipairs(targets) do
      local delay = baseDelay + ((i - 1) * stepDelay)
      s.updatePlan.targets[target.device] = {
        device = target.device,
        program = target.program,
        version = target.version,
        slot = i,
        total = #targets,
        stage = "queued",
        detail = "T-" .. tostring(math.ceil(delay)) .. "s",
        progress = 0,
        scheduledAt = os.clock() + delay,
      }
      s.updateStatus[target.device] = s.updatePlan.targets[target.device]
      send({
        command = command,
        target = target.device,
        program = kind == "bootloader" and "all" or (target.program ~= "unknown" and target.program or "all"),
        confirm = true,
        updateId = updateId,
        updateKind = kind,
        delay = delay,
        slot = i,
        total = #targets,
      }, 3)
    end
    saveUpdatePlan()
  end

  local function pendingBreaker(k)
    s.pendingBreakers = s.pendingBreakers or {}
    local pending = s.pendingBreakers[k]
    if not pending then return nil end
    local actual = ((s.snapshot or {}).breakers or {})[k]
    if actual == pending.value then
      s.pendingBreakers[k] = nil
      return nil
    end
    return pending
  end

  local function resendPendingBreakers()
    s.pendingBreakers = s.pendingBreakers or {}
    for breaker, pending in pairs(s.pendingBreakers) do
      local actual = ((s.snapshot or {}).breakers or {})[breaker]
      if actual == pending.value then
        s.pendingBreakers[breaker] = nil
      elseif os.clock() - (pending.lastSent or 0) >= 1.25 then
        pending.lastSent = os.clock()
        send({ command = "set_breaker", breaker = breaker, value = pending.value }, 3)
      end
    end
  end

  local function drawPower(y, w, h)
    y = drawRow(powerGroups, y, "group", s.powerGroup, 8)
    local group = activePowerGroup()
    local rows = math.max(1, h - y + 1)
    local colW = math.max(15, math.floor(w / 4))
    local i = 0
    for _, k in ipairs(group.breakers) do
      if (s.snapshot.breakers or {})[k] ~= nil then
        local row = y + (i % rows)
        local col = math.floor(i / rows)
        local bx = 1 + (col * colW)
        if bx <= w then
          local closed = s.snapshot.breakers[k]
          local pending = pendingBreaker(k)
          if pending then
            local mark = pending.value and "ON " or "OFF"
            button("breaker:" .. k, bx, row, math.min(colW - 1, w - bx + 1), "[..] " .. k .. ">" .. mark, colors.black, colors.yellow)
          else
            button("breaker:" .. k, bx, row, math.min(colW - 1, w - bx + 1), (closed and "[X] " or "[ ] ") .. k, colors.white, closed and colors.green or colors.red)
          end
        end
        i = i + 1
      end
    end
  end

  local function drawScreens(y, w)
    lib.ui.writeAt(screen, 1, y, "Target display", colors.yellow)
    y = drawRow(screenTargets, y + 1, "target", s.target, 6)
    local isStats = tostring(s.target or ""):find("^statsm") ~= nil
    local contexts = isStats and statsContexts or presentationContexts
    lib.ui.writeAt(screen, 1, y, "Context", colors.yellow)
    local active = ((s.snapshot.displayContexts or {})[s.target]) or s.displayMode or "overview"
    drawRow(contexts, y + 1, "context", active, 8)
  end

  local function drawUpdatePanel(y, w, h)
    refreshUpdatePlan()
    if not (s.updatePlan and s.updatePlan.id and s.updatePlan.targets) then return end
    local pct, done, failed, ack, total = updateProgress()
    local kind = (s.updatePlan and s.updatePlan.kind) or "update"
    local phase = s.updatePlan.phase == "summary" and "SUMMARY" or "ACTIVE"
    lib.ui.writeAt(screen, 1, y, string.format("%s %s %d%%  nodes %d  ack %d  done %d  fail %d", string.upper(kind), phase, pct, total, ack, done, failed), failed > 0 and colors.red or colors.yellow)
    lib.ui.bar(screen, 1, y + 1, math.max(8, w - 2), pct, 100, failed > 0 and colors.red or colors.green)
    y = y + 3

    local rows = {}
    local expected = s.updatePlan and s.updatePlan.targets or s.updateStatus or {}
    for key, item in pairs(expected) do
      rows[#rows + 1] = item
      item.key = key
    end
    table.sort(rows, function(a, b) return (tonumber(a.slot) or 999) < (tonumber(b.slot) or 999) end)
    for _, item in ipairs(rows) do
      if y > h then break end
      local slot = item.slot and (tostring(item.slot) .. "/" .. tostring(item.total or "?") .. " ") or ""
      local text = slot .. tostring(item.device or item.key) .. " " .. tostring(item.stage or "queued")
      if item.version or item.currentVersion then text = text .. " v" .. tostring(item.version or item.currentVersion) end
      if item.detail then text = text .. " " .. tostring(item.detail) end
      lib.ui.writeAt(screen, 1, y, text, updateStageColor(item.stage))
      if item.progress then
        lib.ui.bar(screen, math.max(1, math.floor(w * 0.68)), y, math.max(5, math.floor(w * 0.30)), math.max(0, math.min(100, tonumber(item.displayProgress or item.progress) or 0)), 100, updateStageColor(item.stage))
      end
      y = y + 1
    end
  end

  local function drawUpdateBanner(w, h)
    refreshUpdatePlan()
    if not (s.updatePlan and s.updatePlan.id and s.updatePlan.targets) then return end
    if h < 8 then return end
    local pct, done, failed, ack, total = updateProgress()
    local rows = {}
    for key, item in pairs(s.updatePlan.targets or {}) do
      if type(item) == "table" then
        item.key = key
        rows[#rows + 1] = item
      end
    end
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
    local kind = tostring(s.updatePlan.kind or "update")
    local upperKind = string.upper(kind == "program" and "firmware" or kind)
    local bg = kind == "bootloader" and colors.blue or colors.green
    if failed > 0 then bg = colors.red end
    local fg = bg == colors.green and colors.black or colors.white
    local device = current and tostring(current.device or current.key or "waiting") or "waiting"
    local stage = current and tostring(current.stage or "queued") or "queued"
    local eta = current and tonumber(current.eta) or nil
    local etaText = eta and eta > 0 and (" T-" .. tostring(math.ceil(eta)) .. "s") or ""
    local text = string.format(" %s %d%%  %s %s%s  ack %d/%d  done %d  fail %d", upperKind, pct, device, stage, etaText, ack, total, done, failed)
    lib.ui.writeAt(screen, 1, h, string.rep(" ", w), fg, bg)
    lib.ui.writeAt(screen, 1, h, text:sub(1, w), fg, bg)
  end

  local function drawSettings(y, w)
    local style = currentStyle()
    lib.ui.writeAt(screen, 1, y, "Reset", colors.yellow)
    button("reset:simulation", 8, y, 12, "SIM", colors.white, colors.red)
    button("reset:breakers", 22, y, 12, "BRK", colors.white, colors.orange)
    button("reset:temperatures", 36, y, 12, "TEMP", colors.black, colors.yellow)
    button("reset:damage", 50, y, 12, "DMG", colors.white, colors.purple)
    y = y + 2
    lib.ui.writeAt(screen, 1, y, "Text", colors.yellow)
    local x = 8
    for _, opt in ipairs(colorOptions) do
      button("fg:" .. opt.key, x, y, 3, opt.label, opt.value == colors.black and colors.white or colors.black, opt.value)
      x = x + 4
    end
    y = y + 1
    lib.ui.writeAt(screen, 1, y, "Back", colors.yellow)
    x = 8
    for _, opt in ipairs(colorOptions) do
      button("bg:" .. opt.key, x, y, 3, opt.label, opt.value == colors.black and colors.white or colors.black, opt.value)
      x = x + 4
    end
    y = y + 1
    lib.ui.writeAt(screen, 1, y, "Theme", colors.yellow)
    x = 8
    for _, theme in ipairs(themes) do
      button("theme:" .. theme.key, x, y, math.max(8, #theme.label + 2), theme.label, colors.white, theme.key == style.theme and colors.blue or colors.gray)
      x = x + math.max(8, #theme.label + 2) + 1
    end
    y = y + 1
    lib.ui.writeAt(screen, 1, y, "Sound", colors.yellow)
    x = 8
    for _, channel in ipairs(soundChannels) do
      button("sound:" .. channel, x, y, math.max(7, #channel + 2), channel, colors.white, colors.gray)
      x = x + math.max(7, #channel + 2) + 1
    end
    y = y + 2
    button("update_all", 1, y, 14, "UPDATE ALL", colors.white, colors.orange)
    button("update_self", 17, y, 14, "UPDATE SELF", colors.white, colors.blue)
    button("boot_all", 33, y, 12, "BOOT FLEET", colors.white, colors.purple)
    button("boot_self", 47, y, 12, "BOOT SELF", colors.white, colors.purple)
    y = y + 1
    button("show_versions", 1, y, 16, "VERSIONS", colors.black, colors.yellow)
    drawUpdatePanel(y + 2, w, select(2, lib.ui.size(screen)))
  end

  local function draw()
    local spec = lib.devices.spec(name)
    s.snapshot = s.snapshot or {}
    local eval = lib.power.evaluate(spec, lib.power.inputFor(spec, s.snapshot), s.eval)
    eval.name, eval.label, eval.role = name, spec.label, spec.role
    eval.program, eval.firmwareVersion = MCCR_PROGRAM, MCCR_VERSION
    s.eval = eval
    buttons = {}
    local style = currentStyle()
    lib.ui.clear(screen, style.textColor or colors.white, style.bgColor or colors.black)
    local w, h = lib.ui.size(screen)
    local tabW = math.max(9, math.floor((w - 2) / #tabs))
    local x = 1
    for i, tab in ipairs(tabs) do
      button("tab:" .. i, x, 1, tabW, tab, colors.white, i == s.tab and colors.blue or colors.gray)
      x = x + tabW + 1
    end
    lib.ui.writeAt(screen, math.max(1, w - 23), 2, "Self " .. eval.status .. string.format(" %0.1fV", eval.voltage), lib.ui.statusColor(eval.severity))
    local y = 3
    if s.tab == 1 then
      drawPower(y, w, h)
    elseif s.tab == 2 then
      drawScreens(y, w)
    else
      drawSettings(y, w)
    end
    drawUpdateBanner(w, h)
  end

  local function setThemeField(field, key)
    for _, opt in ipairs(colorOptions) do
      if opt.key == key then
        if field == "fg" then s.textColor = opt.value else s.bgColor = opt.value end
        local style = currentStyle()
        s.snapshot.screenStyle = s.snapshot.screenStyle or {}
        s.snapshot.screenStyle.textColor = style.textColor
        s.snapshot.screenStyle.bgColor = style.bgColor
        s.snapshot.screenStyle.theme = style.theme
        send({ command = "theme", textColor = style.textColor, bgColor = style.bgColor, theme = style.theme }, 3)
        return
      end
    end
  end

  local function applyTheme(key)
    for _, theme in ipairs(themes) do
      if theme.key == key then
        s.theme, s.textColor, s.bgColor = theme.key, theme.fg, theme.bg
        s.snapshot.screenStyle = s.snapshot.screenStyle or {}
        s.snapshot.screenStyle.textColor = s.textColor
        s.snapshot.screenStyle.bgColor = s.bgColor
        s.snapshot.screenStyle.theme = s.theme
        send({ command = "theme", textColor = s.textColor, bgColor = s.bgColor, theme = s.theme }, 3)
        return
      end
    end
  end

  local function click(id)
    if not id then return end
    if id:find("^tab:") then
      s.tab = tonumber(id:sub(5)) or 1
    elseif id:find("^group:") then
      s.powerGroup = id:sub(7)
    elseif id:find("^breaker:") then
      local breaker = id:sub(9)
      local existing = pendingBreaker(breaker)
      local current = existing and existing.value or ((s.snapshot.breakers or {})[breaker] == true)
      local desired = not current
      s.pendingBreakers = s.pendingBreakers or {}
      s.pendingBreakers[breaker] = { value = desired, requested = os.clock(), lastSent = os.clock() }
      send({ command = "set_breaker", breaker = breaker, value = desired }, 4)
    elseif id:find("^target:") then
      s.target = id:sub(8)
    elseif id:find("^context:") then
      local mode = id:sub(9)
      s.displayMode = mode
      s.snapshot.displayContexts = s.snapshot.displayContexts or {}
      s.snapshot.displayContexts[s.target] = mode
      send({ command = "display_context", target = s.target, mode = mode }, 3)
    elseif id:find("^reset:") then
      send({ command = "reset_" .. id:sub(7) }, 2)
    elseif id:find("^fg:") then
      setThemeField("fg", id:sub(4))
    elseif id:find("^bg:") then
      setThemeField("bg", id:sub(4))
    elseif id:find("^theme:") then
      applyTheme(id:sub(7))
    elseif id:find("^sound:") then
      send({ command = "sound_channel", target = "peripheral6_sound", channel = id:sub(7) }, 2)
    elseif id == "update_all" then
      scheduleFleetUpdate("program")
    elseif id == "update_self" then
      local updateId = tostring(os.getComputerID()) .. "-self-" .. tostring(math.floor(os.clock() * 1000))
      lib.state.write("/mccr_update_request.dat", { command = "update_program", source = name, localOnly = true, updateId = updateId, updateKind = "program", slot = 1, total = 1, delay = 0, time = os.clock(), epoch = os.epoch and os.epoch("utc") or nil })
      error("local update requested", 0)
    elseif id == "boot_all" then
      scheduleFleetUpdate("bootloader")
    elseif id == "boot_self" then
      lib.ui.clear(screen, colors.white, colors.purple)
      lib.ui.center(screen, 2, "BOOTLOADER SELF UPDATE", colors.white, colors.purple)
      lib.ui.center(screen, 4, "HANDING CONTROL TO BOOTLOADER", colors.yellow, colors.purple)
      sleep(0.5)
      local updateId = tostring(os.getComputerID()) .. "-boot-" .. tostring(math.floor(os.clock() * 1000))
      lib.state.write("/mccr_update_request.dat", { command = "update_bootloader", source = name, localOnly = true, updateId = updateId, updateKind = "bootloader", slot = 1, total = 1, delay = 0, time = os.clock(), epoch = os.epoch and os.epoch("utc") or nil })
      error("local bootloader update requested", 0)
    elseif id == "show_versions" then
      send({ command = "show_versions", target = "all", duration = 20 }, 3)
    end
  end

  while true do
    draw()
    resendPendingBreakers()
    lib.net.broadcast(name, "telemetry", s.eval)
    savePanelState()
    local timer = os.startTimer(1)
    while true do
      local ev = { os.pullEvent() }
      if ev[1] == "timer" and ev[2] == timer then break end
      if ev[1] == "rednet_message" then
        local pkt = ev[3]
        if type(pkt) == "table" and pkt.system == "mccr" and pkt.kind == "snapshot" then
          s.snapshot = pkt.payload or s.snapshot
        elseif type(pkt) == "table" and pkt.system == "mccr" and pkt.kind == "payload_request" and pkt.payload then
          serveBootloaderPayload(pkt.payload)
        elseif type(pkt) == "table" and pkt.system == "mccr" and pkt.kind == "update_status" and pkt.payload then
          local p = pkt.payload
          if s.updatePlan and s.updatePlan.id and p.updateId == s.updatePlan.id and p.slot and p.total then
            local key = resolveUpdateTargetKey(p, pkt)
            if key and s.updatePlan.targets and s.updatePlan.targets[key] then
              local planned = s.updatePlan.targets[key]
              s.updateStatus = s.updateStatus or {}
              s.updateStatus[key] = {
                device = planned.device or p.device or key,
                program = p.program or planned.program,
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
              }
              for k, v in pairs(s.updateStatus[key]) do s.updatePlan.targets[key][k] = v end
              s.updatePlan.targets[key].lastStatus = os.clock()
              refreshUpdatePlan()
              saveUpdatePlan()
            end
          end
        end
      elseif ev[1] == "monitor_touch" then
        click(hitButton(ev[3], ev[4]))
        draw()
      elseif ev[1] == "mouse_click" then
        click(hitButton(ev[3], ev[4]))
        draw()
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
local run = load_role_admin()

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
