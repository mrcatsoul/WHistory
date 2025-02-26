-- 26.2.25

local ADDON_NAME, ns = ...
if not ns.frame then ns.frame = CreateFrame("frame", ADDON_NAME.."_frame") end
local core = ns.frame

local LOCALE = GetLocale()
local ADDON_NAME_LOCALE_SHORT = LOCALE=="ruRU" and GetAddOnMetadata(ADDON_NAME,"TitleS-ruRU") or GetAddOnMetadata(ADDON_NAME,"TitleShort")
local ADDON_NAME_LOCALE = LOCALE=="ruRU" and GetAddOnMetadata(ADDON_NAME,"Title-ruRU") or GetAddOnMetadata(ADDON_NAME,"Title")
local ADDON_NOTES = LOCALE=="ruRU" and GetAddOnMetadata(ADDON_NAME,"Notes-ruRU") or GetAddOnMetadata(ADDON_NAME,"Notes")
local ADDON_VERSION = GetAddOnMetadata(ADDON_NAME,"Version") or "Unknown"

local currentSessionMsgs,tmpChatTabs,isPrinting={},{},{}
local UPDATE_CHAT_COLOR_Time=0

local YOU_WHISPER_TO = LOCALE=="ruRU" and "Вы шепчете" or "To"
local WHISPERS = LOCALE=="ruRU" and "шепчет" or "whispers"

local DelayedCall = core.DelayedCall
local _print = core._print
local ChatLink = core.ChatLink

local cfg,history={},{}

function core:_InitCfg()
  cfg,history=core.cfg,core.history
end

local function contains(table, element)
  for _, value in pairs(table) do
    if (value == element) then
      return true
    end
  end
  return false
end

function core:HasHistoryByName(name,includeTmp)
  local chatTargetHasHistory
  
  for index=1,#history do
    local msgData = history[index]
    if msgData and msgData[4]==name then
      chatTargetHasHistory=true
      break
    end
  end
  
  if not chatTargetHasHistory and includeTmp then
    for index=1,#currentSessionMsgs do
      local msgData = currentSessionMsgs[index]
      if msgData and msgData[4]==name then
        chatTargetHasHistory=true
        break
      end
    end
  end
  
  return chatTargetHasHistory
end

