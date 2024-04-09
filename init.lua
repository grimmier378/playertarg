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
local winFlag = bit32.bor(ImGuiWindowFlags.NoTitleBar, ImGuiWindowFlags.MenuBar, ImGuiWindowFlags.NoScrollbar, ImGuiWindowFlags.NoScrollWithMouse)
local pulse = true
local iconSize = 26
local flashAlpha = 1
local rise = true
local ShowGUI, locked, flashBorder = true, false, true
local openConfigGUI, openGUI = false, true
local ver = "v1.69"
local tPlayerFlags = bit32.bor(ImGuiTableFlags.NoBordersInBody, ImGuiTableFlags.NoPadInnerX,
    ImGuiTableFlags.NoPadOuterX, ImGuiTableFlags.Resizable, ImGuiTableFlags.SizingFixedFit)
local progressSize = 10
local theme = {}
local ZoomLvl = 1
local themeFile = mq.configDir .. '/MyThemeZ.lua'
local ColorCount, ColorCountConf, StyleCount, StyleCountConf = 0, 0, 0, 0
local themeName = 'Default'
local script = 'PlayerTarg'
local defaults, settings, temp = {}, {}, {}
local themeRowBG, themeBorderBG = {}, {}
themeRowBG = {1,1,1,0}
themeBorderBG = {1,1,1,1}

defaults = {
        Scale = 1.0,
        LoadTheme = 'Default',
        locked = false,
        iconSize = 26,
        FlashBorder = true,
        ProgressSize = 10,
}
local configFile = mq.configDir .. '/MyUI_Configs.lua'

