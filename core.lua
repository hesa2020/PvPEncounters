PvPEncountersState = PvPEncountersState or {}

local PPCAddonName = select(1, ...)
local PPC = select(2, ...) ---@type ns @The addon namespace.

PPC_FRAME = {}

local currentResult = {}
local hooked = {}
local completed

local tooltipLFG = PPC:NewModule("LfgTooltip")
local tooltipCommunity = PPC:NewModule("CommunityTooltip")

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

function tooltipLFG:CanLoad()
    return _G.LFGListSearchPanelScrollFrameButton1 and _G.LFGListApplicationViewerScrollFrameButton1
end

function tooltipCommunity:CanLoad()
    return _G.CommunitiesFrame and _G.ClubFinderGuildFinderFrame and _G.ClubFinderCommunityAndGuildFinderFrame
end

function PPC.OnScrollCommunity()
    GameTooltip:Hide()
    PPC:ExecuteWidgetHandler(GetMouseFocus(), "OnEnter")--TODO
end

function PPC.IsUnitToken(unit)
    return type(unit) == "string" and UNIT_TOKENS[unit]
end

function PPC.IsUnit(arg1, arg2)
    if not arg2 and type(arg1) == "string" and arg1:find("-", nil, true) then
        arg2 = true
    end
    local isUnit = not arg2 or PPC.IsUnitToken(arg1)
    return isUnit, isUnit and UnitExists(arg1), isUnit and UnitIsPlayer(arg1)
end

function PPC.GetNameRealm(arg1, arg2)
    local unit, name, realm
    local _, unitExists, unitIsPlayer = PPC.IsUnit(arg1, arg2)
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

function PPC.OnEnterCommunity(self)--TODO
    local clubType
    local nameAndRealm
    if type(self.GetMemberInfo) == "function" then
        local info = self:GetMemberInfo()
        clubType = info.clubType
        nameAndRealm = info.name
    elseif type(self.cardInfo) == "table" then
        nameAndRealm = PPC.GetNameRealm(self.cardInfo.guildLeader)
    else
        return
    end
    if (clubType and clubType ~= Enum.ClubType.Guild and clubType ~= Enum.ClubType.Character) or not nameAndRealm then
        return
    end
    PPC.ShowPlayerTooltip(nameAndRealm)
    GameTooltip:SetMinimumWidth(150)
    GameTooltip:Show()
end

function PPC.OnLeaveCommunity(self)
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

---@param object Widget @Any interface widget object that supports the methods GetOwner.
---@param owner Widget @Any interface widget object.
---@param anchor string @`ANCHOR_TOPLEFT`, `ANCHOR_NONE`, `ANCHOR_CURSOR`, etc.
---@param offsetX number @Optional offset X for some of the anchors.
---@param offsetY number @Optional offset Y for some of the anchors.
---@return boolean, boolean @If owner was set arg1 is true. If owner was updated arg2 is true. Otherwise both will be set to face to indicate we did not update the Owner of the widget.
function PPC.SetOwnerSafely(object, owner, anchor, offsetX, offsetY)
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

function PPC.HasRealmName(name)
    if string.find(name, "-") then
        return true
    end
    return false
end

function PPC.GetFullName(name)
    local hasRealmName = PPC.HasRealmName(name)
    if not hasRealmName then
        --TODO, Figure a way to get the realm name
        name = name.."-"..GetRealmName()
    end
    return name
end

function PPC.ShowPlayerTooltip(fullName)
    local exists = PvPEncountersState[fullName]
    if exists == nil then
        GameTooltip:AddLine("PvP Encounters", nil, nil, nil, 1)
        GameTooltip:AddDoubleLine("Battlegrounds Won:", "---", 1, 1, 1, 128 / 255 , 128 / 255, 128 / 255)
        GameTooltip:AddDoubleLine("Battlegrounds Lost:", "---", 1, 1, 1, 128 / 255 , 128 / 255, 128 / 255)
        GameTooltip:AddDoubleLine("Arenas Won:", "---", 1, 1, 1, 128 / 255 , 128 / 255, 128 / 255)
        GameTooltip:AddDoubleLine("Arenas Lost:", "---", 1, 1, 1, 128 / 255 , 128 / 255, 128 / 255)
        return true, fullName
    else
        GameTooltip:AddLine("PvP Encounters", nil, nil, nil, 1)
        if exists.battlegroundWon > 0 then
            GameTooltip:AddDoubleLine("Battlegrounds Won:", exists.battlegroundWon, 1, 1, 1, 0 ,1, 0)
        else
            GameTooltip:AddDoubleLine("Battlegrounds Won:", "---", 1, 1, 1, 128 / 255 , 128 / 255, 128 / 255)
        end
        if exists.battlegroundLost > 0 then
            GameTooltip:AddDoubleLine("Battlegrounds Lost:", exists.battlegroundLost, 1, 1, 1, 1, 0, 0)
        else
            GameTooltip:AddDoubleLine("Battlegrounds Lost:", "---", 1, 1, 1, 128 / 255 , 128 / 255, 128 / 255)
        end
        if exists.arenaWon > 0 then
            GameTooltip:AddDoubleLine("Arenas Won:", exists.arenaWon, 1, 1, 1, 0 ,1, 0)
        else
            GameTooltip:AddDoubleLine("Arenas Won:", "---", 1, 1, 1, 128 / 255 , 128 / 255, 128 / 255)
        end
        if exists.arenaLost > 0 then
            GameTooltip:AddDoubleLine("Arenas Lost:", exists.arenaLost, 1, 1, 1, 1, 0, 0)
        else
            GameTooltip:AddDoubleLine("Arenas Lost:", "---", 1, 1, 1, 128 / 255 , 128 / 255, 128 / 255)
        end
        return true, fullName
    end
