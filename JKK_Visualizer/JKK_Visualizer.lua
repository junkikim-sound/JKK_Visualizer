--========================================================
-- @title JKK_Visualizer
-- @description JKK_Visualizer
-- @author Junki Kim
-- @version 1.0.2
-- @provides 
--     [effect] JKK_Visualizer.jsfx
--========================================================
options = reaper.gmem_attach('JKK_Visualizer_Mem') 

local win_w, win_h = 800, 150
local saved_dock = tonumber(reaper.GetExtState("JKK_Visualizer", "DockState")) or 0
gfx.init("JKK_Visualizer", win_w, win_h, saved_dock)

-- 사용자 설정 범위
local g_gain_min, g_gain_max            = 0.0,  2.0
local s_zoom_min, s_zoom_max            = 0.0,  2.5
local spec_ceil_min, spec_ceil_max      = 100,  20
local spec_floor_min, spec_floor_max    = -45, -45
local spec_offset = 0
local g_signal_attack = 0.00001
local g_signal_release = 0.00001

-- 데이터 버퍼 정보
local buf_len = 100000
local fft_size = 4096
local fft_bins = 2048
local ui_order = {1, 2, 3, 4, 5}

----------------------------------------------------------
-- UI Values Setting
----------------------------------------------------------
    -- 전체 설정
    local base_title_size = 20
    local g_font_scale = 1
    local bg_r, bg_g, bg_b, bg_a = 030/255, 030/255, 030/255, 1.0
    local line_r, line_g, line_b, line_a = 200/255, 200/255, 200/255, 0.3
    local text_r, text_g, text_b, text_a = 180/255, 180/255, 180/255, 1.0
    local midpoint = 0.5
    local steepness = 1.2

    -- Gonio Color
    local dot1_r, dot1_g, dot1_b, dot1_a = 006/255, 143/255, 195/255, 0.1
    local dot2_r, dot2_g, dot2_b, dot2_a = 006/255, 143/255, 195/255, 0.8
    local dot3_r, dot3_g, dot3_b, dot3_a = 227/255, 219/255, 142/255, 1.0
    local gr_peak, gg_peak, gb_peak = 255/255, 000/255, 000/255      -- Peak 컬러
        local gonio_peak_hold_time = 2.0  -- 피크 유지 시간 (초)
        local gonio_max_peak_dots = 150   -- 한 화면에 표시할 최대 피크 점 개수
        local gonio_peaks = {} -- 피크 좌표를 저장할 테이블
        local phase_smooth = 0

    -- Symbiote Color
    local sym1_r, sym1_g, sym1_b, sym1_a = 006/255, 143/255, 195/255, 0.1
    local sym2_r, sym2_g, sym2_b, sym2_a = 006/255, 143/255, 195/255, 0.8
    local sym3_r, sym3_g, sym3_b, sym3_a = 227/255, 219/255, 142/255, 1.0
        -- [Symbiote Settings] (변수 정리 및 최적화)
        local sym_points = 150       -- 부드러움 정도
        local sym_noise_speed = 5.0  -- 기본 울렁임 속도
        local sym_size_ratio = 0.3   -- 전체 크기 비율
        local sym_min_scale = 0.1    -- 최소 크기 (60%)
        local sym_max_scale = 1.0    -- 최대 크기 (180%)

        local sym_layers = 25        -- 그라데이션 레이어 수
        local sym_time_accum = 0     -- 시간 누적 변수 (속도 제어용)
        local s_bass_smooth = 0      -- 저음 스무딩 (크기 제어용)
        local s_width_smooth = 0     -- 너비 스무딩
        local sym_spikiness = 0      -- 스파이크 변수

    -- Scope Color
    local scp1_r, scp1_g, scp1_b, scp1_a = 006/255, 143/255, 195/255, 0.1
    local scp2_r, scp2_g, scp2_b, scp2_a = 006/255, 143/255, 195/255, 0.8
    local scp3_r, scp3_g, scp3_b, scp3_a = 227/255, 219/255, 142/255, 1.0
    local scope_speed = 0.1 -- 스코프 속도

    -- Spectrum Color
    local sptr1_r, sptr1_g, sptr1_b, sptr1_a = 006/255, 143/255, 195/255, 0.1
    local sptr2_r, sptr2_g, sptr2_b, sptr2_a = 006/255, 143/255, 195/255, 0.8
    local sptr3_r, sptr3_g, sptr3_b, sptr3_a = 227/255, 219/255, 142/255, 1.0
    local peak_r, peak_g, peak_b, peak_a     = 180/255, 180/255, 180/255, 1.0
        local peak_hold_time = 0.5  -- 피크 유지 시간 (초)
        -- [Data Storage] 피크 데이터를 저장할 테이블 (초기화)
        local spec_smooth_vals = {}
        local spec_peaks = {} 
        local spec_peak_times = {}
        -- 테이블 초기화 (최초 1회)
        for i = 1, 4096 do 
            spec_smooth_vals[i] = -144
            spec_peaks[i] = -144 
            spec_peak_times[i] = 0
        end

