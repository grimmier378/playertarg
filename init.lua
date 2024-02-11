--[[
    Title: PlayerTarget
    Author: Grimmier
    Version:0.6
    Description: Combines Player Information window and Target window into one.
    Displays Your player info. as well as Target: Hp, Your aggro, SecondaryAggroPlayer, Visability, Distance,
    and Buffs with name \ duration on tooltip hover.
]]
---@type Mq
local mq = require('mq')
---@type ImGui
local ImGui = require('ImGui')
local Icons = require('mq.ICONS')
local COLOR = require('colors.colors')
-- set variables
local anim = mq.FindTextureAnimation('A_SpellIcons')
local TLO = mq.TLO
local ME = TLO.Me
local TARGET = TLO.Target
local winFlag = bit32.bor(ImGuiWindowFlags.NoTitleBar, ImGuiWindowFlags.NoScrollbar, ImGuiWindowFlags.NoScrollWithMouse)
local pulse = true
local textureWidth = 20
local textureHeight = 20
local ShowGUI = true
local ver = 'v1.1'
local tPlayerFlags = bit32.bor(ImGuiTableFlags.NoBorders,ImGuiTableFlags.NoBordersInBody, ImGuiTableFlags.NoPadInnerX, ImGuiTableFlags.NoPadOuterX,ImGuiTableFlags.Resizable,ImGuiTableFlags.SizingFixedFit)
local function GetInfoToolTip()
   local pInfoToolTip = ( ME.CleanName()..
    '\t\tlvl: '..tostring(ME.Level())..
    '\nClass: '..ME.Class.Name()..
    '\nHealth: '..tostring(ME.CurrentHPs())..' of '..tostring(ME.MaxHPs())..
    '\nMana: '..tostring(ME.CurrentMana())..' of '..tostring(ME.MaxMana())..
    '\nEnd: '..tostring(ME.CurrentEndurance())..' of '..tostring(ME.MaxEndurance())
)
return pInfoToolTip
end
local combatStateActions = {
    COMBAT = function() DrawStatusIcon(1, 'In Combat') end,
    DEBUFFED = function() DrawStatusIcon(2, 'Debuffed') end,
    COOLDOWN = function() DrawStatusIcon(3, 'Cooling Down') end,
    ACTIVE = function() DrawStatusIcon(4, 'Active') end,
    RESTING = function() DrawStatusIcon(5, 'Resting') end,
    NULL = function() DrawStatusIcon(6, 'Unknown') end
}
local function getDuration(i)
    local remaining = TARGET.Buff(i).Duration() or 0
    remaining = remaining / 1000 -- convert to seconds
    -- Calculate hours, minutes, and seconds
    local h = math.floor(remaining / 3600) or 0
    remaining = remaining % 3600 -- remaining seconds after removing hours
    local m = math.floor(remaining / 60) or 0
    local s = remaining % 60 -- remaining seconds after removing minutes
    -- Format the time string as H : M : S
    local sRemaining = string.format("%02d:%02d:%02d", h, m, s)
    return sRemaining
end
--[[
    Borrowed from rgmercs
    ~Thanks Derple
]]
---@param iconID integer
---@param spell MQSpell
---@param i integer
function DrawInspectableSpellIcon(iconID, spell, i)
    local cursor_x, cursor_y = ImGui.GetCursorPos()
    anim:SetTextureCell(iconID or 0)
    ImGui.DrawTextureAnimation(anim, textureWidth, textureHeight)
    ImGui.SetCursorPos(cursor_x, cursor_y)
    ImGui.PushID(tostring(iconID) .. spell.Name() .. "_invis_btn")
    ImGui.InvisibleButton(spell.Name(), ImVec2(textureWidth, textureHeight),
    bit32.bor(ImGuiButtonFlags.MouseButtonRight))
    if ImGui.IsItemHovered() then
        if (ImGui.IsMouseReleased(1)) then
            spell.Inspect()
            -- print(spell.Name()) -- DEBUG print name to make sure right click is working.
        end
        ImGui.BeginTooltip()
        ImGui.Text(spell.Name()..'\n'..getDuration(i))
        ImGui.EndTooltip()
    end
    ImGui.PopID()
