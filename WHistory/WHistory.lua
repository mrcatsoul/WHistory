local ADDON_NAME = ...

local LOCALE = GetLocale()
local ADDON_NAME_LOCALE_SHORT = LOCALE=="ruRU" and GetAddOnMetadata(ADDON_NAME,"TitleS-ruRU") or GetAddOnMetadata(ADDON_NAME,"TitleShort")
local ADDON_NAME_LOCALE = LOCALE=="ruRU" and GetAddOnMetadata(ADDON_NAME,"Title-ruRU") or GetAddOnMetadata(ADDON_NAME,"Title")
local ADDON_NOTES = LOCALE=="ruRU" and GetAddOnMetadata(ADDON_NAME,"Notes-ruRU") or GetAddOnMetadata(ADDON_NAME,"Notes")

local f=CreateFrame("frame",ADDON_NAME.."_frame")
f:RegisterEvent("CHAT_MSG_WHISPER")
f:RegisterEvent("CHAT_MSG_WHISPER_INFORM")
f:RegisterEvent("UPDATE_CHAT_COLOR")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(self, event, ...) return self[event](self, ...) end)

local history,cfg,isCurrentSessionMsg={},{},{}
local UPDATE_CHAT_COLOR_Time=0
local isPrinting

local YOU_WHISPER_TO = LOCALE=="ruRU" and "Вы шепчете" or "To"
local WHISPERS = LOCALE=="ruRU" and "шепчет" or "whispers"

local function ChatLink(text,arg1,colorHex)
  text = text or "ТЫК"
  arg1 = arg1 or "TEST"
  colorHex = colorHex or "71d5ff"
  return "|cff"..colorHex.."|Haddon:"..ADDON_NAME.."_link:"..arg1..":|h["..text.."|r|cff"..colorHex.."]|h|r"
end

DEFAULT_CHAT_FRAME:HookScript("OnHyperlinkClick", function(self, link, str, button, ...)
  local linkType, arg1, arg2 = strsplit(":", link)
  if linkType == "addon" and arg1 and arg2 and arg1==""..ADDON_NAME.."_link" then
    --print(arg1,arg2)
    if arg2 == "Settings" then
      InterfaceOptionsFrame_OpenToCategory(f.settingsScrollFrame)
    end
  end
end)

do
  local old = ItemRefTooltip.SetHyperlink 
  function ItemRefTooltip:SetHyperlink(link, ...)
    if link:find(ADDON_NAME.."_link") then return end
    return old(self, link, ...)
  end
end

local function _print(msg,msg2,msg3)
  print("|cff3399ff["..ADDON_NAME_LOCALE_SHORT.."]:|r "..msg, msg2 and msg2 or "", msg3 and msg3 or "")
end

local chatFrameDocked = {}

local function showAndDockChatWindow(frame, _fontSize)
  if not frame or chatFrameDocked[frame] then return end
  if _fontSize then FCF_SetChatWindowFontSize(nil, frame, _fontSize) end
  FCF_DockFrame(frame)
  chatFrameDocked[frame] = true
end

local function getChatFrameByName(_name)
  local frame, found, _docked
  for i = 1, NUM_CHAT_WINDOWS do
    local name, fontSize, r, g, b, alpha, shown, locked, docked, uninteractable = GetChatWindowInfo(i)
    if (name == _name) then
      found = true
      frame = _G["ChatFrame" .. i]
      break
    end
  end
  _docked = chatFrameDocked[frame]
  return frame, found, _docked
end

local function func_frameAddMessage(msg, windowName, r, g, b, _fontSize)
  -- if not playerEnteredWorld or not settings["debugMessagesInSeparateChatWindow"] then
    -- print(msg)
    -- return
  -- end

  _fontSize = _fontSize or select(2,FCF_GetChatWindowInfo(DEFAULT_CHAT_FRAME:GetID())) or 13

  local frame, _, docked = getChatFrameByName(windowName)

  if frame and not docked then
    showAndDockChatWindow(frame, _fontSize)
    frame:AddMessage("|ccc55ffaa" .. ADDON_NAME .. ":|r |cccff3355" .. frame:GetName() .. " created|r")
  end

  local chatWindowsNum = FCF_GetNumActiveChatFrames()

  if not frame and chatWindowsNum and chatWindowsNum < 10 then
    FCF_OpenNewWindow(windowName)
    frame = _G["ChatFrame" .. chatWindowsNum]

    if frame then
      showAndDockChatWindow(frame, _fontSize)
      frame:AddMessage("|ccc55ffaa" .. ADDON_NAME .. ":|r |cccff3355" .. frame:GetName() .. " created|r")
    else
      frame = DEFAULT_CHAT_FRAME
      frame:AddMessage("|ccc55ffaa" .. ADDON_NAME .. ":|r |cccff3355" .. frame:GetName() .. " not created:(|r")
    end
  end

  if r == nil then r = 1 end
  if g == nil then g = 1 end
  if b == nil then b = 1 end

  if frame then
    frame:AddMessage(msg, r, g, b)
  else
    print(msg)
  end
