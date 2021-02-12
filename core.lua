PvPEncountersState = PvPEncountersState or {}

local PPCAddonName = select(1, ...)
local PPC = select(2, ...) ---@type ns @The addon namespace.
PPC.FACTION_TO_ID = {Alliance = 1, Horde = 2, Neutral = 3}
PPC.EXPANSION = max(LE_EXPANSION_BATTLE_FOR_AZEROTH, GetExpansionLevel())
PPC.MAX_LEVEL = GetMaxLevelForExpansionLevel(PPC.EXPANSION)

PPC_FRAME = {}

local currentResult = {}
local hooked = {}
local completed

local tooltipLFG = PPC:NewModule("LfgTooltip")
local tooltipCommunity = PPC:NewModule("CommunityTooltip")
local tooltipFriend = PPC:NewModule("FriendTooltip")
local tooltipGame = PPC:NewModule("GameTooltip")
local tooltipGuild = PPC:NewModule("GuildTooltip")

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
        return level >= PPC.MAX_LEVEL
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

function PPC:ShowPlayerTooltip(fullName, tooltip, addTitle)
    local exists = PvPEncountersState[fullName]
    if exists == nil then
        if addTitle then
            tooltip:AddLine("PvP Encounters", nil, nil, nil, 1)
        end
        tooltip:AddDoubleLine("Battlegrounds:", "---", 1, 1, 1, 128 / 255 , 128 / 255, 128 / 255)
        tooltip:AddDoubleLine("2v2:", "---", 1, 1, 1, 128 / 255 , 128 / 255, 128 / 255)
        tooltip:AddDoubleLine("3v3:", "---", 1, 1, 1, 128 / 255 , 128 / 255, 128 / 255)
        tooltip:AddDoubleLine("Overall:", "---", 1, 1, 1, 128 / 255 , 128 / 255, 128 / 255)
        return true, fullName
    else
        if addTitle then
            tooltip:AddLine("PvP Encounters", nil, nil, nil, 1)
        end
        --Fix for older versions
        if type(exists.threesWon) ~= 'number' then
            exists.threesWon = 0;
            exists.threesLost = 0;
            exists.twosWon = 0;
            exists.twosLost = 0;
        end
        --Delete this in older versions...
        if type(exists.arenaWon) == 'number' then
            exists.arenaWon = nil;
            exists.arenaLost = nil;
        end
        local arenaWon = exists.threesWon + exists.twosWon
        local arenaLost = exists.threesLost + exists.twosLost
        --BG Winrate
        local bgwinrate = 0
        if exists.battlegroundWon > 0 and exists.battlegroundLost > 0 then
            bgwinrate = math.floor(exists.battlegroundWon * 100 / (exists.battlegroundWon + exists.battlegroundLost) * 100) / 100
        else
            if exists.battlegroundWon > 0 then
                bgwinrate = 100
            else
                bgwinrate = 0
            end
        end
        --2v2 Winrate
        local arena2winrate = 0
        if exists.twosWon > 0 and exists.twosLost > 0 then
            arena2winrate = math.floor(exists.twosWon * 100 / (exists.twosWon + exists.twosLost) * 100) / 100
        else
            if exists.twosWon > 0 then
                arena2winrate = 100
            else
                arena2winrate = 0
            end
        end
        --3v3 Winrate
        local arena3winrate = 0
        if exists.threesWon > 0 and exists.threesLost > 0 then
            arena3winrate = math.floor(exists.threesWon * 100 / (exists.threesWon + exists.threesLost) * 100) / 100
        else
            if exists.threesWon > 0 then
                arena3winrate = 100
            else
                arena3winrate = 0
            end
        end
        --Battlegrounds
        if bgwinrate > 50 then
            tooltip:AddDoubleLine("Battlegrounds:", format("%s/%s (%s%%)", exists.battlegroundWon, exists.battlegroundLost + exists.battlegroundWon, bgwinrate), 1, 1, 1, 0 ,1, 0)
        else
            if bgwinrate < 50 and exists.battlegroundLost > 0 then
                tooltip:AddDoubleLine("Battlegrounds:", format("%s/%s (%s%%)", exists.battlegroundWon, exists.battlegroundLost + exists.battlegroundWon, bgwinrate), 1, 1, 1, 1 ,0, 0)
            else
                tooltip:AddDoubleLine("Battlegrounds:", format("%s/%s (%s%%)", exists.battlegroundWon, exists.battlegroundLost + exists.battlegroundWon, bgwinrate), 1, 1, 1, 1 ,1, 1)
            end
        end
        --2v2
        if arena2winrate > 50 then
            tooltip:AddDoubleLine("2v2:", format("%s/%s (%s%%)", exists.twosWon, exists.twosLost + exists.twosWon, arena2winrate), 1, 1, 1, 0 ,1, 0)
        else
            if arena2winrate < 50 and exists.twosLost > 0 then
                tooltip:AddDoubleLine("2v2:", format("%s/%s (%s%%)", exists.twosWon, exists.twosLost + exists.twosWon, arena2winrate), 1, 1, 1, 1 ,0, 0)
            else
                tooltip:AddDoubleLine("2v2:", format("%s/%s (%s%%)", exists.twosWon, exists.twosLost + exists.twosWon, arena2winrate), 1, 1, 1, 1 ,1, 1)
            end
        end
        --3v3
        if arena3winrate > 50 then
            tooltip:AddDoubleLine("3v3:", format("%s/%s (%s%%)", exists.threesWon, exists.threesLost + exists.threesWon, arena3winrate), 1, 1, 1, 0 ,1, 0)
        else
            if arena3winrate < 50 and exists.threesLost > 0 then
                tooltip:AddDoubleLine("3v3:", format("%s/%s (%s%%)", exists.threesWon, exists.threesLost + exists.threesWon, arena3winrate), 1, 1, 1, 1 ,0, 0)
            else
                tooltip:AddDoubleLine("3v3:", format("%s/%s (%s%%)", exists.threesWon, exists.threesLost + exists.threesWon, arena3winrate), 1, 1, 1)
            end
        end
        --Overall
        local won = arenaWon + exists.battlegroundWon
        local lost = arenaLost + exists.battlegroundLost
        local winrate = 0
        if won > 0 and lost > 0 then
            winrate = math.floor(won * 100 / (won + lost) * 100) / 100
        else
            if won > 0 then
                winrate = 100
            else
                winrate = 0
            end
        end
        if winrate > 50 then
            tooltip:AddDoubleLine("Overall:", format("%s/%s (%s%%)", won, lost + won, winrate), 1, 1, 1, 0 ,1, 0)
        else
            if winrate < 50 and lost > 0 then
                tooltip:AddDoubleLine("Overall:", format("%s/%s (%s%%)", won, lost + won, winrate), 1, 1, 1, 1 ,0, 0)
            else
                tooltip:AddDoubleLine("Overall:", format("%s/%s (%s%%)", won, lost + won, winrate), 1, 1, 1)
            end
        end
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

--

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
        clubType = info.clubType
        nameAndRealm = PPC:GetFullName(info.name)
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
    print('GUILD TOOLDTIP'..fullName)
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
                                    PPC:AddWinLostToPlayer(PPC:GetFullName(name), playerTeamFaction == winningTeamFaction, false, #GetNumBattlefieldScores())
                                end
                            end
                        else
                            for i=1, GetNumBattlefieldScores() do
                                local name, killingBlows, honorableKills, deaths, honorGained, faction = GetBattlefieldScore(i);
                                if name ~= nil and name ~= playerName and faction == playerTeamFaction then
                                    PPC:AddWinLostToPlayer(PPC:GetFullName(name), playerTeamFaction == winningTeamFaction, true, nil)
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
end

PPC_FRAME = CreateFrame("Frame", "PPCEventFrame")
PPC_FRAME:RegisterEvent("ADDON_LOADED")
PPC_FRAME:RegisterEvent("UPDATE_BATTLEFIELD_STATUS")
PPC_FRAME:RegisterEvent("UPDATE_EXPANSION_LEVEL")
PPC_FRAME:SetScript("OnEvent", PPC.OnEvent)