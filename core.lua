PvPEncountersState = PvPEncountersState or {}
PvPEncountersSettings = PvPEncountersSettings or {}

if type(PvPEncountersSettings.format) ~= 'string' then
    PvPEncountersSettings.format = "win-lose (%)"
end
if type(PvPEncountersSettings.ShowBattlegroundsWith) ~= 'boolean' then
    PvPEncountersSettings.ShowBattlegroundsWith = true
end
if type(PvPEncountersSettings.ShowBattlegroundsAgaisnt) ~= 'boolean' then
    PvPEncountersSettings.ShowBattlegroundsAgaisnt = true
end
if type(PvPEncountersSettings.Show2v2sWith) ~= 'boolean' then
    PvPEncountersSettings.Show2v2sWith = true
end
if type(PvPEncountersSettings.Show2v2sAgaisnt) ~= 'boolean' then
    PvPEncountersSettings.Show2v2sAgaisnt = true
end
if type(PvPEncountersSettings.Show3v3sWith) ~= 'boolean' then
    PvPEncountersSettings.Show3v3sWith = true
end
if type(PvPEncountersSettings.Show3v3sAgaisnt) ~= 'boolean' then
    PvPEncountersSettings.Show3v3sAgaisnt = true
end
if type(PvPEncountersSettings.ShowOverallsWith) ~= 'boolean' then
    PvPEncountersSettings.ShowOverallsWith = true
end
if type(PvPEncountersSettings.ShowOverallsAgaisnt) ~= 'boolean' then
    PvPEncountersSettings.ShowOverallsAgaisnt = true
end

local PPCAddonName = select(1, ...)
local PPC = select(2, ...) ---@type ns @The addon namespace.
PPC.FACTION_TO_ID = {Alliance = 1, Horde = 2, Neutral = 3}
PPC.EXPANSION = max(LE_EXPANSION_BATTLE_FOR_AZEROTH, GetExpansionLevel())
PPC.MAX_LEVEL = GetMaxLevelForExpansionLevel(PPC.EXPANSION)
PPC.OnInspectReady = nil
PPC.InspectPlayer = nil

PPC_FRAME = {}

local currentResult = {}
local hooked = {}
local completed

local tooltipLFG = PPC:NewModule("LfgTooltip")
local tooltipCommunity = PPC:NewModule("CommunityTooltip")
local tooltipFriend = PPC:NewModule("FriendTooltip")
local tooltipGame = PPC:NewModule("GameTooltip")
local tooltipGuild = PPC:NewModule("GuildTooltip")

local ldb = LibStub:GetLibrary("LibDataBroker-1.1", true)
if not ldb then return end

local plugin = ldb:NewDataObject(PPCAddonName, {
	type = "data source",
	text = "0",
	icon = "Interface\\AddOns\\PvPEncounters\\Media\\icon",
})

PPC.VersatilityPerLevel = {
    0, 3.091154721, 3.091154721, 3.091154721, 3.091154721, 3.091154721, 3.091154721, 3.091154721, 3.091154721, 3.091154721, 3.091154721, 3.091154721, 3.245712457, 3.400270193, 3.554827929, 3.709385665, 3.863943401, 4.018501137, 4.173058873, 4.327616609, 4.482174345, 4.636732081, 4.791289817, 4.945847553, 5.100405289, 5.254963025, 5.414083305, 5.579537691, 5.751610634, 5.930600757, 6.11682162, 6.310602529, 6.512289386, 6.722245596, 6.940853023, 7.168513002, 7.405647412, 7.65269981, 7.910136631, 8.178448466, 8.458151403, 8.773380327, 9.100357595, 9.439521059, 9.79132489, 10.15624018, 10.5347556, 10.92737799, 11.33463313, 11.75706636, 12.19524335, 13.46417035, 14.86513044, 16.4118618, 18.11953208, 20.00488711, 22.08641518, 24.38452828, 26.92176229, 29.72299799, 40.0000001
}

function PPC:ExecuteWidgetHandler(object, handler, ...)
    if type(object) ~= "table" or type(object.GetScript) ~= "function" then
        return false
    end
    local func = object:GetScript(handler)
    if type(func) ~= "function" then
        return
    end
    if not pcall(func, object, ...) then
        return false
    end
    return true
end

function PPC:Average(list)
    local totalsum = 0;
    for i = 1, #list do
        totalsum = totalsum + list[i]
    end
    return totalsum / #list;
end

function PPC:GetNameRealmForBNetFriend(bnetIDAccount, getAllChars)
    local index = BNGetFriendIndex(bnetIDAccount)
    if not index then
        return
    end
    local collection = {}
    local collectionIndex = 0
    for i = 1, C_BattleNet.GetFriendNumGameAccounts(index), 1 do
        local accountInfo = C_BattleNet.GetFriendGameAccountInfo(index, i)
        if accountInfo and accountInfo.clientProgram == BNET_CLIENT_WOW and (not accountInfo.wowProjectID or accountInfo.wowProjectID ~= WOW_PROJECT_CLASSIC) then
            if accountInfo.realmName then
                accountInfo.characterName = accountInfo.characterName .. "-" .. accountInfo.realmName:gsub("%s+", "")
            end
            collectionIndex = collectionIndex + 1
            collection[collectionIndex] = {accountInfo.characterName, PPC.FACTION_TO_ID[accountInfo.factionName], tonumber(accountInfo.characterLevel)}
        end
    end
    if not getAllChars then
        for i = 1, collectionIndex do
            local profile = collection[collectionIndex]
            local name, faction, level = profile[1], profile[2], profile[3]
            if PPC:IsMaxLevel(level) then
                return name, faction, level
            end
        end
        return
    end
    return collection
end

function PPC:IsUnitToken(unit)
    return type(unit) == "string" and UNIT_TOKENS[unit]
end

function PPC:IsUnit(arg1, arg2)
    if not arg2 and type(arg1) == "string" and arg1:find("-", nil, true) then
        arg2 = true
    end
    local isUnit = not arg2 or PPC:IsUnitToken(arg1)
    return isUnit, isUnit and UnitExists(arg1), isUnit and UnitIsPlayer(arg1)
end

function PPC:GetNameRealm(arg1, arg2)
    local unit, name, realm
    local _, unitExists, unitIsPlayer = PPC:IsUnit(arg1, arg2)
    if unitExists then
        unit = arg1
        if unitIsPlayer then
            name, realm = UnitName(arg1)
            realm = realm and realm ~= "" and realm or GetNormalizedRealmName()
        end
        return name, realm, unit
    end
    if type(arg1) == "string" then
        if arg1:find("-", nil, true) then
            name, realm = ("-"):split(arg1)
        else
            name = arg1 -- assume this is the name
        end
        if not realm or realm == "" then
            if type(arg2) == "string" and arg2 ~= "" then
                realm = arg2
            else
                realm = GetNormalizedRealmName() -- assume they are on our realm
            end
        end
    end
    return name, realm, unit
end