end

local classColors = {
  ["DEATHKNIGHT"] = "C41F3B", -- 1
  ["DRUID"] = "FF7D0A",       -- 2
  ["HUNTER"] = "A9D271",      -- 3
  ["MAGE"] = "40C7EB",        -- 4
  ["PALADIN"] = "F58CBA",     -- 5
  ["PRIEST"] = "FFFFFF",      -- 6
  ["ROGUE"] = "FFF569",       -- 7
  ["SHAMAN"] = "0070DE",      -- 8
  ["WARLOCK"] = "8787ED",     -- 9
  ["WARRIOR"] = "C79C6E",     -- 10
  ["UNKNOWN"] = "999999",     -- 11
}

local NumberToClass = 
{
  [1] = "DEATHKNIGHT",
  [2] = "DRUID",
  [3] = "HUNTER",
  [4] = "MAGE",
  [5] = "PALADIN",
  [6] = "PRIEST",
  [7] = "ROGUE",
  [8] = "SHAMAN",
  [9] = "WARLOCK",
  [10] = "WARRIOR",
  [11] = "UNKNOWN",
}

local ClassToNumber = 
{
  ["DEATHKNIGHT"]=1,
  ["DRUID"]=2,
  ["HUNTER"]=3,
  ["MAGE"]=4,
  ["PALADIN"]=5,
  ["PRIEST"]=6,
  ["ROGUE"]=7,
  ["SHAMAN"]=8,
  ["WARLOCK"]=9,
  ["WARRIOR"]=10,
  ["UNKNOWN"]=11,
}

-- local function desaturateColor(r, g, b, factor)
  -- r = r * factor
  -- g = g * factor
  -- b = b * factor
  -- return r, g, b
-- end

local function desaturateColor(r, g, b, factor)
  -- Убедимся, что factor в пределах от 0 до 1
  factor = math.max(0, math.min(factor, 1))

  -- Среднее значение яркости (серый тон)
  local gray = 0.5

  -- Смешиваем текущие цвета с серым на основе фактора
  r = r * (1 - factor) + gray * factor
  g = g * (1 - factor) + gray * factor
  b = b * (1 - factor) + gray * factor

  -- Возвращаем результирующие значения
  return r, g, b
end

local function brightenColor(r, g, b, factor)
  r = math.min(r * factor, 255)
  g = math.min(g * factor, 255)
  b = math.min(b * factor, 255)
  return r, g, b
end

local function PlayerHyperLink(name)
  return "|Hplayer:"..name.."|h"..name.."|h"
end

function f:SaveMessage(isFrom,...)
  local msg, nameRealm, _, _, name, status, _, _, _, _, _, guid = ... 
  local class = select(2,GetPlayerInfoByGUID(guid))
  nameRealm = nameRealm or "UNKNOWN"
  --local realm = nameRealm and nameRealm:match("-(.+)")) or select(7,GetPlayerInfoByGUID(guid))
  --history[num] = { isFrom = isFrom, time = "|cff777777["..date("%H:%M:%S", time()).."]|r [|cff"..classColors[class]..""..PlayerHyperLink(nameRealm).."|r]: "..text.."" }
  local index = #history+1
  history[index] = 
  { 
    isFrom, -- true == входящее мсг; false == исходящее
    date("%d.%m.%y"), 
    date("%H:%M:%S", time()), 
    nameRealm or "UNKNOWN", 
    class and ClassToNumber[class] or ClassToNumber["UNKNOWN"], 
    --guid = guid or "UNKNOWN",
    --realm = 
    msg or "",
  }
  isCurrentSessionMsg[index]=true
  if GetCVar("showTimestamps")=="none" then
    f:PrintHistoryToChat()
  end
  --print("msg saved",nameRealm)
end

function f:UPDATE_CHAT_COLOR(...)
  local t=GetTime()
  if UPDATE_CHAT_COLOR_Time>=(t-1) then return end
  --print("UPDATE_CHAT_COLOR_Time")
  UPDATE_CHAT_COLOR_Time = t
  f:PrintHistoryToChat(delay)
end

function f:CHAT_MSG_WHISPER(...)
  f:SaveMessage(true,...)