end

function PPC.ShowApplicantProfile(parent, applicantID, memberIdx)
    local fullName, class, localizedClass, level, itemLevel, tank, healer, damage, assignedRole, relationship = C_LFGList.GetApplicantMemberInfo(applicantID, memberIdx)
    if not fullName then
        return false
    end
    if relationship then
        fullName = PPC.GetFullName(fullName)
    end
    local ownerSet, ownerExisted = PPC.SetOwnerSafely(GameTooltip, parent, "ANCHOR_NONE", 0, 0)
    PPC.ShowPlayerTooltip(fullName)
    if ownerSet then
        GameTooltip:Hide()
    end
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
        GameTooltip:SetMinimumWidth(150)
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

function PPC.AddWinLostToPlayer(player, won, battleground)
    -- print("AddWinLost to "..player)
    local exists = PvPEncountersState[player]
    -- Add the Encounter if new player
    if exists == nil then
        PvPEncountersState[player] = {}
        PvPEncountersState[player].battlegroundWon = 0;
        PvPEncountersState[player].battlegroundLost = 0;
        PvPEncountersState[player].arenaWon = 0;
        PvPEncountersState[player].arenaLost = 0;
    end
    -- Increase Encouter variable
    if battleground then
        if won then
            PvPEncountersState[player].battlegroundWon = PvPEncountersState[player].battlegroundWon + 1;
        else
            PvPEncountersState[player].battlegroundLost = PvPEncountersState[player].battlegroundLost + 1;
        end
    else
        if won then
            PvPEncountersState[player].arenaWon = PvPEncountersState[player].arenaWon + 1;
        else
            PvPEncountersState[player].arenaLost = PvPEncountersState[player].arenaLost + 1;
        end
    end
end

function PPC.GetPlayerTeamFaction()
    local playerName = UnitName("player")
    for i=1, GetNumBattlefieldScores() do
        local name, killingBlows, honorableKills, deaths, honorGained, faction = GetBattlefieldScore(i);
        if name == playerName then
            return faction
        end
    end
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
                        local playerTeamFaction = PPC.GetPlayerTeamFaction()
                        local playerName = UnitName("player")
                        if isArena then
                            for i=1, GetNumBattlefieldScores() do
                                local name, killingBlows, honorableKills, deaths, honorGained, faction = GetBattlefieldScore(i);
                                if name ~= nil and name ~= playerName and faction == playerTeamFaction then
                                    PPC.AddWinLostToPlayer(PPC.GetFullName(name), playerTeamFaction == winningTeamFaction, false)
                                end
                            end
                        else
                            for i=1, GetNumBattlefieldScores() do
                                local name, killingBlows, honorableKills, deaths, honorGained, faction = GetBattlefieldScore(i);
                                if name ~= nil and name ~= playerName and faction == playerTeamFaction then
                                    PPC.AddWinLostToPlayer(PPC.GetFullName(name), playerTeamFaction == winningTeamFaction, true)
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
end

PPC_FRAME = CreateFrame("Frame", "PPCEventFrame")
PPC_FRAME:RegisterEvent("ADDON_LOADED")
PPC_FRAME:RegisterEvent("UPDATE_BATTLEFIELD_STATUS")
-- PPC_FRAME:RegisterEvent("ZONE_CHANGED_NEW_AREA")
-- PPC_FRAME:RegisterEvent("ZONE_CHANGED")
-- PPC_FRAME:RegisterEvent("PLAYER_ENTERING_WORLD")
PPC_FRAME:SetScript("OnEvent", PPC.OnEvent)