function core:ModifyBlizzStuff()
  if core.modBlizzStuff then return end
  core.modBlizzStuff=true
  --print("modBlizzStuff=true")

  core.FCF_OpenTemporaryWindow = FCF_OpenTemporaryWindow
  
  -- чуть перепишем под аддон близз функ по созданию временной вкладки 
  FCF_OpenTemporaryWindow = function(chatType, chatTarget, sourceChatFrame, selectWindow)
    if chatTarget and chatTarget:find(":"..ADDON_NAME) then
      --if chatTarget~=ADDON_NAME then
        chatTarget=chatTarget:gsub(":"..ADDON_NAME,"")
      --end
      
      if chatTarget and chatTarget~=ADDON_NAME and tmpChatTabs[chatTarget] and not core:HasHistoryByName(chatTarget,true) then
        _print("нет истории лички с ["..chatTarget.."], клоуз пм чат")
        core:CloseTmpChat(tmpChatTabs[chatTarget])
        return nil
      end
      
      --_print("FCF_OpenTemporaryWindow:",chatTarget)
      
      --selectWindow = chatTarget~=ADDON_NAME
      
      if chatTarget and tmpChatTabs[chatTarget] then
        --print("dfsdfsdf")
        if selectWindow then
          FCF_SelectDockFrame(tmpChatTabs[chatTarget])
          --FCFDock_SelectWindow(GENERAL_CHAT_DOCK, tmpChatTabs[chatTarget])
        end
        
        return tmpChatTabs[chatTarget]
      end
    end
    
    local frame = core.FCF_OpenTemporaryWindow(chatType, chatTarget, sourceChatFrame, selectWindow)
    
    if frame then
      tmpChatTabs[chatTarget]=frame
      frame.__chatTarget = chatTarget
    end
    
    return frame
  end
  
  local TestDropdownMenuList1 = { "FRIEND" }
  
  for _, v in pairs(TestDropdownMenuList1) do
    table.insert(UnitPopupMenus[v], #UnitPopupMenus[v] - 1, ""..ADDON_NAME.."_SHOW_HISTORY_UNIT_POPUP_BUTTON")
    table.insert(UnitPopupMenus[v], #UnitPopupMenus[v] - 1, ""..ADDON_NAME.."_DELETE_HISTORY_UNIT_POPUP_BUTTON")
  end

  UnitPopupButtons[""..ADDON_NAME.."_SHOW_HISTORY_UNIT_POPUP_BUTTON"] = {
    text = "|cff3399ffИстория лички|r",
    dist = 0,
    func = function(self)
      local name = UIDROPDOWNMENU_INIT_MENU.name
      core:PrintHistoryToChat(name,nil,true)
    end
  }

  UnitPopupButtons[""..ADDON_NAME.."_DELETE_HISTORY_UNIT_POPUP_BUTTON"] = {
    text = "|cffff3322Удалить историю|r",
    dist = 0,
    func = function(self)
      local name = UIDROPDOWNMENU_INIT_MENU.name
      if name then
        name = PlayerWhisperHyperLink(name)
        local popup = StaticPopup_Show(""..ADDON_NAME.."_DELETE_HISTORY_STATIC_POPUP", name)
        if popup then 
          popup.data = name 
        end
      end
    end
  }
  
  hooksecurefunc("UnitPopup_ShowMenu", core.UnitPopup_ShowMenu_Hook)

  hooksecurefunc("FCF_Close", function(frame) 
    --print("FCF_Close",1)
    if frame and frame.__chatTarget then
      --print("FCF_Close",frame.__chatTarget)
      tmpChatTabs[frame.__chatTarget]=nil
    end
  end)

  StaticPopupDialogs[""..ADDON_NAME.."_DELETE_HISTORY_STATIC_POPUP"] = {
    --text		  = ""..icons["rooster"].." |cff00bbeeДобавить в список пидрил [%s]?|r",
    text		  = "|cff5599ffУдалить историю лички для [|r%s|cff5599ff]?|r",
    button1		= YES,
    button2		= CANCEL,
    exclusive	= 0,
    timeout   = 0,
    whileDead = 1,
    --notClosableByLogout = 1,
    showAlert = 1,
    --showAlertGear = 1,
    --closeButton = 1,
    OnHide = function(self)
      self:Hide()
    end,
    OnAccept = function(self)
      local name=self.data
      core:DeleteHistoryByName(name)
      self:Hide()
    end,
    OnCancel = function(self)
      self:Hide()
    end,
    hideOnEscape = 1,
  }	
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

function core:UnitPopup_ShowMenu_Hook(self)
  local name = UIDROPDOWNMENU_INIT_MENU.name
  --print(UIDROPDOWNMENU_INIT_MENU.chatType)
	for i=1, UIDROPDOWNMENU_MAXBUTTONS do
		local button = _G["DropDownList"..UIDROPDOWNMENU_MENU_LEVEL.."Button"..i]
		if button.value == ""..ADDON_NAME.."_SHOW_HISTORY_UNIT_POPUP_BUTTON" then
      button.func = UnitPopupButtons[""..ADDON_NAME.."_SHOW_HISTORY_UNIT_POPUP_BUTTON"].func
    elseif button.value == ""..ADDON_NAME.."_DELETE_HISTORY_UNIT_POPUP_BUTTON" then
      button.func = UnitPopupButtons[""..ADDON_NAME.."_DELETE_HISTORY_UNIT_POPUP_BUTTON"].func
    elseif button.value == MOVE_TO_WHISPER_WINDOW then
      core:PrintHistoryToChat(name,nil,true)
    end
	end
end

function core:CloseTmpChat(frame)
  if frame and frame.__chatTarget then
    _print("CloseTmpChat",frame.__chatTarget)
    tmpChatTabs[frame.__chatTarget]=nil
    FCF_Close(frame)
  end
end

function core:DeleteHistoryByName(targetName)
  if not targetName then return end
  
  for index = #history, 1, -1 do
    local data=history[index]
    if data then
      --local name=data[4]
      --local msg=data[6]
      if data[4]==targetName then
        --print("DeleteHistoryByName",name,msg)
        --history[index]=nil
        table.remove(history,index)
      end
    end
  end
  
  for name in pairs(tmpChatTabs) do
    core:PrintHistoryToChat(name)
  end
end

-- local function PlayerHyperLink(name)
  -- return "|Hplayer:"..name.."|h"..name.."|h"
-- end

local function PlayerWhisperHyperLink(name,classColor,addBrackets)
  local link

  if name then
    classColor = classColor or classColors[core:GetClassByName(name)] or "999999"
  
    if addBrackets then
      link = "|Hplayer:"..name..":WHISPER:"..string.upper(name).."|h[|cff"..classColor..""..name.."|r]|h"
    else
      link = "|Hplayer:"..name..":WHISPER:"..string.upper(name).."|h|cff"..classColor..""..name.."|r|h"
    end
  else
    link = addBrackets and "|cff999999[UNKNOWN]|r" or "|cff999999UNKNOWN|r"
  end
  
  return link
end

function core:OnNewMessage(isFrom,...)
  if not cfg["enable_addon"] or not core.historyLoaded then return end
  --print("OnNewMessage",isFrom)
  local msg, nameRealm, _, _, name, status, _, _, _, _, _, guid = ... 
  local class = select(2,GetPlayerInfoByGUID(guid))
  nameRealm = nameRealm or "UNKNOWN"
  --local realm = nameRealm and nameRealm:match("-(.+)")) or select(7,GetPlayerInfoByGUID(guid))
  --history[num] = { isFrom = isFrom, time = "|cff777777["..date("%H:%M:%S", time()).."]|r [|cff"..classColors[class]..""..PlayerHyperLink(nameRealm).."|r]: "..text.."" }
  --local index = #history+1
  
  if isFrom and cfg["enable_sound_on_message_receive"] then
    PlaySound("TellMessage")
  end
  
  local msgData = 
  { 
    isFrom, -- true == входящее мсг, false == исходящее
    date("%d.%m.%y"), 
    date("%H:%M:%S", time()), 
    nameRealm or "UNKNOWN", 
    class and ClassToNumber[class] or ClassToNumber["UNKNOWN"], 
    --guid = guid or "UNKNOWN",
    --realm = 
    msg or "",
  }
  
  if cfg["enable_save_history"] then
    table.insert(history,msgData)
  end
  
  table.insert(currentSessionMsgs,msgData)
  --currentSessionMsgs[index]=history[index]
  
  local lastMsgFull = core:GetFullMessageFromTableData(msgData, nameRealm)
  
  --local old=GetCVar("showTimestamps")
  --SetCVar("showTimestamps","none")
  --if GetCVar("showTimestamps")=="none" or CHAT_TIMESTAMP_FORMAT==nil then
    local shouldFocusPMTab = isFrom and (cfg["focus_player_PM_chat_tab_when_received"] and nameRealm~="UNKNOWN")
    local shouldFocusHistoryTab = isFrom and cfg["focus_all_history_chat_tab_when_received"] and not shouldFocusPMTab
    local shouldCreatePMTab = cfg["create_player_PM_chat_tab_when_received"] and nameRealm~="UNKNOWN"
    
    core:PrintHistoryToChat(ADDON_NAME,lastMsgFull,shouldFocusHistoryTab,isFrom)
    
    if shouldCreatePMTab or shouldFocusPMTab or tmpChatTabs[nameRealm] then
      core:PrintHistoryToChat(nameRealm,lastMsgFull,shouldFocusPMTab,isFrom)
    end
  --SetCVar("showTimestamps",old)
  --end
  --print("msg saved",nameRealm)
end

function core:UPDATE_CHAT_COLOR()
  if not cfg["enable_addon"] or not core.historyLoaded then return end
  local t=GetTime()
  if UPDATE_CHAT_COLOR_Time>=(t-1) then return end
  --print("UPDATE_CHAT_COLOR_Time")
  UPDATE_CHAT_COLOR_Time = t
  for name in pairs(tmpChatTabs) do
    core:PrintHistoryToChat(name)
  end
end

function core:CloseAllTmpChatTabs()
  if tmpChatTabs then
    for _,frame in pairs(tmpChatTabs) do
      core:CloseTmpChat(frame)
    end
  end
end

function core:CHAT_MSG_WHISPER(...)
  core:OnNewMessage(true,...)
  --core:OnMessageReceived(...)
end

function core:CHAT_MSG_WHISPER_INFORM(...)
  core:OnNewMessage(false,...)
end

--local testTime, testDate = date("%H:%M:%S", time()), date("%d.%m.%y")

-- Функция для генерации случайной даты и времени
function generateRandomDateTime(year)
  -- Генерация случайных значений для дня, месяца и года
  local day = math.random(1, 31)  -- День (от 1 до 31)
  local month = math.random(1, 12)  -- Месяц (от 1 до 12)
  local year = year or math.random(0, 99)  -- Год (от 0 до 99, для представления года в двух цифрах)

  -- Генерация случайного времени
  local hour = math.random(0, 23)  -- Часы (от 0 до 23)
  local minute = math.random(0, 59)  -- Минуты (от 0 до 59)
  local second = math.random(0, 59)  -- Секунды (от 0 до 59)

  -- Форматирование даты в строку "DD.MM.YY"
  local dateStr = string.format("%02d.%02d.%02d", day, month, year)

  -- Форматирование времени в строку "HH:MM:SS"
  local timeStr = string.format("%02d:%02d:%02d", hour, minute, second)

  -- Возвращаем дату и время
  return dateStr, timeStr
end

local testMsgs =
{
  [1] = { true, "", "", "Эйнастяй-x100", 1, "Приветики бро, го бг, устал соло за рейд дамажить" },
  [2] = { true, "", "", "Qp", 3, "Я Зеленая Залупка МУУУУУУУ" },
  [3] = { true, "", "", "Луздетка-x100500", 5, "Я пусси никому не кидающий боп" },
  [4] = { true, "", "", "Моча-x1", 7, "А я просто моча не чекающая точки" },
  [5] = { true, "", "", "Гром", 1, "Величайший в деле, поднимем мотивацию" },
  [6] = { true, "", "", "Эледрон", 5, "вам что скучно там в дсе?" },
  [7] = { true, "", "", "Vrumm-Fan", 4, "Бро я чет думал ты скриптовый, но эт я забухал и не доигрывал просто)) го бг с AssPin, заливать треш" },
  [8] = { true, "", "", "Русскийрэп", 10, "Братишка, я тебе послушать принёс" },
  [9] = { true, "", "", "Абблевуха", 1, "Я робот долбаеб я должен грипать дк ато дк грипать меня" },
  [10] = { true, "", "", "Skillsapped", 7, "Амбуш в е#@ло, инста покрывало" },
  [11] = { true, "", "", "Слезадьявола-Hell", 4, "нет сынок, это маусовер" },
  [12] = { true, "", "", "Dorianlohz", 4, "Был у доктора, поставил мне диагноз \"скулящий петух обиженка\", говорит не лечится" },
  [13] = { true, "", "", "Сфера", 6, "Сервер работает ПРЕКРАСНО! ВСЕГДА!" },
  [14] = { true, "", "", "Vasule", 5, "дай голды пж бро" },
  [15] = { true, "", "", "Антон", 10, "Разговорчики,фарм хк,телега вместа дс - всё что нужно от жизни до и после завода" },
  [16] = { true, "", "", "Прихлоп", 5, "Хочу в модераторы, гмом стало скучно" },
  [16] = { true, "", "", "Ячсмить", 1, "СНАЧАЛАТОПАДИНПАТОМПАСПИМ" },
  [17] = { true, "", "", "Гарпия", 3, "КУКАРЕКУ В ПМ НЕ БРОСИМ, ФЛАГОВ В ОЧКЕ ПЕРДЕЛ НЕ ВОСЕМЬ" },
  [18] = { true, "", "", "Cummerton", 1, "Один дедов грип и ты RIP" },
  [19] = { true, "", "", "Нарезка", 2, "Я ЧИЛАВИК ПАВУК АРТЁМ ПАРКЕР" },
  [20] = { true, "", "", "Destiny", 3, "Я - Легенда" },
}

for k,v in pairs(testMsgs) do
  local d,t = generateRandomDateTime(math.random(23, 24))
  v[2] = d
  v[3] = t
end

-- -- Универсальная функция для преобразования строки
-- local function formatTime(timeStr, separator)
  -- -- Если не задан разделитель, используем двоеточие по умолчанию
  -- separator = separator or ":"
  
  -- timeStr = timeStr:gsub(" ","")

  -- -- Разбиваем строку на части
  -- local hours = timeStr:sub(1, 2)   -- Первые 2 символа (часы)
  -- local minutes = timeStr:sub(3, 4) -- Следующие 2 символа (минуты)
  -- local seconds = timeStr:sub(5, 6) -- Последние 2 символа (секунды)

  -- -- Собираем строку в формате "HH:MM:SS" с указанным разделителем
  -- local formattedStr = hours .. separator .. minutes .. separator .. seconds

  -- return formattedStr
-- end

function core:GetFullMessageFromTableData(msgData,name)
  local fullmsg = ""
  
  local isFrom=msgData[1]
  --local msgDate=formatTime(msgData[2],".")
  --local msgTime=formatTime(msgData[3],":")
  local msgDate=msgData[2]
  local msgTime=msgData[3]
  local senderName=msgData[4]
  local senderClassId=msgData[5]
  local msgText=msgData[6]
  
  if name and name~=senderName then 
    return nil 
  end
  
  local todayDate = date("%d.%m.%y")
  --BetterDate(CHAT_TIMESTAMP_FORMAT, time())
  
  if cfg["show_date_if_it_not_today"] and todayDate~=msgDate then
    fullmsg = "|cff777777["..msgDate..""
    
    if cfg["show_time"] then
      fullmsg = fullmsg .. " "..msgTime.."]|r"
    else
      fullmsg = fullmsg .. "]|r"
    end
  elseif cfg["show_time"] then
    fullmsg = fullmsg .. "|cff777777["..msgTime.."]|r"
  end
  
  local classColor = classColors[NumberToClass[msgData[5]]]
  local nameColoredHyperlink = PlayerWhisperHyperLink(senderName,classColor)
  --local nameColoredHyperlink = "|cff"..classColors[NumberToClass[msgData[5]]]..""..PlayerHyperLink(msgData[4]).."|r"
  
  -- тест: интеграция с чаттером
  if IsAddOnLoaded("Chatter") then
    local wFrom = WHISPERS
    local wTo = YOU_WHISPER_TO
    
    local profile = ChatterDB and ChatterDB["profileKeys"][UnitName("player").." - "..GetRealmName()]
    
    if profile then
      --print(profile)
      local enableChannelNames = ChatterDB["profiles"][profile]["modules"]["Channel Names"]
      
      if enableChannelNames then
        wFrom = ChatterDB["namespaces"]["ChannelNames"]["profiles"][profile]["channels"]["Whisper From"]
        wTo = ChatterDB["namespaces"]["ChannelNames"]["profiles"][profile]["channels"]["Whisper To"]
        
        if isFrom==true then
          fullmsg = fullmsg .. wFrom
        else
          fullmsg = fullmsg .. wTo
        end
        
        fullmsg = fullmsg .. " ["..nameColoredHyperlink.."]:"
      else
        if isFrom==true then
          fullmsg = fullmsg .. " ["..nameColoredHyperlink.."] "..WHISPERS..":"
        else
          fullmsg = fullmsg .. " "..YOU_WHISPER_TO.." ["..nameColoredHyperlink.."]:"
        end
      end
    end
  else
    if isFrom==true then
      fullmsg = fullmsg .. " ["..nameColoredHyperlink.."] "..WHISPERS..":"
    else
      fullmsg = fullmsg .. " "..YOU_WHISPER_TO.." ["..nameColoredHyperlink.."]:"
    end
  end
  
  fullmsg = fullmsg .. " " .. msgText
  
  return fullmsg
end

-- /run FCF_OpenTemporaryWindow("WHISPER","Moriarty")

function core:PrintHistoryToChat(chatTarget,message,selectWindow,flashTab,deleteFromSourceChat)
  if not cfg["enable_addon"] or isPrinting[chatTarget] or not core.historyLoaded then 
    return 
  end

  if not cfg["enable_all_players_history_tab"] and chatTarget==ADDON_NAME then
    if tmpChatTabs[chatTarget] then
      core:CloseTmpChat(tmpChatTabs[chatTarget])
    end
    return
  end
  
  core:ModifyBlizzStuff()
  
  if not core:IsEventRegistered("UPDATE_CHAT_COLOR") then
    core:RegisterEvent("UPDATE_CHAT_COLOR")
  end
  
  --print("PrintHistoryToChat",test,chatTarget)

  -- if not cfg["enable_addon"] then 
    -- for _,frame in pairs(tmpChatTabs) do
      -- core:CloseTmpChat(frame)
    -- end
    -- return 
  -- end
  
  isPrinting[chatTarget]=true

  local info = ChatTypeInfo["WHISPER"]
  local r,g,b=info.r,info.g,info.b
  local rd,gd,bd=r,g,b
  
  if cfg["desaturated_history_color"] then
    rd,gd,bd = desaturateColor(r, g, b, 0.8)
    --rd,gd,bd = brightenColor(desaturatedR, desaturatedG, desaturatedB, 2)
  end
  
  -- WHistory:WHistory
  -- Mori:WHistory
  --local sourceChatFrame = deleteFromSourceChatFrame and chatTarget and ChatChannelDropDown and ChatChannelDropDown.chatFrame
  
  local chatTabExists = tmpChatTabs[chatTarget]~=nil
  
  local frame = FCF_OpenTemporaryWindow("WHISPER", chatTarget..":"..ADDON_NAME, nil, selectWindow)
  
  if message and frame and not chatTabExists then
    ChatFrame_ExcludePrivateMessageTarget(frame, chatTarget) -- фикс дублей отправленых в пм собеседнику в приватной вкладке
  end

  DelayedCall(0.001,function()
    if not frame then 
      isPrinting[chatTarget]=nil
      return
    end
    
    if message and chatTabExists then
      frame:AddMessage(message,r,g,b)
    else
      frame:Clear()
      --frame:AddMessage("Clear()",r,g,b)
      if chatTarget~=ADDON_NAME then
        _print("История диалога с персонажем ["..PlayerWhisperHyperLink(chatTarget).."]:",nil,nil,frame)
      end

      -- test
      if chatTarget==ADDON_NAME then
        if frame and cfg["enable_test_whisper_messages"] then
          for index,msgData in ipairs(testMsgs) do
            local msg = core:GetFullMessageFromTableData(msgData)
            --func_frameAddMessage(msg,frame,rd,gd,bd)
            frame:AddMessage(msg,rd,gd,bd)
          end
          
          -- при первом запуске аддона + добавлении новых опций
          if core.isFirstLaunch and frame and DEFAULT_CHAT_FRAME~=frame then
            core.isFirstLaunch=nil
            
            FCF_StartAlertFlash(frame)
            
            local info = "|cff3399ffПривет. Была создана вкладка чата с названием \""..ADDON_NAME.."\". В ней будет отображаться история пм от всех игроков. Отключить и провести настройки можно через: Игровое меню>Интерфейс>Модификации>"..ADDON_NAME_LOCALE_SHORT.."|r"
            
            _print(info)
            
            RaidWarningFrame:Show()
            RaidNotice_AddMessage(RaidWarningFrame, info, ChatTypeInfo["RAID_WARNING"])
            
            DelayedCall(10,function()
              info = "|cff00bbeeОб аддоне: "..ADDON_NOTES.."|r"
              RaidNotice_AddMessage(RaidWarningFrame, info, ChatTypeInfo["RAID_WARNING"])
              _print(info)
            end)
          end
        end
      end
      
      --local text = ""
      
      -- распечатать в чат currentSessionMsgs, но ТОЛЬКО ТЕ, которые не в history
      for index=1,#currentSessionMsgs do
        local msgData = currentSessionMsgs[index]
        if msgData and not contains(history,msgData) then
          local msg = core:GetFullMessageFromTableData(msgData,chatTarget~=ADDON_NAME and chatTarget)
          if msg then
            frame:AddMessage(msg,r,g,b)
            --text = text=="" and msg or text.."\n"..msg
          end
        end
      end
      
      -- if text~="" then
        -- frame:AddMessage(text,r,g,b)
      -- end
      
      -- text=""
      
      for index=1,#history do
        local msgData = history[index]
        if msgData then
          local msg = core:GetFullMessageFromTableData(msgData,chatTarget~=ADDON_NAME and chatTarget)
          if msg then
            if cfg["desaturated_history_color"] and not contains(currentSessionMsgs,msgData) then
              frame:AddMessage(msg,rd,gd,bd)
              --text = text=="" and msg or text.."\n"..msg
            else
              frame:AddMessage(msg,r,g,b)
              --text = text=="" and msg or text.."\n"..msg
            end
          end
        end
      end
      
      -- if text~="" then
        -- frame:AddMessage(text,r,g,b)
      -- end
    end
    
    if selectWindow then
      --print("selectWindow",chatTarget)
      --FCF_SelectDockFrame(frame)
    elseif flashTab and cfg["enable_tab_flash"] and frame~=SELECTED_CHAT_FRAME and frame.isDocked then
      FCF_StartAlertFlash(frame)
      --FCF_FlashTab(frame)
    end

    isPrinting[chatTarget]=nil
  end)
end

-- function core:PLAYER_LOGIN()
  -- core:UnregisterEvent("PLAYER_LOGIN")
  -- DelayedCall(0.001, function() 
    -- core:PrintHistoryToChat(ADDON_NAME)
  -- end)
-- end

function core:GetClassByName(name)
  local class = "UNKNOWN"
  for index=1,#history do
    local msgData = history[index]
    if msgData and msgData[4]==name then
      class=NumberToClass[msgData[5]]
      break
    end
  end
  return class
end

function core:ShowHistoryTotalStats()
  local info,infoOrdered,totalMsgs,lastMsgDate = {},{},{},{}

  for index = #history, 1, -1 do
    local msgData=history[index]
    
    if msgData then
      local name=msgData[4]
      local classId=msgData[5]
      
      totalMsgs[name] = totalMsgs[name] and totalMsgs[name]+1 or 1
      
      if not lastMsgDate[name] then
        --lastMsgDate[name] = formatTime(msgData[2],".")
        lastMsgDate[name] = msgData[2]
      end

      info[name] = 
      {
        ChatLink(PlayerWhisperHyperLink(name),"Show_History",nil,name),
        totalMsgs[name],
        lastMsgDate[name],
      }
    end
  end
  
  if #history>0 then
    local text,num = "",0
    local link,msgs,_date
    
    _print("среди истории пм есть диалоги с (линки кликабельны):",text)
    
    for _,v in pairs(info) do
      num = num+1
      link = v[1]
      msgs = v[2]
      _date = v[3]
      _print(""..num..") " .. ""..link.." => сообщений: |cff33aaff"..msgs.."|r, последнее: |cff33aaff".._date.."|r")
      --text = text .. "\n"..num..") " .. ""..link.." => сообщений: |cff33aaff"..msgs.."|r, последнее: |cff33aaff".._date.."|r"
    end
    
    --_print("среди истории пм есть диалоги с (линки кликабельны):",text)
  else
    _print("нет истории лички ни с кем")
  end
end

SlashCmdList[ADDON_NAME] = function(chatTarget)
  if not chatTarget or chatTarget=="" then
    core:ShowHistoryTotalStats()
  else
    core:PrintHistoryToChat(chatTarget,nil,true)
  end
end

_G["SLASH_"..ADDON_NAME.."1"] = "/wh"
_G["SLASH_"..ADDON_NAME.."2"] = "/whst"
