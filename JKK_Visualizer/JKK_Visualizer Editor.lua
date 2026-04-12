--========================================================
-- @title JKK_Visualizer Editor
-- @description JKK_Visualizer Editor
-- @author Junki Kim
-- @version 1.2.0
-- @provides
--     [nomain] JKK_Theme.lua
--     [nomain] LOGO.png
--========================================================

local ctx = reaper.ImGui_CreateContext('JKK_Visualizer Editor')
local sans_font = reaper.ImGui_CreateFont('Arial', 14)
reaper.ImGui_Attach(ctx, sans_font)

local image_path = reaper.GetResourcePath() .. "/Scripts/JKK_Visualizer/JKK_Visualizer/LOGO.png"
local image_logo = reaper.ImGui_CreateImage(image_path)
local theme_path = reaper.GetResourcePath() .. "/Scripts/JKK_Visualizer/JKK_Visualizer/JKK_Theme.lua"
local ApplyTheme = (reaper.file_exists(theme_path) and dofile(theme_path).ApplyTheme) 
                   or function(ctx) return 0, 0 end

-- Memory Address 
    options = reaper.gmem_attach('JKK_Visualizer_Mem')
    local MEM_GAIN_GONIO    = 2
    local MEM_GAIN_SYMBIOTE = 6
    local MEM_GAIN_SCOPE    = 7
    local MEM_GAIN_SPECTRUM = 8
    local MEM_BG    = 1000
    local MEM_LINE  = 1010
    local MEM_TEXT  = 1020
    local MEM_ZERO  = 1030
    local MEM_MID   = 1040
    local MEM_PEAK  = 1050
    local MEM_FREZ  = 1060
    local ui_order  = {1, 2, 3, 4, 5, 6}
    local ui_active = {true, true, true, true, true, true}

----------------------------------------------------------
-- UI Info Description
----------------------------------------------------------
    local widget_descriptions = {
        ["LOGO"]    = { "Sound Designer 김준기 (Junki Kim)", "junkikim.sound@gmail.com" },
        ["GAIN"]    = { "Signal Gain",      "Adjusts the visual sensitivity of the visualizer.\n비주얼라이저의 반응 감도를 조절합니다." },
        ["GAIN_GONIO"]    = { "Gonio Gain",    "Adjusts the visual sensitivity of the Goniometer.\nGonio 모듈의 반응 감도를 조절합니다." },
        ["GAIN_SYMBIOTE"] = { "Symbiote Gain", "Adjusts the visual sensitivity of the Symbiote.\nSymbiote 모듈의 반응 감도를 조절합니다." },
        ["GAIN_SCOPE"]    = { "Scope Gain",    "Adjusts the visual sensitivity of the Scope.\nScope 모듈의 반응 감도를 조절합니다." },
        ["GAIN_SPECTRUM"] = { "Spectrum Gain", "Adjusts the visual sensitivity of the Spectrum.\nSpectrum 모듈의 반응 감도를 조절합니다." },
        ["FONT"]    = { "Font Scale",       "Adjusts the size of all text at the same ratio.\n모든 텍스트의 크기를 동일한 비율로 조절합니다." },
        ["ATTACK"]  = { "Response Speed (Attack)", "Adjusts how quickly the visualizer reacts to signals.\n비주얼라이저가 신호에 반응하는 속도를 조절합니다." },
        ["RELEASE"] = { "Decay Speed (Release)", "Adjusts how quickly the visualizer fades out.\n비주얼라이저의 잔상이 사라지는 속도를 조절합니다." },
        ["ORDER"]   = { "Module Order",     "Drag and drop items to change the display order of the visualizer modules.\n마우스로 항목을 드래그하여 비주얼라이저의 표시 순서를 변경합니다." },
        ["BG"]      = { "Background",       "Sets the background color of the visualizer.\n비주얼라이저의 배경 색상을 조절합입니다." },
        ["LINE"]    = { "Grid & Lines",     "Sets the color for grids and outlines.\n그리드 및 외곽선의 색상을 조절합니다." },
        ["TEXT"]    = { "Text & Labels",    "Sets the color for text and labels.\n텍스트 및 라벨의 색상을 조절합니다." },
        ["ZERO"]    = { "Weak Signal",      "Sets the color for very weak signals.\n신호가 아주 약할 때의 색상을 조절합니다." },
        ["MID"]     = { "Normal Signal",    "Sets the color for normal volume levels.\n일반적인 볼륨일 때의 색상을 조절합니다." },
        ["PEAK"]    = { "Strong Signal",    "Sets the color for strong (peak) signals.\n신호가 강할 때의 색상을 조절합니다." },
        ["FREZ"]    = { "Peak Line",        "Sets the color for the peak line.\n스펙트럼의 피크라인 색상을 조절합니다." },
        ["RESET"]   = { "Reset",            "Resets the color settings to default.\n컬러 설정을 기본값으로 초기화합니다." },
    }
    local shared_info = { hovered_id = nil }