---@param object Widget @Any interface widget object that supports the methods GetOwner.
---@param owner Widget @Any interface widget object.
---@param anchor string @`ANCHOR_TOPLEFT`, `ANCHOR_NONE`, `ANCHOR_CURSOR`, etc.
---@param offsetX number @Optional offset X for some of the anchors.
---@param offsetY number @Optional offset Y for some of the anchors.
---@return boolean, boolean @If owner was set arg1 is true. If owner was updated arg2 is true. Otherwise both will be set to face to indicate we did not update the Owner of the widget.
function PPC:SetOwnerSafely(object, owner, anchor, offsetX, offsetY)
    if type(object) ~= "table" or type(object.GetOwner) ~= "function" then
        return
    end
    local currentOwner = object:GetOwner()
    if not currentOwner then
        object:SetOwner(owner, anchor, offsetX, offsetY)
        return true
    end
    offsetX, offsetY = offsetX or 0, offsetY or 0
    local currentAnchor, currentOffsetX, currentOffsetY = object:GetAnchorType()
    currentOffsetX, currentOffsetY = currentOffsetX or 0, currentOffsetY or 0
    if currentAnchor ~= anchor or (currentOffsetX ~= offsetX and abs(currentOffsetX - offsetX) > 0.01) or (currentOffsetY ~= offsetY and abs(currentOffsetY - offsetY) > 0.01) then
        object:SetOwner(owner, anchor, offsetX, offsetY)
        return true
    end
    return false, true
end

---@param level number @The level to test
---@param fallback boolean @If level isn't provided, we'll fallback to this boolean
function PPC:IsMaxLevel(level, fallback)
    if level and type(level) == "number" then
        return level >= PPC.MAX_LEVEL - 10
    end
    return fallback
end

---@param unit string
---@param fallback boolean @If unit isn't valid (doesn't exists or not a player), we'll fallback to this number
function PPC:IsUnitMaxLevel(unit, fallback)
    if unit and UnitExists(unit) and UnitIsPlayer(unit) then
        return PPC:IsMaxLevel(UnitLevel(unit), fallback)
    end
    return fallback
end

function PPC:HasRealmName(name)
    if string.find(name, "-") then
        return true
    end
    return false
end

function PPC:GetFullName(name)
    local hasRealmName = PPC:HasRealmName(name)
    if not hasRealmName then
        --TODO, Figure a way to get the realm name
        name = name.."-"..GetRealmName()
    end
    return name
end

function PPC:GetCharacterName(fullname)
    local t={}
    for str in string.gmatch(fullname, "[^-]+") do
        return str
    end
    return fullname
end

function PPC:AddArenaDataLine(tooltip, index, name)
    local rating, seasonPlayed, seasonWon, weeklyPlayed, weeklyWon = GetInspectArenaData(index)
    if rating and seasonPlayed and seasonWon then
        local seasonLost = seasonPlayed - seasonWon
        local winrate = 0
        if seasonWon > 0 and seasonLost > 0 then
            winrate = math.floor(seasonWon * 100 / seasonPlayed * 100) / 100
        else
            if seasonWon > 0 then
                winrate = 100
            else
                winrate = 0
            end
        end
        if winrate > 50 then
            tooltip:AddDoubleLine(name..":", format("%sCR %s/%s (%s%%)", rating, seasonWon, seasonLost + seasonWon, winrate), 1, 1, 1, 0 ,1, 0)
        else
            if winrate < 50 and seasonLost > 0 then
                tooltip:AddDoubleLine(name..":", format("%sCR %s/%s (%s%%)", rating, seasonWon, seasonLost + seasonWon, winrate), 1, 1, 1, 1 ,0, 0)
            else
                tooltip:AddDoubleLine(name..":", format("%sCR %s/%s (%s%%)", rating, seasonWon, seasonLost + seasonWon, winrate), 1, 1, 1, 1 ,1, 1)
            end
        end
        tooltip:Show()
    end
end

function PPC:GetVersatilityFromEnchant(enchantId)
    --Hard coded until i figure how to get stats from enchant id...for this expension those are the only enchant that give verst.
    if enchantId then
        if enchantId == "6170" then
            return 16
        end
        if enchantId == "6169" then
            return 12
        end
    end
    return 0
end

function PPC:GetVersatilityFromGem(gemId)
    --Hard coded until i figure how to get stats from enchant id...for this expension those are the only enchant that give verst.
    if gemId then
        if gemId == "173129" then
            return 16
        end
        if gemId == "173123" then
            return 12
        end
    end
    return 0
end

function PPC:ShowPlayerStatistics(tooltip, fullName)
    local characterName = PPC:GetCharacterName(fullName)
    --if CanInspect(characterName, false) then
        PPC.OnInspectReady = function(guid)
            local locClass, engClass, locRace, engRace, gender, name, server = GetPlayerInfoByGUID(guid);
            if name ~= nil and name == characterName then
                PPC.OnInspectReady = nil
                PPC.InspectPlayer = nil
                local nameToUse = "mouseover"
                local ilvl = C_PaperDollInfo.GetInspectItemLevel(nameToUse)
                if ilvl == 0 then
                    nameToUse = characterName
                    ilvl = C_PaperDollInfo.GetInspectItemLevel(nameToUse)
                end
                if ilvl > 0 then
                    tooltip:AddDoubleLine("Item level:", ilvl, 1, 1, 1, 128 / 255 , 128 / 255, 128 / 255)
                end
                --
                local totalVersatility = 0
                for i=1, 17 do
                    local itemLink = GetInventoryItemLink(nameToUse, i)
                    if itemLink then
                        local itemStats = GetItemStats(itemLink) or {};
                        for statName, value in pairs(itemStats or {}) do
                            if statName == "ITEM_MOD_VERSATILITY" then
                                totalVersatility = totalVersatility + value
                            end
                        end
                        local itemId, enchantId, gem1, gem2, gem3, gem4 = itemLink:match("item:(%d*):(%d*):(%d*):(%d*):(%d*):(%d*)")
                        totalVersatility = totalVersatility + PPC:GetVersatilityFromEnchant(enchantId)
                        totalVersatility = totalVersatility + PPC:GetVersatilityFromGem(gem1)
                        totalVersatility = totalVersatility + PPC:GetVersatilityFromGem(gem2)
                        totalVersatility = totalVersatility + PPC:GetVersatilityFromGem(gem3)
                        totalVersatility = totalVersatility + PPC:GetVersatilityFromGem(gem4)
                    end
                end

                if totalVersatility > 0 then
                    local versatilityPercent = string.format("%.2f", totalVersatility / 40.0000001)
                    tooltip:AddDoubleLine("Versatility:", totalVersatility.." "..versatilityPercent.."%", 1, 1, 1, 128 / 255 , 128 / 255, 128 / 255)
                end
                --
                tooltip:AddLine("Season stats:")
                PPC:AddArenaDataLine(tooltip, 1, "2v2")
                PPC:AddArenaDataLine(tooltip, 2, "3v3")
                PPC:AddArenaDataLine(tooltip, 4, "10v10")
            end
        end
        if PPC.InspectPlayer == nil then
            PPC.InspectPlayer = characterName
            C_Timer.After(1,function()
                if PPC.OnInspectReady ~= nil then
                    NotifyInspect("mouseover")
                end
            end)
        end
    --end
end