end

function f:CHAT_MSG_WHISPER_INFORM(...)
  f:SaveMessage(false,...)
end

local testTime, testDate = date("%H:%M:%S", time()), date("%d.%m.%y")

local testMsgs =
{
  [1] = { 1, testDate, testTime, "Энайэсти-x100", 1, "Приветики бро, го бг" },
  [2] = { 1, testDate, testTime, "Qp", 3, "Я Зеленая Залупка МУУУУУУУ" },
  [3] = { 1, testDate, testTime, "Луздетка-x100500", 5, "Я пусси не кидающий боп хачу в вашу ги" },
  [4] = { 1, testDate, testTime, "Моча-x1", 7, "А я просто моча не чекающая точки" },
  [5] = { 1, testDate, testTime, "Гром", 1, "Величайший в деле" },
  [6] = { 1, testDate, testTime, "Эледрон", 5, "вам что скучно там?" },
  [7] = { 1, testDate, testTime, "Vrumm-Fun", 4, "Сорри бро, я думал ты скриптовый, го бг с Аспин, всех кливом выносить" },
  [8] = { 1, testDate, testTime, "Crazypenus", 5, "ЙООООООООООООООООООООООООООООООООООООУ" },
  [9] = { 1, testDate, testTime, "Абблевуха", 1, "Я робот долбаеб я должен грипать дк ато грипать меня" },
  [10] = { 1, testDate,  testTime, "Skillcapped", 7, "Амбуш в ебало, инста покрывало" },
  [11] = { 1, testDate, testTime, "Слезадьявола-Hell", 4, "это маусовер, понимать надо сына" },
}

local function GetMessageFromTableData(data)
  local msg = ""
  
  local todayDate = date("%d.%m.%y")
  
  if cfg["show_date_if_it_not_today"] and todayDate~=data[2] then
    msg = "[|cff777777"..data[2].."|r]"
  end
  
  if cfg["show_time"] then
    msg = msg .. "|cff777777["..data[3].."]|r"
  end
  
  local nameColoredHyperlink = "|cff"..classColors[NumberToClass[data[5]]]..""..PlayerHyperLink(data[4]).."|r"
  
  if IsAddOnLoaded("Chatter") then
    if data[1]==true then
      msg = msg .. "[W:From]"
    else
      msg = msg .. "[W:To]"
    end
    msg = msg .. " ["..nameColoredHyperlink.."]:"
  else
    if data[1]==true then
      msg = msg .. " ["..nameColoredHyperlink.."] "..WHISPERS..":"
    else
      msg = msg .. " "..YOU_WHISPER_TO.." ["..nameColoredHyperlink.."]:"
    end
  end
  
  msg = msg .. " " .. data[6]
  
  return msg
end

function f:PrintHistoryToChat(delay)
  --print("PrintHistoryToChat")
  if isPrinting then return true end
  isPrinting=true
  
  if not cfg["enable_addon"] then 
    local frame, found = getChatFrameByName(ADDON_NAME)
    if frame and found then
      frame:Clear()
    end
    isPrinting=nil
    return 
  end

  local t=0
  
  CreateFrame("frame"):SetScript("onupdate",function(self,elapsed)
    t=t+elapsed
    
    if delay and t<delay then 
      return 
    end
    
    local info = ChatTypeInfo["WHISPER"]
    local r,g,b=info.r,info.g,info.b
    local rd,gd,bd=r,g,b
    
    if cfg["desaturated_history_color"] then
      rd,gd,bd = desaturateColor(r, g, b, 0.8)
      --rd,gd,bd = brightenColor(desaturatedR, desaturatedG, desaturatedB, 2)
    end
    
    func_frameAddMessage("test",ADDON_NAME,r,g,b)
    
    local frame, found = getChatFrameByName(ADDON_NAME)
    
    if frame and found then
      for ChatType in pairs(ChatTypeInfo) do
        ChatFrame_RemoveMessageGroup(frame, ChatType)
      end
      
      ChatFrame_AddMessageGroup(frame, "WHISPER")
      ChatFrame_AddMessageGroup(frame, "WHISPER_INFORM")
      frame:Clear()
    end
    
    if cfg["enable_test_whisper_messages"] then
      for index,data in ipairs(testMsgs) do
        local msg = GetMessageFromTableData(data)
        func_frameAddMessage(msg,ADDON_NAME,rd,gd,bd)
      end
      
      if frame and found and DEFAULT_CHAT_FRAME~=frame then
        FCF_StartAlertFlash(frame)
      end
    end

    for index,data in ipairs(history) do
      local msg = GetMessageFromTableData(data)
      if not isCurrentSessionMsg[index] and cfg["desaturated_history_color"] then
        func_frameAddMessage(msg,ADDON_NAME,rd,gd,bd)
      else
        func_frameAddMessage(msg,ADDON_NAME,r,g,b)
      end
    end
    
    isPrinting=nil
    self:SetScript("onupdate",nil)
    self=nil
  end)