----------------------------------------------------------
-- Save & Load Values
----------------------------------------------------------
    local SECTION = "JKK_Visualizer"

    local function SaveAllSettings()
        for i = 1000, 1140 do
            local val = reaper.gmem_read(i)
            reaper.SetExtState(SECTION, "MEM_"..i, tostring(val), true)
        end
        reaper.SetExtState(SECTION, "FontScale", tostring(reaper.gmem_read(1300)), true)
        
        local order_str = ""
        for i = 1, 6 do order_str = order_str .. ui_order[i] .. (i < 6 and "," or "") end
        reaper.SetExtState(SECTION, "ModuleOrder", order_str, true)
        
        local active_str = ""
        for i = 1, 6 do active_str = active_str .. (ui_active[i] and "1" or "0") .. (i < 6 and "," or "") end
        reaper.SetExtState(SECTION, "ModuleActive", active_str, true)
    end

    local function LoadAllSettings()
        for i = 1000, 1140 do
            if reaper.HasExtState(SECTION, "MEM_"..i) then
                reaper.gmem_write(i, tonumber(reaper.GetExtState(SECTION, "MEM_"..i)))
            end
        end
        if reaper.HasExtState(SECTION, "FontScale") then
            reaper.gmem_write(1300, tonumber(reaper.GetExtState(SECTION, "FontScale")))
        end
        if reaper.HasExtState(SECTION, "ModuleOrder") then
            local order_str = reaper.GetExtState(SECTION, "ModuleOrder")
            local idx = 1
            for val in string.gmatch(order_str, '([^,]+)') do
                ui_order[idx] = tonumber(val)
                reaper.gmem_write(1100 + idx, ui_order[idx])
                idx = idx + 1
            end
        end
        if reaper.HasExtState(SECTION, "ModuleActive") then
            local active_str = reaper.GetExtState(SECTION, "ModuleActive")
            local idx = 1
            for val in string.gmatch(active_str, '([^,]+)') do
                ui_active[idx] = (val == "1")
                reaper.gmem_write(1150 + idx, ui_active[idx] and 1 or 0)
                idx = idx + 1
            end
        else
            for i = 1, 6 do reaper.gmem_write(1150 + i, 1) end
        end
    end
    LoadAllSettings()

----------------------------------------------------------
-- Color Editor
----------------------------------------------------------
        local DEFAULTS = {
            bg   = {030/255, 030/255, 030/255, 1.0}, 
            line = {200/255, 200/255, 200/255, 0.3}, 
            text = {180/255, 180/255, 180/255, 1.0}, 
            zero = {006/255, 143/255, 195/255, 0.1}, 
            mid  = {006/255, 143/255, 195/255, 0.8}, 
            peak = {227/255, 219/255, 142/255, 1.0}, 
            frez = {180/255, 180/255, 180/255, 1.0}  
        }
    function ColorEdit(ctx, label, mem_idx, desc_id)
        local r = reaper.gmem_read(mem_idx)
        local g = reaper.gmem_read(mem_idx + 1)
        local b = reaper.gmem_read(mem_idx + 2)
        local a = reaper.gmem_read(mem_idx + 3)
        
        if r == 0 and g == 0 and b == 0 and a == 0 then 
            ApplyDefaults()
            r = reaper.gmem_read(mem_idx)
            g = reaper.gmem_read(mem_idx + 1)
            b = reaper.gmem_read(mem_idx + 2)
            a = reaper.gmem_read(mem_idx + 3)
        end

        local packed_col = reaper.ImGui_ColorConvertDouble4ToU32(r, g, b, a)

        local flags = reaper.ImGui_ColorEditFlags_NoInputs() | 
                      reaper.ImGui_ColorEditFlags_AlphaPreviewHalf() |
                      reaper.ImGui_ColorEditFlags_AlphaBar()

        reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FramePadding(), 6, 6)
        reaper.ImGui_SetNextItemWidth(ctx, 30)

        local retval, new_packed_col = reaper.ImGui_ColorEdit4(ctx, label, packed_col, flags)
        reaper.ImGui_PopStyleVar(ctx)

        if retval then
            local nr, ng, nb, na = reaper.ImGui_ColorConvertU32ToDouble4(new_packed_col)
            reaper.gmem_write(mem_idx, nr); SaveAllSettings()
            reaper.gmem_write(mem_idx + 1, ng); SaveAllSettings()
            reaper.gmem_write(mem_idx + 2, nb); SaveAllSettings()
            reaper.gmem_write(mem_idx + 3, na); SaveAllSettings()
        end
        if desc_id and reaper.ImGui_IsItemHovered(ctx) then
            shared_info.hovered_id = desc_id
        end
    end