function PPC:FormatStatistics(won, lost, winrate)
    if PvPEncountersSettings.format == "win-lose (%)" then
        return format("%s-%s (%s%%)", won, lost, winrate)
    else
        return format("%s/%s (%s%%)", won, lost + won, winrate)
    end
end

function PPC:ShowPlayerTooltip(fullName, tooltip, addTitle)
    local exists = PvPEncountersState[fullName]
    if exists == nil then
        -- if addTitle then
        --     tooltip:AddLine("PvP Encounters", nil, nil, nil, 1)
        -- end
        -- tooltip:AddDoubleLine("Battlegrounds:", "---", 1, 1, 1, 128 / 255 , 128 / 255, 128 / 255)
        -- tooltip:AddDoubleLine("2v2:", "---", 1, 1, 1, 128 / 255 , 128 / 255, 128 / 255)
        -- tooltip:AddDoubleLine("3v3:", "---", 1, 1, 1, 128 / 255 , 128 / 255, 128 / 255)
        -- tooltip:AddDoubleLine("Overall:", "---", 1, 1, 1, 128 / 255 , 128 / 255, 128 / 255)
        -- PPC:ShowPlayerStatistics(tooltip, fullName)
        return true, fullName
    else
        if addTitle then
            tooltip:AddLine("PvP Encounters", nil, nil, nil, 1)
        end
        --Encounters stats
        if true then
            --Fix for older versions
            if type(exists.threesWon) ~= 'number' then
                exists.threesWon = 0;
            end
            if type(exists.threesLost) ~= 'number' then
                exists.threesLost = 0;
            end
            if type(exists.twosWon) ~= 'number' then
                exists.twosWon = 0;
            end
            if type(exists.twosLost) ~= 'number' then
                exists.twosLost = 0;
            end
            --
            if type(exists.threesWonAgaisnt) ~= 'number' then
                exists.threesWonAgaisnt = 0;
            end
            if type(exists.threesLostAgaisnt) ~= 'number' then
                exists.threesLostAgaisnt = 0;
            end
            if type(exists.twosWonAgaisnt) ~= 'number' then
                exists.twosWonAgaisnt = 0;
            end
            if type(exists.twosLostAgaisnt) ~= 'number' then
                exists.twosLostAgaisnt = 0;
            end
            if type(exists.battlegroundWonAgaisnt) ~= 'number' then
                exists.battlegroundWonAgaisnt = 0;
            end
            if type(exists.battlegroundLostAgaisnt) ~= 'number' then
                exists.battlegroundLostAgaisnt = 0;
            end
            --Delete this in older versions...
            if type(exists.arenaWon) == 'number' then
                exists.arenaWon = nil;
                exists.arenaLost = nil;
            end
            local arenaWon = exists.threesWon + exists.twosWon
            local arenaLost = exists.threesLost + exists.twosLost
            --Battlegrounds
            local bgwinrate = 0
            if exists.battlegroundWon > 0 or exists.battlegroundLost > 0 then
                if exists.battlegroundWon < 1 then
                    exists.battlegroundWon = 0
                end
                if exists.battlegroundLost < 1 then
                    exists.battlegroundLost = 0
                end
                bgwinrate = math.floor(exists.battlegroundWon * 100 / (exists.battlegroundWon + exists.battlegroundLost) * 100) / 100
                if PvPEncountersSettings.ShowBattlegroundsWith then
                    if bgwinrate > 50 then
                        tooltip:AddDoubleLine("Battlegrounds:", PPC:FormatStatistics(exists.battlegroundWon, exists.battlegroundLost, bgwinrate), 1, 1, 1, 0 ,1, 0)
                    else
                        if bgwinrate < 50 and exists.battlegroundLost > 0 then
                            tooltip:AddDoubleLine("Battlegrounds:", PPC:FormatStatistics(exists.battlegroundWon, exists.battlegroundLost, bgwinrate) , 1, 1, 1, 1 ,0, 0)
                        else
                            tooltip:AddDoubleLine("Battlegrounds:", PPC:FormatStatistics(exists.battlegroundWon, exists.battlegroundLost, bgwinrate), 1, 1, 1, 1 ,1, 1)
                        end
                    end
                end
            end
            --2v2
            local arena2winrate = 0
            if exists.twosWon > 0 or exists.twosLost > 0 then
                if exists.twosWon < 1 then
                    exists.twosWon = 0
                end
                if exists.twosLost < 1 then
                    exists.twosLost = 0
                end
                arena2winrate = math.floor(exists.twosWon * 100 / (exists.twosWon + exists.twosLost) * 100) / 100
                if PvPEncountersSettings.Show2v2sWith then
                    if arena2winrate > 50 then
                        tooltip:AddDoubleLine("2v2:", PPC:FormatStatistics(exists.twosWon, exists.twosLost, arena2winrate), 1, 1, 1, 0 ,1, 0)
                    else
                        if arena2winrate < 50 and exists.twosLost > 0 then
                            tooltip:AddDoubleLine("2v2:", PPC:FormatStatistics(exists.twosWon, exists.twosLost, arena2winrate), 1, 1, 1, 1 ,0, 0)
                        else
                            tooltip:AddDoubleLine("2v2:", PPC:FormatStatistics(exists.twosWon, exists.twosLost, arena2winrate), 1, 1, 1, 1 ,1, 1)
                        end
                    end
                end
            end
            --3v3
            local arena3winrate = 0
            if exists.threesWon > 0 or exists.threesLost > 0 then
                if exists.threesWon < 1 then
                    exists.threesWon = 0
                end
                if exists.threesLost < 1 then
                    exists.threesLost = 0
                end
                arena3winrate = math.floor(exists.threesWon * 100 / (exists.threesWon + exists.threesLost) * 100) / 100
                if PvPEncountersSettings.Show3v3sWith then
                    if arena3winrate > 50 then
                        tooltip:AddDoubleLine("3v3:", PPC:FormatStatistics(exists.threesWon, exists.threesLost, arena3winrate), 1, 1, 1, 0 ,1, 0)
                    else
                        if arena3winrate < 50 and exists.threesLost > 0 then
                            tooltip:AddDoubleLine("3v3:", PPC:FormatStatistics(exists.threesWon, exists.threesLost, arena3winrate), 1, 1, 1, 1 ,0, 0)
                        else
                            tooltip:AddDoubleLine("3v3:", PPC:FormatStatistics(exists.threesWon, exists.threesLost, arena3winrate), 1, 1, 1)
                        end
                    end
                end
            end
            --Overall
            local won = arenaWon + exists.battlegroundWon
            local lost = arenaLost + exists.battlegroundLost
            local winrate = 0
            if won > 0 or lost > 0 then
                if won < 1 then
                    won = 0
                end
                if lost < 1 then
                    lost = 0
                end
                winrate = math.floor(won * 100 / (won + lost) * 100) / 100
                if PvPEncountersSettings.ShowOverallsWith then
                    if winrate > 50 then
                        tooltip:AddDoubleLine("Overall with:", PPC:FormatStatistics(won, lost, winrate), 1, 1, 1, 0 ,1, 0)
                    else
                        if winrate < 50 and lost > 0 then
                            tooltip:AddDoubleLine("Overall with:", PPC:FormatStatistics(won, lost, winrate), 1, 1, 1, 1 ,0, 0)
                        else
                            tooltip:AddDoubleLine("Overall with:", PPC:FormatStatistics(won, lost, winrate), 1, 1, 1)
                        end
                    end
                end
            end
            --Agaisnt
            local arenaWonAgaisnt = exists.threesWonAgaisnt + exists.twosWonAgaisnt
            local arenaLostAgaisnt = exists.threesLostAgaisnt + exists.twosLostAgaisnt
            --Battlegrounds
            local bgwinrateAgaisnt = 0
            if exists.battlegroundWonAgaisnt > 0 or exists.battlegroundLostAgaisnt > 0 then
                if exists.battlegroundWonAgaisnt < 1 then
                    exists.battlegroundWonAgaisnt = 0
                end
                if exists.battlegroundLostAgaisnt < 1 then
                    exists.battlegroundLosAgaisntt = 0
                end
                bgwinrateAgaisnt = math.floor(exists.battlegroundWonAgaisnt * 100 / (exists.battlegroundWonAgaisnt + exists.battlegroundLostAgaisnt) * 100) / 100
                if PvPEncountersSettings.ShowBattlegroundsAgaisnt then
                    if bgwinrateAgaisnt > 50 then
                        tooltip:AddDoubleLine("Battlegrounds agaisnt:", PPC:FormatStatistics(exists.battlegroundWonAgaisnt, exists.battlegroundLostAgaisnt, bgwinrateAgaisnt), 1, 1, 1, 0 ,1, 0)
                    else
                        if bgwinrateAgaisnt < 50 and exists.battlegroundLostAgaisnt > 0 then
                            tooltip:AddDoubleLine("Battlegrounds agaisnt:", PPC:FormatStatistics(exists.battlegroundWonAgaisnt, exists.battlegroundLostAgaisnt, bgwinrateAgaisnt), 1, 1, 1, 1 ,0, 0)
                        else
                            tooltip:AddDoubleLine("Battlegrounds agaisnt:", PPC:FormatStatistics(exists.battlegroundWonAgaisnt, exists.battlegroundLostAgaisnt, bgwinrateAgaisnt), 1, 1, 1, 1 ,1, 1)
                        end
                    end
                end
            end
            --2v2
            local arena2winrateAgaisnt = 0
            if exists.twosWonAgaisnt > 0 or exists.twosLostAgaisnt > 0 then
                if exists.twosWonAgaisnt < 1 then
                    exists.twosWonAgaisnt = 0
                end
                if exists.twosLostAgaisnt < 1 then
                    exists.twosLostAgaisnt = 0
                end
                arena2winrateAgaisnt = math.floor(exists.twosWonAgaisnt * 100 / (exists.twosWonAgaisnt + exists.twosLostAgaisnt) * 100) / 100
                if PvPEncountersSettings.Show2v2sAgaisnt then
                    if arena2winrateAgaisnt > 50 then
                        tooltip:AddDoubleLine("2v2 agaisnt:", PPC:FormatStatistics(exists.twosWonAgaisnt, exists.twosLostAgaisnt, arena2winrateAgaisnt), 1, 1, 1, 0 ,1, 0)
                    else
                        if arena2winrateAgaisnt < 50 and exists.twosLostAgaisnt > 0 then
                            tooltip:AddDoubleLine("2v2 agaisnt:", PPC:FormatStatistics(exists.twosWonAgaisnt, exists.twosLostAgaisnt, arena2winrateAgaisnt), 1, 1, 1, 1 ,0, 0)
                        else
                            tooltip:AddDoubleLine("2v2 agaisnt:", PPC:FormatStatistics(exists.twosWonAgaisnt, exists.twosLostAgaisnt, arena2winrateAgaisnt), 1, 1, 1, 1 ,1, 1)
                        end
                    end
                end
            end
            --3v3
            local arena3winrateAgaisnt = 0
            if exists.threesWonAgaisnt > 0 or exists.threesLostAgaisnt > 0 then
                if exists.threesWonAgaisnt < 1 then
                    exists.threesWonAgaisnt = 0
                end
                if exists.threesLostAgaisnt < 1 then
                    exists.threesLostAgaisnt = 0
                end
                arena3winrateAgaisnt = math.floor(exists.threesWonAgaisnt * 100 / (exists.threesWonAgaisnt + exists.threesLostAgaisnt) * 100) / 100
                if PvPEncountersSettings.Show3v3sAgaisnt then
                    if arena3winrateAgaisnt > 50 then
                        tooltip:AddDoubleLine("3v3 agaisnt:", PPC:FormatStatistics(exists.threesWonAgaisnt, exists.threesLostAgaisnt, arena3winrateAgaisnt), 1, 1, 1, 0 ,1, 0)
                    else
                        if arena3winrateAgaisnt < 50 and exists.threesLostAgaisnt > 0 then
                            tooltip:AddDoubleLine("3v3 agaisnt:", PPC:FormatStatistics(exists.threesWonAgaisnt, exists.threesLostAgaisnt, arena3winrateAgaisnt), 1, 1, 1, 1 ,0, 0)
                        else
                            tooltip:AddDoubleLine("3v3 agaisnt:", PPC:FormatStatistics(exists.threesWonAgaisnt, exists.threesLostAgaisnt, arena3winrateAgaisnt), 1, 1, 1)
                        end
                    end
                end
            end
            --Overall
            local wonAgaisnt = arenaWonAgaisnt + exists.battlegroundWonAgaisnt
            local lostAgaisnt = arenaLostAgaisnt + exists.battlegroundLostAgaisnt
            local winrateAgaisnt = 0
            if wonAgaisnt > 0 or lostAgaisnt > 0 then
                if wonAgaisnt < 1 then
                    wonAgaisnt = 0
                end
                if lostAgaisnt < 1 then
                    lostAgaisnt = 0
                end
                winrateAgaisnt = math.floor(wonAgaisnt * 100 / (wonAgaisnt + lostAgaisnt) * 100) / 100
                if PvPEncountersSettings.ShowOverallsAgaisnt then
                    if winrateAgaisnt > 50 then
                        tooltip:AddDoubleLine("Overall agaisnt:", PPC:FormatStatistics(wonAgaisnt, lostAgaisnt, winrateAgaisnt), 1, 1, 1, 0 ,1, 0)
                    else
                        if winrateAgaisnt < 50 and lostAgaisnt > 0 then
                            tooltip:AddDoubleLine("Overall agaisnt:", PPC:FormatStatistics(wonAgaisnt, lostAgaisnt, winrateAgaisnt), 1, 1, 1, 1 ,0, 0)
                        else
                            tooltip:AddDoubleLine("Overall agaisnt:", PPC:FormatStatistics(wonAgaisnt, lostAgaisnt, winrateAgaisnt), 1, 1, 1)
                        end
                    end
                end
            end
        end
        -- PPC:ShowPlayerStatistics(tooltip, fullName)
        return true, fullName
    end