----------------------------------------------------------
-- Functions: Features (LUFS, Gonio, Symbiote, Scope, Spetrum)
----------------------------------------------------------
    function draw_lufs(x, y, w, h)
        local mom_val = reaper.gmem_read(20)
        local short_val = reaper.gmem_read(21)
        local mom_peak = reaper.gmem_read(22) -- JSFX에서 보낸 최고점

        local base_label_size = 15 -- Momentary, Short-term 라벨
        local base_val_size = 35   -- 큰 숫자 값
        local base_peak_size = 20  -- 옆에 작은 피크 값

        gfx.set(bg_r, bg_g, bg_b, bg_a)
        gfx.rect(x, y, w, h, 1)
        
        local cx = x + w * 0.5
        local unit_h = h / 2 -- 2등분
        gfx.setfont(1, "Arial", base_label_size * g_font_scale)

        -- === [상단: MOMENTARY (+ PEAK)] ===
        local m_py = y
        gfx.set(text_r, text_g, text_b, text_a)
        local m_lab = "MOMENTARY"
        local lw, lh = gfx.measurestr(m_lab)
        gfx.x, gfx.y = cx - lw * 0.5, m_py + unit_h * 0.15
        gfx.drawstr(m_lab)

        -- Momentary 값 숫자
        local m_str = (mom_val <= -100) and "- Inf" or string.format("%.1f", mom_val)
        gfx.setfont(2, "Arial", base_val_size * g_font_scale, "b")
        gfx.set(scp2_r, scp2_g, scp2_b, scp2_a)
        local sw, sh = gfx.measurestr(m_str)
        gfx.x, gfx.y = cx - sw * 0.5, m_py + unit_h * 0.35
        gfx.drawstr(m_str)

        -- Peak 값 표시
        gfx.setfont(1, "Arial", base_peak_size * g_font_scale, "b")
        gfx.set(scp3_r, scp3_g, scp3_b, scp3_a ) -- 황금색/노란색 계열
        local p_str = (mom_peak <= -100) and "- Inf" or string.format("%.1f", mom_peak)
        local pw, ph = gfx.measurestr(p_str)
        gfx.x, gfx.y = cx - pw * 0.5, m_py + unit_h * 0.80
        gfx.drawstr(p_str)

        -- === [하단: SHORT-TERM] ===
        local s_py = y + unit_h
        gfx.set(line_r, line_g, line_b, line_a)
        gfx.line(x + 10, s_py + 8, x + w - 10, s_py + 8) -- 구분선

        gfx.setfont(1, "Arial", base_label_size * g_font_scale) 
        gfx.set(text_r, text_g, text_b, text_a)
        local s_lab = "SHORT-TERM"
        local slw, slh = gfx.measurestr(s_lab)
        gfx.x, gfx.y = cx - slw * 0.5, s_py + unit_h * 0.25
        gfx.drawstr(s_lab)

        local s_str = (short_val <= -100) and "- Inf" or string.format("%.1f", short_val)
        gfx.setfont(2, "Arial", base_val_size * g_font_scale, "b")
        gfx.set(scp2_r, scp2_g, scp2_b, scp2_a)
        local ssw, ssh = gfx.measurestr(s_str)
        gfx.x, gfx.y = cx - ssw * 0.5, s_py + unit_h * 0.45
        gfx.drawstr(s_str)
    
        gfx.setfont(1, "Arial", base_title_size * g_font_scale)

        -- 마우스 왼쪽 버튼(1)이 눌렸고, 마우스가 LUFS 모듈 영역 안에 있을 때
        if gfx.mouse_cap == 1 then
            if gfx.mouse_x >= x and gfx.mouse_x <= x + w and 
               gfx.mouse_y >= y and gfx.mouse_y <= y + h then
                
                reaper.gmem_write(30, 1) 
                
                gfx.set(1, 1, 1, 0.15)
                gfx.rect(x, y, w, h, 1)
            end
        end
    end

    function draw_gonio(x, y, w, h, gain)
        -- Goniometer
            local base_trail = 2000
            local trail_len = math.floor(base_trail / (g_signal_release / 2))
            local is_hover = (gfx.mouse_x >= x and gfx.mouse_x <= x + w and 
                          gfx.mouse_y >= y and gfx.mouse_y <= y + h)
            if is_hover then
                trail_len = trail_len * 5
            end

            local cx, cy = x + w * 0.5, y + h * 0.45
            local dim_limit = math.min(w, h)
            local guide_size = dim_limit * 0.35 
            local dot_size = dim_limit * 0.35 * gain 
            local now = reaper.time_precise()
            
            local true_zero_limit = 1.0 
            local visual_limit = guide_size / (2 * dot_size)

            -- 가이드 라인 그리기
            gfx.set(line_r, line_g, line_b, line_a * 3 / 2)
            gfx.line(cx - guide_size, cy - guide_size, cx + guide_size, cy + guide_size)
            gfx.line(cx + guide_size, cy - guide_size, cx - guide_size, cy + guide_size)
            
            local write_idx = reaper.gmem_read(0)
            
            -- 일반 점들 그리기 루프
            for i = 0, trail_len, 2 do
                local idx = (write_idx - i - 1) % buf_len
                local l, r = reaper.gmem_read(10000 + idx), reaper.gmem_read(110000 + idx)
                
                local peak_intensity = math.max(math.abs(l), math.abs(r))
                local is_clipping = peak_intensity >= true_zero_limit
                
                -- 1. [핵심] 0dB 초과 시 피크 좌표 저장
                if peak_intensity >= true_zero_limit and #gonio_peaks < gonio_max_peak_dots then
                    local cl, cr = math.max(-visual_limit, math.min(visual_limit, l)), math.max(-visual_limit, math.min(visual_limit, r))
                    local px, py = cx + (cl - cr) * dot_size, cy - (cl + cr) * dot_size
                    table.insert(gonio_peaks, {px = px, py = py, time = now})
                end

                -- 일반 점 색상 보간
                local t = math.min(1.0, peak_intensity / visual_limit)
                local gonio_r, gonio_g, gonio_b, gonio_a

                if t < midpoint then
                    local local_t = t / midpoint 
                    local curve = local_t ^ steepness
                    
                    gonio_r = dot1_r + (dot2_r - dot1_r) * curve
                    gonio_g = dot1_g + (dot2_g - dot1_g) * curve
                    gonio_b = dot1_b + (dot2_b - dot1_b) * curve
                    gonio_a = dot1_a + (dot2_a - dot1_a) * curve
                else
                    local local_t = (t - midpoint) / (1 - midpoint)
                    local curve = local_t ^ steepness
                    
                    gonio_r = dot2_r + (dot3_r - dot2_r) * curve
                    gonio_g = dot2_g + (dot3_g - dot2_g) * curve
                    gonio_b = dot2_b + (dot3_b - dot2_b) * curve
                    gonio_a = dot2_a + (dot3_a - dot2_a) * curve
                end

                local cl, cr = math.max(-visual_limit, math.min(visual_limit, l)), math.max(-visual_limit, math.min(visual_limit, r))
                local px, py = cx + (cl - cr) * dot_size, cy - (cl + cr) * dot_size

                gfx.set(gonio_r, gonio_g, gonio_b, (1 - (i / trail_len)))
                gfx.x, gfx.y = px, py
                gfx.setpixel(gonio_r, gonio_g, gonio_b)
            end
            
            -- 저장된 피크 점들을 2초 동안 별도 색상으로 표시
            for i = #gonio_peaks, 1, -1 do
                local p = gonio_peaks[i]
                if (now - p.time) > gonio_peak_hold_time then
                    table.remove(gonio_peaks, i)
                else
                    gfx.set(gr_peak, gg_peak, gb_peak, 1.0)
                    gfx.rect(p.px - 1, p.py - 1, 2, 2) 
                end
            end
        -- phase correction
                -- [Phase Correlation Meter 추가]
            local write_idx = reaper.gmem_read(0)
            local idx = (write_idx - 1) % buf_len
            local l = reaper.gmem_read(10000 + idx)
            local r = reaper.gmem_read(110000 + idx)

            -- 1. 상관관계 계산
            local dot_product = l * r
            local mag_l = l * l
            local mag_r = r * r
            local denom = math.sqrt(mag_l * mag_r)
            
            local current_phase = 0
            if denom > 0.000001 then
                current_phase = dot_product / denom
            end

            -- 2. 스무딩 (너무 빨리 변하지 않게)
            phase_smooth = phase_smooth + (current_phase - phase_smooth) * 0.1
            
            -- 3. UI 그리기 (Gonio 하단에 배치)
            local bar_h = 4
            local bar_w = w * 0.6
            local bar_x = x + (w - bar_w) * 0.5
            local bar_y = y + h - 15 -- 하단 라벨 위쪽
            
            -- 배경 바 (가이드)
            gfx.set(line_r, line_g, line_b, line_a)
            gfx.rect(bar_x, bar_y, bar_w, bar_h, 0)
            gfx.line(bar_x + bar_w * 0.5, bar_y - 2, bar_x + bar_w * 0.5, bar_y + bar_h + 2) -- 0점 표시
            
            -- 현재 상태 바
            local indicator_x = bar_x + (bar_w * 0.5) + (phase_smooth * (bar_w * 0.5))
            
            -- 색상 결정 (양수면 Cyan 계열, 음수면 Red 계열)
            if phase_smooth >= 0 then
                gfx.set(dot2_r, dot2_g, dot2_b, 0.8) -- 정위상 (Mid Color)
            else
                gfx.set(1, 0, 0, 0.8) -- 역위상 (Red)
            end
            
            -- 인디케이터 그리기 (작은 사각형 혹은 선)
            gfx.rect(indicator_x - 1, bar_y - 2, 3, bar_h + 4, 1)

            -- 텍스트 라벨 (옵션)
            gfx.setfont(1, "Arial", (base_title_size - 4) * g_font_scale) -- 폰트 설정
            local label_padding = 5 -- 바와 텍스트 사이의 간격

            -- "-1" 라벨 정렬 및 출력
            local tw_minus, th_minus = gfx.measurestr("-1")
            gfx.x = bar_x - tw_minus - label_padding
            gfx.y = bar_y + (bar_h * 1) - (th_minus * 0.5) -- 바의 세로 중앙 정렬
            gfx.drawstr("-1")

            -- "+1" 라벨 정렬 및 출력
            local tw_plus, th_plus = gfx.measurestr("+1")
            gfx.x = bar_x + bar_w + label_padding
            gfx.y = bar_y + (bar_h * 1) - (th_plus * 0.5) -- 바의 세로 중앙 정렬
            gfx.drawstr("+1")
        
        gfx.set(line_r, line_g, line_b, line_a)
        gfx.setfont(1, "Arial", base_title_size * g_font_scale)
        gfx.x, gfx.y = x + 5, y + 5
        gfx.drawstr("Gonio")
    end

    function draw_symbiote(x, y, w, h, gain)
        ---------------------초기값
        local base_attack = 0.3
        local base_release = 0.3
        ---------------------초기값

        local sym_base_radius = math.min(w, h) * 0.45 * sym_size_ratio
        local fixed_cx, fixed_cy = x + w * 0.5, y + h * 0.5
        
        -- [Drift Logic] 움직임 계산
        local time = reaper.time_precise()
        local drift_radius = 10.0 -- 움직임 반경
        local drift_speed = 0.7   -- 움직임 속도
        
        local drift_x = math.sin(time * drift_speed) * drift_radius 
                      + math.cos(time * drift_speed * 1.3) * (drift_radius * 0.5)
        local drift_y = math.cos(time * drift_speed * 0.8) * drift_radius 
                      + math.sin(time * drift_speed * 1.7) * (drift_radius * 0.5)

        -- 그리기 중심점 (심비오트의 실제 위치 = 고정점 + 오차)
        local cx, cy = fixed_cx + drift_x, fixed_cy + drift_y
        
        -- 1. [데이터 읽기]
        local write_idx = reaper.gmem_read(0)
        local idx = (write_idx - 1) % buf_len
        local l = reaper.gmem_read(10000 + idx)
        local r = reaper.gmem_read(110000 + idx)
        
        local target_vol = (math.abs(l) + math.abs(r)) * 0.5 * gain
        local target_width = math.abs(l - r) * gain
        s_width_smooth = s_width_smooth + (target_width - s_width_smooth) * 0.1

        -- 2. [저음 데이터] (크기 제어용)
        local bass_sum = 0
        for k = 2, 16 do 
            bass_sum = bass_sum + reaper.gmem_read(300000 + k)
        end
        local current_bass = (bass_sum / 16) * gain * 0.032
        local size_attack = base_attack * g_signal_attack
        local size_release = base_release * g_signal_release
        
        local smoothing = (current_bass > s_bass_smooth) and size_attack or size_release
        s_bass_smooth = s_bass_smooth + (current_bass - s_bass_smooth) * smoothing
        
        -- [가시 입력값 강제 제한]
        local spike_raw = 0
        if current_bass > 1.7 then 
            spike_raw = (current_bass - 0.25) * 2
        end
        spike_raw = math.min(0.5, spike_raw)

        -- 가시 반응 속도 
        local spike_attack = size_attack * 1.5 
        local spike_release = size_release * 1.0

        local spike_smoothing = (spike_raw > sym_spikiness) and spike_attack or spike_release
        sym_spikiness = sym_spikiness + (spike_raw - sym_spikiness) * math.min(1.0, spike_smoothing)

        -- 속도 누적
        local cur_time = reaper.time_precise()
        if not last_time then last_time = cur_time end
        sym_time_accum = sym_time_accum + (cur_time - last_time) * (0.3 + target_vol * 12.0)
        last_time = cur_time

        -- 3. [벽 돌파 방지]
        local max_allowed_r = (math.min(w, h) * 0.5) - 5
        local raw_r_dyn = sym_base_radius * (1 + s_bass_smooth * 0.5)
        local clamped_r = math.min(max_allowed_r * 0.8, raw_r_dyn)
        clamped_r = math.max(sym_base_radius * sym_min_scale, clamped_r)

        -- 4. [형태 계산]
        local shape_points = {}
        local stretch = 1.0 + (s_width_smooth * 2.0)

        for i = 0, sym_points do
            local angle = (i / sym_points) * 2 * math.pi
            local n1 = math.sin(angle * 3 + sym_time_accum * sym_noise_speed)
            local n2 = math.cos(angle * 5 - sym_time_accum * (sym_noise_speed * 0.2))
            local wobble = (n1 + n2) * 0.12
            
            local spike = math.sin(angle * 8 + sym_time_accum) * sym_spikiness * 0.3
            
            local r_final = raw_r_dyn * (1 + wobble + spike)
            
            local dx = math.cos(angle) * r_final * stretch
            local dy = math.sin(angle) * r_final * stretch
            
            local abs_dx = dx + drift_x -- 고정점으로부터의 거리 X
            local abs_dy = dy + drift_y -- 고정점으로부터의 거리 Y
            local dist_from_fixed = math.sqrt(abs_dx*abs_dx + abs_dy*abs_dy)

            if dist_from_fixed > max_allowed_r then
                local scale = max_allowed_r / dist_from_fixed
                local constrained_abs_dx = abs_dx * scale
                local constrained_abs_dy = abs_dy * scale
                dx = constrained_abs_dx - drift_x
                dy = constrained_abs_dy - drift_y
            end
            
            shape_points[i] = { dx = dx, dy = dy }
        end
        
        -- 5. [Onion Skin 그리기]
        local t_col = math.min(1.0, clamped_r / (max_allowed_r * 0.8))

        for j = sym_layers, 1, -1 do
            local layer_t = j / sym_layers
            local cur_r, cur_g, cur_b, cur_a
            if layer_t < midpoint then
                local local_t = (layer_t / midpoint) ^ steepness
                cur_r = sym1_r + (sym2_r - sym1_r) * local_t
                cur_g = sym1_g + (sym2_g - sym1_g) * local_t
                cur_b = sym1_b + (sym2_b - sym1_b) * local_t
                cur_a = sym1_a + (sym2_a - sym1_a) * local_t
            else
                local local_t = ((layer_t - midpoint) / (1 - midpoint)) ^ steepness
                cur_r = sym2_r + (sym3_r - sym2_r) * local_t
                cur_g = sym2_g + (sym3_g - sym2_g) * local_t
                cur_b = sym2_b + (sym3_b - sym2_b) * local_t
                cur_a = sym2_a + (sym3_a - sym2_a) * local_t
            end
            gfx.set(cur_r, cur_g, cur_b, cur_a)
            local first_x, first_y, prev_x, prev_y
            for i = 0, sym_points do
                local p = shape_points[i]
                local px, py = cx + p.dx * layer_t, cy + p.dy * layer_t
                if i==0 then first_x,first_y=px,py; prev_x,prev_y=px,py else gfx.triangle(cx,cy,prev_x,prev_y,px,py); prev_x,prev_y=px,py end
            end
            gfx.triangle(cx, cy, prev_x, prev_y, first_x, first_y)
        end
        
        -- 6. [외곽선]
        gfx.set(sym3_r, sym3_g, sym3_b, 1.0)
        local pp = shape_points[0]
        for i = 1, sym_points do
            local cp = shape_points[i]
            gfx.line(cx+pp.dx, cy+pp.dy, cx+cp.dx, cy+cp.dy)
            gfx.line(cx+pp.dx, cy+pp.dy+1, cx+cp.dx, cy+cp.dy+1)
            pp = cp
        end
        gfx.line(cx+pp.dx, cy+pp.dy, cx+shape_points[0].dx, cy+shape_points[0].dy)

        gfx.set(line_r, line_g, line_b, line_a)
        gfx.x, gfx.y = x + 5, y + 5
        gfx.drawstr("Symbiote")
    end

    function draw_scope(x, y, w, h, zoom)
        local cy = y + h * 0.5
        local write_idx = reaper.gmem_read(0)
        
        -- step: 1픽셀당 표현해야 할 데이터의 양 (예: 125 샘플)
        local step = (buf_len / w) * scope_speed 
        local is_hover = (gfx.mouse_x >= x and gfx.mouse_x <= x + w and 
                      gfx.mouse_y >= y and gfx.mouse_y <= y + h)
        if is_hover then
            step = (buf_len / w) * (0.3)
        end
        local scan_stride = math.max(1, math.floor(step / 8)) 

        for m = 0, w - 1 do
            -- 현재 픽셀(m)이 보여줘야 할 데이터의 시작 위치 계산
            local start_pos = (write_idx - (w - m) * step)
            
            -- [Min-Max 탐색]
            -- 해당 구간(step) 안에서 가장 높은 값(max_v)과 낮은 값(min_v)을 찾습니다.
            local max_v = -100 -- 초기값
            local min_v = 100  -- 초기값
            local abs_peak = 0 -- 색상 결정을 위한 절대값 피크
            
            for s = 0, step - 1, scan_stride do
                local read_ptr = math.floor(start_pos + s) % buf_len
                local raw_val = reaper.gmem_read(10000 + read_ptr) -- Left Channel
                
                if raw_val > max_v then max_v = raw_val end
                if raw_val < min_v then min_v = raw_val end
                
                local abs_v = math.abs(raw_val)
                if abs_v > abs_peak then abs_peak = abs_v end
            end
            
            -- 값 보정 (Zoom 적용)
            local draw_max = max_v * zoom * 0.5
            local draw_min = min_v * zoom * 0.5
            
            -- 좌표 변환 (화면 위아래 뒤집힘 주의: -를 붙여야 함)
            local y_top = cy - (draw_max * h)
            local y_bottom = cy - (draw_min * h)
            
            -- 화면 밖으로 나가는 것 방지 (Clamping)
            y_top = math.max(y, math.min(y + h, y_top))
            y_bottom = math.max(y, math.min(y + h, y_bottom))
            
            -- [색상 계산] 구간 내 최대 피크(abs_peak)를 기준으로 색상 결정
            local t = math.min(1.0, abs_peak * zoom)
            local local_t = t ^ steepness
            local scp_r, scp_g, scp_b, scp_a

            if t < midpoint then
                local local_t = t / midpoint
                local curve = local_t ^ steepness

                scp_r = scp1_r + (scp2_r - scp1_r) * curve
                scp_g = scp1_g + (scp2_g - scp1_g) * curve
                scp_b = scp1_b + (scp2_b - scp1_b) * curve
                scp_a = scp1_a + (scp2_a - scp1_a) * curve
            else
                local local_t = (t - midpoint) / (1 - midpoint)
                local curve = local_t ^ steepness
                
                scp_r = scp2_r + (scp3_r - scp2_r) * curve
                scp_g = scp2_g + (scp3_g - scp2_g) * curve
                scp_b = scp2_b + (scp3_b - scp2_b) * curve
                scp_a = scp2_a + (scp3_a - scp2_a) * curve
            end
            
            gfx.set(scp_r, scp_g, scp_b, scp_a)

            -- [그리기] 점을 잇는 게 아니라, 수직선(Bar)을 그립니다.
            -- 만약 파형이 거의 없어서 위아래 차이가 1픽셀 미만이면 점을 찍습니다.
            if math.abs(y_bottom - y_top) < 1 then
                gfx.rect(x + m, y_top, 1, 1)
            else
                -- 윗점에서 아랫점까지 선 긋기
                gfx.line(x + m, y_top, x + m, y_bottom)
            end
        end
        
        gfx.set(line_r, line_g, line_b, line_a)
        gfx.x, gfx.y = x + 5, y + 5
        gfx.drawstr("Scope")
    end

    local function freq_to_note(freq)
        if freq <= 0 then return "N/A" end
        -- MIDI Number 계산: 69 + 12 * log2(freq / 440)
        local n = 12 * (math.log(freq / 440, 2)) + 69
        local midi_int = math.floor(n + 0.5)
        local names = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"}
        local note_idx = (midi_int % 12) + 1
        local octave = math.floor(midi_int / 12) - 1
        return names[note_idx] .. octave
    end

    function draw_spectrum(x, y, w, h, ceil, floor)
        -------------------------
        local base_area_decay = 4.0 -- 값이 작을수록 더 천천히 떨어짐 (부드러움)
        local base_peak_decay = 3.0 -- Peak Frez 떨어지는 속도 (dB/frame approx)
        local area_decay_rate = base_area_decay * g_signal_release
        local peak_decay_rate = base_peak_decay * g_signal_release
        -------------------------초기
        local is_hover = (gfx.mouse_x >= x and gfx.mouse_x <= x + w and 
                      gfx.mouse_y >= y and gfx.mouse_y <= y + h)
        local is_frozen = is_hover and (gfx.mouse_cap & 1 == 1)
        if is_hover and not is_frozen then
            area_decay_rate = 1.0 * g_signal_release
        end

        local range = ceil - floor
        local srate = reaper.gmem_read(1)
        if srate == 0 then srate = 48000 end
        local now = reaper.time_precise()
        local target_max_hz = 48000 -- 무조건 화면 우측 끝에 표시할 최대 주파수
        local max_k = target_max_hz * fft_size / srate -- 48kHz가 위치한 Bin 인덱스 계산
        local k_max_log = math.log(max_k) -- X 좌표 정규화에 사용될 로그 스케일 최대치
        
        -- 1. Grid
        gfx.set(line_r, line_g, line_b, line_a)
        local k_max_log = math.log(fft_bins)
        
        -- 2. Draw Spectrum (Fill & Peak Line)
        local ox, oy = x, y + h       -- Fill용 이전 좌표
        local pox, poy = x, y + h     -- Peak Line용 이전 좌표
        local k = 1
        
        while k <= max_k do
            local k_int = math.floor(k)
            local mag = reaper.gmem_read(300000 + k_int)
            
            -- 1. 순수한 오디오 dB 값 계산 (Visual Gain 적용 전)
            local pure_db = 20 * math.log(mag + 0.0000001, 10)
            
            -- 2. Visual Gain(spec_offset) 적용
            local raw_db = pure_db - spec_offset
            
            -- 3. [노이즈 플로어 앵커 로직]
            -- 만약 순수 오디오가 -120dB 이하라면 (사실상 무음이라면)
            if pure_db < -120 then 
                -- Gain 값을 무시하고 화면 바닥(floor)보다 10dB 아래로 고정
                raw_db = floor - 10 
            end

            -- db 변수는 raw_db와 동일하게 사용
            local db = raw_db

            -- [Area Smoothing Logic] 면 프리즈 효과
            local smooth_db = spec_smooth_vals[k_int] or (floor - 10)
            
            -- 💡 프리즈 상태가 아닐 때만 값 업데이트
            if not is_frozen then 
                if raw_db >= smooth_db then
                    local attack_coef = math.min(1.0, 0.8 * g_signal_attack) 
                    smooth_db = smooth_db + (raw_db - smooth_db) * attack_coef
                else
                    smooth_db = smooth_db - area_decay_rate
                end
                spec_smooth_vals[k_int] = smooth_db -- 업데이트된 값을 저장
            end
            -- 프리즈 상태라면 위 로직을 무시하므로 smooth_db는 멈춰있게 됨

            -- [Peak Hold Logic]
            local current_peak = spec_peaks[k_int] or -144
            local last_time = spec_peak_times[k_int] or 0
            
            -- 💡 프리즈 상태가 아닐 때만 값 업데이트
            if not is_frozen then 
                if db >= current_peak then
                    spec_peaks[k_int] = db
                    spec_peak_times[k_int] = now
                else
                    if (now - last_time) > peak_hold_time then
                        spec_peaks[k_int] = current_peak - peak_decay_rate
                    end
                end
            end
            local peak_db = spec_peaks[k_int]

            -- --- 좌표 계산 ---
            -- 1) Real-time Fill (면)
            local t_raw = (smooth_db - floor) / range
            t_raw = math.max(0, math.min(1, t_raw))
            local t = t_raw ^ 1.5 
            
            local dy = y + h - (t * h)
            
            -- 피크 라인도 동일하게 적용
            local pt_raw = (peak_db - floor) / range
            local pt = math.max(0, math.min(1, pt_raw)) ^ 1.5
            local pdy = y + h - (pt * h)

            -- X 좌표 (공통)
            local x_norm = math.log(k) / k_max_log
            local dx = x + (x_norm * w)
            
            -- --- 그리기 (Draw) ---
            -- A. Filled Area (Gradient)
            if t < midpoint then
                -- [구간 A -> B] (0.0 ~ 0.5 사이)
                -- 0~0.5 범위를 0~1로 확장하여 비율(ratio) 계산
                local local_t = t / midpoint 
                local curve = local_t ^ steepness
                sptr_r = sptr1_r + (sptr2_r - sptr1_r) * curve
                sptr_g = sptr1_g + (sptr2_g - sptr1_g) * curve
                sptr_b = sptr1_b + (sptr2_b - sptr1_b) * curve
                sptr_a = sptr1_a + (sptr2_a - sptr1_a) * curve
            else
                local local_t = (t - midpoint) / (1 - midpoint)
                local curve = local_t ^ steepness
                
                sptr_r = sptr2_r + (sptr3_r - sptr2_r) * curve
                sptr_g = sptr2_g + (sptr3_g - sptr2_g) * curve
                sptr_b = sptr2_b + (sptr3_b - sptr2_b) * curve
                sptr_a = sptr2_a + (sptr3_a - sptr2_a) * curve
            end
            
            gfx.set(sptr_r, sptr_g, sptr_b, sptr_a)
            if k > 1 then
                gfx.triangle(ox, y + h, ox, oy, dx, dy, dx, y + h)
            end
            
            -- B. Peak Hold Line
            gfx.set(peak_r, peak_g, peak_b, peak_a)
            if k > 1 then
                gfx.line(pox, poy, dx, pdy)
            end
            
            -- 좌표 갱신
            ox, oy = dx, dy
            pox, poy = dx, pdy
            
            -- Step 증가
            local step = 1
            if k > 50 then step = k * 0.05 end
            k = k + step
        end
        
        -- Hz Lines
        gfx.set(line_r, line_g, line_b, line_a * 3 / 2)
        local freqs = {100, 1000, 10000}
        local labels = {"100", "1k", "10k"}
        for i, freq in ipairs(freqs) do
            local k = freq * (fft_size) / srate
            if k > 0 then
                local x_norm = math.log(k) / k_max_log
                if x_norm > 0 and x_norm < 1 then
                    local gx = x + x_norm * w
                    gfx.line(gx, y, gx, y + h)
                    gfx.x, gfx.y = gx + 2, y + h - 22
                    gfx.drawstr(labels[i])
                end
            end
        end
        
        -- [draw_spectrum 함수]
            if gfx.mouse_x >= x and gfx.mouse_x <= x + w and gfx.mouse_y >= y and gfx.mouse_y <= y + h then
                -- 1. 마우스 X좌표를 주파수로 역산 (로그 스케일 기준)
                local x_norm = (gfx.mouse_x - x) / w
                local k_max_log = math.log(fft_bins)
                local k_val = math.exp(x_norm * k_max_log)
                local hz = k_val * srate / fft_size
                
                -- 2. 정보 텍스트 생성 (dB 제외)
                local note = freq_to_note(hz)
                local info_text = string.format("%.0f Hz (%s)", hz, note)
                
                -- 3. 툴팁 그리기
                gfx.setfont(1, "Arial", (base_title_size) * g_font_scale) -- 툴팁용 작은 폰트
                local tw, th = gfx.measurestr(info_text)
                local tx, ty = gfx.mouse_x + 10, gfx.mouse_y - 20
                
                -- 화면 밖으로 나가지 않게 조정
                if tx + tw > gfx.w then tx = gfx.mouse_x - tw - 10 end
                if ty < 0 then ty = gfx.mouse_y + 20 end
                
                -- 배경 사각형 (테마 색상 활용)
                gfx.set(bg_r, bg_g, bg_b, 0.9) 
                gfx.rect(tx - 4, ty - 2, tw + 8, th + 4, 1)
                
                -- 테두리 선 추가 (가독성 향상)
                gfx.set(line_r, line_g, line_b, 0.5)
                gfx.rect(tx - 4, ty - 2, tw + 8, th + 4, 0)

                -- 텍스트 출력
                gfx.set(1, 1, 1, 1) 
                gfx.x, gfx.y = tx, ty
                gfx.drawstr(info_text)
                
                -- 4. 마우스 위치 가이드 세로선
                gfx.set(line_r, line_g, line_b, 0.3)
                gfx.line(gfx.mouse_x, y, gfx.mouse_x, y + h)
                
                -- 폰트 원복 (중요)
                gfx.setfont(1, "Arial", base_title_size * g_font_scale)
            end

        gfx.set(line_r, line_g, line_b, line_a)
        gfx.x, gfx.y = x + 5, y + 5
        gfx.drawstr("Spectrum")

        if is_frozen then
            gfx.set(227/255, 219/255, 142/255, 1.0)
            local fw, fh = gfx.measurestr("FREEZE")
            gfx.x, gfx.y = x + w - fw - 5, y + 5
            gfx.drawstr("FREEZE")
        end
    end

