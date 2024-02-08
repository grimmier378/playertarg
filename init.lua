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
-- set variables
local anim = mq.FindTextureAnimation('A_SpellIcons')
local winFlag = bit32.bor(ImGuiWindowFlags.NoTitleBar)
local pulse = true
local textureWidth = 20
local textureHeight = 20
local ver = 'v0.6'
local function barColor(c)
    if (c == 'red') then return ImGui.PushStyleColor(ImGuiCol.PlotHistogram,0.7, 0, 0, 0.7) end
    if (c == 'pink') then return ImGui.PushStyleColor(ImGuiCol.PlotHistogram,0.9, 0.4, 0.4, 0.8) end
    if (c == 'blue') then return ImGui.PushStyleColor(ImGuiCol.PlotHistogram, 0.2, 0.6, 1, 0.4) end
    if (c == 'yellow') then return ImGui.PushStyleColor(ImGuiCol.PlotHistogram, 0.7, .6, .1, .7) end
    if (c == 'purple') then return ImGui.PushStyleColor(ImGuiCol.PlotHistogram, 0.6, 0.0, 0.6, 0.7) end
    if (c == 'grey') then return ImGui.PushStyleColor(ImGuiCol.PlotHistogram, 1, 1, 1, 0.2) end
end
local function getDuration(i)
    local remaining = mq.TLO.Target.Buff(i).Duration() or 0
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
        ImGui.Text(spell.Name()..' '..getDuration(i))
        ImGui.EndTooltip()
    end
    ImGui.PopID()
end
local function targetBuffs(count)
    -- Save the original item spacing
    local originalSpacingX, originalSpacingY = ImGui.GetStyle().ItemSpacing.x, ImGui.GetStyle().ItemSpacing.y
    ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 0, 0)
    -- Width and height of each texture
    local iconsDrawn = 0
    -- Calculate max icons per row based on the window width
    local windowWidth = ImGui.GetWindowContentRegionWidth()
    local maxIconsRow = math.floor(windowWidth / (textureWidth))
    ImGui.BeginGroup()
    for i = 1, count do
        local sIcon = mq.TLO.Target.Buff(i).SpellIcon()
        DrawInspectableSpellIcon(sIcon, mq.TLO.Target.Buff(i), i)
        iconsDrawn = iconsDrawn + 1
        -- Check if we've reached the max icons for the row, if so reset counter and new line
        if iconsDrawn >= maxIconsRow then
            iconsDrawn = 0 -- Reset counter
            else
            -- Use SameLine to keep drawing items on the same line, except for when a new line is needed
            if i < count then
                ImGui.SameLine()
            end
        end
    end
    ImGui.EndGroup()
    ImGui.PopStyleVar()