local function GetInfoToolTip()
    local pInfoToolTip = (ME.DisplayName() ..
        '\t\tlvl: ' .. tostring(ME.Level()) ..
        '\nClass: ' .. ME.Class.Name() ..
        '\nHealth: ' .. tostring(ME.CurrentHPs()) .. ' of ' .. tostring(ME.MaxHPs()) ..
        '\nMana: ' .. tostring(ME.CurrentMana()) .. ' of ' .. tostring(ME.MaxMana()) ..
        '\nEnd: ' .. tostring(ME.CurrentEndurance()) .. ' of ' .. tostring(ME.MaxEndurance())
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
---@param settings table -- Table of settings to write
local function writeSettings(file, settings)
    mq.pickle(file, settings)
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
    temp = {}
    settings = dofile(configFile)
    if not settings[script] then
        settings[script] = {}
        settings[script] = defaults end
        temp = settings[script]
    end

    loadTheme()

    if settings[script].locked == nil then
        settings[script].locked = false
    end
    if settings[script].FlashBorder == nil then
        settings[script].FlashBorder = true
    end

    if settings[script].Scale == nil then
        settings[script].Scale = 1
    end

    if settings[script].IconSize == nil then
        settings[script].IconSize = 26
    end

    if settings[script].LoadTheme == nil then
        settings[script].LoadTheme = theme.LoadTheme
    end

    if settings[script].ProgressSize == nil then
        settings[script].ProgressSize = progressSize
    end
    flashBorder = settings[script].FlashBorder
    progressSize = settings[script].ProgressSize
    iconSize = settings[script].IconSize
    locked = settings[script].locked
    ZoomLvl = settings[script].Scale
    themeName = settings[script].LoadTheme

    writeSettings(configFile, settings)

    temp = settings[script]
end

---comment
---@param themeName string -- name of the theme to load form table
---@return integer, integer -- returns the new counter values 
local function DrawTheme(themeName)
    local StyleCounter = 0
    local ColorCounter = 0
    for tID, tData in pairs(theme.Theme) do
        if tData.Name == themeName then
            for pID, cData in pairs(theme.Theme[tID].Color) do
                ImGui.PushStyleColor(pID, ImVec4(cData.Color[1], cData.Color[2], cData.Color[3], cData.Color[4]))
                ColorCounter = ColorCounter + 1
                if cData.PropertyName == 'Border' then
                    themeBorderBG = {cData.Color[1], cData.Color[2], cData.Color[3], cData.Color[4]}
                elseif cData.PropertyName == 'TableRowBg' then
                    themeRowBG = {cData.Color[1], cData.Color[2], cData.Color[3], cData.Color[4]}
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
    if sDur < 18 and sDur > 0 then
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

local function PlayerTargConf_GUI(open)
    if not openConfigGUI then return end
    ColorCountConf = 0
	StyleCountConf = 0
    ColorCountConf, StyleCountConf = DrawTheme(themeName)
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

    flashBorder = ImGui.Checkbox('Flash Border', flashBorder)
    ImGui.SameLine()
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

    ImGui.SeparatorText("Save and Close##"..script)
    if ImGui.Button('Save and Close##'..script) then
        openConfigGUI = false
        settings = dofile(configFile)
        settings[script].FlashBorder = flashBorder
        settings[script].ProgressSize = progressSize
        settings[script].Scale = ZoomLvl
        settings[script].IconSize = iconSize
        settings[script].LoadTheme = themeName
        writeSettings(configFile,settings)
    end
    if StyleCountConf > 0 then ImGui.PopStyleVar(StyleCountConf) end
    if ColorCountConf > 0 then ImGui.PopStyleColor(ColorCountConf) end
    ImGui.SetWindowFontScale(1)
    ImGui.End()

end

local cRise = false
local cAlpha = 255
function GUI_Target(open)
    if not ShowGUI then return end
    if TLO.Me.Zoning() then return end
    ColorCount = 0
    StyleCount = 0
    local flags = winFlag
    -- Default window size
    ImGui.SetNextWindowSize(216, 239, ImGuiCond.FirstUseEver)
    ColorCount, StyleCount = DrawTheme(themeName)
    local show = false
    if locked then
        flags = bit32.bor(ImGuiWindowFlags.NoTitleBar, ImGuiWindowFlags.NoScrollbar, ImGuiWindowFlags.MenuBar, ImGuiWindowFlags.NoMove, ImGuiWindowFlags.NoScrollWithMouse)
    end
    open, show = ImGui.Begin(ME.DisplayName().."##Target", open, flags)
    if not show then
        if StyleCount > 0 then ImGui.PopStyleVar(StyleCount) end
        if ColorCount > 0 then ImGui.PopStyleColor(ColorCount) end
        ImGui.SetWindowFontScale(1)
        ImGui.End()
        return open
    end
    -- ImGui.BeginGroup()
    if ImGui.BeginMenuBar() then
        if ZoomLvl > 1.25 then ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, 4,7) end
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
        ImGui.EndMenuBar()
    end
    ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, 4,3)
        -- Combat Status
        -- if ME.Combat() then
        --     ImGui.SetNextItemAllowOverlap()
        --     --ImGui.SetCursorPosY(10)
            ImGui.SetCursorPosX((ImGui.GetContentRegionAvail() / 2) - 22)
        --     if pulse then
        --         ImGui.PushStyleColor(ImGuiCol.PlotHistogram,(COLOR.color('pink')))
        --         pulse = false
        --     else
        --         ImGui.PushStyleColor(ImGuiCol.PlotHistogram,(COLOR.color('red')))
        --         pulse = true
        --     end
        --     ImGui.ProgressBar(1, iconSize - 5, iconSize - 6, '##c')
        --     --ImGui.Text(Icons.MD_LENS)
        --     ImGui.PopStyleColor()
        -- end
        ImGui.Dummy(iconSize - 5, iconSize - 6)
        ImGui.SameLine()
        ImGui.SetCursorPosX(5)
        --ImGui.SetCursorPosY(10)
        -- Player Information
        ImGui.BeginGroup()
        local tPFlags = tPlayerFlags
        local cFlag = bit32.bor(ImGuiChildFlags.AlwaysAutoResize)
        if ME.Combat() then
            if cRise then
                cAlpha = cAlpha + 5
            else
                cAlpha = cAlpha - 5
            end
            if cAlpha >= 250 then
                cRise = false
            elseif cAlpha < 15 then
                cRise = true
            end
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
        if flashBorder then ImGui.BeginChild('pInfo##', 0,(iconSize*1.8*ZoomLvl),cFlag) end
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
            ImGui.Text(meName)
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
            ImGui.SetWindowFontScale(ZoomLvl * 0.91)
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
            ImGui.SetWindowFontScale(ZoomLvl * .75)
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
        ImGui.Separator()
        -- My Health Bar
        local yPos = ImGui.GetCursorPosY()
        ImGui.SetWindowFontScale(ZoomLvl * 0.75)
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
        ImGui.ProgressBar(((tonumber(ME.PctHPs() or 0)) / 100), ImGui.GetContentRegionAvail(), progressSize , '##pctHps')
        ImGui.PopStyleColor()
        ImGui.SetCursorPosY(yPos)
        ImGui.SetCursorPosX(ImGui.GetCursorPosX() + ((ImGui.GetWindowWidth() / 2) - 8))
        ImGui.Text(tostring(ME.PctHPs() or 0))
        local yPos = ImGui.GetCursorPosY()
        --My Mana Bar
        if (tonumber(ME.MaxMana()) > 0) then
            ImGui.PushStyleColor(ImGuiCol.PlotHistogram,(COLOR.color('blue')))
            ImGui.ProgressBar(((tonumber(ME.PctMana() or 0)) / 100), ImGui.GetContentRegionAvail(), progressSize, '##pctMana')
            ImGui.PopStyleColor()
            ImGui.SetCursorPosY(yPos)
            ImGui.SetCursorPosX(ImGui.GetCursorPosX() + ((ImGui.GetWindowWidth() / 2) - 8))
            ImGui.Text(tostring(ME.PctMana() or 0))
        end
        local yPos = ImGui.GetCursorPosY()
        --My Endurance bar
        ImGui.PushStyleColor(ImGuiCol.PlotHistogram,(COLOR.color('yellow2')))
        ImGui.ProgressBar(((tonumber(ME.PctEndurance() or 0)) / 100), ImGui.GetContentRegionAvail(), progressSize, '##pctEndurance')
        ImGui.PopStyleColor()
        ImGui.SetCursorPosY(yPos)
        ImGui.SetCursorPosX(ImGui.GetCursorPosX() + ((ImGui.GetWindowWidth() / 2) - 8))
        ImGui.Text(tostring(ME.PctEndurance() or 0))
        ImGui.Separator()
        ImGui.EndGroup()
        if ImGui.IsItemHovered() and ImGui.IsMouseReleased(ImGuiMouseButton.Left) then
            mq.cmdf("/target %s", ME())
        end
        --Target Info
        if (TARGET() ~= nil) then
            ImGui.BeginGroup()
            local targetName = TARGET.CleanName() or '?'
            local tC = getConLevel(TARGET) or "WHITE"
            if tC == 'red' then tC = 'pink' end
            local tClass = TARGET.Class.ShortName() == 'UNKNOWN CLASS' and Icons.MD_HELP_OUTLINE or
                TARGET.Class.ShortName()
            local tLvl = TARGET.Level() or 0
            local tBodyType = TARGET.Body.Name() or '?'
            --Target Health Bar
            ImGui.BeginGroup()
            if TARGET.PctHPs() < 25 then
                ImGui.PushStyleColor(ImGuiCol.PlotHistogram,(COLOR.color('orange')))
            else
                ImGui.PushStyleColor(ImGuiCol.PlotHistogram,(COLOR.color('red')))
            end
            ImGui.ProgressBar(((tonumber(TARGET.PctHPs() or 0)) / 100), ImGui.GetContentRegionAvail(), progressSize * 3,'##' .. TARGET.PctHPs())
            ImGui.PopStyleColor()
            
            if ImGui.IsItemHovered() then
                ImGui.SetWindowFontScale(ZoomLvl)
                ImGui.BeginTooltip()
                ImGui.Text(string.format("Name: %s\t Lvl: %s\nClass: %s\nType: %s", targetName,tLvl,tClass,tBodyType ))
                ImGui.EndTooltip()
            end
            ImGui.SetWindowFontScale(ZoomLvl * 0.9)
            ImGui.SetCursorPosY(ImGui.GetCursorPosY() - (progressSize * 3 + 7))
            ImGui.SetCursorPosX(9)
            if ImGui.BeginTable("##targetInfoOverlay", 2, tPlayerFlags) then
                ImGui.TableSetupColumn("##col1", ImGuiTableColumnFlags.NoResize, (ImGui.GetContentRegionAvail() * .5) - 8)
                ImGui.TableSetupColumn("##col2", ImGuiTableColumnFlags.NoResize, (ImGui.GetContentRegionAvail() * .5) + 8) -- Adjust width for distance and Aggro% text
                -- First Row: Name, con, distance
                ImGui.TableNextRow()
                ImGui.TableSetColumnIndex(0) -- Name and CON in the first column
                ImGui.Text(targetName)
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
            ImGui.SetWindowFontScale(ZoomLvl * 0.75)
            ImGui.Separator()
            --Aggro % Bar
            if (TARGET.Aggressive) then
                local yPos = ImGui.GetCursorPosY()
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

            ImGui.EndGroup()
            if ImGui.IsItemHovered() and ImGui.IsMouseReleased(ImGuiMouseButton.Left) then
                if mq.TLO.Cursor() then
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
        if StyleCount > 0 then ImGui.PopStyleVar(StyleCount) else ImGui.PopStyleVar(1) end
        if ColorCount > 0 then ImGui.PopStyleColor(ColorCount) end
        ImGui.Spacing()
        ImGui.SetWindowFontScale(1)
        ImGui.End()
    return open
end

local function init()
    loadSettings()
    mq.imgui.init('GUI_Target', GUI_Target)
    mq.imgui.init("PlayerTargConfig", PlayerTargConf_GUI)
end

local function MainLoop()
    while true do
        if TLO.Window('CharacterListWnd').Open() then return false end
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

init()
printf("\ag %s \aw[\ayPlayer Targ\aw] ::\a-t Loaded",TLO.Time())
MainLoop()