----------------------------------------------------------
-- Apply Default Values
----------------------------------------------------------
    function ApplyDefaults()
        local function write_col(mem, col)
            reaper.gmem_write(mem,   col[1]); SaveAllSettings()
            reaper.gmem_write(mem+1, col[2]); SaveAllSettings()
            reaper.gmem_write(mem+2, col[3]); SaveAllSettings()
            reaper.gmem_write(mem+3, col[4]); SaveAllSettings()
        end
        write_col(MEM_BG,   DEFAULTS.bg)
        write_col(MEM_LINE, DEFAULTS.line)
        write_col(MEM_TEXT, DEFAULTS.text)
        write_col(MEM_ZERO, DEFAULTS.zero)
        write_col(MEM_MID,  DEFAULTS.mid)
        write_col(MEM_PEAK, DEFAULTS.peak)
        write_col(MEM_FREZ, DEFAULTS.frez)
    end

    function init_order_from_gmem()
        local has_data = false
        for i = 1, 6 do
            local val = reaper.gmem_read(1100 + i)
            if val > 0 then 
                ui_order[i] = val 
                has_data = true
            end
        end
        if not has_data then
            for i = 1, 6 do reaper.gmem_write(1100 + i, ui_order[i]) end
            SaveAllSettings()
        end
    end

    init_order_from_gmem()