end

function PPC:AddWinLostToPlayer(player, won, battleground, numPlayers)
    -- print("AddWinLost to "..player)
    local exists = PvPEncountersState[player]
    -- Add the Encounter if new player
    if exists == nil then
        PvPEncountersState[player] = {}
        PvPEncountersState[player].battlegroundWon = 0;
        PvPEncountersState[player].battlegroundLost = 0;
        PvPEncountersState[player].arenaWon = 0;
        PvPEncountersState[player].arenaLost = 0;
        PvPEncountersState[player].threesWon = 0;
        PvPEncountersState[player].threesLost = 0;
        PvPEncountersState[player].twosWon = 0;
        PvPEncountersState[player].twosLost = 0;
        --
        PvPEncountersState[player].battlegroundWonAgaisnt = 0;
        PvPEncountersState[player].battlegroundLostAgaisnt = 0;
        PvPEncountersState[player].arenaWonAgaisnt = 0;
        PvPEncountersState[player].arenaLostAgaisnt = 0;
        PvPEncountersState[player].threesWonAgaisnt = 0;
        PvPEncountersState[player].threesLostAgaisnt = 0;
        PvPEncountersState[player].twosWonAgaisnt = 0;
        PvPEncountersState[player].twosLostAgaisnt = 0;
    end
    -- Increase Encouter variable
    if battleground then
        if won then
            PvPEncountersState[player].battlegroundWon = PvPEncountersState[player].battlegroundWon + 1;
        else
            PvPEncountersState[player].battlegroundLost = PvPEncountersState[player].battlegroundLost + 1;
        end
    else
        if numPlayers > 4 then--3v3
            if won then
                PvPEncountersState[player].threesWon = PvPEncountersState[player].threesWon + 1;
            else
                PvPEncountersState[player].threesLost = PvPEncountersState[player].threesLost + 1;
            end
        else--2v2
            if won then
                PvPEncountersState[player].twosWon = PvPEncountersState[player].twosWon + 1;
            else
                PvPEncountersState[player].twosLost = PvPEncountersState[player].twosLost + 1;
            end
        end
    end