end
---@param iconID integer
---@param spell MQSpell
---@param i integer
function DrawStatusIcon(iconID, txt)
    local cursor_x, cursor_y = ImGui.GetCursorPos()
    anim:SetTextureCell(iconID or 0)
    ImGui.DrawTextureAnimation(anim, textureWidth-5, textureHeight-5)
    if ImGui.IsItemHovered() then
        ImGui.BeginTooltip()
        ImGui.Text(txt)
        ImGui.EndTooltip()
    end
end
local function targetBuffs(count)
    -- Save the original item spacing
    local originalSpacingX, originalSpacingY = ImGui.GetStyle().ItemSpacing.x, ImGui.GetStyle().ItemSpacing.y
    ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 0, 0)
    -- Width and height of each texture
    local iconsDrawn = 0
    -- Calculate max icons per row based on the window width
    local windowWidth = ImGui.GetWindowContentRegionWidth()
    local maxIconsRow = (windowWidth) / (textureWidth)
    ImGui.BeginGroup()
    for i = 1, count do
        local sIcon = TARGET.Buff(i).SpellIcon()
        DrawInspectableSpellIcon(sIcon, TARGET.Buff(i), i)
        iconsDrawn = iconsDrawn + 1
        -- Check if we've reached the max icons for the row, if so reset counter and new line
        if iconsDrawn >= maxIconsRow then
            iconsDrawn = 0 -- Reset counter
            else
            -- Use SameLine to keep drawing items on the same line, except for when a new line is needed
            if i < count then
                ImGui.SameLine()
                else
                ImGui.SetCursorPosX(1)
            end
        end
    end
    ImGui.EndGroup()
    ImGui.PopStyleVar()
end
local function getConLevel(spawn)
    local conColor = string.lower(spawn.ConColor())
    return conColor