end
function GUI_Target(open)
    ImGui.PushStyleVar(ImGuiStyleVar.FrameRounding, 5)
    -- change the window size
    ImGui.SetNextWindowSize(300, 300, ImGuiCond.FirstUseEver)
    local show = false
    open, show = ImGui.Begin("Target", open, winFlag)
    if not show then
        ImGui.End()
        return open
    end
    --Name and combat status
    local isInCombat = mq.TLO.Me.Combat()
    ImGui.SetWindowFontScale(.91)
    if (isInCombat) then
        if (pulse) then
            ImGui.BeginGroup()
            barColor('pink')
            ImGui.ProgressBar(1, ImGui.GetContentRegionAvail(), 15, '##'..mq.TLO.Me.CleanName())
            ImGui.PopStyleColor()
            ImGui.SetCursorPosY(ImGui.GetCursorPosY()-20)
            ImGui.SetCursorPosX(ImGui.GetCursorPosX() + 5)
            ImGui.Text(mq.TLO.Me.CleanName())
            ImGui.EndGroup()
            pulse = false
            else
            ImGui.BeginGroup()
            barColor('red')
            ImGui.ProgressBar(1, ImGui.GetContentRegionAvail(), 15, '##'..mq.TLO.Me.CleanName())
            ImGui.PopStyleColor()
            ImGui.SetCursorPosY(ImGui.GetCursorPosY()-20)
            ImGui.SetCursorPosX(ImGui.GetCursorPosX() + 5)
            ImGui.Text(mq.TLO.Me.CleanName())
            ImGui.EndGroup()
            pulse = true
        end
        else
        ImGui.Text(mq.TLO.Me.CleanName())
    end
    --level
    ImGui.SameLine(ImGui.GetWindowWidth() - 40)
    ImGui.Text(tostring(mq.TLO.Me.Level()))
    --class
    ImGui.SameLine(ImGui.GetWindowWidth() - 80)
    ImGui.Text(mq.TLO.Me.Class.ShortName())
    --Visible
    if (mq.TLO.Target()~=nil) then
        ImGui.SameLine(ImGui.GetWindowWidth()/2)
        ImGui.SetCursorPosY(ImGui.GetCursorPosY()-3)
        ImGui.SetWindowFontScale(1.1)
        if (mq.TLO.Target.LineOfSight()) then
            ImGui.PushStyleColor(ImGuiCol.Text, 0, 1, 0, 1)
            ImGui.Text(Icons.MD_VISIBILITY)
            ImGui.PopStyleColor()
            else
            ImGui.PushStyleColor(ImGuiCol.Text, 0.9, 0, 0, 1)
            ImGui.Text(Icons.MD_VISIBILITY_OFF)
            ImGui.PopStyleColor()
        end
    end
    -- My Health
    ImGui.SetWindowFontScale(0.75)
    barColor('red')
    ImGui.ProgressBar(((tonumber(mq.TLO.Me.PctHPs() or 0))/100), ImGui.GetContentRegionAvail(), 10, '##'..mq.TLO.Me.PctHPs())
    ImGui.PopStyleColor()
    ImGui.SetCursorPosY(ImGui.GetCursorPosY()-15)
    ImGui.SetCursorPosX(ImGui.GetCursorPosX() + ((ImGui.GetWindowWidth()/2)-8))
    ImGui.Text(tostring(mq.TLO.Me.PctHPs()))
    --My mana bar
    barColor('blue')
    if (tonumber(mq.TLO.Me.MaxMana())>0) then
        ImGui.ProgressBar(((tonumber(mq.TLO.Me.PctMana() or 0))/100), ImGui.GetContentRegionAvail(), 10, '##' ..mq.TLO.Me.PctMana())
        ImGui.SetCursorPosY(ImGui.GetCursorPosY()-15)
        ImGui.SetCursorPosX(ImGui.GetCursorPosX() + ((ImGui.GetWindowWidth()/2)-8))
        ImGui.Text(tostring(mq.TLO.Me.PctMana()))
        else
        ImGui.Text('')
    end
    ImGui.PopStyleColor()
    --My endurance bar
    barColor('yellow')
    ImGui.ProgressBar(((tonumber(mq.TLO.Me.PctEndurance() or 0))/100), ImGui.GetContentRegionAvail(), 10, '##'..mq.TLO.Me.PctEndurance())
    ImGui.PopStyleColor()
    ImGui.SetCursorPosY(ImGui.GetCursorPosY()-15)
    ImGui.SetCursorPosX(ImGui.GetCursorPosX() + ((ImGui.GetWindowWidth()/2)-8))
    ImGui.Text(tostring(mq.TLO.Me.PctEndurance()))
    ImGui.Separator()
    --target
    if (mq.TLO.Target()~= nil) then
        --Target Health
        barColor('red')
        ImGui.ProgressBar(((tonumber(mq.TLO.Target.PctHPs()or 0))/100), ImGui.GetContentRegionAvail(), 30, '##'..mq.TLO.Target.PctHPs())
        ImGui.PopStyleColor()
        ImGui.SetWindowFontScale(0.9)
        --Target name
        ImGui.SetCursorPosY(ImGui.GetCursorPosY()-35)
        ImGui.SetCursorPosX(8)
        ImGui.Text(mq.TLO.Target.CleanName()..'\n'..tostring(mq.TLO.Target.Level() or 0)..' '..mq.TLO.Target.Class.ShortName())
        --Target lvl
        --ImGui.Text(tostring(mq.TLO.Target.Level() or 0))
        --Target Class
        -- ImGui.SameLine(ImGui.GetWindowWidth()/2)
        --ImGui.Text(mq.TLO.Target.Class.ShortName())
        --Target Distance
        ImGui.SameLine(ImGui.GetWindowWidth() - 35)
        ImGui.Text(tostring(math.floor(mq.TLO.Target.Distance() or 0)))
        ImGui.SameLine()
        ImGui.SetCursorPosY(ImGui.GetCursorPosY()+15)
        ImGui.SetCursorPosX(((ImGui.GetWindowWidth()/2)-8))
        ImGui.SetWindowFontScale(1.0)
        ImGui.Text(tostring(mq.TLO.Target.PctHPs())..'%')
        ImGui.SetWindowFontScale(0.75)
        ImGui.Separator()
        --Aggro % Bar
        if (mq.TLO.Target.Aggressive) then
            barColor('purple')
            ImGui.ProgressBar(((tonumber(mq.TLO.Target.PctAggro() or 0))/100), ImGui.GetContentRegionAvail(), 10, '##'..mq.TLO.Target.PctAggro())
            ImGui.PopStyleColor()
            --Secondary Aggro Person
            if (mq.TLO.Target.SecondaryAggroPlayer()~= nil) then
                ImGui.SetCursorPosY(ImGui.GetCursorPosY()-15)
                ImGui.SetCursorPosX(ImGui.GetCursorPosX() + 5)
                ImGui.Text(mq.TLO.Target.SecondaryAggroPlayer.CleanName())
            end
            --Aggro % Label middle of bar
            ImGui.SetCursorPosY(ImGui.GetCursorPosY()-15)
            ImGui.SetCursorPosX(ImGui.GetCursorPosX() + ((ImGui.GetWindowWidth()/2)-8))
            ImGui.Text(mq.TLO.Target.PctAggro())
            if (mq.TLO.Target.SecondaryAggroPlayer()~= nil) then
                ImGui.SetCursorPosY(ImGui.GetCursorPosY()-18)
                ImGui.SetCursorPosX(ImGui.GetWindowWidth()-40)
                ImGui.Text(mq.TLO.Target.SecondaryPctAggro())
            end
            else
            ImGui.Text('')
        end
        ImGui.Separator()
        --Target Buffs
        if tonumber(mq.TLO.Target.BuffCount()) > 0 then
            targetBuffs(tonumber(mq.TLO.Target.BuffCount()))
        end
        else
        ImGui.Text('')
    end
    ImGui.PopStyleVar()
    ImGui.Spacing()
    ImGui.End()
    return open
end
local openGUI = true
ImGui.Register('GUI_Target', function()
    openGUI = GUI_Target(openGUI)
end)
while openGUI do
    mq.delay(1000)
end