end

function PPC:AddWinLostAgaisntPlayer(player, won, battleground, numPlayers)
    -- print("AddWinLost to "..player)
    local exists = PvPEncountersState[player]
    -- Add the Encounter if new player
    if exists == nil then
        PvPEncountersState[player] = {}
        PvPEncountersState[player].battlegroundWon = 0;
        PvPEncountersState[player].battlegroundLost = 0;
        PvPEncountersState[player].arenaWon = 0;
        PvPEncountersState[player].arenaLost = 0;
        PvPEncountersState[player].threesWon = 0;
        PvPEncountersState[player].threesLost = 0;
        PvPEncountersState[player].twosWon = 0;
        PvPEncountersState[player].twosLost = 0;
        --
        PvPEncountersState[player].battlegroundWonAgaisnt = 0;
        PvPEncountersState[player].battlegroundLostAgaisnt = 0;
        PvPEncountersState[player].arenaWonAgaisnt = 0;
        PvPEncountersState[player].arenaLostAgaisnt = 0;
        PvPEncountersState[player].threesWonAgaisnt = 0;
        PvPEncountersState[player].threesLostAgaisnt = 0;
        PvPEncountersState[player].twosWonAgaisnt = 0;
        PvPEncountersState[player].twosLostAgaisnt = 0;
    end
    -- Increase Encouter variable
    if battleground then
        if won then
            PvPEncountersState[player].battlegroundWonAgaisnt = PvPEncountersState[player].battlegroundWonAgaisnt + 1;
        else
            PvPEncountersState[player].battlegroundLostAgaisnt = PvPEncountersState[player].battlegroundLostAgaisnt + 1;
        end
    else
        if numPlayers > 4 then--3v3
            if won then
                PvPEncountersState[player].threesWonAgaisnt = PvPEncountersState[player].threesWonAgaisnt + 1;
            else
                PvPEncountersState[player].threesLostAgaisnt = PvPEncountersState[player].threesLostAgaisnt + 1;
            end
        else--2v2
            if won then
                PvPEncountersState[player].twosWonAgaisnt = PvPEncountersState[player].twosWonAgaisnt + 1;
            else
                PvPEncountersState[player].twosLostAgaisnt = PvPEncountersState[player].twosLostAgaisnt + 1;
            end
        end
    end
end

function PPC:GetPlayerTeamFaction()
    local playerName = UnitName("player")
    for i=1, GetNumBattlefieldScores() do
        local name, killingBlows, honorableKills, deaths, honorGained, faction = GetBattlefieldScore(i);
        if name == playerName then
            return faction
        end
    end
end

function tooltipFriend:CanLoad()
    return FriendsTooltip and GameTooltip
end

function tooltipFriend:OnLoad()
    self:Enable()
    hooksecurefunc(FriendsTooltip, "Show", PPC.FriendsTooltip_Show)
    hooksecurefunc(FriendsTooltip, "Hide", PPC.FriendsTooltip_Hide)
end

function tooltipLFG:CanLoad()
    return _G.LFGListSearchPanelScrollFrameButton1 and _G.LFGListApplicationViewerScrollFrameButton1
end

function tooltipGame:CanLoad()
    return true
end

function tooltipGame:OnLoad()
    self:Enable()
    GameTooltip:HookScript("OnTooltipSetUnit", PPC.OnGameTooltipSetUnit)
    GameTooltip:HookScript("OnTooltipCleared", PPC.OnGameTooltipCleared)
    GameTooltip:HookScript("OnHide", PPC.OnGameTooltipHidden)
end

function tooltipCommunity:CanLoad()
    return _G.CommunitiesFrame and _G.ClubFinderGuildFinderFrame and _G.ClubFinderCommunityAndGuildFinderFrame
end

function tooltipCommunity:OnLoad()
    self:Enable()
    hooksecurefunc(_G.CommunitiesFrame.MemberList, "RefreshLayout", PPC.OnRefreshApplyHooksCommunity)
    hooksecurefunc(_G.CommunitiesFrame.MemberList, "Update", PPC.OnScrollCommunity)
    hooksecurefunc(_G.ClubFinderGuildFinderFrame.CommunityCards, "RefreshLayout", PPC.OnRefreshApplyHooksCommunity)
    hooksecurefunc(_G.ClubFinderGuildFinderFrame.CommunityCards.ListScrollFrame, "update", PPC.OnScrollCommunity)
    hooksecurefunc(_G.ClubFinderGuildFinderFrame.PendingCommunityCards, "RefreshLayout", PPC.OnRefreshApplyHooksCommunity)
    hooksecurefunc(_G.ClubFinderGuildFinderFrame.PendingCommunityCards.ListScrollFrame, "update", PPC.OnScrollCommunity)
    hooksecurefunc(_G.ClubFinderGuildFinderFrame.GuildCards, "RefreshLayout", PPC.OnRefreshApplyHooksCommunity)
    hooksecurefunc(_G.ClubFinderGuildFinderFrame.PendingGuildCards, "RefreshLayout", PPC.OnRefreshApplyHooksCommunity)
    hooksecurefunc(_G.ClubFinderCommunityAndGuildFinderFrame.CommunityCards, "RefreshLayout", PPC.OnRefreshApplyHooksCommunity)
    hooksecurefunc(_G.ClubFinderCommunityAndGuildFinderFrame.CommunityCards.ListScrollFrame, "update", PPC.OnScrollCommunity)
    hooksecurefunc(_G.ClubFinderCommunityAndGuildFinderFrame.PendingCommunityCards, "RefreshLayout", PPC.OnRefreshApplyHooksCommunity)
    hooksecurefunc(_G.ClubFinderCommunityAndGuildFinderFrame.PendingCommunityCards.ListScrollFrame, "update", PPC.OnScrollCommunity)
    hooksecurefunc(_G.ClubFinderCommunityAndGuildFinderFrame.GuildCards, "RefreshLayout", PPC.OnRefreshApplyHooksCommunity)
    hooksecurefunc(_G.ClubFinderCommunityAndGuildFinderFrame.PendingGuildCards, "RefreshLayout", PPC.OnRefreshApplyHooksCommunity)
