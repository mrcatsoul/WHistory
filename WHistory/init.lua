local ADDON_NAME, ns = ...
if not ns.frame then ns.frame = CreateFrame("frame", ADDON_NAME.."_frame") end
local core = ns.frame

local LOCALE = GetLocale()
local ADDON_NAME_LOCALE_SHORT = LOCALE=="ruRU" and GetAddOnMetadata(ADDON_NAME,"TitleS-ruRU") or GetAddOnMetadata(ADDON_NAME,"TitleShort") or ADDON_NAME
local ADDON_NAME_LOCALE = LOCALE=="ruRU" and GetAddOnMetadata(ADDON_NAME,"Title-ruRU") or GetAddOnMetadata(ADDON_NAME,"Title") or ADDON_NAME
local ADDON_NOTES = LOCALE=="ruRU" and GetAddOnMetadata(ADDON_NAME,"Notes-ruRU") or GetAddOnMetadata(ADDON_NAME,"Notes") or "Unknown"
local ADDON_VERSION = GetAddOnMetadata(ADDON_NAME,"Version") or "Unknown"

local function _print(msg,msg2,msg3,frame)
  if frame then
    frame:AddMessage("|cff3399ff[|r"..ADDON_NAME_LOCALE_SHORT.."|cff3399ff]|r: "..msg, msg2 and msg2 or "", msg3 and msg3 or "")
  else
    print("|cff3399ff[|r"..ADDON_NAME_LOCALE_SHORT.."|cff3399ff]|r: "..msg, msg2 and msg2 or "", msg3 and msg3 or "")
  end
end
core._print = _print

local DelayedCallFrame = CreateFrame("Frame")  -- Создаем один фрейм для всех отложенных вызовов
local calls = {}  -- Таблица для хранения отложенных вызовов

local function OnUpdate(self, elapsed)
  for i, call in ipairs(calls) do
    call.time = call.time + elapsed
    if call.time >= call.delay then
      call.func()
      table.remove(calls, i)  -- Удаляем вызов из списка
    end
  end
end

DelayedCallFrame:SetScript("OnUpdate", OnUpdate)

-- Основная функция для отложенных вызовов
local function DelayedCall(delay, func)
  table.insert(calls, { delay = delay, time = 0, func = func })
end
core.DelayedCall = DelayedCall

-- чат линк
local function ChatLink(text,option,colorHex,chatTarget)
  text = text or "ТЫК"
  option = option or ""
  chatTarget = chatTarget or ""
  colorHex = colorHex or "71d5ff"
  return "|cff"..colorHex.."|Haddon:"..ADDON_NAME.."_link:"..option..":"..chatTarget..":|h["..text.."|r|cff"..colorHex.."]|h|r"
end
core.ChatLink = ChatLink

DEFAULT_CHAT_FRAME:HookScript("OnHyperlinkClick", function(self, link, str, button, ...)
  local linkType, arg1, option, chatTarget = strsplit(":", link)
  if linkType == "addon" and arg1 and option and arg1==""..ADDON_NAME.."_link" then
    --print(arg1,arg2)
    if option == "Settings" then
      InterfaceOptionsFrame_OpenToCategory(core.settingsScrollFrame)
    elseif option == "Show_History" and chatTarget and chatTarget~="" then
      core:PrintHistoryToChat(chatTarget,nil,true)
    elseif option == "Show_History" then
      --print("qqqqqqqqqqqqqqqqqqqqq")
      core:ShowHistoryTotalStats()
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