end

function f:PLAYER_LOGIN()
  f:UnregisterEvent("PLAYER_LOGIN")
  f:PrintHistoryToChat(2)
end

------------------
-- опции: параметр/описание/значение по умолчанию для дефолт конфига
local options =
{
  {"enable_addon","Включить аддон",true},
  {"enable_test_whisper_messages","Тестовые фейк сообщения в пм",true},
  {"desaturated_history_color","Снижать контраст текста истории",true},
  {"show_time","Показывать время отправки сообщения",true},
  {"show_date_if_it_not_today","Показывать дату если сообщение не сегодняшнее",true},
}

function f:ADDON_LOADED(...) 
  if arg1~=ADDON_NAME then return end
  
  if mrcatsoul_WHistory == nil then 
    mrcatsoul_WHistory = {}
  end
  
  if mrcatsoul_WHistory[UnitName("player").." ~ "..GetRealmName()] == nil then
    mrcatsoul_WHistory[UnitName("player").." ~ "..GetRealmName()] = {}
  end
  
  history = mrcatsoul_WHistory[UnitName("player").." ~ "..GetRealmName()]

  if mrcatsoul_WHistory_Config == nil then
    mrcatsoul_WHistory_Config = {}
    cfg=mrcatsoul_WHistory_Config
    for _,v in ipairs(options) do
      cfg[v[1]]=v[3]
    end
    _print("Инициализация дефолтного конфига. Об аддоне:", LOCALE=="ruRU" and GetAddOnMetadata(ADDON_NAME,"Notes-ruRU") or GetAddOnMetadata(ADDON_NAME,"Notes"))
  end
  
  cfg=mrcatsoul_WHistory_Config
  
  _print("Аддон загружен. Всего сохранено личных сообщений: "..#history..". Настройки: "..ChatLink("Настройки (ТЫК)","Settings").."")
end

-- опции\настройки\конфиг - создание фреймов
local width, height = 800, 500
local settingsScrollFrame = CreateFrame("ScrollFrame",ADDON_NAME.."SettingsScrollFrame",InterfaceOptionsFramePanelContainer,"UIPanelScrollFrameTemplate")
settingsScrollFrame.name = ADDON_NAME_LOCALE_SHORT -- Название во вкладке интерфейса
settingsScrollFrame:SetSize(width, height)
settingsScrollFrame:SetVerticalScroll(10)
settingsScrollFrame:SetHorizontalScroll(10)
settingsScrollFrame:Hide()
_G[ADDON_NAME.."SettingsScrollFrameScrollBar"]:SetPoint("topleft",ADDON_NAME.."SettingsScrollFrame","topright",-25,-25)
_G[ADDON_NAME.."SettingsScrollFrameScrollBar"]:SetFrameLevel(1000)
_G[ADDON_NAME.."SettingsScrollFrameScrollBarScrollDownButton"]:SetPoint("top",ADDON_NAME.."SettingsScrollFrameScrollBar","bottom",0,7)

local settingsFrame = CreateFrame("button", nil, InterfaceOptionsFramePanelContainer)
settingsFrame:SetSize(width, height) 
settingsFrame:SetAllPoints(InterfaceOptionsFramePanelContainer)
settingsFrame:Hide()

settingsScrollFrame:SetScrollChild(settingsFrame)

InterfaceOptions_AddCategory(settingsScrollFrame)

settingsScrollFrame:SetScript("OnShow", function()
  settingsFrame:Show()
end)

settingsScrollFrame:SetScript("OnHide", function()
  settingsFrame:Hide()
end)

settingsFrame.TitleText = settingsFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
settingsFrame.TitleText:SetPoint("TOPLEFT", 24, -16)
settingsFrame.TitleText:SetText(ADDON_NAME_LOCALE)

do
  local f = CreateFrame("button", ADDON_NAME.."_tooltipFrame", settingsFrame)
  f:SetPoint("center",settingsFrame.TitleText,"center")
  f:SetSize(settingsFrame.TitleText:GetStringWidth()+11,settingsFrame.TitleText:GetStringHeight()+1) 
  
  f:SetScript("OnEnter", function(self) 
    GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
    GameTooltip:SetText(""..ADDON_NAME_LOCALE.."\n\n"..ADDON_NOTES.."", nil, nil, nil, nil, true)
    GameTooltip:Show() 
  end)

  f:SetScript("OnLeave", function(self) 
    GameTooltip:Hide() 
  end)
end

-- функция по созданию чекбокса для конфига
local function CreateOptionCheckbox(optionName,optionDescription,num)
  local checkbox = CreateFrame("CheckButton", ADDON_NAME.."_"..optionName, settingsFrame, "UICheckButtonTemplate")
  checkbox:SetPoint("TOPLEFT", settingsFrame.TitleText, "BOTTOMLEFT", 0, -10-(num*10))

  local textFrame = CreateFrame("Button",nil,checkbox) 
  textFrame:SetPoint("LEFT", checkBox, "RIGHT", 0, 0)

  local textRegion = textFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  --textRegion:SetPoint("LEFT", checkbox, "RIGHT", 5, 0)
  textRegion:SetText(optionDescription or "")
  
  textRegion:SetJustifyH("LEFT")
  textRegion:SetJustifyV("BOTTOM")
  
  textRegion:SetAllPoints(textFrame)
  
  textFrame:SetSize(textRegion:GetStringWidth()+50,textRegion:GetStringHeight()) 
  textFrame:SetPoint("LEFT", checkbox, "RIGHT", 0, 0)

  checkbox:SetScript("OnClick", function(self)
    cfg[optionName]=self:GetChecked() and true or false
    f:PrintHistoryToChat()
  end)

  checkbox:SetScript("onshow", function(self)
    self:SetChecked(cfg[optionName]==true and true or false)
  end)
  
  textFrame:SetScript("OnEnter", function(self) 
    GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
    GameTooltip:SetText(optionDescription, 1, 1, 1, nil, true)
    GameTooltip:Show() 
  end)
  
  textFrame:SetScript("OnLeave", function(self) 
    GameTooltip:Hide() 
  end)
  
  textFrame:SetScript("OnClick", function() 
    if checkbox:GetChecked() then
      checkbox:SetChecked(false)
    else
      checkbox:SetChecked(true)
    end
    cfg[optionName] = checkbox:GetChecked() and true or false
  end)
end

do
  local num=0
  for _,v in ipairs(options) do
    CreateOptionCheckbox(v[1],v[2],num)
    num=num+2
  end
end

--------------------------------------------------
-- кнопка очистки истории
--------------------------------------------------
do
  local resetCount=0
  local f = CreateFrame('BUTTON', ADDON_NAME.."_clearHistory", settingsFrame, 'UIPanelButtonTemplate')
  f:SetPoint("RIGHT", ADDON_NAME.."_tooltipFrame", "RIGHT", 80, 0)
  f:SetFrameLevel(1000)
  f:SetHeight(30)
  f:SetWidth(70)
  f:Show()
  _G[ADDON_NAME.."_clearHistoryText"]:SetFont("GameFontNormal", 14)
  _G[ADDON_NAME.."_clearHistoryText"]:SetTextColor(1, 0.1, 0, 1)
  _G[ADDON_NAME.."_clearHistoryText"]:SetText('Очистить\nИсторию')
  f:SetScript('OnClick',function()
    resetCount=resetCount+1
    --GameTooltip:Show()
    if resetCount >= 5 then
      resetCount=0
      table.wipe(history)
      --mrcatsoul_WHistory[UnitName("player")..", "..GetRealmName()]=history
      --mrcatsoul_WHistory={}
      _G[ADDON_NAME.."_frame"]:PrintHistoryToChat()
      GameTooltip:SetText("История пм очищена.")
      _print("История пм очищена.")
      UIFrameFlash(settingsFrame, 1.5, 0.5, 2, true, 2, 0)
    else
      local needCount=5-resetCount
      _print("Чтобы выполнить очистку истории нажать ещё "..needCount.." раз(а)")
      GameTooltip:SetText("Чтобы выполнить очистку истории нажать 5 раз.|r\nОсталось "..(5-resetCount).." раз(а).")
    end
  end)
  
  f:SetScript("OnEnter", function(self) 
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    if resetCount==0 then
      GameTooltip:SetText("Чтобы выполнить очистку истории нажать 5 раз.")
    else
      GameTooltip:SetText("Чтобы выполнить очистку истории нажать 5 раз.\nОсталось "..(5-resetCount).." раз(а).")
    end
    GameTooltip:Show() 
  end)

  f:SetScript("OnLeave", function(self) 
    GameTooltip:Hide() 
  end)
end

f.settingsScrollFrame = settingsScrollFrame
