--========================================================
-- @title JKK_Visualizer Editor
-- @description JKK_Visualizer Editor
-- @author Junki Kim
-- @version 0.8.0
-- @provides
--     [nomain] JKK_Theme.lua
--     [nomain] LOGO.png
--========================================================

local ctx = reaper.ImGui_CreateContext('JKK_Visualizer Editor')
local sans_font = reaper.ImGui_CreateFont('Arial', 14)
reaper.ImGui_Attach(ctx, sans_font)

local image_path = reaper.GetResourcePath() .. "/Scripts/JKK_Visualizer/LOGO.png"
local image_logo = reaper.ImGui_CreateImage(image_path)
local theme_path = reaper.GetResourcePath() .. "/Scripts/JKK_Visualizer/JKK_Theme.lua"
local ApplyTheme = (reaper.file_exists(theme_path) and dofile(theme_path).ApplyTheme) 
                   or function(ctx) return 0, 0 end

-- Memory Address 
    options = reaper.gmem_attach('JKK_Visualizer_Mem')
    local MEM_GAIN  = 2
    local MEM_BG    = 1000
    local MEM_LINE  = 1010
    local MEM_TEXT  = 1020
    local MEM_ZERO  = 1030
    local MEM_MID   = 1040
    local MEM_PEAK  = 1050
    local MEM_FREZ  = 1060
    local ui_order = {1, 2, 3, 4, 5} 

