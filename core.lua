PvPEncountersState = PvPEncountersState or {}

local PPCAddonName = select(1, ...)
local PPC = select(2, ...) ---@type ns @The addon namespace.

PPC_FRAME = {}

local currentResult = {}
local hooked = {}

local tooltip = PPC:NewModule("LfgTooltip")

function tooltip:CanLoad()
    return _G.LFGListSearchPanelScrollFrameButton1 and _G.LFGListApplicationViewerScrollFrameButton1
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

function PPC.ShowApplicantProfile(parent, applicantID, memberIdx)
    local fullName, class, localizedClass, level, itemLevel, tank, healer, damage, assignedRole, relationship = C_LFGList.GetApplicantMemberInfo(applicantID, memberIdx)
    if not fullName then
        return false
    end
    if relationship then
        fullName = PPC.GetFullName(fullName)
    end
    local ownerSet, ownerExisted = PPC.SetOwnerSafely(GameTooltip, parent, "ANCHOR_NONE", 0, 0)
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
    if ownerSet then
        GameTooltip:Hide()
    end
    return false
end

function PPC.OnEnter(self)
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

function PPC.OnLeave(self)
    GameTooltip:Hide()
    -- profile:ShowProfile(false, "player", ns.PLAYER_FACTION)
end

function PPC.HookApplicantButtons(buttons)
    for _, button in pairs(buttons) do
        if not hooked[button] then
            hooked[button] = true
            button:HookScript("OnEnter", PPC.OnEnter)
            button:HookScript("OnLeave", PPC.OnLeave)
        end
    end
end

function PPC.OnAddonLoaded(name)
    for i = 1, 10 do
        local button = _G["LFGListSearchPanelScrollFrameButton" .. i]
        button:HookScript("OnLeave", PPC.OnLeave)
    end
    -- the player hosting a group looking at applicants
    for i = 1, 14 do
        local button = _G["LFGListApplicationViewerScrollFrameButton" .. i]
        button:HookScript("OnEnter", PPC.OnEnter)
        button:HookScript("OnLeave", PPC.OnLeave)
    end
    -- remove the shroud and allow hovering over people even when not the group leader
    do
        local f = _G.LFGListFrame.ApplicationViewer.UnempoweredCover
        f:EnableMouse(false)
        f:EnableMouseWheel(false)
        f:SetToplevel(false)
    end
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