----------------------------------------------------------
-- UI Loop
----------------------------------------------------------
    function loop()
        local textcol_title = 0xE3DB8EFF
        local textcol_gray = 0x808080FF
        local pushed_vars, pushed_cols = ApplyTheme(ctx)
        reaper.ImGui_PushFont(ctx, sans_font, 12)
        reaper.ImGui_SetNextWindowSize(ctx, 530, 640, reaper.ImGui_Cond_Once())

        local visible, open = reaper.ImGui_Begin(ctx, 'JKK_Visualizer Editor v1.2', true,
            reaper.ImGui_WindowFlags_NoCollapse())
        reaper.ImGui_PopFont(ctx)
        if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Escape()) then
            open = false
        end    
        reaper.ImGui_PushFont(ctx, sans_font, 13)
        if visible then
            local active_desc = nil
                reaper.ImGui_Dummy(ctx, -5, 0)
                reaper.ImGui_SameLine(ctx)
                reaper.ImGui_Image(ctx, image_logo, 45, 45)
                    if reaper.ImGui_IsItemHovered(ctx) then
                        shared_info.hovered_id = "LOGO"
                    end
                reaper.ImGui_SameLine(ctx)
                reaper.ImGui_PushFont(ctx, font, 24)
                reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), textcol_title)
                local text = " "
                reaper.ImGui_Text(ctx, text)
                reaper.ImGui_PopFont(ctx)
                reaper.ImGui_PopStyleColor(ctx, 1)
                reaper.ImGui_SameLine(ctx)
                local INFO_LINE_SPACING = 12
                local INFO_MAX_LINES    = 2
                local INFO_AREA_HEIGHT  = (INFO_LINE_SPACING * INFO_MAX_LINES) + 5
                local start_y = reaper.ImGui_GetCursorPosY(ctx)
                local desc_text = " "
                if shared_info.hovered_id and widget_descriptions[shared_info.hovered_id] then
                    desc_text = widget_descriptions[shared_info.hovered_id]
                end

                if desc_text and type(desc_text) == "table" then
                    local title, body = desc_text[1], desc_text[2]
                    local window_width = reaper.ImGui_GetWindowWidth(ctx)
                    local padding = 15
                    local spacing_adjust = -30

                    reaper.ImGui_PushFont(ctx, font, 13)
                    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), textcol_title)
                    
                    local title_width, _ = reaper.ImGui_CalcTextSize(ctx, title)
                    reaper.ImGui_SetCursorPosX(ctx, window_width - title_width - padding)
                    reaper.ImGui_Text(ctx, title)
                    
                    reaper.ImGui_PopStyleColor(ctx, 1)
                    reaper.ImGui_PopFont(ctx)

                    reaper.ImGui_SetCursorPosY(ctx, reaper.ImGui_GetCursorPosY(ctx) + spacing_adjust)

                    if body then
                        reaper.ImGui_PushFont(ctx, font, 11)
                        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), textcol_gray)
                        
                        for line in body:gmatch("([^\n]+)") do
                            local line_width, _ = reaper.ImGui_CalcTextSize(ctx, line)
                            reaper.ImGui_SetCursorPosX(ctx, window_width - line_width - padding)
                            reaper.ImGui_Text(ctx, line)
                        end
                        
                        reaper.ImGui_PopStyleColor(ctx, 1)
                        reaper.ImGui_PopFont(ctx)
                    end
                end

                reaper.ImGui_SetCursorPosY(ctx, start_y + INFO_AREA_HEIGHT + 18)
                reaper.ImGui_Spacing(ctx)
                reaper.ImGui_SetCursorPosY(ctx, 85)
                shared_info.hovered_id = nil
            -- Visual Size
                reaper.ImGui_SeparatorText(ctx, 'Visual Size')
                -- 1. Gonio Gain
                local g_gain = reaper.gmem_read(MEM_GAIN_GONIO)
                local g_changed, g_new = reaper.ImGui_SliderDouble(ctx, "Gonio Gain", g_gain, 0.0, 1.0, "%.3f")
                if g_changed then reaper.gmem_write(MEM_GAIN_GONIO, g_new) SaveAllSettings() end
                if reaper.ImGui_IsItemHovered(ctx) then shared_info.hovered_id = "GAIN_GONIO" end

                -- 2. Symbiote Gain
                local sym_gain = reaper.gmem_read(MEM_GAIN_SYMBIOTE)
                local s_changed, s_new = reaper.ImGui_SliderDouble(ctx, "Symbiote Gain", sym_gain, 0.0, 1.0, "%.3f")
                if s_changed then reaper.gmem_write(MEM_GAIN_SYMBIOTE, s_new) SaveAllSettings() end
                if reaper.ImGui_IsItemHovered(ctx) then shared_info.hovered_id = "GAIN_SYMBIOTE" end

                -- 3. Scope Gain
                local scp_gain = reaper.gmem_read(MEM_GAIN_SCOPE)
                local scp_changed, scp_new = reaper.ImGui_SliderDouble(ctx, "Scope Gain", scp_gain, 0.0, 1.0, "%.3f")
                if scp_changed then reaper.gmem_write(MEM_GAIN_SCOPE, scp_new) SaveAllSettings() end
                if reaper.ImGui_IsItemHovered(ctx) then shared_info.hovered_id = "GAIN_SCOPE" end

                -- 4. Spectrum Gain
                local spec_gain = reaper.gmem_read(MEM_GAIN_SPECTRUM)
                local sp_changed, sp_new = reaper.ImGui_SliderDouble(ctx, "Spectrum Gain", spec_gain, 0.0, 1.0, "%.3f")
                if sp_changed then reaper.gmem_write(MEM_GAIN_SPECTRUM, sp_new) SaveAllSettings() end
                if reaper.ImGui_IsItemHovered(ctx) then shared_info.hovered_id = "GAIN_SPECTRUM" end

                reaper.ImGui_Spacing(ctx)
                local font_scale = reaper.gmem_read(1300)
                    if font_scale <= 0 then font_scale = 1.0 end
                    local changed, new_scale = reaper.ImGui_SliderDouble(ctx, "Font Scale", font_scale, 0.5, 2.0, "%.2fx")
                    if changed then
                        reaper.gmem_write(1300, new_scale)
                        SaveAllSettings()
                    end
                    if reaper.ImGui_IsItemHovered(ctx) then shared_info.hovered_id = "FONT" end
                    reaper.ImGui_Spacing(ctx)
            -- Signal Speed
                -- Attack Slider
                    local current_att = reaper.gmem_read(4)
                    if current_att <= 0 then current_att = 1.0 end
                    local changed_att, new_att = reaper.ImGui_SliderDouble(ctx, "Response Speed", current_att, 0.1, 1.0, "%.2fx")
                    if reaper.ImGui_IsItemClicked(ctx, 1) then 
                        new_att = 1.0
                        changed_att = true
                    end
                    if changed_att then
                        reaper.gmem_write(4, new_att); SaveAllSettings()
                    end
                    if reaper.ImGui_IsItemHovered(ctx) then shared_info.hovered_id = "ATTACK" end

                -- Release Slider
                    local current_rel = reaper.gmem_read(5)
                    if current_rel <= 0 then current_rel = 1.0 end
                    local changed_rel, new_rel = reaper.ImGui_SliderDouble(ctx, "Decay Speed", current_rel, 0.1, 1.0, "%.2fx")
                    if reaper.ImGui_IsItemClicked(ctx, 1) then 
                        new_rel = 1.0
                        changed_rel = true
                    end
                    if changed_rel then
                        reaper.gmem_write(5, new_rel); SaveAllSettings()
                    end
                    if reaper.ImGui_IsItemHovered(ctx) then shared_info.hovered_id = "RELEASE" end
                    reaper.ImGui_Spacing(ctx)

            -- Order (폭포수 모듈 추가)
                local module_names = {
                    [1]="   ▩ LUFS", [2]="   ▩ Gonio", [3]="   ▩ Symbiote", 
                    [4]="   ▩ Scope", [5]="   ▩ Spectrum", [6]="   ▩ Spectrogram"
                }

                reaper.ImGui_SeparatorText(ctx, "Module Order (Drag to Reorder)")

                for i, module_id in ipairs(ui_order) do
                    local is_active = ui_active[module_id]
                    local rv, new_val = reaper.ImGui_Checkbox(ctx, "##act_"..i, is_active)
                    if rv then
                        ui_active[module_id] = new_val
                        reaper.gmem_write(1150 + module_id, new_val and 1 or 0)
                        SaveAllSettings()
                    end
                    reaper.ImGui_SameLine(ctx)
                    if reaper.ImGui_IsItemHovered(ctx) then shared_info.hovered_id = "ORDER" end
                    
                    reaper.ImGui_PushID(ctx, i)
                    if not ui_active[module_id] then reaper.ImGui_BeginDisabled(ctx) end
                    reaper.ImGui_Selectable(ctx, module_names[module_id], false)
                    if not ui_active[module_id] then reaper.ImGui_EndDisabled(ctx) end
                    reaper.ImGui_PopID(ctx)

                    if reaper.ImGui_BeginDragDropSource(ctx, reaper.ImGui_DragDropFlags_None()) then
                        reaper.ImGui_SetDragDropPayload(ctx, "DND_ORDER", tostring(i))
                        reaper.ImGui_Text(ctx, module_names[module_id])
                        reaper.ImGui_EndDragDropSource(ctx)
                    end

                    if reaper.ImGui_BeginDragDropTarget(ctx) then
                        local retval, payload = reaper.ImGui_AcceptDragDropPayload(ctx, "DND_ORDER")
                        if retval then
                            local source_idx = tonumber(payload)
                            local target_idx = i
                            local item_to_move = table.remove(ui_order, source_idx)
                            table.insert(ui_order, target_idx, item_to_move)
                            for k=1, 6 do reaper.gmem_write(1100 + k, ui_order[k]) end
                            SaveAllSettings() 
                        end
                        reaper.ImGui_EndDragDropTarget(ctx)
                    end
                end
                reaper.ImGui_Spacing(ctx)
            -- Color Theme
                reaper.ImGui_SeparatorText(ctx, 'Global Theme')
                ColorEdit(ctx, "Background", MEM_BG, "BG")
                reaper.ImGui_SameLine(ctx)
                ColorEdit(ctx, "Grid & Lines", MEM_LINE, "LINE")
                reaper.ImGui_SameLine(ctx)
                ColorEdit(ctx, "Text & Labels", MEM_TEXT, "TEXT")
                
                reaper.ImGui_Spacing(ctx)
                reaper.ImGui_SeparatorText(ctx, 'Signal Colors')
                ColorEdit(ctx, "Weak (Zero)", MEM_ZERO, "ZERO")
                reaper.ImGui_SameLine(ctx)
                ColorEdit(ctx, "Normal (Mid)", MEM_MID, "MID")
                reaper.ImGui_SameLine(ctx)
                ColorEdit(ctx, "Strong (Peak)", MEM_PEAK, "PEAK")
                reaper.ImGui_SameLine(ctx)
                ColorEdit(ctx, "Spec Frez Line", MEM_FREZ, "FREZ")
                
                reaper.ImGui_Spacing(ctx)
                reaper.ImGui_Spacing(ctx)
            -- Reset
                if reaper.ImGui_Button(ctx, "Reset to Defualts", -1, 27) then
                    ApplyDefaults()
                end
                if reaper.ImGui_IsItemHovered(ctx) then shared_info.hovered_id = "RESET" end
            if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Space()) then
                reaper.Main_OnCommand(40044, 0)
            end
            reaper.ImGui_End(ctx)
        end
        reaper.ImGui_PopFont(ctx)

        if pushed_vars > 0 then reaper.ImGui_PopStyleVar(ctx, pushed_vars) end
        if pushed_cols > 0 then reaper.ImGui_PopStyleColor(ctx, pushed_cols) end

        if open then
            reaper.defer(loop)
        end
    end

loop()