----------------------------------------------------------
-- Functions: Color Setting
----------------------------------------------------------
    -- [메모리 주소 상수]
        local MEM_BG    = 1000
        local MEM_LINE  = 1010
        local MEM_TEXT  = 1020
        local MEM_ZERO  = 1030
        local MEM_MID   = 1040
        local MEM_PEAK  = 1050

    -- Function: Save ExtState
        local SECTION = "JKK_Visualizer"

        function LoadSettingsFromExtState()
            for i = 1000, 1100 do
                local key = "MEM_" .. i
                if reaper.HasExtState(SECTION, key) then
                    local val = tonumber(reaper.GetExtState(SECTION, key))
                    reaper.gmem_write(i, val)
                end
            end

            if reaper.HasExtState(SECTION, "FontScale") then
                local val = tonumber(reaper.GetExtState(SECTION, "FontScale"))
                reaper.gmem_write(1300, val)
            end
            
            if reaper.HasExtState(SECTION, "ModuleOrder") then
                local order_str = reaper.GetExtState(SECTION, "ModuleOrder")
                local idx = 1
                for val in string.gmatch(order_str, '([^,]+)') do
                    local n = tonumber(val)
                    if n then
                        ui_order[idx] = n
                        reaper.gmem_write(1100 + idx, n)
                        idx = idx + 1
                    end
                end
            end
        end

    -- Function: Default Color
        function init_default_colors()
            -- 1. UI Defaults
            reaper.gmem_write(1000, 030/255); reaper.gmem_write(1001, 030/255); reaper.gmem_write(1002, 030/255); reaper.gmem_write(1003, 1.0) -- BG
            reaper.gmem_write(1010, 200/255); reaper.gmem_write(1011, 200/255); reaper.gmem_write(1012, 200/255); reaper.gmem_write(1013, 0.3) -- Line
            reaper.gmem_write(1020, 180/255); reaper.gmem_write(1021, 180/255); reaper.gmem_write(1022, 180/255); reaper.gmem_write(1023, 1.0) -- Text

            -- 2. Signal Defaults
            reaper.gmem_write(1030, 006/255); reaper.gmem_write(1031, 143/255); reaper.gmem_write(1032, 195/255); reaper.gmem_write(1033, 0.1) -- Weak
            reaper.gmem_write(1040, 006/255); reaper.gmem_write(1041, 143/255); reaper.gmem_write(1042, 195/255); reaper.gmem_write(1043, 0.8) -- Mid
            reaper.gmem_write(1050, 227/255); reaper.gmem_write(1051, 219/255); reaper.gmem_write(1052, 142/255); reaper.gmem_write(1053, 1.0) -- Peak
            reaper.gmem_write(1060, 180/255); reaper.gmem_write(1061, 180/255); reaper.gmem_write(1062, 180/255); reaper.gmem_write(1063, 1.0) -- Frez Line

            -- 3. Gain & Font Scale Default
            reaper.gmem_write(2, 0.5) -- Default Gain (0.0~1.0 scale)
            reaper.gmem_write(1300, 1.0) -- Default Font Scale
            -- Attack & Release Defaults
            reaper.gmem_write(4, 1.0) 
            reaper.gmem_write(5, 1.0)
            
            -- 4. Order Default
            for i=1, 5 do reaper.gmem_write(1100 + i, i) end
        end

    -- Function: Read Memory
        function update_settings_from_gmem()
            -- 1. Read Save History
            if reaper.gmem_read(1003) == 0 then
                LoadSettingsFromExtState()
                if reaper.gmem_read(1003) == 0 then
                    init_default_colors()
                end
            end
                -- Atk, Rel Read
                local att = reaper.gmem_read(4)
                local rel = reaper.gmem_read(5)
                if att > 0 then g_signal_attack = att else g_signal_attack = 1.0 end
                if rel > 0 then g_signal_release = rel else g_signal_release = 1.0 end

            -- 1. Reset
            if reaper.gmem_read(1100) > 0 then
                reaper.gmem_write(1100, 0)
            end
            if reaper.gmem_read(1000 + 3) == 0 then return end

            -- 2. Read Color Memory
                bg_r = reaper.gmem_read(1000); bg_g = reaper.gmem_read(1001); bg_b = reaper.gmem_read(1002); bg_a = reaper.gmem_read(1003)
                line_r = reaper.gmem_read(1010); line_g = reaper.gmem_read(1011); line_b = reaper.gmem_read(1012); line_a = reaper.gmem_read(1013)
                text_r = reaper.gmem_read(1020); text_g = reaper.gmem_read(1021); text_b = reaper.gmem_read(1022); text_a = reaper.gmem_read(1023)

                local c1_r = reaper.gmem_read(1030); local c1_g = reaper.gmem_read(1031); local c1_b = reaper.gmem_read(1032); local c1_a = reaper.gmem_read(1033)
                local c2_r = reaper.gmem_read(1040); local c2_g = reaper.gmem_read(1041); local c2_b = reaper.gmem_read(1042); local c2_a = reaper.gmem_read(1043)
                local c3_r = reaper.gmem_read(1050); local c3_g = reaper.gmem_read(1051); local c3_b = reaper.gmem_read(1052); local c3_a = reaper.gmem_read(1053)
                local c4_r = reaper.gmem_read(1060); local c4_g = reaper.gmem_read(1061); local c4_b = reaper.gmem_read(1062); local c4_a = reaper.gmem_read(1063)

            -- 3. Color Mapping
                -- Gonio
                dot1_r, dot1_g, dot1_b, dot1_a = c1_r, c1_g, c1_b, c1_a
                dot2_r, dot2_g, dot2_b, dot2_a = c2_r, c2_g, c2_b, c2_a
                dot3_r, dot3_g, dot3_b, dot3_a = c3_r, c3_g, c3_b, c3_a
                gr_peak, gg_peak, gb_peak      = c3_r, c3_g, c3_b 

                -- Symbiote
                sym1_r, sym1_g, sym1_b, sym1_a = c1_r, c1_g, c1_b, c1_a
                sym2_r, sym2_g, sym2_b, sym2_a = c2_r, c2_g, c2_b, c2_a
                sym3_r, sym3_g, sym3_b, sym3_a = c3_r, c3_g, c3_b, c3_a

                -- Scope
                scp1_r, scp1_g, scp1_b, scp1_a = c1_r, c1_g, c1_b, c1_a
                scp2_r, scp2_g, scp2_b, scp2_a = c2_r, c2_g, c2_b, c2_a
                scp3_r, scp3_g, scp3_b, scp3_a = c3_r, c3_g, c3_b, c3_a

                -- Spectrum
                sptr1_r, sptr1_g, sptr1_b, sptr1_a = c1_r, c1_g, c1_b, c1_a
                sptr2_r, sptr2_g, sptr2_b, sptr2_a = c2_r, c2_g, c2_b, c2_a
                sptr3_r, sptr3_g, sptr3_b, sptr3_a = c3_r, c3_g, c3_b, c3_a
                
                -- Spectrum Peak Line
                peak_r, peak_g, peak_b, peak_a = c4_r, c4_g, c4_b, c4_a

            -- 4. Read UI Order
                for i=1, 5 do
                    local order_val = reaper.gmem_read(1100 + i)
                    if order_val > 0 then ui_order[i] = order_val end
                end

            -- 5. Read Font Scale
                local scale_val = reaper.gmem_read(1300)
                if scale_val > 0 then 
                    g_font_scale = scale_val 
                else
                    g_font_scale = 1.0
                end
        end

    -- Function: Initialize_System
        local SECTION = "JKK_Visualizer" -- [중요] 에디터와 똑같은 이름이어야 함!

        local function Initialize_System()
            -- (A) ExtState에서 저장된 값 불러오기 시도
            local function load_color(mem_idx, ext_key)
                if reaper.HasExtState(SECTION, "MEM_"..mem_idx) then
                    reaper.gmem_write(mem_idx, tonumber(reaper.GetExtState(SECTION, "MEM_"..mem_idx)))
                    return true
                end
                return false
            end

            -- 색상 불러오기 (실패하면 nil 반환)
            local loaded = load_color(1000, "MEM_1000") -- 배경색 R값만 체크해봐도 됨

            -- (B) 저장된 값이 없거나, gmem이 비어있으면(0이면) -> 기본값 강제 주입
            -- 배경색(1000번지)의 Alpha값(1003)이 0이면 "초기화 안 됨"으로 간주
            if reaper.gmem_read(1003) == 0 then
                -- Helper: gmem에 RGBA 쓰기
                local function write_def(idx, col)
                    reaper.gmem_write(idx, col[1])
                    reaper.gmem_write(idx+1, col[2])
                    reaper.gmem_write(idx+2, col[3])
                    reaper.gmem_write(idx+3, col[4])
                end
                
                -- 게인, 속도 기본값
                reaper.gmem_write(2, 0.5) -- Gain
                reaper.gmem_write(4, 1.0) -- Attack
                reaper.gmem_write(5, 1.0) -- Release
                reaper.gmem_write(1300, 1.0) -- Font Scale
            end

            -- (C) 모듈 순서 및 활성화 상태 불러오기
            -- 순서 불러오기
            if reaper.HasExtState(SECTION, "ModuleOrder") then
                local order_str = reaper.GetExtState(SECTION, "ModuleOrder")
                local idx = 1
                for val in string.gmatch(order_str, '([^,]+)') do
                    reaper.gmem_write(1100 + idx, tonumber(val))
                    idx = idx + 1
                end
            else
                -- 저장된 순서 없으면 기본 순서 (1,2,3,4,5) 입력
                for i=1, 5 do reaper.gmem_write(1100 + i, i) end
            end

            -- 활성화(체크박스) 상태 불러오기
            if reaper.HasExtState(SECTION, "ModuleActive") then
                local active_str = reaper.GetExtState(SECTION, "ModuleActive")
                local idx = 1
                for val in string.gmatch(active_str, '([^,]+)') do
                    reaper.gmem_write(1150 + idx, (val == "1" and 1 or 0))
                    idx = idx + 1
                end
            else
                -- 저장된 값 없으면 전부 켜기(1)
                for i=1, 5 do reaper.gmem_write(1150 + i, 1) end
            end
        end

        -- [핵심] 스크립트 시작 시 딱 한 번 실행!
        Initialize_System()