end

function tooltipLFG:OnLoad()
    self:Enable()
    -- LFG
    for i = 1, 10 do
        local button = _G["LFGListSearchPanelScrollFrameButton" .. i]
        button:HookScript("OnLeave", PPC.OnLeaveApplicant)
    end
    -- the player hosting a group looking at applicants
    for i = 1, 14 do
        local button = _G["LFGListApplicationViewerScrollFrameButton" .. i]
        button:HookScript("OnEnter", PPC.OnEnterApplicant)
        button:HookScript("OnLeave", PPC.OnLeaveApplicant)
    end
    -- remove the shroud and allow hovering over people even when not the group leader
    do
        local f = _G.LFGListFrame.ApplicationViewer.UnempoweredCover
        f:EnableMouse(false)
        f:EnableMouseWheel(false)
        f:SetToplevel(false)
    end
end

function tooltipGuild:CanLoad()
    return _G.GuildFrame
end

function tooltipGuild:OnLoad()
    self:Enable()
    for i = 1, #GuildRosterContainer.buttons do
        local button = GuildRosterContainer.buttons[i]
        button:HookScript("OnEnter", PPC.OnGuildTooltipEnter)
        button:HookScript("OnLeave", PPC.OnGuildTooltipLeave)
    end
    hooksecurefunc(GuildRosterContainer, "update", PPC.OnScrollGuild)
end

function PPC:CalculateTeamAverage()
    local ubase = IsInRaid() and "raid" or "party"
    for i=1, GetNumGroupMembers() do
        local unit = ubase..i
        local characterName = UnitName(unit)
        --
    end
end

function PPC.FriendsTooltip_Show(self)
    if not tooltipFriend:IsEnabled() then
        return
    end
    local button = self.button
    local fullName, faction, level
    if button.buttonType == FRIENDS_BUTTON_TYPE_BNET then
        local bnetIDAccountInfo = C_BattleNet.GetFriendAccountInfo(button.id)
        if bnetIDAccountInfo then
            fullName, faction, level = PPC:GetNameRealmForBNetFriend(bnetIDAccountInfo.bnetAccountID)
        end
    elseif button.buttonType == FRIENDS_BUTTON_TYPE_WOW then
        local friendInfo = C_FriendList.GetFriendInfoByIndex(button.id)
        if friendInfo then
            fullName, level = friendInfo.name, friendInfo.level
            faction = PPC.PLAYER_FACTION
        end
    end
    if not fullName or not PPC:IsMaxLevel(level) then
        return
    end
    local ownerSet, ownerExisted = PPC:SetOwnerSafely(GameTooltip, FriendsTooltip, "ANCHOR_BOTTOMRIGHT", -FriendsTooltip:GetWidth(), -4)
    GameTooltip:SetText("PvP Encounters", nil, nil, nil, 1)
    PPC:ShowPlayerTooltip(fullName, GameTooltip, false)
    GameTooltip:SetMinimumWidth(200)
    GameTooltip:Show()
end

function PPC.FriendsTooltip_Hide()
    if not tooltipFriend:IsEnabled() then
        return
    end
    GameTooltip:Hide()
end

function PPC.OnGameTooltipSetUnit(self)
    if not tooltipGame:IsEnabled() then
        return
    end
    if InCombatLockdown() then
        return
    end
    local _, unit = self:GetUnit()
    if not unit or not UnitIsPlayer(unit) then
        return
    end
    if PPC:IsUnitMaxLevel(unit) then
        local name, realm, unit = PPC:GetNameRealm(unit)
        if realm == nil then
            realm = ''
        end
        PPC:ShowPlayerTooltip(name..'-'..realm, GameTooltip, true)
    end
end

function PPC.OnGameTooltipCleared(self)
    -- render:ClearTooltip(self)
end

function PPC.OnGameTooltipHidden(self)
    -- self:Hide()
end

function PPC.OnScrollCommunity()
    GameTooltip:Hide()
    PPC:ExecuteWidgetHandler(GetMouseFocus(), "OnEnter")
end

function PPC.OnScrollGuild()
    GameTooltip:Hide()
    PPC:ExecuteWidgetHandler(GetMouseFocus(), "OnEnter")
end

function PPC.OnEnterCommunity(self)
    local clubType
    local nameAndRealm
    if type(self.GetMemberInfo) == "function" then
        local info = self:GetMemberInfo()
        if info ~= nil then
            clubType = info.clubType
            nameAndRealm = PPC:GetFullName(info.name)
        else
            return
        end
    elseif type(self.cardInfo) == "table" then
        nameAndRealm = PPC:GetNameRealm(self.cardInfo.guildLeader)
    else
        return
    end
    if (clubType and clubType ~= Enum.ClubType.Guild and clubType ~= Enum.ClubType.Character) or not nameAndRealm then
        return
    end
    PPC:ShowPlayerTooltip(nameAndRealm, GameTooltip, true)
    GameTooltip:SetMinimumWidth(200)
    GameTooltip:Show()
end

function PPC.OnLeaveCommunity(self)
    GameTooltip:Hide()
end

function PPC.OnGuildTooltipEnter(self)
    if not self.guildIndex then
        return
    end
    local fullName, _, _, level = GetGuildRosterInfo(self.guildIndex)
    if not fullName or not PPC:IsMaxLevel(level) then
        return
    end
    -- print('GUILD TOOLDTIP'..fullName)
    local ownerSet, ownerExisted = PPC:SetOwnerSafely(GameTooltip, self, "ANCHOR_TOPLEFT", 0, 0)
    GameTooltip:SetText("PvP Encounters", nil, nil, nil, 1)
    PPC:ShowPlayerTooltip(fullName, GameTooltip, false)
    GameTooltip:SetMinimumWidth(200)
    GameTooltip:Show()
end

function PPC.OnGuildTooltipLeave(self)
    if not self.guildIndex then
        return
    end
    GameTooltip:Hide()
end

