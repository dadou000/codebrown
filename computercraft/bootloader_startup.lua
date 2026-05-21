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
  local out = { term.current() }
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

function drawBootUpdate(stage, detail, program, instance)
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
  local deadline = os.clock() + 12
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
  drawBootUpdate("BOOTLOADER", "download attempt " .. tostring(attempt or 1), program, instance)
  broadcastUpdateStatus(program, instance, "bootloader", "attempt " .. tostring(attempt or 1), 25)
  print("Downloading MCCR bootloader...")
  print("Instance: " .. instance.name)
  print("Source: " .. tostring(url))

  if attempt == 1 then
    broadcastUpdateStatus(program, instance, "bootloader", "requesting LAN cache", 28)
    print("Trying LAN bootloader cache first...")
    local lanOk, lanErr = requestBootloaderPayload(url, STARTUP_TMP, program, instance)
    if lanOk then
      drawBootUpdate("BOOTLOADER", "LAN payload verified", program, instance)
      broadcastUpdateStatus(program, instance, "bootloader", "LAN payload", 80)
    else
      print("LAN cache unavailable: " .. tostring(lanErr))
      print("Falling back to GitHub...")
      local usedUrl = downloadFirstUrlTo(urls, STARTUP_TMP)
      print("Used: " .. tostring(usedUrl))
    end
  else
    local usedUrl = downloadFirstUrlTo(urls, STARTUP_TMP)
    print("Used: " .. tostring(usedUrl))
  end
  drawBootUpdate("BOOTLOADER", "verifying", program, instance)
  verifyBootloader(STARTUP_TMP)
  broadcastUpdateStatus(program, instance, "bootloader", "verified", 85)
  drawBootUpdate("BOOTLOADER", "installing", program, instance)
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
      broadcastUpdateStatus(program, instance, "starting", "bootloader", 10)
      drawBootUpdate("BOOTLOADER", "starting", program, instance)
      sleep(1)
      downloadBootloader(program, instance)
      print("Rebooting to new bootloader...")
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
