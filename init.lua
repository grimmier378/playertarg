--[[
    Title: PlayerTarget
    Author: Grimmier
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
local gIcon = Icons.MD_SETTINGS
-- set variables
local animSpell = mq.FindTextureAnimation('A_SpellIcons')
local animItem = mq.FindTextureAnimation('A_DragItem')
local TLO = mq.TLO
local ME = TLO.Me
local TARGET = TLO.Target
local BUFF = TLO.Target.Buff
local pulse = true
local iconSize, progressSize = 26, 10
local flashAlpha, ZoomLvl, cAlpha = 1, 1, 255
local ShowGUI, locked, flashBorder, rise, cRise = true, false, true, true, false
local openConfigGUI, openGUI, running = false, true, false
local themeFile = mq.configDir .. '/MyThemeZ.lua'
local configFile = mq.configDir .. '/MyUI_Configs.lua'
local ColorCount, ColorCountConf, StyleCount, StyleCountConf = 0, 0, 0, 0
local themeName = 'Default'
local script = 'PlayerTarg'
local pulseSpeed = 5
local combatPulseSpeed = 10
local colorHpMax = {0.992, 0.138, 0.138, 1.000}
local colorHpMin = {0.551, 0.207, 0.962, 1.000}
local colorMpMax = {0.231, 0.707, 0.938, 1.000}
local colorMpMin = {0.600, 0.231, 0.938, 1.000}
local testValue, testValue2 = 100, 100
local splitTarget = false
local mouseHud, mouseHudTarg = false, false
local ProgressSizeTarget = 30

-- Flags

local tPlayerFlags = bit32.bor(ImGuiTableFlags.NoBordersInBody, ImGuiTableFlags.NoPadInnerX,
ImGuiTableFlags.NoPadOuterX, ImGuiTableFlags.Resizable, ImGuiTableFlags.SizingFixedFit)
local winFlag = bit32.bor(ImGuiWindowFlags.NoTitleBar, ImGuiWindowFlags.MenuBar, ImGuiWindowFlags.NoScrollbar, ImGuiWindowFlags.NoScrollWithMouse)
local targFlag = bit32.bor(ImGuiWindowFlags.NoTitleBar, ImGuiWindowFlags.NoScrollbar, ImGuiWindowFlags.NoScrollWithMouse)

--Tables

local defaults, settings, themeRowBG, themeBorderBG, theme = {}, {}, {}, {}, {}
themeRowBG = {1,1,1,0}
themeBorderBG = {1,1,1,1}

defaults = {
        Scale = 1.0,
        LoadTheme = 'Default',
        locked = false,
        iconSize = 26,
        doPulse = true,
        SplitTarget = false,
        showXtar = false,
        ColorHPMax = {0.992, 0.138, 0.138, 1.000},
        ColorHPMin = {0.551, 0.207, 0.962, 1.000},
        ColorMPMax = {0.231, 0.707, 0.938, 1.000},
        ColorMPMin = {0.600, 0.231, 0.938, 1.000},
        pulseSpeed = 5,
        combatPulseSpeed = 10,
        DynamicHP = false,
        DynamicMP = false,
        FlashBorder = true,
        MouseOver = false,
        WinTransparency = 1.0,
        ProgressSize = 10,
        ProgressSizeTarget = 30,
}

-- Functions

local function GetInfoToolTip()
    local pInfoToolTip = (ME.DisplayName() ..
        '\t\tlvl: ' .. tostring(ME.Level()) ..
        '\nClass: \t ' .. ME.Class.Name() ..
        '\nHealth:\t' .. tostring(ME.CurrentHPs()) .. ' of ' .. tostring(ME.MaxHPs()) ..
        '\nMana:  \t' .. tostring(ME.CurrentMana()) .. ' of ' .. tostring(ME.MaxMana()) ..
        '\nEnd: \t\t ' .. tostring(ME.CurrentEndurance()) .. ' of ' .. tostring(ME.MaxEndurance()) ..
        string.format("\nExp: %d%s",tonumber(ME.PctExp() or 0), '%')
    )
    return pInfoToolTip
end

---comment Check to see if the file we want to work on exists.
---@param name string -- Full Path to file
---@return boolean -- returns true if the file exists and false otherwise
local function File_Exists(name)
    local f=io.open(name,"r")
    if f~=nil then io.close(f) return true else return false end
end

---comment Writes settings from the settings table passed to the setting file (full path required)
-- Uses mq.pickle to serialize the table and write to file
---@param file string -- File Name and path
---@param table table -- Table of settings to write
local function writeSettings(file, table)
    mq.pickle(file, table)
end

local function loadTheme()
    if File_Exists(themeFile) then
        theme = dofile(themeFile)
    else
        theme = require('themes')
    end
    themeName = theme.LoadTheme or 'notheme'
end

local function loadSettings()
    if not File_Exists(configFile) then
        mq.pickle(configFile, defaults)
        loadSettings()
    else

    -- Load settings from the Lua config file
    settings = dofile(configFile)
    if not settings[script] then
        settings[script] = {}
        settings[script] = defaults end
    end

    loadTheme()

    local newSetting = false

    if settings[script].doPulse == nil then
        settings[script].doPulse = true
        newSetting = true
    end
    if settings[script].pulseSpeed == nil then
        settings[script].pulseSpeed = 5
        newSetting = true
    end
    if settings[script].combatPulseSpeed == nil then
        settings[script].combatPulseSpeed = 10
        newSetting = true
    end
    if settings[script].locked == nil then
        settings[script].locked = false
        newSetting = true
    end
    if settings[script].FlashBorder == nil then
        settings[script].FlashBorder = true
        newSetting = true
    end

    if settings[script].Scale == nil then
        settings[script].Scale = 1
        newSetting = true
    end

    if settings[script].IconSize == nil then
        settings[script].IconSize = 26
        newSetting = true
    end

    if settings[script].ColorHPMax == nil then
        settings[script].ColorHPMax = defaults.ColorHPMax
        newSetting = true
    end

    if settings[script].ColorHPMin == nil then
        settings[script].ColorHPMin = defaults.ColorHPMin
        newSetting = true
    end

    if settings[script].ColorMPMax == nil then
        settings[script].ColorMPMax = defaults.ColorMPMax
        newSetting = true
    end

    if settings[script].ColorMPMin == nil then
        settings[script].ColorMPMin = defaults.ColorMPMin
        newSetting = true
    end

    if settings[script].DynamicHP == nil then
        settings[script].DynamicHP = false
        newSetting = true
    end

    if settings[script].DynamicMP == nil then
        settings[script].DynamicMP = false
        newSetting = true
    end

    if settings[script].LoadTheme == nil then
        settings[script].LoadTheme = theme.LoadTheme
        newSetting = true
    end

    if settings[script].ProgressSize == nil then
        settings[script].ProgressSize = progressSize
        newSetting = true
    end
    
    if settings[script].ProgressSizeTarget == nil then
        settings[script].ProgressSizeTarget = 30
        newSetting = true
    end

    if settings[script].SplitTarget == nil then
        settings[script].SplitTarget = false
        newSetting = true
    end

    if settings[script].showXtar == nil then
        settings[script].showXtar = false
        newSetting = true
    end

    --[[        MouseOver = false,
    WinTransparency = 1.0,]]
    if settings[script].MouseOver == nil then
        settings[script].MouseOver = false
        newSetting = true
    end

    if settings[script].WinTransparency == nil then
        settings[script].WinTransparency = 1.0
        newSetting = true
    end


    splitTarget = settings[script].SplitTarget
    colorHpMax = settings[script].ColorHPMax
    colorHpMin = settings[script].ColorHPMin
    colorMpMax = settings[script].ColorMPMax
    colorMpMin = settings[script].ColorMPMin
    combatPulseSpeed = settings[script].combatPulseSpeed
    pulseSpeed = settings[script].pulseSpeed
    pulse = settings[script].doPulse
    flashBorder = settings[script].FlashBorder
    progressSize = settings[script].ProgressSize
    iconSize = settings[script].IconSize
    locked = settings[script].locked
    ZoomLvl = settings[script].Scale
    themeName = settings[script].LoadTheme
    ProgressSizeTarget = settings[script].ProgressSizeTarget

    if newSetting then writeSettings(configFile, settings) end
end

local lastTime = os.clock()
local frameTime = 1 / 60 -- time for each frame at 60 fps
local function pulseIcon(speed)
    if speed == 0 then flashAlpha = 0 pulse = false return end
    local currentTime = os.clock()
    if currentTime - lastTime < frameTime then
        return -- exit if not enough time has passed
    end
    lastTime = currentTime -- update the last time
    if rise == true then
        flashAlpha = flashAlpha + speed
        elseif rise == false then
        flashAlpha = flashAlpha - speed
    end
    if flashAlpha == 200 then rise = false end
    if flashAlpha == 10 then rise = true end
end

local lastTimeCombat = os.clock()
local frameTimeCombat = 1 / 120 -- time for each frame at 60 fps
local function pulseCombat(combatPulseSpeed)
    if combatPulseSpeed == 0 then cAlpha = 255 return end
    local currentTime = os.clock()
    if currentTime - lastTimeCombat < frameTimeCombat then
        return -- exit if not enough time has passed
    end
    lastTimeCombat = currentTime -- update the last time
    if cRise then
        cAlpha = cAlpha + combatPulseSpeed
    else
        cAlpha = cAlpha - combatPulseSpeed
    end
    if cAlpha >= 250 then
        cRise = false
    elseif cAlpha < 10 then
        cRise = true
    end
end

---comment
---@param tName string -- name of the theme to load form table
---@param window string -- name of the window to apply the theme to
---@return integer, integer -- returns the new counter values 
local function DrawTheme(tName, window)
    local StyleCounter = 0
    local ColorCounter = 0
    for tID, tData in pairs(theme.Theme) do
        if tData.Name == tName then
            for pID, cData in pairs(theme.Theme[tID].Color) do
                if window == 'main' then
                    if cData.PropertyName == 'Border' then
                        themeBorderBG = {cData.Color[1], cData.Color[2], cData.Color[3], cData.Color[4]}
                        ColorCounter = ColorCounter + 1
                    elseif cData.PropertyName == 'TableRowBg' then
                        themeRowBG = {cData.Color[1], cData.Color[2], cData.Color[3], cData.Color[4]}
                        ColorCounter = ColorCounter + 1
                    elseif cData.PropertyName == 'WindowBg' then
                        if not settings[script].MouseOver then
                            ImGui.PushStyleColor(ImGuiCol.WindowBg, ImVec4(cData.Color[1], cData.Color[2], cData.Color[3], settings[script].WinTransparency))
                            ColorCounter = ColorCounter + 1
                        elseif settings[script].MouseOver and mouseHud then
                            ImGui.PushStyleColor(ImGuiCol.WindowBg, ImVec4(cData.Color[1], cData.Color[2], cData.Color[3], 1.0))
                            ColorCounter = ColorCounter + 1
                        elseif settings[script].MouseOver and not mouseHud then
                            ImGui.PushStyleColor(ImGuiCol.WindowBg, ImVec4(cData.Color[1], cData.Color[2], cData.Color[3], settings[script].WinTransparency))
                            ColorCounter = ColorCounter + 1
                        end
                    else
                        ImGui.PushStyleColor(pID, ImVec4(cData.Color[1], cData.Color[2], cData.Color[3], cData.Color[4]))
                        ColorCounter = ColorCounter + 1
                    end
                elseif window == 'targ' then
                    if cData.PropertyName == 'Border' then
                        themeBorderBG = {cData.Color[1], cData.Color[2], cData.Color[3], cData.Color[4]}
                        ColorCounter = ColorCounter + 1
                    elseif cData.PropertyName == 'TableRowBg' then
                        themeRowBG = {cData.Color[1], cData.Color[2], cData.Color[3], cData.Color[4]}
                        ColorCounter = ColorCounter + 1
                    elseif cData.PropertyName == 'WindowBg' then
                        if not settings[script].MouseOver then
                            ImGui.PushStyleColor(ImGuiCol.WindowBg, ImVec4(cData.Color[1], cData.Color[2], cData.Color[3], settings[script].WinTransparency))
                            ColorCounter = ColorCounter + 1
                        elseif settings[script].MouseOver and mouseHudTarg then
                            ImGui.PushStyleColor(ImGuiCol.WindowBg, ImVec4(cData.Color[1], cData.Color[2], cData.Color[3], 1.0))
                            ColorCounter = ColorCounter + 1
                        elseif settings[script].MouseOver and not mouseHudTarg then
                            ImGui.PushStyleColor(ImGuiCol.WindowBg, ImVec4(cData.Color[1], cData.Color[2], cData.Color[3], settings[script].WinTransparency))
                            ColorCounter = ColorCounter + 1
                        end
                    else
                        ImGui.PushStyleColor(pID, ImVec4(cData.Color[1], cData.Color[2], cData.Color[3], cData.Color[4]))
                        ColorCounter = ColorCounter + 1
                    end
                else
                    ImGui.PushStyleColor(pID, ImVec4(cData.Color[1], cData.Color[2], cData.Color[3], cData.Color[4]))
                    ColorCounter = ColorCounter + 1
                end
            end
            if tData['Style'] ~= nil then
                if next(tData['Style']) ~= nil then
                    
                    for sID, sData in pairs (theme.Theme[tID].Style) do
                        if sData.Size ~= nil then
                            ImGui.PushStyleVar(sID, sData.Size)
                            StyleCounter = StyleCounter + 1
                            elseif sData.X ~= nil then
                            ImGui.PushStyleVar(sID, sData.X, sData.Y)
                            StyleCounter = StyleCounter + 1
                        end
                    end
                end
            end
        end
    end
    return ColorCounter, StyleCounter
end

local function getDuration(i)
    local remaining = TARGET.Buff(i).Duration() or 0
    remaining = remaining / 1000 -- convert to seconds
    -- Calculate hours, minutes, and seconds
    local h = math.floor(remaining / 3600) or 0
    remaining = remaining % 3600 -- remaining seconds after removing hours
    local m = math.floor(remaining / 60) or 0
    local s = remaining % 60     -- remaining seconds after removing minutes
    -- Format the time string as H : M : S
    local sRemaining = string.format("%02d:%02d:%02d", h, m, s)
    return sRemaining
end

function CalculateColor(minColor, maxColor, value)
    -- Ensure value is within the range of 0 to 100
    value = math.max(0, math.min(100, value))

    -- Calculate the proportion of the value within the range
    local proportion = value / 100

    -- Interpolate between minColor and maxColor based on the proportion
    local r = minColor[1] + proportion * (maxColor[1] - minColor[1])
    local g = minColor[2] + proportion * (maxColor[2] - minColor[2])
    local b = minColor[3] + proportion * (maxColor[3] - minColor[3])
    local a = minColor[4] + proportion * (maxColor[4] - minColor[4])

    return r, g, b, a
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
    local beniColor = IM_COL32(0,20,180,190) -- blue benificial default color
    animSpell:SetTextureCell(iconID or 0)
    local caster = spell.Caster() or '?' -- the caster of the Spell
    if not spell.Beneficial() then 
        beniColor = IM_COL32(255,0,0,190) --red detrimental
    end
    if caster == ME.DisplayName() and not spell.Beneficial() then
        beniColor = IM_COL32(190,190,20,255) -- detrimental cast by me (yellow)
    end
    ImGui.GetWindowDrawList():AddRectFilled(ImGui.GetCursorScreenPosVec() + 1,
        ImGui.GetCursorScreenPosVec() + iconSize, beniColor)
    ImGui.SetCursorPos(cursor_x+3, cursor_y+3)
    if caster == ME.DisplayName() and spell.Beneficial() then
        ImGui.DrawTextureAnimation(animSpell, iconSize - 6, iconSize -6, true)
    else
        ImGui.DrawTextureAnimation(animSpell, iconSize - 5, iconSize - 5)
    end
    ImGui.SetCursorPos(cursor_x+2, cursor_y+2)
    local sName = spell.Name() or '??'
    local sDur = spell.Duration.TotalSeconds() or 0
    ImGui.PushID(tostring(iconID) .. sName .. "_invis_btn")
    if sDur < 18 and sDur > 0 and pulse then
        local flashColor = IM_COL32(0, 0, 0, flashAlpha)
        ImGui.GetWindowDrawList():AddRectFilled(ImGui.GetCursorScreenPosVec() +1,
            ImGui.GetCursorScreenPosVec() + iconSize -4, flashColor)
    end 
    ImGui.SetCursorPos(cursor_x, cursor_y)
    ImGui.InvisibleButton(sName, ImVec2(iconSize, iconSize), bit32.bor(ImGuiButtonFlags.MouseButtonRight))
    if ImGui.IsItemHovered() then
        if (ImGui.IsMouseReleased(1)) then
            spell.Inspect()
            if TLO.MacroQuest.BuildName()=='Emu' then
                mq.cmdf("/nomodkey /altkey /notify TargetWindow Buff%s leftmouseup", i-1)
            end
        end
        ImGui.SetWindowFontScale(ZoomLvl)
        ImGui.BeginTooltip()
        ImGui.Text(sName .. '\n' .. getDuration(i))
        ImGui.EndTooltip()
    end
    ImGui.PopID()
end

---@param type string
---@param txt string
function DrawStatusIcon(iconID, type, txt)
    animSpell:SetTextureCell(iconID or 0)
    animItem:SetTextureCell(iconID or 3996)
    if type == 'item' then
        ImGui.DrawTextureAnimation(animItem, iconSize - 9, iconSize - 9)
    elseif type == 'pwcs' then
        local animPWCS = mq.FindTextureAnimation(iconID)
        animPWCS:SetTextureCell(iconID)
        ImGui.DrawTextureAnimation(animPWCS, iconSize - 9, iconSize - 9)
    else
        ImGui.DrawTextureAnimation(animSpell, iconSize - 9, iconSize - 9)
    end
        if ImGui.IsItemHovered() then
            ImGui.SetWindowFontScale(ZoomLvl)
            ImGui.BeginTooltip()
            ImGui.Text(txt)
            ImGui.EndTooltip()
        end
end

local function targetBuffs(count)
    local iconsDrawn = 0
    -- Width and height of each texture
    local windowWidth = ImGui.GetWindowContentRegionWidth()
    -- Calculate max icons per row based on the window width
    local maxIconsRow = (windowWidth / iconSize) - 0.75
    if rise == true then
        flashAlpha = flashAlpha + 5
    elseif rise == false then
        flashAlpha = flashAlpha - 5
    end
    if flashAlpha == 128 then rise = false end
    if flashAlpha == 25 then rise = true end
    ImGui.BeginGroup()
    ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 0, 0)
    if TARGET.BuffCount() ~= nil then
        for i = 1, count do
            local sIcon = BUFF(i).SpellIcon() or 0
            if BUFF(i)~= nil then
                DrawInspectableSpellIcon(sIcon, BUFF(i), i)
                iconsDrawn = iconsDrawn + 1
            end
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
    end
    ImGui.PopStyleVar()
    ImGui.EndGroup()
end

---@param spawn MQSpawn
local function getConLevel(spawn)
    local conColor = string.lower(spawn.ConColor()) or 'WHITE'
    return conColor
end

-- GUI
local function PlayerTargConf_GUI(open)
    if not openConfigGUI then return end
    ColorCountConf = 0
	StyleCountConf = 0
    ColorCountConf, StyleCountConf = DrawTheme(themeName, 'config')
    open, openConfigGUI = ImGui.Begin("PlayerTarg Conf##"..script, open, bit32.bor(ImGuiWindowFlags.None, ImGuiWindowFlags.NoCollapse, ImGuiWindowFlags.AlwaysAutoResize))
    ImGui.SetWindowFontScale(ZoomLvl)
    if not openConfigGUI then
        openConfigGUI = false
        open = false
        if StyleCountConf > 0 then ImGui.PopStyleVar(StyleCountConf) end
        if ColorCountConf > 0 then ImGui.PopStyleColor(ColorCountConf) end
        ImGui.SetWindowFontScale(1)
        ImGui.End()
        return open
    end
    ImGui.SeparatorText("Theme##"..script)

    ImGui.Text("Cur Theme: %s", themeName)
    -- Combo Box Load Theme
    if ImGui.BeginCombo("Load Theme##"..script, themeName) then
        ImGui.SetWindowFontScale(ZoomLvl)
        for k, data in pairs(theme.Theme) do
            local isSelected = data.Name == themeName
            if ImGui.Selectable(data.Name, isSelected) then
                theme.LoadTheme = data.Name
                themeName = theme.LoadTheme
                settings[script].LoadTheme = themeName
            end
        end
        ImGui.EndCombo()
    end

    if ImGui.Button('Reload Theme File') then
        loadTheme()
    end
    
    settings[script].MouseOver = ImGui.Checkbox('Mouse Over', settings[script].MouseOver)
    settings[script].WinTransparency = ImGui.SliderFloat('Window Transparency##'..script, settings[script].WinTransparency, 0.1, 1.0)
    ImGui.SeparatorText("Scaling##"..script)
    -- Slider for adjusting zoom level
    local tmpZoom = ZoomLvl
    if ZoomLvl then
        tmpZoom = ImGui.SliderFloat("Zoom Level##"..script, tmpZoom, 0.5, 2.0)
    end
    if ZoomLvl ~= tmpZoom then
        ZoomLvl = tmpZoom
    end
    -- Slider for adjusting Icon Size
    local tmpSize = iconSize
    if iconSize then
        tmpSize = ImGui.SliderInt("Icon Size##"..script, tmpSize, 15, 50)
    end
    if iconSize ~= tmpSize then
        iconSize = tmpSize
    end

    -- Slider for adjusting Progress Bar Size
    local tmpPrgSz = progressSize
    if progressSize then
        tmpPrgSz = ImGui.SliderInt("Progress Bar Size##"..script, tmpPrgSz, 5, 50)
    end
    if progressSize ~= tmpPrgSz then
        progressSize = tmpPrgSz
    end
    ProgressSizeTarget = ImGui.SliderInt("Target Progress Bar Size##"..script, ProgressSizeTarget, 5, 150)
    settings[script].showXtar = ImGui.Checkbox('Show XTarget Number', settings[script].showXtar)
    ImGui.SeparatorText("Pulse Settings##"..script)
    flashBorder = ImGui.Checkbox('Flash Border', flashBorder)
    ImGui.SameLine()
    local tmpPulse = pulse
    tmpPulse , _= ImGui.Checkbox('Pulse Icons', tmpPulse)
    if _ then
        if tmpPulse == true and pulseSpeed == 0 then
            pulseSpeed = defaults.pulseSpeed
        end
    end
    if pulse ~= tmpPulse then
        pulse = tmpPulse
    end
    if pulse then
        local tmpSpeed = pulseSpeed
        tmpSpeed = ImGui.SliderInt('Icon Pulse Speed##'..script, tmpSpeed, 0, 50)
        if pulseSpeed ~= tmpSpeed then
            pulseSpeed = tmpSpeed
        end
    end
    local tmpCmbtSpeed = combatPulseSpeed
    tmpCmbtSpeed = ImGui.SliderInt('Combat Pulse Speed##'..script, tmpCmbtSpeed, 0, 50)
    if combatPulseSpeed ~= tmpCmbtSpeed then
        combatPulseSpeed = tmpCmbtSpeed
    end

    if ImGui.Button('Reset Defaults##'..script) then
        settings = dofile(configFile)
        flashBorder = false
        progressSize = 10
        ZoomLvl = 1
        iconSize = 26
        themeName = 'Default'
        settings[script].FlashBorder = flashBorder
        settings[script].ProgressSize = progressSize
        settings[script].Scale = ZoomLvl
        settings[script].IconSize = iconSize
        settings[script].LoadTheme = themeName
    end

    ImGui.SeparatorText("Dynamic Bar Colors##"..script)
    local tmpDHP = settings[script].DynamicHP
    local tmpDMP = settings[script].DynamicMP

    tmpDHP = ImGui.Checkbox('Dynamic HP Bar', tmpDHP)
    if tmpDHP ~= settings[script].DynamicHP then
        settings[script].DynamicHP = tmpDHP
    end
    ImGui.SameLine()
    ImGui.SetNextItemWidth(60)
    colorHpMin = ImGui.ColorEdit4("HP Min Color##"..script, colorHpMin, bit32.bor(ImGuiColorEditFlags.AlphaBar, ImGuiColorEditFlags.NoInputs))
    ImGui.SameLine()
    ImGui.SetNextItemWidth(60)
    colorHpMax = ImGui.ColorEdit4("HP Max Color##"..script, colorHpMax, bit32.bor(ImGuiColorEditFlags.AlphaBar, ImGuiColorEditFlags.NoInputs))

    testValue = ImGui.SliderInt("Test HP##"..script, testValue, 0, 100)
    local r, g, b, a = CalculateColor(colorHpMin, colorHpMax, testValue)
    ImGui.PushStyleColor(ImGuiCol.PlotHistogram,ImVec4(r, g, b, a))
    ImGui.ProgressBar((testValue / 100), ImGui.GetContentRegionAvail(), progressSize , '##Test')
    ImGui.PopStyleColor()
    tmpDMP = ImGui.Checkbox('Dynamic Mana Bar', tmpDMP)
    if tmpDMP ~= settings[script].DynamicMP then
        settings[script].DynamicMP = tmpDMP
    end
    ImGui.SameLine()
    ImGui.SetNextItemWidth(60)
    colorMpMin = ImGui.ColorEdit4("Mana Min Color##"..script, colorMpMin, bit32.bor( ImGuiColorEditFlags.NoInputs))
    ImGui.SameLine()
    ImGui.SetNextItemWidth(60)
    colorMpMax = ImGui.ColorEdit4("Mana Max Color##"..script, colorMpMax, bit32.bor( ImGuiColorEditFlags.NoInputs))
    
    testValue2 = ImGui.SliderInt("Test MP##"..script, testValue2, 0, 100)
    local r2, g2, b2, a2 = CalculateColor(colorMpMin, colorMpMax, testValue2)
    ImGui.PushStyleColor(ImGuiCol.PlotHistogram,ImVec4(r2, g2, b2, a2))
    ImGui.ProgressBar((testValue2 / 100), ImGui.GetContentRegionAvail(), progressSize , '##Test')
    ImGui.PopStyleColor()

    ImGui.SeparatorText("Save and Close##"..script)
    if ImGui.Button('Save and Close##'..script) then
        openConfigGUI = false
        settings[script].ProgressSizeTarget = ProgressSizeTarget
        settings[script].ColorHPMax = colorHpMax
        settings[script].ColorHPMin = colorHpMin
        settings[script].ColorMPMax = colorMpMax
        settings[script].ColorMPMin = colorMpMin
        settings[script].DynamicHP = tmpDHP
        settings[script].DynamicMP = tmpDMP
        settings[script].FlashBorder = flashBorder
        settings[script].ProgressSize = progressSize
        settings[script].Scale = ZoomLvl
        settings[script].IconSize = iconSize
        settings[script].LoadTheme = themeName
        settings[script].doPulse = pulse
        settings[script].pulseSpeed = pulseSpeed
        settings[script].combatPulseSpeed = combatPulseSpeed
        writeSettings(configFile,settings)
    end
    if StyleCountConf > 0 then ImGui.PopStyleVar(StyleCountConf) end
    if ColorCountConf > 0 then ImGui.PopStyleColor(ColorCountConf) end
    ImGui.SetWindowFontScale(1)
    ImGui.End()

end

local function findXTarSlot(id)
    for i = 1 , mq.TLO.Me.XTargetSlots() do
        if mq.TLO.Me.XTarget(i).ID() == id then
            return i
        end
    end 
end

local function drawTarget()
    if (TARGET() ~= nil) then
        ImGui.BeginGroup()
        local targetName = TARGET.CleanName() or '?'
        local xSlot = findXTarSlot(TARGET.ID()) or 0
        local tC = getConLevel(TARGET) or "WHITE"
        if tC == 'red' then tC = 'pink' end
        local tClass = TARGET.Class.ShortName() == 'UNKNOWN CLASS' and Icons.MD_HELP_OUTLINE or
            TARGET.Class.ShortName()
        local tLvl = TARGET.Level() or 0
        local tBodyType = TARGET.Body.Name() or '?'
        --Target Health Bar
        ImGui.BeginGroup()
        if settings[script].DynamicHP then
            local tr,tg,tb,ta = CalculateColor(colorHpMin, colorHpMax, TARGET.PctHPs())
            ImGui.PushStyleColor(ImGuiCol.PlotHistogram, ImVec4(tr, tg,tb, ta))
        else
            if TARGET.PctHPs() < 25 then
                ImGui.PushStyleColor(ImGuiCol.PlotHistogram,(COLOR.color('orange')))
            else
                ImGui.PushStyleColor(ImGuiCol.PlotHistogram,(COLOR.color('red')))
            end
        end
        ImGui.ProgressBar(((tonumber(TARGET.PctHPs() or 0)) / 100), ImGui.GetContentRegionAvail(), ProgressSizeTarget,'##' .. TARGET.PctHPs())
        ImGui.PopStyleColor()
                    
        if ImGui.IsItemHovered() then
            ImGui.SetWindowFontScale(ZoomLvl)
            ImGui.BeginTooltip()
            ImGui.Text("Name: %s\t Lvl: %s\nClass: %s\nType: %s", targetName,tLvl,tClass,tBodyType )
            ImGui.EndTooltip()
        end
        ImGui.SetWindowFontScale(ZoomLvl)
        ImGui.SetCursorPosY(ImGui.GetCursorPosY() - (ProgressSizeTarget + 4))
        ImGui.SetCursorPosX(9)
        if ImGui.BeginTable("##targetInfoOverlay", 2, tPlayerFlags) then
            ImGui.TableSetupColumn("##col1", ImGuiTableColumnFlags.NoResize, (ImGui.GetContentRegionAvail() * .5) - 8)
            ImGui.TableSetupColumn("##col2", ImGuiTableColumnFlags.NoResize, (ImGui.GetContentRegionAvail() * .5) + 8) -- Adjust width for distance and Aggro% text
            -- First Row: Name, con, distance
            ImGui.TableNextRow()
            ImGui.TableSetColumnIndex(0)
            -- Name and CON in the first column
            if xSlot > 0 and settings[script].showXtar then
                ImGui.Text("X#%s %s", xSlot, targetName)
            else
                ImGui.Text("%s",targetName)
            end
            -- Distance in the second column
            ImGui.TableSetColumnIndex(1)
    
            ImGui.PushStyleColor(ImGuiCol.Text,COLOR.color(tC))
            if tC == 'pink' then
                ImGui.Text('   ' .. Icons.MD_WARNING)
            else
                ImGui.Text('   ' .. Icons.MD_LENS)
            end
            ImGui.PopStyleColor()
            
            ImGui.SameLine(ImGui.GetColumnWidth() - 35)
            ImGui.PushStyleColor(ImGuiCol.Text,COLOR.color('yellow'))

            ImGui.Text(tostring(math.floor(TARGET.Distance() or 0)) .. 'm')
            ImGui.PopStyleColor()
            -- Second Row: Class, Level, and Aggro%
            ImGui.TableNextRow()
            ImGui.TableSetColumnIndex(0) -- Class and Level in the first column
    
            ImGui.Text(tostring(tLvl) .. ' ' .. tClass .. '\t' .. tBodyType)
            -- Aggro% text in the second column
            ImGui.TableSetColumnIndex(1)
            ImGui.SetWindowFontScale(ZoomLvl)
            ImGui.Text(tostring(TARGET.PctHPs()) .. '%')
            ImGui.EndTable()
        end
        ImGui.EndGroup()
        ImGui.SetWindowFontScale(ZoomLvl)
        ImGui.Separator()
        --Aggro % Bar
        ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 8, 1)
        if (TARGET.Aggressive) then
            local yPos = ImGui.GetCursorPosY() +2
            ImGui.BeginGroup()
            if TARGET.PctAggro() < 100 then 
                ImGui.PushStyleColor(ImGuiCol.PlotHistogram,(COLOR.color('orange')))
            else
                ImGui.PushStyleColor(ImGuiCol.PlotHistogram,(COLOR.color('purple')))
            end                
            ImGui.ProgressBar(((tonumber(TARGET.PctAggro() or 0)) / 100), ImGui.GetContentRegionAvail(), progressSize,
                '##pctAggro')
            ImGui.PopStyleColor()
            --Secondary Aggro Person
                        
            if (TARGET.SecondaryAggroPlayer() ~= nil) then
                ImGui.SetCursorPosY(yPos)
                ImGui.SetCursorPosX(ImGui.GetCursorPosX() + 5)
                ImGui.Text(TARGET.SecondaryAggroPlayer())
            end
            --Aggro % Label middle of bar
            ImGui.SetCursorPosY(yPos)
            ImGui.SetCursorPosX(ImGui.GetCursorPosX() + ((ImGui.GetWindowWidth() / 2) - 8))
            ImGui.Text(TARGET.PctAggro())
            if (TARGET.SecondaryAggroPlayer() ~= nil) then
                ImGui.SetCursorPosY(yPos)
                ImGui.SetCursorPosX(ImGui.GetWindowWidth() - 40)
                ImGui.Text(TARGET.SecondaryPctAggro())
            end
            ImGui.EndGroup()
        else
            ImGui.Text('')
        end
        ImGui.PopStyleVar()
        ImGui.EndGroup()
        if ImGui.IsItemHovered() and ImGui.IsMouseReleased(ImGuiMouseButton.Left) then
            if TLO.Cursor() then
                mq.cmdf('/multiline ; /if (${Cursor.ID}) /click left target')
            end
        end
        --Target Buffs
        if tonumber(TARGET.BuffCount()) > 0 then
            local windowWidth, windowHeight = ImGui.GetContentRegionAvail()
            -- Begin a scrollable child
            ImGui.BeginChild("TargetBuffsScrollRegion", ImVec2(windowWidth, windowHeight),ImGuiChildFlags.Border)
            targetBuffs(tonumber(TARGET.BuffCount()))
            ImGui.EndChild()
            -- End the scrollable region
        end
                    
    else
        ImGui.Text('')
    end