function PPC.SmartHookButtonsCommunity(buttons)
    if not buttons then
        return
    end
    local numButtons = 0
    for _, button in pairs(buttons) do
        numButtons = numButtons + 1
        if not hooked[button] then
            hooked[button] = true
            button:HookScript("OnEnter", PPC.OnEnterCommunity)
            button:HookScript("OnLeave", PPC.OnLeaveCommunity)
            if type(button.OnEnter) == "function" then hooksecurefunc(button, "OnEnter", PPC.OnEnterCommunity) end
            if type(button.OnLeave) == "function" then hooksecurefunc(button, "OnLeave", PPC.OnLeaveCommunity) end
        end
    end
    return numButtons > 0
end

function PPC.OnRefreshApplyHooksCommunity()
    if completed then
        return
    end
    PPC.SmartHookButtonsCommunity(_G.CommunitiesFrame.MemberList.ListScrollFrame.buttons)
    PPC.SmartHookButtonsCommunity(_G.ClubFinderGuildFinderFrame.CommunityCards.ListScrollFrame.buttons)
    PPC.SmartHookButtonsCommunity(_G.ClubFinderGuildFinderFrame.PendingCommunityCards.ListScrollFrame.buttons)
    PPC.SmartHookButtonsCommunity(_G.ClubFinderGuildFinderFrame.GuildCards.Cards)
    PPC.SmartHookButtonsCommunity(_G.ClubFinderGuildFinderFrame.PendingGuildCards.Cards)
    PPC.SmartHookButtonsCommunity(_G.ClubFinderCommunityAndGuildFinderFrame.CommunityCards.ListScrollFrame.buttons)
    PPC.SmartHookButtonsCommunity(_G.ClubFinderCommunityAndGuildFinderFrame.PendingCommunityCards.ListScrollFrame.buttons)
    PPC.SmartHookButtonsCommunity(_G.ClubFinderCommunityAndGuildFinderFrame.GuildCards.Cards)
    PPC.SmartHookButtonsCommunity(_G.ClubFinderCommunityAndGuildFinderFrame.PendingGuildCards.Cards)
    return true
end

function PPC.ShowApplicantProfile(parent, applicantID, memberIdx)
    local fullName, class, localizedClass, level, itemLevel, tank, healer, damage, assignedRole, relationship = C_LFGList.GetApplicantMemberInfo(applicantID, memberIdx)
    if not fullName then
        return false
    end
    if relationship then
        fullName = PPC:GetFullName(fullName)
    end
    local ownerSet, ownerExisted = PPC:SetOwnerSafely(GameTooltip, parent, "ANCHOR_NONE", 0, 0)
    PPC:ShowPlayerTooltip(fullName, GameTooltip, true)
    -- if ownerSet then
    --     GameTooltip:Hide()
    -- end
    return false
end

function PPC.OnEnterApplicant(self)
    local entry = C_LFGList.GetActiveEntryInfo()
    if entry then
        currentResult.activityID = entry.activityID
    end
    if self.applicantID and self.Members then
        PPC.HookApplicantButtons(self.Members)
    elseif self.memberIdx then
        local shown, fullName = PPC.ShowApplicantProfile(self, self:GetParent().applicantID, self.memberIdx)
        GameTooltip:SetMinimumWidth(200)
        GameTooltip:Show()
    end
end

function PPC.OnLeaveApplicant(self)
    GameTooltip:Hide()
    -- profile:ShowProfile(false, "player", ns.PLAYER_FACTION)
end

function PPC.HookApplicantButtons(buttons)
    for _, button in pairs(buttons) do
        if not hooked[button] then
            hooked[button] = true
            button:HookScript("OnEnter", PPC.OnEnterApplicant)
            button:HookScript("OnLeave", PPC.OnLeaveApplicant)
        end
    end
end

function PPC.OnAddonLoaded(name)
    PPC.LoadModules()
end

function PPC.UpdatePVPStatus()
    for i=1, GetMaxBattlefieldID() do
        local status, mapName, teamSize, registeredMatch = GetBattlefieldStatus(i);
        if status == "active" then
            local BATTLEFIELD_SHUTDOWN_TIMER = GetBattlefieldInstanceExpiration()/1000;
            if BATTLEFIELD_SHUTDOWN_TIMER > 0 then
                local winningTeamFaction = GetBattlefieldWinner()
                if winningTeamFaction then
                    local isArena, isRegistered = IsActiveBattlefieldArena()
                    -- isRegistered = true--DEV TEST SQUIRMISH
                    if isRegistered then
                        local playerTeamFaction = PPC:GetPlayerTeamFaction()
                        local playerName = UnitName("player")
                        if isArena then
                            for i=1, GetNumBattlefieldScores() do
                                local name, killingBlows, honorableKills, deaths, honorGained, faction = GetBattlefieldScore(i);
                                if name ~= nil and name ~= playerName and faction == playerTeamFaction then
                                    PPC:AddWinLostToPlayer(PPC:GetFullName(name), playerTeamFaction == winningTeamFaction, false, GetNumBattlefieldScores())
                                end
                                if name ~= nil and name ~= playerName and faction ~= playerTeamFaction then
                                    PPC:AddWinLostAgaisntPlayer(PPC:GetFullName(name), playerTeamFaction ~= winningTeamFaction, false, GetNumBattlefieldScores())
                                end
                            end
                        else
                            for i=1, GetNumBattlefieldScores() do
                                local name, killingBlows, honorableKills, deaths, honorGained, faction = GetBattlefieldScore(i);
                                if name ~= nil and name ~= playerName and faction == playerTeamFaction then
                                    PPC:AddWinLostToPlayer(PPC:GetFullName(name), playerTeamFaction == winningTeamFaction, true, nil)
                                end
                                if name ~= nil and name ~= playerName and faction ~= playerTeamFaction then
                                    PPC:AddWinLostAgaisntPlayer(PPC:GetFullName(name), playerTeamFaction ~= winningTeamFaction, true, nil)
                                end
                            end
                        end
                    else
                        --print("Non ranked match, ignoring...")
                    end
				else
                    --print("INSTANCE_SHUTDOWN_MESSAGE")
				end
			end
        end
    end
end

function PPC.OnEvent(self, event, ...)
    -- print(event)
    if event == "ADDON_LOADED" then PPC.OnAddonLoaded(...) end
    if event == "UPDATE_BATTLEFIELD_STATUS" then PPC.UpdatePVPStatus() end
    if event == "UPDATE_EXPANSION_LEVEL" then
        PPC.EXPANSION = max(LE_EXPANSION_BATTLE_FOR_AZEROTH, GetExpansionLevel())
        PPC.MAX_LEVEL = GetMaxLevelForExpansionLevel(PPC.EXPANSION)
    end
    -- if event == "INSPECT_READY" then
    --     if PPC.OnInspectReady ~= nil then
    --         PPC.OnInspectReady(...)
    --     end
    -- end
end

PPC_FRAME = CreateFrame("Frame", "PPCEventFrame")
PPC_FRAME:RegisterEvent("ADDON_LOADED")
PPC_FRAME:RegisterEvent("UPDATE_BATTLEFIELD_STATUS")
PPC_FRAME:RegisterEvent("UPDATE_EXPANSION_LEVEL")
-- PPC_FRAME:RegisterEvent("INSPECT_READY")
PPC_FRAME:SetScript("OnEvent", PPC.OnEvent)