----------------------------------------------------------
-- UI Info Description
----------------------------------------------------------
    local widget_descriptions = {
        ["LOGO"]    = { "Sound Designer 김준기 (Junki Kim)", "junkikim.sound@gmail.com" },
        ["GAIN"]    = { "Signal Gain",      "Adjusts the visual sensitivity of the visualizer.\n비주얼라이저의 반응 감도를 조절합니다." },
        ["FONT"]    = { "Font Scale",       "Adjusts the size of all text at the same ratio.\n모든 텍스트의 크기를 동일한 비율로 조절합니다." },
        ["ATTACK"]  = { "Response Speed (Attack)", "비주얼라이저가 신호에 반응하는 속도를 조절합니다.\nAdjusts how quickly the visualizer reacts to signals." },
        ["RELEASE"] = { "Decay Speed (Release)", "비주얼라이저의 잔상이 사라지는 속도를 조절합니다.\nAdjusts how quickly the visualizer fades out." },
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

    -- [모든 설정을 ExtState에 저장]
    local function SaveAllSettings()
        -- 1. 색상 저장 (메모리 주소 1101~1125 등 모든 색상 루프)
        for i = 1000, 1140 do -- 충분한 범위를 저장
            local val = reaper.gmem_read(i)
            reaper.SetExtState(SECTION, "MEM_"..i, tostring(val), true)
        end
        -- 2. 폰트 스케일 저장
        reaper.SetExtState(SECTION, "FontScale", tostring(reaper.gmem_read(1300)), true)
        -- 3. 모듈 순서 저장
        local order_str = ""
        for i = 1, 5 do order_str = order_str .. ui_order[i] .. (i < 5 and "," or "") end
        reaper.SetExtState(SECTION, "ModuleOrder", order_str, true)
    end

    -- [저장된 설정 불러오기]
    local function LoadAllSettings()
        -- 1. 색상 불러오기
        for i = 1000, 1140 do
            if reaper.HasExtState(SECTION, "MEM_"..i) then
                reaper.gmem_write(i, tonumber(reaper.GetExtState(SECTION, "MEM_"..i)))
            end
        end
        -- 2. 폰트 스케일
        if reaper.HasExtState(SECTION, "FontScale") then
            reaper.gmem_write(1300, tonumber(reaper.GetExtState(SECTION, "FontScale")))
        end
        -- 3. 순서 불러오기
        if reaper.HasExtState(SECTION, "ModuleOrder") then
            local order_str = reaper.GetExtState(SECTION, "ModuleOrder")
            local idx = 1
            for val in string.gmatch(order_str, '([^,]+)') do
                ui_order[idx] = tonumber(val)
                reaper.gmem_write(1100 + idx, ui_order[idx])
                idx = idx + 1
            end
        end
    end
    LoadAllSettings()

----------------------------------------------------------
-- Color Editor
----------------------------------------------------------
    -- Defualt Colors
        local DEFAULTS = {
            -- 1. UI
            bg   = {030/255, 030/255, 030/255, 1.0},  -- 배경색 (어두운 회색)
            line = {200/255, 200/255, 200/255, 0.3},  -- 그리드/라인 (반투명 흰색)
            text = {180/255, 180/255, 180/255, 1.0},  -- 일반 텍스트 (흰색)

            -- 2. Signal Level
            zero = {006/255, 143/255, 195/255, 0.1},  -- Weak (약한 신호, 투명도 낮음)
            mid  = {006/255, 143/255, 195/255, 0.8},  -- Mid  (중간 신호)
            peak = {227/255, 219/255, 142/255, 1.0},  -- Peak (강한 신호, 황금색)
            frez = {180/255, 180/255, 180/255, 1.0}   -- Peak Freeze
        }
    function ColorEdit(ctx, label, mem_idx, desc_id)
        local r = reaper.gmem_read(mem_idx)
        local g = reaper.gmem_read(mem_idx + 1)
        local b = reaper.gmem_read(mem_idx + 2)
        local a = reaper.gmem_read(mem_idx + 3)
        
        -- 초기 실행 시(값이 없으면) 기본값 로드
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

        reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FramePadding(), 6, 6) -- 숫자를 키우면 아이콘이 커집니다.
        reaper.ImGui_SetNextItemWidth(ctx, 30)

        local retval, new_packed_col = reaper.ImGui_ColorEdit4(ctx, label, packed_col, flags)
        reaper.ImGui_PopStyleVar(ctx)

        if retval then
            local nr, ng, nb, na = reaper.ImGui_ColorConvertU32ToDouble4(new_packed_col)
            reaper.gmem_write(mem_idx, nr)
                SaveAllSettings()
            reaper.gmem_write(mem_idx + 1, ng)
                SaveAllSettings()
            reaper.gmem_write(mem_idx + 2, nb)
                SaveAllSettings()
            reaper.gmem_write(mem_idx + 3, na)
                SaveAllSettings()
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
            reaper.gmem_write(mem,   col[1])
                SaveAllSettings()
            reaper.gmem_write(mem+1, col[2])
                SaveAllSettings()
            reaper.gmem_write(mem+2, col[3])
                SaveAllSettings()
            reaper.gmem_write(mem+3, col[4])
                SaveAllSettings()
        end

        write_col(MEM_BG,   DEFAULTS.bg)
        write_col(MEM_LINE, DEFAULTS.line)
        write_col(MEM_TEXT, DEFAULTS.text)
        write_col(MEM_ZERO, DEFAULTS.zero)
        write_col(MEM_MID,  DEFAULTS.mid)
        write_col(MEM_PEAK, DEFAULTS.peak)
        write_col(MEM_FREZ, DEFAULTS.frez)
    end

    -- 순서 읽어오기 함수
    function init_order_from_gmem()
        local has_data = false
        for i = 1, 5 do
            local val = reaper.gmem_read(1100 + i)
            if val > 0 then 
                ui_order[i] = val 
                has_data = true
            end
        end
        
        if not has_data then
            for i = 1, 5 do reaper.gmem_write(1100 + i, ui_order[i]) end
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
        reaper.ImGui_SetNextWindowSize(ctx, 530, 500, reaper.ImGui_Cond_Once())

        local visible, open = reaper.ImGui_Begin(ctx, 'JKK_Visualizer Theme Editor v0.5', true,
            reaper.ImGui_WindowFlags_NoCollapse())
        reaper.ImGui_PopFont(ctx)
        if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Escape()) then
            open = false
        end    
        reaper.ImGui_PushFont(ctx, sans_font, 13)
        if visible then
            local active_desc = nil
            -- Logo ========================================================
                reaper.ImGui_Dummy(ctx, -5, 0)
                reaper.ImGui_SameLine(ctx)
                reaper.ImGui_Image(ctx, image_logo, 45, 45)
                    if reaper.ImGui_IsItemHovered(ctx) then
                        shared_info.hovered_id = "LOGO"
                    end
                reaper.ImGui_SameLine(ctx)
            -- Title ========================================================
                reaper.ImGui_PushFont(ctx, font, 24)
                reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), textcol_title)
                local text = " "
                reaper.ImGui_Text(ctx, text)
                reaper.ImGui_PopFont(ctx)
                reaper.ImGui_PopStyleColor(ctx, 1)
                reaper.ImGui_SameLine(ctx)
            -- Info ========================================================
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

                    -- Title
                    reaper.ImGui_PushFont(ctx, font, 13)
                    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), textcol_title)
                    
                    local title_width, _ = reaper.ImGui_CalcTextSize(ctx, title)
                    reaper.ImGui_SetCursorPosX(ctx, window_width - title_width - padding)
                    reaper.ImGui_Text(ctx, title)
                    
                    reaper.ImGui_PopStyleColor(ctx, 1)
                    reaper.ImGui_PopFont(ctx)

                    reaper.ImGui_SetCursorPosY(ctx, reaper.ImGui_GetCursorPosY(ctx) + spacing_adjust)

                    -- Body
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
            -- Visual Size ========================================================
                reaper.ImGui_SeparatorText(ctx, 'Visual Size')
                local current_gain = reaper.gmem_read(MEM_GAIN)
                    reaper.ImGui_SetNextItemWidth(ctx, -1)
                    local changed, new_gain = reaper.ImGui_SliderDouble(ctx, "##Gain", current_gain, 0.0, 1.0, "Signal Gain: %.3f")
                    if reaper.ImGui_IsItemClicked(ctx, 1) then 
                        new_gain = 0.5 
                        changed = true
                    end
                    if changed then
                        reaper.gmem_write(MEM_GAIN, new_gain)
                        SaveAllSettings()
                    end
                    if reaper.ImGui_IsItemHovered(ctx) then
                        shared_info.hovered_id = "GAIN"
                    end
                local font_scale = reaper.gmem_read(1300)
                    if font_scale <= 0 then font_scale = 1.0 end
                    reaper.ImGui_SetNextItemWidth(ctx, -1)
                    local changed, new_scale = reaper.ImGui_SliderDouble(ctx, "##Font Scale", font_scale, 0.5, 2.0, "Font Size: %.2fx")
                    if changed then
                        reaper.gmem_write(1300, new_scale)
                        SaveAllSettings()
                    end
                    if reaper.ImGui_IsItemHovered(ctx) then
                        shared_info.hovered_id = "FONT"
                    end
                    reaper.ImGui_Spacing(ctx)
            -- Signal Speed ========================================================
                -- Attack Slider
                local current_att = reaper.gmem_read(4)
                if current_att <= 0 then current_att = 1.0 end
                
                reaper.ImGui_SetNextItemWidth(ctx, -1)
                local changed_att, new_att = reaper.ImGui_SliderDouble(ctx, "##Attack", current_att, 0.1, 3.0, "Response Speed: %.2fx")
                    if reaper.ImGui_IsItemClicked(ctx, 1) then 
                        new_att = 1.0
                        changed = true
                    end
                    if changed_att then
                        reaper.gmem_write(4, new_att)
                        SaveAllSettings()
                    end
                    if reaper.ImGui_IsItemHovered(ctx) then shared_info.hovered_id = "ATTACK" end

                -- Release Slider
                local current_rel = reaper.gmem_read(5)
                if current_rel <= 0 then current_rel = 1.0 end

                reaper.ImGui_SetNextItemWidth(ctx, -1)
                local changed_rel, new_rel = reaper.ImGui_SliderDouble(ctx, "##Release", current_rel, 0.1, 3.0, "Decay Speed: %.2fx")
                    if reaper.ImGui_IsItemClicked(ctx, 1) then 
                        new_rel = 1.0
                        changed = true
                    end
                    if changed_rel then
                        reaper.gmem_write(5, new_rel)
                        SaveAllSettings()
                    end
                    if reaper.ImGui_IsItemHovered(ctx) then shared_info.hovered_id = "RELEASE" end

            -- Order ========================================================
                local module_names = {[1]="   ▩ LUFS", [2]="   ▩ Gonio", [3]="   ▩ Symbiote", [4]="   ▩ Scope", [5]="   ▩ Spectrum"}

                reaper.ImGui_SeparatorText(ctx, "Module Order (Drag to Reorder)")

                -- [드래그 앤 드롭 리스트]
                for i, module_id in ipairs(ui_order) do
                    if reaper.ImGui_IsItemHovered(ctx) then
                        shared_info.hovered_id = "ORDER"
                    end
                    -- 1. 아이템 표시 (Selectable 사용)
                    reaper.ImGui_PushID(ctx, i)
                    reaper.ImGui_Selectable(ctx, module_names[module_id], false)
                    reaper.ImGui_PopID(ctx)

                    -- 2. 드래그 시작 (Drag Source)
                    if reaper.ImGui_BeginDragDropSource(ctx, reaper.ImGui_DragDropFlags_None()) then
                        -- 드래그 중인 아이템의 '현재 인덱스(i)'를 전달
                        reaper.ImGui_SetDragDropPayload(ctx, "DND_ORDER", tostring(i))
                        reaper.ImGui_Text(ctx, module_names[module_id]) -- 드래그 따라다니는 텍스트
                        reaper.ImGui_EndDragDropSource(ctx)
                    end

                    -- 3. 드래그 놓기 (Drop Target)
                    if reaper.ImGui_BeginDragDropTarget(ctx) then
                        local retval, payload = reaper.ImGui_AcceptDragDropPayload(ctx, "DND_ORDER")
                        if retval then
                            local source_idx = tonumber(payload)
                            local target_idx = i
                            
                            -- Swap 대신 Insert 방식 사용
                            local item_to_move = table.remove(ui_order, source_idx)
                            table.insert(ui_order, target_idx, item_to_move)
                            
                            for k=1, 5 do reaper.gmem_write(1100 + k, ui_order[k]) end
                        end
                        reaper.ImGui_EndDragDropTarget(ctx)
                    end
                end
                reaper.ImGui_Spacing(ctx)
            -- Color Theme ========================================================
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
            -- Reset ========================================================
                if reaper.ImGui_Button(ctx, "Reset to Defualts", -1, 27) then
                    ApplyDefaults()
                end
                if reaper.ImGui_IsItemHovered(ctx) then
                    shared_info.hovered_id = "RESET"
                end
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