end
function GUI_Target(open)
    if not ShowGUI then return end
    --Rounded corners
    ImGui.PushStyleVar(ImGuiStyleVar.FrameRounding, 5)
    -- Default window size
    ImGui.SetNextWindowSize(216,239, ImGuiCond.FirstUseEver)
    local show = false
    open, show = ImGui.Begin("Target", open, winFlag)
    if not show then
        ImGui.PopStyleVar()
        ImGui.End()
        return open
    end
    if not TLO.Me.Zoning() then
        -- Combat Status
        if ME.Combat() then
            ImGui.SetItemAllowOverlap()
            --ImGui.SetCursorPosY(10)
            ImGui.SetCursorPosX((ImGui.GetContentRegionAvail()/2)-22)
            if pulse then
                COLOR.barColor('pink')
                pulse = false
                else
                COLOR.barColor('red')
                pulse = true
            end
            ImGui.ProgressBar(1, 21, 20, '##c')
            --ImGui.Text(Icons.MD_LENS)
            ImGui.PopStyleColor()
        end
        ImGui.SameLine()
        ImGui.SetCursorPosX(5)
        --ImGui.SetCursorPosY(10)
        -- Player Information
        ImGui.BeginGroup()
        if ImGui.BeginTable("##playerInfo", 4, tPlayerFlags) then
            ImGui.TableSetupColumn("##tName", ImGuiTableColumnFlags.NoResize,(ImGui.GetContentRegionAvail()*.5))
            ImGui.TableSetupColumn("##tVis", ImGuiTableColumnFlags.NoResize,16)
            ImGui.TableSetupColumn("##tIcons", ImGuiTableColumnFlags.WidthStretch,60)   --ImGui.GetContentRegionAvail()*.25)
            ImGui.TableSetupColumn("##tLvl", ImGuiTableColumnFlags.NoResize,30)
            ImGui.TableNextRow()
            -- Name
            ImGui.SetWindowFontScale(1)
            ImGui.TableSetColumnIndex(0)
            local meName = ME.CleanName()
            ImGui.Text(meName)
            local combatState = mq.TLO.Me.CombatState()
            if combatState=='COMBAT' then
                ImGui.SameLine(ImGui.GetColumnWidth()-25)
                DrawStatusIcon(50,'Combat')
            end
            -- Visiblity
            ImGui.TableSetColumnIndex(1)
            if TARGET() ~= nil then
                if TARGET.LineOfSight() then
                    ImGui.PushStyleColor(ImGuiCol.Text, 0, 1, 0, 1)
                    ImGui.Text(Icons.MD_VISIBILITY)
                    ImGui.PopStyleColor()
                    else
                    ImGui.PushStyleColor(ImGuiCol.Text, 0.9, 0, 0, 1)
                    ImGui.Text(Icons.MD_VISIBILITY_OFF)
                    ImGui.PopStyleColor()
                end
            end
            ImGui.SetWindowFontScale(.91)
            -- Icons
            ImGui.TableSetColumnIndex(2)
            ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 0, 0)
            ImGui.Text('')
            if TLO.Group.MainTank.ID() == ME.ID() then
                ImGui.SameLine()
                DrawStatusIcon(46,'Main Tank')
            end
            if TLO.Group.MainAssist.ID() == ME.ID() then
                ImGui.SameLine()
                DrawStatusIcon(49,'Main Assist')
            end
            ImGui.SameLine()
            --  ImGui.SameLine()
            ImGui.Text('')
            ImGui.PopStyleVar()
            -- Lvl
            ImGui.TableSetColumnIndex(3)
            ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 2, 0)
            ImGui.SetWindowFontScale(1)
            ImGui.Text(tostring(ME.Level() or 0))
           -- ImGui.Text(tostring('125'))
            if ImGui.IsItemHovered() then
                ImGui.BeginTooltip()
                ImGui.Text(GetInfoToolTip())
                ImGui.EndTooltip()
            end            
            -- ImGui.SameLine()
            -- ImGui.SetWindowFontScale(.75)
            -- ImGui.Text(ME.Class.ShortName())
            --ImGui.Text('UNK')
            ImGui.PopStyleVar()
            ImGui.EndTable()
        end
        ImGui.Separator()
        -- My Health Bar
        ImGui.SetWindowFontScale(0.75)
        COLOR.barColor('red')
        ImGui.ProgressBar(((tonumber(ME.PctHPs() or 0))/100), ImGui.GetContentRegionAvail(), 10, '##pctHps')
        ImGui.PopStyleColor()
        ImGui.SetCursorPosY(ImGui.GetCursorPosY()-15)
        ImGui.SetCursorPosX(ImGui.GetCursorPosX() + ((ImGui.GetWindowWidth()/2)-8))
        ImGui.Text(tostring(ME.PctHPs() or 0))
        --My Mana Bar
        if (tonumber(ME.MaxMana())>0) then
            COLOR.barColor('blue')
            ImGui.ProgressBar(((tonumber(ME.PctMana() or 0))/100), ImGui.GetContentRegionAvail(), 10, '##pctMana')
            ImGui.PopStyleColor()
            ImGui.SetCursorPosY(ImGui.GetCursorPosY()-15)
            ImGui.SetCursorPosX(ImGui.GetCursorPosX() + ((ImGui.GetWindowWidth()/2)-8))
            ImGui.Text(tostring(ME.PctMana()or 0))
        end
        --My Endurance barB
        COLOR.barColor('yellow')
        ImGui.ProgressBar(((tonumber(ME.PctEndurance() or 0))/100), ImGui.GetContentRegionAvail(), 10, '##pctEndurance')
        ImGui.PopStyleColor()
        ImGui.SetCursorPosY(ImGui.GetCursorPosY()-15)
        ImGui.SetCursorPosX(ImGui.GetCursorPosX() + ((ImGui.GetWindowWidth()/2)-8))
        ImGui.Text(tostring(ME.PctEndurance()or 0))
        ImGui.Separator()
        ImGui.EndGroup()
        if ImGui.IsItemHovered() and ImGui.IsMouseReleased(ImGuiMouseButton.Left) then
            mq.cmd('/target  ${Me}')
        end
        --Target Info
        if (TARGET()~= nil) then
            --Target Health Bar
            COLOR.barColor('red')
            ImGui.ProgressBar(((tonumber(TARGET.PctHPs()or 0))/100), ImGui.GetContentRegionAvail(), 30, '##'..TARGET.PctHPs())
            ImGui.PopStyleColor()
            ImGui.SetWindowFontScale(0.9)
            ImGui.SetCursorPosY(ImGui.GetCursorPosY()-37)
            ImGui.SetCursorPosX(9)
            if ImGui.BeginTable("##targetInfoOverlay", 2, tPlayerFlags) then
                ImGui.TableSetupColumn("##col1", ImGuiTableColumnFlags.NoResize,(ImGui.GetContentRegionAvail()*.5) - 8)
                ImGui.TableSetupColumn("##col2", ImGuiTableColumnFlags.NoResize,(ImGui.GetContentRegionAvail()*.5) +8) -- Adjust width for distance and Aggro% text
                -- First Row: Name, con, distance
                ImGui.TableNextRow()
                ImGui.TableSetColumnIndex(0) -- Name and CON in the first column
                ImGui.SetWindowFontScale(0.9)
                local targetName = TARGET.CleanName()
                ImGui.Text(targetName)
                -- Distance in the second column
                ImGui.TableSetColumnIndex(1)
                local tC = getConLevel(TARGET)
                COLOR.txtColor(tC)
                if tC == 'red' then
                    ImGui.Text('   '..Icons.MD_WARNING)
                    else
                    ImGui.Text('   '..Icons.MD_LENS)
                end
                ImGui.PopStyleColor()
                ImGui.SameLine(ImGui.GetColumnWidth()-35)
                COLOR.txtColor('yellow')
                ImGui.Text(tostring(math.floor(TARGET.Distance() or 0))..'m')
                ImGui.PopStyleColor()
                -- Second Row: Class, Level, and Aggro%
                ImGui.TableNextRow()
                ImGui.TableSetColumnIndex(0) -- Class and Level in the first column
                local tClass = TARGET.Class.ShortName() == 'UNKNOWN CLASS' and Icons.MD_HELP_OUTLINE or TARGET.Class.ShortName()
                local tLvl = TARGET.Level() or 0
                ImGui.Text(tostring(tLvl)..' '..tClass)
                -- Aggro% text in the second column
                ImGui.TableSetColumnIndex(1)
                ImGui.SetWindowFontScale(1)
                ImGui.Text(tostring(TARGET.PctHPs())..'%')
                ImGui.EndTable()
            end
            ImGui.SetWindowFontScale(0.75)
            ImGui.Separator()
            --Aggro % Bar
            if (TARGET.Aggressive) then
                COLOR.barColor('purple')
                ImGui.ProgressBar(((tonumber(TARGET.PctAggro() or 0))/100), ImGui.GetContentRegionAvail(), 10, '##pctAggro')
                ImGui.PopStyleColor()
                --Secondary Aggro Person
                if (TARGET.SecondaryAggroPlayer()~= nil) then
                    ImGui.SetCursorPosY(ImGui.GetCursorPosY()-15)
                    ImGui.SetCursorPosX(ImGui.GetCursorPosX() + 5)
                    ImGui.Text(TARGET.SecondaryAggroPlayer.CleanName())
                end
                --Aggro % Label middle of bar
                ImGui.SetCursorPosY(ImGui.GetCursorPosY()-15)
                ImGui.SetCursorPosX(ImGui.GetCursorPosX() + ((ImGui.GetWindowWidth()/2)-8))
                ImGui.Text(TARGET.PctAggro())
                if (TARGET.SecondaryAggroPlayer()~= nil) then
                    ImGui.SetCursorPosY(ImGui.GetCursorPosY()-18)
                    ImGui.SetCursorPosX(ImGui.GetWindowWidth()-40)
                    ImGui.Text(TARGET.SecondaryPctAggro())
                end
                else
                ImGui.Text('')
            end
            ImGui.Separator()
            --Target Buffs
            if tonumber(TARGET.BuffCount()) > 0 then
                local windowWidth, windowHeight = ImGui.GetContentRegionAvail()
                -- Begin a scrollable child
                ImGui.BeginChild("TargetBuffsScrollRegion", ImVec2(windowWidth, windowHeight), true)
                targetBuffs(tonumber(TARGET.BuffCount()))
                ImGui.EndChild()
                -- End the scrollable region
                ImGui.Separator()
            end
            else
            ImGui.Text('')
        end
        ImGui.PopStyleVar()
        ImGui.Spacing()
        ImGui.End()
        else
        ImGui.PopStyleVar()
        ImGui.Spacing()
        ImGui.End()
    end
    return open
end
local openGUI = true
ImGui.Register('GUI_Target', function()
    openGUI = GUI_Target(openGUI)
end)
local function MainLoop()
    while true do
        mq.delay(1000)
        if ME.Zoning() then
                ShowGUI = false
            else
                ShowGUI = true
        end
        if not openGUI then
            openGUI = ShowGUI
            GUI_Target(openGUI)
        end
    end
end
MainLoop()