end

function GUI_Target()
    if not ShowGUI then return end
    if TLO.Me.Zoning() then return end
    ColorCount = 0
    StyleCount = 0
    local flags = winFlag
    -- Default window size
    ImGui.SetNextWindowSize(216, 239, ImGuiCond.FirstUseEver)
    ColorCount, StyleCount = DrawTheme(themeName,'main')
    if locked then
        flags = bit32.bor(ImGuiWindowFlags.NoTitleBar, ImGuiWindowFlags.NoScrollbar, ImGuiWindowFlags.MenuBar, ImGuiWindowFlags.NoMove, ImGuiWindowFlags.NoScrollWithMouse)
    end
    local open, show = ImGui.Begin(ME.DisplayName().."##Target", true, flags)
    if show then
        
        mouseHud = ImGui.IsWindowHovered(ImGuiHoveredFlags.ChildWindows)

    -- ImGui.BeginGroup()
        if ImGui.BeginMenuBar() then
            -- if ZoomLvl > 1.25 then ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, 4,7) end
            local lockedIcon = locked and Icons.FA_LOCK .. '##lockTabButton_MyChat' or
            Icons.FA_UNLOCK .. '##lockTablButton_MyChat'
            if ImGui.Button(lockedIcon) then
                --ImGuiWindowFlags.NoMove
                locked = not locked
                settings = dofile(configFile)
                settings[script].locked = locked
                writeSettings(configFile, settings)
            end
            if ImGui.IsItemHovered() then
                ImGui.SetWindowFontScale(ZoomLvl)
                ImGui.BeginTooltip()
                ImGui.Text("Lock Window")
                ImGui.EndTooltip()
            end
            if ImGui.Button(gIcon..'##PlayerTarg') then
                openConfigGUI = not openConfigGUI
            end
            local splitIcon = splitTarget and Icons.FA_TOGGLE_ON ..'##PtargSplit' or Icons.FA_TOGGLE_OFF ..'##PtargSplit'
            if ImGui.Button(splitIcon) then
                splitTarget = not splitTarget
                settings = dofile(configFile)
                settings[script].SplitTarget = splitTarget
                writeSettings(configFile, settings)
            end
            if ImGui.IsItemHovered() then
                ImGui.SetWindowFontScale(ZoomLvl)
                ImGui.BeginTooltip()
                ImGui.Text("Split Windows")
                ImGui.EndTooltip()
            end
            ImGui.SetCursorPosX(ImGui.GetWindowContentRegionWidth() - 10)
            if ImGui.MenuItem('X##Close'..script) then
                running = false
            end
            ImGui.EndMenuBar()
        end
        
        ImGui.SetCursorPosX((ImGui.GetContentRegionAvail() / 2) - 22)
        ImGui.Dummy(iconSize - 5, iconSize - 6)
        ImGui.SameLine()
        ImGui.SetCursorPosX(5)
        -- Player Information
        -- ImGui.PushStyleVar(ImGuiStyleVar.CellPadding)
        ImGui.BeginGroup()
        local tPFlags = tPlayerFlags
        local cFlag = bit32.bor(ImGuiChildFlags.AlwaysAutoResize)
        if ME.Combat() then
            if flashBorder then
                ImGui.PushStyleColor(ImGuiCol.Border,0.9, 0.1, 0.1, (cAlpha/255))
                cFlag = bit32.bor(ImGuiChildFlags.Border,cFlag)
                tPFlags = tPlayerFlags
            else
                ImGui.PushStyleColor(ImGuiCol.TableRowBg,0.9, 0.1, 0.1, (cAlpha/255))
                tPFlags = bit32.bor(ImGuiTableFlags.RowBg, tPlayerFlags)
                cFlag = bit32.bor(ImGuiChildFlags.AlwaysAutoResize)
            end
        else
            if flashBorder then
                ImGui.PushStyleColor(ImGuiCol.Border,themeBorderBG[1], themeBorderBG[2], themeBorderBG[3], themeBorderBG[4])
                cFlag = bit32.bor(ImGuiChildFlags.Border,cFlag)
                tPFlags = tPlayerFlags
            else
                ImGui.PushStyleColor(ImGuiCol.TableRowBg,themeRowBG[1], themeRowBG[2], themeRowBG[3], themeRowBG[4])
                tPFlags = bit32.bor(ImGuiTableFlags.RowBg, tPlayerFlags)
                cFlag = bit32.bor(ImGuiChildFlags.AlwaysAutoResize)
            end
        end
        ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, 1,1)
        ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, 4,2)
        if flashBorder then ImGui.BeginChild('pInfo##', 0,((iconSize+4)*ZoomLvl),cFlag) end
        if ImGui.BeginTable("##playerInfo", 4, tPFlags) then
            ImGui.TableSetupColumn("##tName", ImGuiTableColumnFlags.NoResize, (ImGui.GetContentRegionAvail() * .5))
            ImGui.TableSetupColumn("##tVis", ImGuiTableColumnFlags.NoResize, 24)
            ImGui.TableSetupColumn("##tIcons", ImGuiTableColumnFlags.WidthStretch, 80) --ImGui.GetContentRegionAvail()*.25)
            ImGui.TableSetupColumn("##tLvl", ImGuiTableColumnFlags.NoResize, 30)
            ImGui.TableNextRow()

            -- Name
            ImGui.SetWindowFontScale(ZoomLvl)
            ImGui.TableSetColumnIndex(0)
            local meName = ME.DisplayName()
            ImGui.Text(" %s",meName)
            local combatState = ME.CombatState()
            if ME.Poisoned() and ME.Diseased() then
                ImGui.SameLine(ImGui.GetColumnWidth() - 45)
                DrawStatusIcon(2579,'item','Diseased and Posioned')
            elseif ME.Poisoned() then 
                ImGui.SameLine(ImGui.GetColumnWidth() - 45)
                DrawStatusIcon(42,'spell','Posioned')
            elseif ME.Diseased() then
                ImGui.SameLine(ImGui.GetColumnWidth() - 45)
                DrawStatusIcon(41,'spell','Diseased')
            elseif ME.Dotted() then
                ImGui.SameLine(ImGui.GetColumnWidth() - 45)
                DrawStatusIcon(5987,'item','Dotted')
            elseif ME.Cursed() then
                ImGui.SameLine(ImGui.GetColumnWidth() - 45)
                DrawStatusIcon(5759,'item','Cursed')
            elseif ME.Corrupted() then
                ImGui.SameLine(ImGui.GetColumnWidth() - 45)
                DrawStatusIcon(5758,'item','Corrupted')
            end
            ImGui.SameLine(ImGui.GetColumnWidth() - 25)
            if combatState == 'DEBUFFED' then                
                DrawStatusIcon('A_PWCSDebuff','pwcs','You are Debuffed and need a cure before resting.')
            elseif combatState == 'ACTIVE' then
                DrawStatusIcon('A_PWCSStanding','pwcs','You are not in combat and may rest at any time.')
            elseif combatState == 'COOLDOWN' then
                DrawStatusIcon('A_PWCSTimer','pwcs','You are recovering from combat and can not reset yet')
            elseif combatState == 'RESTING' then
                DrawStatusIcon('A_PWCSRegen','pwcs','You are Resting.')
            elseif combatState == 'COMBAT' then
                DrawStatusIcon('A_PWCSInCombat','pwcs','You are in Combat.')
            else
                DrawStatusIcon(3996,'item',' ')
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
            ImGui.SetWindowFontScale(ZoomLvl)
            -- Icons
            ImGui.TableSetColumnIndex(2)
            ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 0, 0)
            ImGui.Text('')
            if TLO.Group.MainTank.ID() == ME.ID() then
                ImGui.SameLine()
                DrawStatusIcon('A_Tank','pwcs','Main Tank')
            end
            if TLO.Group.MainAssist.ID() == ME.ID() then
                ImGui.SameLine()
                DrawStatusIcon('A_Assist','pwcs','Main Assist')
            end
            if TLO.Group.Puller.ID() == ME.ID() then
                ImGui.SameLine()
                DrawStatusIcon('A_Puller','pwcs','Puller')
            end
            ImGui.SameLine()
            --  ImGui.SameLine()
            ImGui.Text(' ')
            ImGui.SameLine()
            ImGui.SetWindowFontScale(ZoomLvl)
            ImGui.Text(ME.Heading() or '??')
            ImGui.PopStyleVar()
            -- Lvl
            ImGui.TableSetColumnIndex(3)
            ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 2, 0)
            ImGui.SetWindowFontScale(ZoomLvl)
            ImGui.Text(tostring(ME.Level() or 0))
            if ImGui.IsItemHovered() then
                ImGui.BeginTooltip()
                ImGui.SetWindowFontScale(ZoomLvl)
                ImGui.Text(GetInfoToolTip())
                ImGui.EndTooltip()
            end
            ImGui.PopStyleVar()
            ImGui.EndTable()
            
        end
        if flashBorder then ImGui.EndChild() end
        ImGui.PopStyleColor()
        ImGui.PopStyleVar()
        ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, 4,3)
        
        ImGui.Separator()
        ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 8, 1)
        -- My Health Bar
        local yPos = ImGui.GetCursorPosY()
        ImGui.SetWindowFontScale(ZoomLvl)
        if settings[script].DynamicHP then
            local hr,hg,hb,ha = CalculateColor(colorHpMin, colorHpMax, ME.PctHPs())
            ImGui.PushStyleColor(ImGuiCol.PlotHistogram, ImVec4(hr, hg, hb, ha))
        else
            if ME.PctHPs() <= 0 then
                ImGui.PushStyleColor(ImGuiCol.PlotHistogram,(COLOR.color('purple')))
            elseif ME.PctHPs() < 15 then
                if pulse then
                    ImGui.PushStyleColor(ImGuiCol.PlotHistogram,(COLOR.color('orange')))
                    if not ME.CombatState() == 'COMBAT' then pulse = false end
                else
                    ImGui.PushStyleColor(ImGuiCol.PlotHistogram,(COLOR.color('red')))
                    if not ME.CombatState() == 'COMBAT' then pulse = true end
                end
            else
                ImGui.PushStyleColor(ImGuiCol.PlotHistogram,(COLOR.color('red')))
            end
        end
        ImGui.ProgressBar(((tonumber(ME.PctHPs() or 0)) / 100), ImGui.GetContentRegionAvail(), progressSize , '##pctHps')
        ImGui.PopStyleColor()
        ImGui.SetCursorPosY(yPos-1)
        ImGui.SetCursorPosX(ImGui.GetCursorPosX() + ((ImGui.GetWindowWidth() / 2) - 8))
        ImGui.Text(tostring(ME.PctHPs() or 0))
        local yPos = ImGui.GetCursorPosY()
        --My Mana Bar
        if (tonumber(ME.MaxMana()) > 0) then
            if settings[script].DynamicMP then
                local mr,mg,mb,ma = CalculateColor(colorMpMin, colorMpMax, ME.PctMana())
                ImGui.PushStyleColor(ImGuiCol.PlotHistogram, ImVec4(mr, mg, mb, ma))
            else
                ImGui.PushStyleColor(ImGuiCol.PlotHistogram,(COLOR.color('light blue2')))
            end
            ImGui.ProgressBar(((tonumber(ME.PctMana() or 0)) / 100), ImGui.GetContentRegionAvail(), progressSize, '##pctMana')
            ImGui.PopStyleColor()
            ImGui.SetCursorPosY(yPos -1)
            ImGui.SetCursorPosX(ImGui.GetCursorPosX() + ((ImGui.GetWindowWidth() / 2) - 8))
            ImGui.Text(tostring(ME.PctMana() or 0))
        end
        local yPos = ImGui.GetCursorPosY()
        --My Endurance bar
        ImGui.PushStyleColor(ImGuiCol.PlotHistogram,(COLOR.color('yellow2')))
        ImGui.ProgressBar(((tonumber(ME.PctEndurance() or 0)) / 100), ImGui.GetContentRegionAvail(), progressSize, '##pctEndurance')
        ImGui.PopStyleColor()
        ImGui.SetCursorPosY(yPos -1)
        ImGui.SetCursorPosX(ImGui.GetCursorPosX() + ((ImGui.GetWindowWidth() / 2) - 8))
        ImGui.Text(tostring(ME.PctEndurance() or 0))
        ImGui.Separator()
        ImGui.EndGroup()
        if ImGui.IsItemHovered() and ImGui.IsMouseReleased(ImGuiMouseButton.Left) then
            mq.cmdf("/target %s", ME())
        end
        ImGui.PopStyleVar()
        --Target Info
        if not splitTarget then
            drawTarget()
        end
        ImGui.PopStyleVar(2)
    end
    if StyleCount > 0 then ImGui.PopStyleVar(StyleCount) end
    if ColorCount > 0 then ImGui.PopStyleColor(ColorCount) end
    ImGui.SetWindowFontScale(1)
    ImGui.End()

    
    if splitTarget and TARGET() ~= nil then
        local colorCountTarget, styleCountTarget = DrawTheme(themeName, 'targ')
        local openT, showT = ImGui.Begin("Target##TargetPopout", true, targFlag)
        if showT then
            if ImGui.IsWindowHovered(ImGuiHoveredFlags.ChildWindows) then
                mouseHudTarg = true
            else
                mouseHudTarg = false
            end
            ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, 1,1)
            ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, 4,2)
            drawTarget()
            ImGui.PopStyleVar(2)
        end
        
        if styleCountTarget > 0 then ImGui.PopStyleVar(styleCountTarget) end
        if colorCountTarget > 0 then ImGui.PopStyleColor(colorCountTarget) end
        ImGui.SetWindowFontScale(1)
        ImGui.End()
    end
end

--Setup and Loop

local function init()
    running = true
    loadSettings()
    mq.imgui.init('GUI_Target', GUI_Target)
    mq.imgui.init("PlayerTargConfig", PlayerTargConf_GUI)
end

local function MainLoop()
    while running do
        if TLO.Window('CharacterListWnd').Open() then return false end
        mq.delay(100)
        pulseIcon(pulseSpeed)
        pulseCombat(combatPulseSpeed)
        if ME.Zoning() then
            ShowGUI = false
        else
            ShowGUI = true
        end
        -- if not openGUI then
        --     openGUI = ShowGUI
        --     GUI_Target(openGUI)
        -- end
    end
end

init()
printf("\ag %s \aw[\ayPlayer Targ\aw] ::\a-t Loaded",TLO.Time())
MainLoop()