----------------------------------------------------------
-- UI Loops
----------------------------------------------------------
    function run()
        if gfx.getchar() == 27 then return end 
        update_settings_from_gmem()

        -- [Right Click Logic]
            if gfx.mouse_cap == 2 then 
                gfx.x, gfx.y = gfx.mouse_x, gfx.mouse_y
                
                -- 현재 도킹 상태 확인 (0이면 Float, 0보다 크면 도킹됨)
                local current_dock_state = gfx.dock(-1) 
                local is_docked = current_dock_state > 0
                
                local menu_str = (is_docked and "!" or "") .. "Dock to Docker|"
                menu_str = menu_str .. "#For editing theme, run 'JKK_Visualizer Editor' from Action List"
                
                local selection = gfx.showmenu(menu_str)
                
                if selection == 1 then
                    if is_docked then 
                        -- 도킹되어 있으면 밖으로 빼냄 (Float)
                        gfx.dock(0) 
                    else 
                        -- 밖으로 나와 있으면 무조건 위쪽 도커(513)로 집어넣음
                        gfx.dock(513) 
                    end
                end
            end
        -- [Mouse Scroll Logic]
            if gfx.mouse_wheel ~= 0 then
                -- 1. 현재 Gain 값 읽기
                local current_gain = reaper.gmem_read(2)
                
                -- 2. 휠 방향에 따라 값 변경 (감도 조절: 0.05)
                -- 휠을 위로 올리면(+) 게인 증가, 내리면(-) 게인 감소
                local sensitivity = 0.02
                local change = (gfx.mouse_wheel / 120) * sensitivity 
                -- (참고: 리퍼/OS에 따라 휠 한 칸이 120일 수도, 1일 수도 있습니다. 
                -- 너무 빠르면 120을 나누고, 너무 느리면 120을 지우세요.)
                
                if math.abs(change) < 0.01 then -- 미세 조정 보정
                     change = (gfx.mouse_wheel > 0) and 0.02 or -0.02
                end

                current_gain = current_gain + change

                -- 3. 최대/최소 제한 (Clamping)
                if current_gain > 1.0 then current_gain = 1.0 end
                if current_gain < 0.0 then current_gain = 0.0 end

                -- 4. 변경된 값 저장 (gmem & ExtState)
                reaper.gmem_write(2, current_gain)
                -- (선택 사항) 영구 저장을 원하면 아래 주석 해제 (하지만 너무 빈번한 저장은 비추천)
                -- reaper.SetExtState("JKK_Visualizer", "MEM_2", tostring(current_gain), true)

                -- 5. 휠 값 초기화 (필수! 안 하면 계속 돌아감)
                gfx.mouse_wheel = 0
                
                -- [보너스] 화면 중앙에 현재 게인 값 잠시 띄우기 위한 변수 설정
                -- (이 변수는 run 함수 밖, 전역 변수로 선언해두는 것이 좋습니다: local gain_popup_time = 0)
                gain_popup_timer = 30 -- 약 0.5초간 표시 (30프레임)
            end

        -- [Value Calculation]
        local s1 = reaper.gmem_read(2)
        local s2 = reaper.gmem_read(3)

        local gain = g_gain_min + (g_gain_max - g_gain_min) * s1
        local ceil = spec_ceil_min + (spec_ceil_max - spec_ceil_min) * s1
        local zoom = s_zoom_min + (s_zoom_max - s_zoom_min) * s1
        local floor = spec_floor_min + (spec_floor_max - spec_floor_min) * s2

        -- [Background Draw]
        gfx.set(bg_r, bg_g, bg_b, bg_a)
        gfx.rect(0, 0, gfx.w, gfx.h)

        -- [Module Settings]
        local module_widths = {
            [1] = 0.10, -- LUFS
            [2] = 0.15, -- Gonio
            [3] = 0.15, -- Symbiote
            [4] = 0.15, -- Scope
            [5] = 0.45  -- Spectrum
        }

        -- [Step 1] 활성화된 모듈의 총 비율과 개수 계산
        -- 모듈이 꺼지면 남은 모듈들이 화면을 꽉 채우기 위해 필요합니다.
        local total_active_ratio = 0
        local active_count = 0
        
        for i = 1, 5 do
            local mod_id = ui_order[i]
            -- 1150 + id 값을 읽어 활성 상태 확인 (1=On, 0=Off)
            -- 에디터가 아직 값을 안 썼을 경우를 대비해 기본값 1 처리
            local val = reaper.gmem_read(1150 + mod_id)
            -- 초기에 값이 0일 수도 있으므로, 저장된 적이 없으면 1로 간주하는 안전장치 필요 시 추가 가능
            -- 여기서는 에디터에서 기본적으로 1을 쓴다고 가정
            
            if val == 1 then
                total_active_ratio = total_active_ratio + module_widths[mod_id]
                active_count = active_count + 1
            end
        end

        -- 만약 모든 모듈이 꺼져있다면 0으로 나누는 오류 방지
        if total_active_ratio == 0 then total_active_ratio = 1 end

        -- [Step 2] 그리기 루프
        local current_x = 0
        local drawn_count = 0 -- 실제로 그려진 모듈 수 카운트

        for i = 1, 5 do
            local mod_id = ui_order[i]
            local is_active = (reaper.gmem_read(1150 + mod_id) == 1)

            if is_active then
                drawn_count = drawn_count + 1
                
                -- 비율 재계산 (꺼진 모듈만큼 너비 확장)
                local ratio = module_widths[mod_id] / total_active_ratio
                local w = math.floor(gfx.w * ratio)
                
                -- 마지막으로 그려지는 모듈은 남은 공간을 모두 채움 (빈틈 방지)
                if drawn_count == active_count then 
                    w = gfx.w - current_x 
                end

                -- 1. 모듈 내용 그리기
                if mod_id == 1 then draw_lufs(current_x, 0, w, gfx.h)
                elseif mod_id == 2 then draw_gonio(current_x, 0, w, gfx.h, gain)
                elseif mod_id == 3 then draw_symbiote(current_x, 0, w, gfx.h, gain)
                elseif mod_id == 4 then draw_scope(current_x, 0, w, gfx.h, zoom)
                elseif mod_id == 5 then draw_spectrum(current_x, 0, w, gfx.h, ceil, floor)
                end
                
                -- 2. 왼쪽 경계선 그리기
                -- 화면의 가장 왼쪽에 있는 모듈(첫 번째로 그려지는 녀석)은 경계선을 배경색으로 숨김
                if drawn_count == 1 then
                    gfx.set(bg_r, bg_g, bg_b, bg_a)
                else
                    gfx.set(line_r, line_g, line_b, line_a)
                end
                
                gfx.line(current_x, 0, current_x, gfx.h)
                current_x = current_x + w
            end
        end
        
        gfx.update()
        reaper.defer(run)
    end

    local function exit_cleanup()
        local current_dock = gfx.dock(-1)
        
        reaper.SetExtState("JKK_Visualizer", "DockState", tostring(current_dock), true)
    end

reaper.atexit(exit_cleanup)

run()



