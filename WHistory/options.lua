local ADDON_NAME, ns = ...
if not ns.frame then ns.frame = CreateFrame("frame", ADDON_NAME.."_frame") end
local core = ns.frame

local LOCALE = GetLocale()
local ADDON_NAME_LOCALE_SHORT = LOCALE=="ruRU" and GetAddOnMetadata(ADDON_NAME,"TitleS-ruRU") or GetAddOnMetadata(ADDON_NAME,"TitleShort") or ADDON_NAME
local ADDON_NAME_LOCALE = LOCALE=="ruRU" and GetAddOnMetadata(ADDON_NAME,"Title-ruRU") or GetAddOnMetadata(ADDON_NAME,"Title") or ADDON_NAME
local ADDON_NOTES = LOCALE=="ruRU" and GetAddOnMetadata(ADDON_NAME,"Notes-ruRU") or GetAddOnMetadata(ADDON_NAME,"Notes") or "Unknown"
local ADDON_VERSION = GetAddOnMetadata(ADDON_NAME,"Version") or "Unknown"

local _print = core._print 
local ChatLink = core.ChatLink

core:SetScript("OnEvent", function(self, event, ...) if self[event] then self[event](self, ...) end end)
core:RegisterEvent("ADDON_LOADED")

function core:GetCharacterProfileKey()
  return UnitName("player").." ~ "..GetRealmName():gsub("%b[]", ""):gsub("%s+$", "")
end

local cfg,history

------------------
-- опции: параметр/описание/значение по умолчанию для дефолт конфига
local options =
{
  {"enable_addon","Включить аддон",true},
  {"enable_save_history","Включить запись истории",true},
  {"enable_all_players_history_tab","Отображать вкладку чата общей истории пм от всех персонажей с кем общались |cffff0000(могут быть фризы если большой размер истории, при получении и отправке пм)|r",true},
  {"enable_sound_on_message_receive","Играть дефолтный звук при получении пм всегда",true},
  {"enable_tab_flash","Мигание вкладки чата общей истории при получении пм",true},
  {"enable_test_whisper_messages","Тестовые фейк сообщения в пм",true},
  {"desaturated_history_color","Снижать контраст текста истории (серый цвет для старых сообщений)",true},
  {"show_time","Показывать сохранённое время сообщения",true},
  {"show_date_if_it_not_today","Показывать сохранённую дату сообщения если оно не сегодняшнее",true},
  {"focus_all_history_chat_tab_when_received","Фокусить вкладку чата общей истории пм получении сообщения",true},
  {"create_player_PM_chat_tab_when_received","Создавать отдельную приватную вкладку чата для каждого игрока при получении пм от него (приоритет выше чем у опции вверху \"Фокусить вкладку чата общей истории пм получении сообщения\")",true},
  {"focus_player_PM_chat_tab_when_received","Фокусить вкладку пм чата конкретного игрока при получении входящего сообщения от него (приоритет выше чем у опции вверху \"Фокусить вкладку чата общей истории пм получении сообщения\")",true},
}

function core:UnregisterMainEvents()
  core:UnregisterEvent("CHAT_MSG_WHISPER")
  core:UnregisterEvent("CHAT_MSG_WHISPER_INFORM")
  --core:UnregisterEvent("PLAYER_LOGIN")
end

function core:RegisterMainEvents()
  core:RegisterEvent("CHAT_MSG_WHISPER")
  core:RegisterEvent("CHAT_MSG_WHISPER_INFORM")
  --core:RegisterEvent("PLAYER_LOGIN")
end

function core:OnChangeCfg(login)
  if cfg["enable_addon"] then
    core:RegisterMainEvents()
  else
    core:UnregisterMainEvents()
    core:CloseAllTmpChatTabs()
  end
  
  --if not login then
    core.DelayedCall(0.001, function() 
      core:PrintHistoryToChat(ADDON_NAME) -- обновление текста во вкладках при изменении конфига
    end)
  --end
end

function core:InitCfg()
  cfg = mrcatsoul_WHistory_Config or {}
  
  -- [1] - параметр, [2] - описание, [3] - значение по умолчанию
  for _,option in ipairs(options) do
    if cfg[option[1]]==nil then
      core.isFirstLaunch=true
      cfg[option[1]]=option[3]
      _print(""..option[1]..":",tostring(cfg[option[1]]),"(задан параметр по умолчанию)")
    end
  end
  
  if mrcatsoul_WHistory_Config == nil then
    mrcatsoul_WHistory_Config = cfg
    cfg = mrcatsoul_WHistory_Config
    _print("Инициализация конфига. Об аддоне:", ADDON_NOTES)
  end
  
  core.cfg = cfg
  
  if mrcatsoul_WHistory == nil then 
    mrcatsoul_WHistory = {}
  end
  
  local characterProfileKey = core:GetCharacterProfileKey()
  
  if mrcatsoul_WHistory[characterProfileKey] == nil then
    mrcatsoul_WHistory[characterProfileKey] = {}
  end
  
  history = mrcatsoul_WHistory[characterProfileKey]
  core.history = history
  
  core.historyLoaded = true

  _print("История пм загружена. Сохранено пм: |cff33aaff"..#history.."|r. Настройки:|r "..ChatLink("Линк","Settings")..". Данные по истории пм: "..ChatLink("Линк","Show_History").."")
  
  core:_InitCfg()
end

function core:ADDON_LOADED(...)
  if arg1~=ADDON_NAME then 
    return 
  end
  
  core:InitCfg()
  core:OnChangeCfg(true)
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
local function CreateOptionCheckbox(optionName,optionDescription,optNum)
  local checkbox = CreateFrame("CheckButton", ADDON_NAME.."_"..optionName, settingsFrame, "UICheckButtonTemplate")
  checkbox:SetPoint("TOPLEFT", settingsFrame.TitleText, "BOTTOMLEFT", 0, -10-(optNum*10))

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
    _print(""..optionName..":",tostring(cfg[optionName]))
    core:OnChangeCfg()
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
    _print(""..optionName..":",tostring(cfg[optionName]))
    core:OnChangeCfg()
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
  _G[ADDON_NAME.."_clearHistoryText"]:SetText('Очистить\nИсторию пм')
  f:SetScript('OnClick',function()
    resetCount=resetCount+1
    --GameTooltip:Show()
    if resetCount >= 5 then
      resetCount=0
      table.wipe(history)
      core:PrintHistoryToChat(ADDON_NAME)
      GameTooltip:SetText("История пм очищена")
      _print("История пм очищена")
      UIFrameFlash(settingsFrame, 1.5, 0.5, 2, true, 2, 0)
    else
      local needCount=5-resetCount
      _print("Чтобы выполнить очистку истории нажать ещё "..needCount.." раз(а)")
      GameTooltip:SetText("Чтобы выполнить очистку истории нажать 5 раз.\nОсталось "..(5-resetCount).." раз(а).")
    end
  end)
  
  f:SetScript("OnEnter", function(self) 
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    if resetCount==0 then
      GameTooltip:SetText("Чтобы выполнить очистку истории пм нажать 5 раз.")
    else
      GameTooltip:SetText("Чтобы выполнить очистку истории пм нажать 5 раз.\nОсталось "..(5-resetCount).." раз(а).")
    end
    GameTooltip:Show() 
  end)

  f:SetScript("OnLeave", function(self) 
    GameTooltip:Hide() 
  end)
end

core.settingsScrollFrame = settingsScrollFrame