local f = CreateFrame("Frame")
f:SetScript("OnEvent", function()
	local icon = LibStub("LibDBIcon-1.0", true)
	if not icon then return end
	if not PPCLDBIconDB then PPCLDBIconDB = {} end
	icon:Register(PPCAddonName, plugin, PPCLDBIconDB)
end)
f:RegisterEvent("PLAYER_LOGIN")

-- Settings
local PPC_SETTINGS_FRAME = CreateFrame("FRAME")
PPC_SETTINGS_FRAME.name = "PvP Encounters"
PPC_SETTINGS_FRAME:Hide()
PPC_SETTINGS_FRAME:SetScript("OnShow", function(frame)
	local function newCheckbox(label, description, onClick)
		local check = CreateFrame("CheckButton", "PPCCheck" .. label, frame, "InterfaceOptionsCheckButtonTemplate")
		check:SetScript("OnClick", function(self)
			local tick = self:GetChecked()
			onClick(self, tick and true or false)
			if tick then
				PlaySound(856) -- SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON
			else
				PlaySound(857) -- SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF
			end
		end)
		check.label = _G[check:GetName() .. "Text"]
		check.label:SetText(label)
		check.tooltipText = label
		check.tooltipRequirement = description
		return check
	end

    local function newDropdown(name, values, initialValue, getSettingValue, onChange)
        local info = {}
        local dropdown = CreateFrame("Frame", name, frame, "UIDropDownMenuTemplate")
        dropdown.initialize = function()
            wipe(info)
            for _, value in next, values do
                info.text = value
                info.value = value
                info.func = onChange
                info.checked = value == getSettingValue()
                UIDropDownMenu_AddButton(info)
            end
        end
        return dropdown;
	end

	local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 16, -16)
	title:SetText(PPCAddonName)

	local battlegroundsWithCheckbox = newCheckbox(
		"Show Battlegrounds With",
		"Show battleground statistics inside the tooltip of characters you played with.",
		function(self, value)
            PvPEncountersSettings.ShowBattlegroundsWith = value
        end
    )
    battlegroundsWithCheckbox:SetChecked(PvPEncountersSettings.ShowBattlegroundsWith)
    battlegroundsWithCheckbox:SetPoint("TOPLEFT", title, "BOTTOMLEFT", -2, -16)

    local battlegroundsAgaisntCheckbox = newCheckbox(
		"Show Battlegrounds Agaisnt",
		"Show battleground statistics inside the tooltip of characters you played agaisnt.",
		function(self, value)
            PvPEncountersSettings.ShowBattlegroundsAgaisnt = value
        end
    )
    battlegroundsAgaisntCheckbox:SetChecked(PvPEncountersSettings.ShowBattlegroundsAgaisnt)
    battlegroundsAgaisntCheckbox:SetPoint("LEFT", battlegroundsWithCheckbox, "RIGHT", 200, 0)

	local twovtwosWithCheckbox = newCheckbox(
		"Show 2v2 With",
		"Show 2v2 statistics inside the tooltip of characters you played with.",
		function(self, value)
            PvPEncountersSettings.Show2v2sWith = value
        end
    )
    twovtwosWithCheckbox:SetChecked(PvPEncountersSettings.Show2v2sWith)
    twovtwosWithCheckbox:SetPoint("TOPLEFT", battlegroundsWithCheckbox, "BOTTOMLEFT", 0, -8)

    local twovtwosAgaisntCheckbox = newCheckbox(
		"Show 2v2 Agaisnt",
		"Show 2v2 statistics inside the tooltip of characters you played agaisnt.",
		function(self, value)
            PvPEncountersSettings.Show2v2sAgaisnt = value
        end
    )
    twovtwosAgaisntCheckbox:SetChecked(PvPEncountersSettings.Show2v2sAgaisnt)
    twovtwosAgaisntCheckbox:SetPoint("LEFT", twovtwosWithCheckbox, "RIGHT", 200, 0)

	local threevthreesWithCheckbox = newCheckbox(
		"Show 3v3 With",
		"Show 3v3 statistics inside the tooltip of characters you played with.",
		function(self, value)
            PvPEncountersSettings.Show3v3sWith = value
        end
    )
    threevthreesWithCheckbox:SetChecked(PvPEncountersSettings.Show3v3sWith)
    threevthreesWithCheckbox:SetPoint("TOPLEFT", twovtwosWithCheckbox, "BOTTOMLEFT", 0, -8)

    local threevthreesAgaisntCheckbox = newCheckbox(
		"Show 3v3 Agaisnt",
		"Show 2v2 statistics inside the tooltip of characters you played agaisnt.",
		function(self, value)
            PvPEncountersSettings.Show3v3sAgaisnt = value
        end
    )
    threevthreesAgaisntCheckbox:SetChecked(PvPEncountersSettings.Show3v3sAgaisnt)
    threevthreesAgaisntCheckbox:SetPoint("LEFT", threevthreesWithCheckbox, "RIGHT", 200, 0)

	local overallsWithCheckbox = newCheckbox(
		"Show Overall With",
		"Show overall statistics inside the tooltip of characters you played with.",
		function(self, value)
            PvPEncountersSettings.ShowOverallsWith = value
        end
    )
    overallsWithCheckbox:SetChecked(PvPEncountersSettings.ShowOverallsWith)
    overallsWithCheckbox:SetPoint("TOPLEFT", threevthreesWithCheckbox, "BOTTOMLEFT", 0, -8)

    local overallsAgaisntCheckbox = newCheckbox(
		"Show Overall Agaisnt",
		"Show overall statistics inside the tooltip of characters you played agaisnt.",
		function(self, value)
            PvPEncountersSettings.ShowOverallsAgaisnt = value
        end
    )
    overallsAgaisntCheckbox:SetChecked(PvPEncountersSettings.ShowOverallsAgaisnt)
    overallsAgaisntCheckbox:SetPoint("LEFT", overallsWithCheckbox, "RIGHT", 200, 0)

    local minimap = newCheckbox(
		"Show Minimap Icon",
		"Show the icon button arround the minimap.",
		function(self, value)
			PPCLDBIconDB.hide = not value
			if PPCLDBIconDB.hide then
				LibStub("LibDBIcon-1.0"):Hide(PPCAddonName)
			else
				LibStub("LibDBIcon-1.0"):Show(PPCAddonName)
			end
		end
    )
	minimap:SetChecked(not PPCLDBIconDB.hide)
	minimap:SetPoint("TOPLEFT", overallsWithCheckbox, "BOTTOMLEFT", 0, -8)

    local formatDropdown = newDropdown("PPCFormat", {"win-lose (%)", "win/total (%)"}, "", function()
        return PvPEncountersSettings.format
    end,
    function(self)
        PvPEncountersSettings.format = self.value
        PPCFormatText:SetText(self:GetText())
    end)
	formatDropdown:SetPoint("TOPLEFT", minimap, "BOTTOMLEFT", -15, -10)
	PPCFormatText:SetText("Format")

	frame:SetScript("OnShow", nil)
end)
InterfaceOptions_AddCategory(PPC_SETTINGS_FRAME)
function plugin.OnClick(self, button)
    InterfaceOptionsFrame_OpenToCategory("PvP Encounters")
end