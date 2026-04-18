--========================================================
-- @title JKK_Visualizer
-- @description JKK_Visualizer
-- @author Junki Kim
-- @version 1.2.6
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
local ui_order = {1, 2, 3, 4, 6, 5}

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
    local gr_peak, gg_peak, gb_peak = 255/255, 000/255, 000/255      
        local gonio_peak_hold_time = 2.0  
        local gonio_max_peak_dots = 150   
        local gonio_peaks = {} 
        local phase_smooth = 0

    -- Symbiote Color
    local sym1_r, sym1_g, sym1_b, sym1_a = 006/255, 143/255, 195/255, 0.1
    local sym2_r, sym2_g, sym2_b, sym2_a = 006/255, 143/255, 195/255, 0.8
    local sym3_r, sym3_g, sym3_b, sym3_a = 227/255, 219/255, 142/255, 1.0
        local sym_points = 150       
        local sym_noise_speed = 5.0  
        local sym_size_ratio = 0.3   
        local sym_min_scale = 0.1    
        local sym_max_scale = 1.0    
        local sym_layers = 25        
        local sym_time_accum = 0     
        local s_bass_smooth = 0      
        local s_width_smooth = 0     
        local sym_spikiness = 0      

    -- Scope Color
    local scp1_r, scp1_g, scp1_b, scp1_a = 006/255, 143/255, 195/255, 0.1
    local scp2_r, scp2_g, scp2_b, scp2_a = 006/255, 143/255, 195/255, 0.8
    local scp3_r, scp3_g, scp3_b, scp3_a = 227/255, 219/255, 142/255, 1.0
    local scope_speed = 0.1 

    -- Spectrum & Waterfall Color
    local sptr1_r, sptr1_g, sptr1_b, sptr1_a = 006/255, 143/255, 195/255, 0.1
    local sptr2_r, sptr2_g, sptr2_b, sptr2_a = 006/255, 143/255, 195/255, 0.8
    local sptr3_r, sptr3_g, sptr3_b, sptr3_a = 227/255, 219/255, 142/255, 1.0
    local peak_r, peak_g, peak_b, peak_a     = 180/255, 180/255, 180/255, 1.0
        local peak_hold_time = 0.5  
        local spec_smooth_vals = {}
        local spec_peaks = {} 
        local spec_peak_times = {}
        for i = 1, 4096 do 
            spec_smooth_vals[i] = -144
            spec_peaks[i] = -144 
            spec_peak_times[i] = 0
        end
        
        -- Waterfall 전용 변수
        local waterfall_canvas_id = 1
        local w_cursor_idx = 0
        local w_last_w, w_last_h = 0, 0
        local w_last_col_data = {}
        local w_scan_speed = 12

----------------------------------------------------------
-- Functions: Features (LUFS, Gonio, Symbiote, Scope, Spectrum, Waterfall)
----------------------------------------------------------
    function draw_lufs(x, y, w, h)
        local mom_val = reaper.gmem_read(20)
        local short_val = reaper.gmem_read(21)
        local mom_peak = reaper.gmem_read(22)

        local base_label_size = 15 
        local base_val_size = 35   
        local base_peak_size = 20  

        gfx.set(bg_r, bg_g, bg_b, bg_a)
        gfx.rect(x, y, w, h, 1)
        
        local cx = x + w * 0.5
        local unit_h = h / 2 
        gfx.setfont(1, "Arial", base_label_size * g_font_scale)

        local m_py = y
        gfx.set(text_r, text_g, text_b, text_a)
        local m_lab = "MOMENTARY"
        local lw, lh = gfx.measurestr(m_lab)
        gfx.x, gfx.y = cx - lw * 0.5, m_py + unit_h * 0.15
        gfx.drawstr(m_lab)

        local m_str = (mom_val <= -100) and "- Inf" or string.format("%.1f", mom_val)
        gfx.setfont(2, "Arial", base_val_size * g_font_scale, "b")
        gfx.set(scp2_r, scp2_g, scp2_b, scp2_a)
        local sw, sh = gfx.measurestr(m_str)
        gfx.x, gfx.y = cx - sw * 0.5, m_py + unit_h * 0.35
        gfx.drawstr(m_str)

        gfx.setfont(1, "Arial", base_peak_size * g_font_scale, "b")
        gfx.set(scp3_r, scp3_g, scp3_b, scp3_a )
        local p_str = (mom_peak <= -100) and "- Inf" or string.format("%.1f", mom_peak)
        local pw, ph = gfx.measurestr(p_str)
        gfx.x, gfx.y = cx - pw * 0.5, m_py + unit_h * 0.80
        gfx.drawstr(p_str)

        local s_py = y + unit_h
        gfx.set(line_r, line_g, line_b, line_a)
        gfx.line(x + 10, s_py + 8, x + w - 10, s_py + 8) 

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
        local srate = reaper.gmem_read(1)
        if srate <= 0 then srate = 44100 end
        
        local base_trail = 2000 * (srate / 44100) 
        local trail_len = math.floor(base_trail / (g_signal_release / 2))

        local is_hover = (gfx.mouse_x >= x and gfx.mouse_x <= x + w and
                          gfx.mouse_y >= y and gfx.mouse_y <= y + h)
        if is_hover then
            trail_len = trail_len * 3
        end

        local cx, cy = x + w * 0.5, y + h * 0.45
        local dim_limit = math.min(w, h)
        local guide_size = dim_limit * 0.37
        local dot_size = dim_limit * 0.25 * gain 
        local now = reaper.time_precise()            

        local true_zero_limit = 1.0 
        local visual_limit = guide_size / (2 * dot_size)

        gfx.set(line_r, line_g, line_b, line_a * 3 / 2)
        gfx.line(cx - guide_size, cy - guide_size, cx + guide_size, cy + guide_size)
        gfx.line(cx + guide_size, cy - guide_size, cx - guide_size, cy + guide_size)            

        local write_idx = reaper.gmem_read(0)            

        for i = 0, trail_len, 2 do
            local idx = (write_idx - i - 1) % buf_len
            local l, r = reaper.gmem_read(10000 + idx), reaper.gmem_read(110000 + idx)

            local exp = 0.8
            local l_scaled = (l >= 0 and 1 or -1) * (math.abs(l) ^ exp)
            local r_scaled = (r >= 0 and 1 or -1) * (math.abs(r) ^ exp)

            local peak_intensity = math.max(math.abs(l), math.abs(r))
            
            if peak_intensity >= true_zero_limit and #gonio_peaks < gonio_max_peak_dots then
                local l_p_scaled = (l >= 0 and 1 or -1) * (math.abs(l) ^ exp)
                local r_p_scaled = (r >= 0 and 1 or -1) * (math.abs(r) ^ exp)

                local cl = math.max(-visual_limit, math.min(visual_limit, l_p_scaled))
                local cr = math.max(-visual_limit, math.min(visual_limit, r_p_scaled))
                local px, py = cx + (cr - cl) * dot_size, cy - (cr + cl) * dot_size
                table.insert(gonio_peaks, {px = px, py = py, time = now})
            end

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

            local cl = math.max(-visual_limit, math.min(visual_limit, l_scaled))
            local cr = math.max(-visual_limit, math.min(visual_limit, r_scaled))
            local px, py = cx + (cr - cl) * dot_size, cy - (cr + cl) * dot_size

            gfx.set(gonio_r, gonio_g, gonio_b, (1 - (i / trail_len)))
            gfx.x, gfx.y = px, py
            gfx.setpixel(gonio_r, gonio_g, gonio_b)
        end            

        for i = #gonio_peaks, 1, -1 do
            local p = gonio_peaks[i]
            if (now - p.time) > gonio_peak_hold_time then
                table.remove(gonio_peaks, i)
            else
                gfx.set(gr_peak, gg_peak, gb_peak, 1.0)
                gfx.rect(p.px - 1, p.py - 1, 2, 2) 
            end
        end

        local idx = (write_idx - 1) % buf_len
        local l = reaper.gmem_read(10000 + idx)
        local r = reaper.gmem_read(110000 + idx)

        local dot_product = l * r
        local mag_l = l * l
        local mag_r = r * r
        local denom = math.sqrt(mag_l * mag_r)            

        local current_phase = 0
        if denom > 0.000001 then current_phase = dot_product / denom end

        phase_smooth = phase_smooth + (current_phase - phase_smooth) * 0.1            

        local bar_h = 4
        local bar_w = w * 0.6
        local bar_x = x + (w - bar_w) * 0.5
        local bar_y = y + h - 15 

        gfx.set(line_r, line_g, line_b, line_a)
        gfx.rect(bar_x, bar_y, bar_w, bar_h, 0)
        gfx.line(bar_x + bar_w * 0.5, bar_y - 2, bar_x + bar_w * 0.5, bar_y + bar_h + 2)            

        local indicator_x = bar_x + (bar_w * 0.5) + (phase_smooth * (bar_w * 0.5))

        if phase_smooth >= 0 then
            gfx.set(dot2_r, dot2_g, dot2_b, 0.8) 
        else
            gfx.set(1, 0, 0, 0.8) 
        end            

        gfx.rect(indicator_x - 1, bar_y - 2, 3, bar_h + 4, 1)

        gfx.setfont(1, "Arial", (base_title_size - 4) * g_font_scale) 
        local label_padding = 5 

        local tw_minus, th_minus = gfx.measurestr("-1")
        gfx.x = bar_x - tw_minus - label_padding
        gfx.y = bar_y + (bar_h * 1) - (th_minus * 0.5)
        gfx.drawstr("-1")

        local tw_plus, th_plus = gfx.measurestr("+1")
        gfx.x = bar_x + bar_w + label_padding
        gfx.y = bar_y + (bar_h * 1) - (th_plus * 0.5)
        gfx.drawstr("+1")

        gfx.set(line_r, line_g, line_b, line_a)
        gfx.setfont(1, "Arial", base_title_size * g_font_scale)
        gfx.x, gfx.y = x + 5, y + 5
        gfx.drawstr("Gonio")
    end

    function draw_symbiote(x, y, w, h, gain)
        local base_attack = 0.3
        local base_release = 0.3

        local sym_base_radius = math.min(w, h) * 0.45 * sym_size_ratio
        local fixed_cx, fixed_cy = x + w * 0.5, y + h * 0.5
        
        local time = reaper.time_precise()
        local drift_radius = 10.0 
        local drift_speed = 0.7   
        
        local drift_x = math.sin(time * drift_speed) * drift_radius 
                      + math.cos(time * drift_speed * 1.3) * (drift_radius * 0.5)
        local drift_y = math.cos(time * drift_speed * 0.8) * drift_radius 
                      + math.sin(time * drift_speed * 1.7) * (drift_radius * 0.5)

        local cx, cy = fixed_cx + drift_x, fixed_cy + drift_y
        
        local write_idx = reaper.gmem_read(0)
        local idx = (write_idx - 1) % buf_len
        local l = reaper.gmem_read(10000 + idx)
        local r = reaper.gmem_read(110000 + idx)
        
        local target_vol = (math.abs(l) + math.abs(r)) * 0.5 * gain
        local target_width = math.abs(l - r) * gain
        s_width_smooth = s_width_smooth + (target_width - s_width_smooth) * 0.1

        local bass_sum = 0
        for k = 2, 16 do 
            bass_sum = bass_sum + reaper.gmem_read(300000 + k)
        end
        local current_bass = (bass_sum / 16) * gain * 0.032
        local size_attack = base_attack * g_signal_attack
        local size_release = base_release * g_signal_release
        
        local smoothing = (current_bass > s_bass_smooth) and size_attack or size_release
        s_bass_smooth = s_bass_smooth + (current_bass - s_bass_smooth) * smoothing
        
        local spike_raw = 0
        if current_bass > 1.7 then spike_raw = (current_bass - 0.25) * 2 end
        spike_raw = math.min(0.5, spike_raw)

        local spike_attack = size_attack * 1.5 
        local spike_release = size_release * 1.0

        local spike_smoothing = (spike_raw > sym_spikiness) and spike_attack or spike_release
        sym_spikiness = sym_spikiness + (spike_raw - sym_spikiness) * math.min(1.0, spike_smoothing)

        local cur_time = reaper.time_precise()
        if not last_time then last_time = cur_time end
        sym_time_accum = sym_time_accum + (cur_time - last_time) * (0.3 + target_vol * 12.0)
        last_time = cur_time

        local max_allowed_r = (math.min(w, h) * 0.5) - 5
        local raw_r_dyn = sym_base_radius * (1 + s_bass_smooth * 0.5)
        local clamped_r = math.min(max_allowed_r * 0.8, raw_r_dyn)
        clamped_r = math.max(sym_base_radius * sym_min_scale, clamped_r)

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
            
            local abs_dx = dx + drift_x
            local abs_dy = dy + drift_y
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
        
        local srate = reaper.gmem_read(1)
        if srate <= 0 then srate = 44100 end
        local scope_speed_scaled = scope_speed * (srate / 44100)
        local step = (buf_len / w) * scope_speed_scaled

        local is_hover = (gfx.mouse_x >= x and gfx.mouse_x <= x + w and 
                      gfx.mouse_y >= y and gfx.mouse_y <= y + h)
        
        if is_hover then
            step = (buf_len / w) * 0.3 * (srate / 44100)
        end
        local scan_stride = 2 

        for m = 0, w - 1 do
            local start_pos = (write_idx - (w - m) * step)
            
            local max_v = -100 
            local min_v = 100  
            local abs_peak = 0 
            
            for s = 0, step - 1, scan_stride do
                local read_ptr = math.floor(start_pos + s) % buf_len
                local raw_val = reaper.gmem_read(10000 + read_ptr) 
                
                if raw_val > max_v then max_v = raw_val end
                if raw_val < min_v then min_v = raw_val end
                
                local abs_v = math.abs(raw_val)
                if abs_v > abs_peak then abs_peak = abs_v end
            end
            
            local draw_max = max_v * zoom * 0.5
            local draw_min = min_v * zoom * 0.5
            
            local y_top = cy - (draw_max * h)
            local y_bottom = cy - (draw_min * h)
            
            y_top = math.max(y, math.min(y + h, y_top))
            y_bottom = math.max(y, math.min(y + h, y_bottom))
            
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

            if math.abs(y_bottom - y_top) < 1 then
                gfx.rect(x + m, y_top, 1, 1)
            else
                gfx.line(x + m, y_top, x + m, y_bottom)
            end
        end
        
        gfx.set(line_r, line_g, line_b, line_a)
        gfx.x, gfx.y = x + 5, y + 5
        gfx.drawstr("Scope")
    end

    local function freq_to_note(freq)
        if freq <= 0 then return "N/A" end
        local n = 12 * (math.log(freq / 440, 2)) + 69
        local midi_int = math.floor(n + 0.5)
        local names = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"}
        local note_idx = (midi_int % 12) + 1
        local octave = math.floor(midi_int / 12) - 1
        return names[note_idx] .. octave
    end

    function draw_spectrum(x, y, w, h, ceil, floor)
        local base_area_decay = 2.0 
        local base_peak_decay = 1.0 
        local area_decay_rate = base_area_decay * g_signal_release
        local peak_decay_rate = base_peak_decay * g_signal_release
        
        local is_hover = (gfx.mouse_x >= x and gfx.mouse_x <= x + w and 
                      gfx.mouse_y >= y and gfx.mouse_y <= y + h)
        local is_user_frozen = is_hover and (gfx.mouse_cap & 1 == 1)
        local is_frozen = is_user_frozen or g_is_standby
        if is_hover and not is_frozen then
            area_decay_rate = 1.0 * g_signal_release
        end

        local range = ceil - floor
        local srate = reaper.gmem_read(1)
        if srate == 0 then srate = 48000 end
        local now = reaper.time_precise()
        local target_max_hz = 48000
        local max_k = target_max_hz * fft_size / srate
        local k_max_log = math.log(max_k)
        
        gfx.set(line_r, line_g, line_b, line_a)
        
        local ox, oy = x, y + h
        local pox, poy = x, y + h
        local k = 1
        while k <= max_k do
            local k_int = math.floor(k)
            local k_frac = k - k_int
            
            local k_idx = math.floor(k * 10)
            
            local mag1 = reaper.gmem_read(300000 + k_int)
            local mag2 = reaper.gmem_read(300000 + k_int + 1)
            local mag = mag1 + (mag2 - mag1) * k_frac

            local pure_db = 20 * math.log(mag + 0.0000001, 10)
            local raw_db = pure_db - spec_offset
            if pure_db < -120 then 
                raw_db = floor - 10 
            end

            local db = raw_db

            local smooth_db = spec_smooth_vals[k_idx] or (floor - 10)
            
            if not is_frozen then 
                if raw_db >= smooth_db then
                    local attack_coef = math.min(1.0, 0.8 * g_signal_attack) 
                    smooth_db = smooth_db + (raw_db - smooth_db) * attack_coef
                else
                    smooth_db = smooth_db - area_decay_rate
                end
                spec_smooth_vals[k_idx] = smooth_db
            end

            local current_peak = spec_peaks[k_idx] or -144
            local last_time = spec_peak_times[k_idx] or 0
            
            if not is_frozen then 
                if db >= current_peak then
                    spec_peaks[k_idx] = db
                    spec_peak_times[k_idx] = now
                else
                    if (now - last_time) > peak_hold_time then
                        spec_peaks[k_idx] = current_peak - peak_decay_rate
                    end
                end
            end
            local peak_db = spec_peaks[k_idx]

            local t_raw = (smooth_db - floor) / range
            t_raw = math.max(0, math.min(1, t_raw))
            local t = t_raw ^ 1.5 
            
            local dy = y + h - (t * h)
            
            local pt_raw = (peak_db - floor) / range
            local pt = math.max(0, math.min(1, pt_raw)) ^ 1.5
            local pdy = y + h - (pt * h)

            local x_norm = math.log(k) / k_max_log
            local dx = x + (x_norm * w)
            
            if t < midpoint then
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
            
            gfx.set(peak_r, peak_g, peak_b, peak_a)
            if k > 1 then
                gfx.line(pox, poy, dx, pdy)
            end
            
            ox, oy = dx, dy
            pox, poy = dx, pdy
            
            local step = 1
            if k <= 200 then
                step = 0.2
            else
                step = k * 0.005
            end
            k = k + step
        end
        
        gfx.set(line_r, line_g, line_b, line_a)
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
        
        if gfx.mouse_x >= x and gfx.mouse_x <= x + w and gfx.mouse_y >= y and gfx.mouse_y <= y + h then
            local x_norm = (gfx.mouse_x - x) / w
            local k_val = math.exp(x_norm * k_max_log)
            local hz = k_val * srate / fft_size
            
            local note = freq_to_note(hz)
            local info_text = string.format("%.0f Hz (%s)", hz, note)
            
            gfx.setfont(1, "Arial", (base_title_size) * g_font_scale)
            local tw, th = gfx.measurestr(info_text)
            local tx, ty = gfx.mouse_x + 10, gfx.mouse_y - 20
            
            if tx + tw > gfx.w then tx = gfx.mouse_x - tw - 10 end
            if ty < 0 then ty = gfx.mouse_y + 20 end
            
            gfx.set(bg_r, bg_g, bg_b, 0.9) 
            gfx.rect(tx - 4, ty - 2, tw + 8, th + 4, 1)
            
            gfx.set(line_r, line_g, line_b, 0.5)
            gfx.rect(tx - 4, ty - 2, tw + 8, th + 4, 0)

            gfx.set(1, 1, 1, 1) 
            gfx.x, gfx.y = tx, ty
            gfx.drawstr(info_text)
            
            gfx.set(line_r, line_g, line_b, 0.3)
            gfx.line(gfx.mouse_x, y, gfx.mouse_x, y + h)
            
            gfx.setfont(1, "Arial", base_title_size * g_font_scale)
        end

        gfx.set(line_r, line_g, line_b, line_a)
        gfx.x, gfx.y = x + 5, y + 5
        gfx.drawstr("Spectrum")

        if is_user_frozen then
            gfx.set(227/255, 219/255, 142/255, 1.0)
            local fw, fh = gfx.measurestr("FREEZE")
            gfx.x, gfx.y = x + w - fw - 5, y + 5
            gfx.drawstr("FREEZE")
        end
    end

    function draw_spectrogram(x, y, w, h, gain, floor_db)
        local is_hover = (gfx.mouse_x >= x and gfx.mouse_x <= x + w and 
                          gfx.mouse_y >= y and gfx.mouse_y <= y + h)
        local is_user_frozen = is_hover and (gfx.mouse_cap & 1 == 1)
        local is_frozen = is_user_frozen or g_is_standby

        local current_scan_speed = w_scan_speed
        if is_hover and not is_frozen then
            current_scan_speed = math.max(1, math.floor(w_scan_speed * 0.25)) 
        end

        if w ~= w_last_w or h ~= w_last_h then
            gfx.dest = waterfall_canvas_id
            gfx.setimgdim(waterfall_canvas_id, -1, -1)
            gfx.setimgdim(waterfall_canvas_id, w, h)
            gfx.set(bg_r, bg_g, bg_b, 1) 
            gfx.rect(0, 0, w, h, 1)
            w_last_w, w_last_h = w, h
            w_last_col_data = {}
            w_cursor_idx = 0
        end

        local RES_W = math.floor(w) * 2
        local RES_H = math.floor(h)
        if RES_H < 10 then RES_H = 10 end
        local block_w = w / RES_W
        local block_h = h / RES_H
        local scale_exponent = 3.0 

        local srate = reaper.gmem_read(1)
        if srate <= 0 then srate = 48000 end
        local min_hz = 50
        local min_bin = min_hz * fft_size / srate
        local num_bins = fft_size / 2
        local bin_range = num_bins - min_bin

        local val_threshold = 1.0
        local val_gain = 0.25
        local thresh_db = -100 + (val_threshold * 80)
        local gain_boost = val_gain * 60

        if not is_frozen then
            local col_data = {}
            for y_px = 0, RES_H - 1 do
                local norm_y = (RES_H - 1 - y_px) / RES_H
                local idx_float = min_bin + (bin_range * (norm_y ^ scale_exponent))
                local i1 = math.floor(idx_float)
                local t = idx_float - i1
                local i2 = math.min(num_bins - 1, i1 + 1)
                
                local p1 = reaper.gmem_read(300000 + i1)
                local p2 = reaper.gmem_read(300000 + i2)
                
                local raw = p1 + (p2 - p1) * t
                if raw < 1e-10 then raw = 1e-10 end
                col_data[y_px] = 20 * math.log(raw, 10)
            end

            if w_last_col_data[0] == nil then 
                w_last_col_data = col_data 
            end

            gfx.dest = waterfall_canvas_id
            for s = 0, current_scan_speed - 1 do
                local current_idx = (w_cursor_idx + s) % RES_W
                local screen_x = current_idx * block_w
                local horiz_t = s / current_scan_speed
                
                gfx.set(bg_r, bg_g, bg_b, 1)
                gfx.rect(screen_x, 0, block_w + 1, h, 1)

                for y_px = 0, RES_H - 1 do
                    local prev_db = w_last_col_data[y_px] or col_data[y_px]
                    local interp_db = prev_db * (1 - horiz_t) + col_data[y_px] * horiz_t
                    
                    if interp_db >= thresh_db then
                        local effective_db = (interp_db - thresh_db) + gain_boost
                        local intensity = effective_db / 60.0
                        if intensity > 0.05 then
                            if intensity > 1 then intensity = 1 end
                            local c_r, c_g, c_b, c_a
                            local w_sptr2_a = sptr2_a * 0.7
                            if intensity < 0.5 then
                                local t_c = intensity * 2.0
                                c_r = sptr1_r + (sptr2_r - sptr1_r) * t_c
                                c_g = sptr1_g + (sptr2_g - sptr1_g) * t_c
                                c_b = sptr1_b + (sptr2_b - sptr1_b) * t_c
                                c_a = sptr1_a + (w_sptr2_a - sptr1_a) * t_c
                            else
                                local t_c = (intensity - 0.5) * 2.0
                                c_r = sptr2_r + (sptr3_r - sptr2_r) * t_c
                                c_g = sptr2_g + (sptr3_g - sptr2_g) * t_c
                                c_b = sptr2_b + (sptr3_b - sptr2_b) * t_c
                                c_a = w_sptr2_a + (sptr3_a - w_sptr2_a) * t_c
                            end
                            gfx.set(c_r, c_g, c_b, c_a)
                            gfx.rect(screen_x, y_px * block_h, block_w + 0.5, block_h + 0.1, 1)
                        end
                    end
                end
            end
            w_last_col_data = col_data
        end

        gfx.dest = -1
        gfx.set(1, 1, 1, 1)
        
        local advance = is_frozen and 0 or current_scan_speed
        local split_x = (w_cursor_idx + advance) * block_w
        
        gfx.blit(waterfall_canvas_id, 1, 0, split_x, 0, w - split_x, h, x, y, w - split_x, h)
        gfx.blit(waterfall_canvas_id, 1, 0, 0, 0, split_x, h, x + w - split_x, y, split_x, h)

        local function draw_freq_line(hz_val, label_text)
            local target_bin = hz_val * fft_size / srate
            if target_bin < min_bin then return end
            local norm_y = ((target_bin - min_bin) / bin_range) ^ (1 / scale_exponent)
            local line_y = y + (1 - norm_y) * h
            
            gfx.set(line_r, line_g, line_b, line_a / 2) 
            gfx.line(x, line_y, x + w, line_y)
            
            gfx.set(text_r, text_g, text_b, text_a / 3)
            gfx.x = x + 5; gfx.y = line_y - 12
            gfx.drawstr(label_text)
        end
        
        draw_freq_line(10000, "10k")
        draw_freq_line(1000, "1k")
        draw_freq_line(100, "100")

        if is_hover then
            local norm_y = 1 - ((gfx.mouse_y - y) / h)
            local idx_float = min_bin + (bin_range * (norm_y ^ scale_exponent))
            local hz = idx_float * srate / fft_size
            local note = freq_to_note(hz)
            local info_text = string.format("%.0f Hz (%s)", hz, note)
            
            gfx.setfont(1, "Arial", base_title_size * g_font_scale)
            local tw, th = gfx.measurestr(info_text)
            local tx, ty = gfx.mouse_x + 10, gfx.mouse_y - 20
            if tx + tw > gfx.w then tx = gfx.mouse_x - tw - 10 end
            if ty < 0 then ty = gfx.mouse_y + 20 end
            
            gfx.set(bg_r, bg_g, bg_b, 0.9) 
            gfx.rect(tx - 4, ty - 2, tw + 8, th + 4, 1)
            gfx.set(line_r, line_g, line_b, 0.5)
            gfx.rect(tx - 4, ty - 2, tw + 8, th + 4, 0)

            gfx.set(text_r, text_g, text_b, text_a)
            gfx.x, gfx.y = tx, ty
            gfx.drawstr(info_text)
            
            gfx.set(line_r, line_g, line_b, 0.3)
            gfx.line(x, gfx.mouse_y, x + w, gfx.mouse_y)
        end

        gfx.set(line_r, line_g, line_b, line_a)
        gfx.x, gfx.y = x + 5, y + 5
        gfx.drawstr("Spectrogram")

        if is_user_frozen then
            gfx.set(peak_r, peak_g, peak_b, peak_a)
            local fw, fh = gfx.measurestr("FREEZE")
            gfx.x, gfx.y = x + w - fw - 5, y + 5
            gfx.drawstr("FREEZE")
        elseif not is_frozen then
            w_cursor_idx = (w_cursor_idx + current_scan_speed) % RES_W
        end
    end

----------------------------------------------------------
-- Functions: Color Setting
----------------------------------------------------------
    local MEM_BG    = 1000
    local MEM_LINE  = 1010
    local MEM_TEXT  = 1020
    local MEM_ZERO  = 1030
    local MEM_MID   = 1040
    local MEM_PEAK  = 1050

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

    function init_default_colors()
        reaper.gmem_write(1000, 030/255); reaper.gmem_write(1001, 030/255); reaper.gmem_write(1002, 030/255); reaper.gmem_write(1003, 1.0) 
        reaper.gmem_write(1010, 200/255); reaper.gmem_write(1011, 200/255); reaper.gmem_write(1012, 200/255); reaper.gmem_write(1013, 0.3) 
        reaper.gmem_write(1020, 180/255); reaper.gmem_write(1021, 180/255); reaper.gmem_write(1022, 180/255); reaper.gmem_write(1023, 1.0) 

        reaper.gmem_write(1030, 006/255); reaper.gmem_write(1031, 143/255); reaper.gmem_write(1032, 195/255); reaper.gmem_write(1033, 0.1) 
        reaper.gmem_write(1040, 006/255); reaper.gmem_write(1041, 143/255); reaper.gmem_write(1042, 195/255); reaper.gmem_write(1043, 0.8) 
        reaper.gmem_write(1050, 227/255); reaper.gmem_write(1051, 219/255); reaper.gmem_write(1052, 142/255); reaper.gmem_write(1053, 1.0) 
        reaper.gmem_write(1060, 180/255); reaper.gmem_write(1061, 180/255); reaper.gmem_write(1062, 180/255); reaper.gmem_write(1063, 1.0) 

        reaper.gmem_write(2, 0.5) 
        reaper.gmem_write(6, 0.5) 
        reaper.gmem_write(7, 0.5) 
        reaper.gmem_write(8, 0.5) 
        reaper.gmem_write(9, 0.5) -- Waterfall Default
        reaper.gmem_write(1300, 1.0) 
        reaper.gmem_write(4, 1.0) 
        reaper.gmem_write(5, 1.0)
        
        for i=1, 6 do reaper.gmem_write(1100 + i, i) end
    end

    function update_settings_from_gmem()
        if reaper.gmem_read(1003) == 0 then
            LoadSettingsFromExtState()
            if reaper.gmem_read(1003) == 0 then
                init_default_colors()
            end
        end
            local att = reaper.gmem_read(4)
            local rel = reaper.gmem_read(5)
            if att > 0 then g_signal_attack = att else g_signal_attack = 1.0 end
            if rel > 0 then g_signal_release = rel else g_signal_release = 1.0 end

        if reaper.gmem_read(1100) > 0 then
            reaper.gmem_write(1100, 0)
        end
        if reaper.gmem_read(1000 + 3) == 0 then return end

            bg_r = reaper.gmem_read(1000); bg_g = reaper.gmem_read(1001); bg_b = reaper.gmem_read(1002); bg_a = reaper.gmem_read(1003)
            line_r = reaper.gmem_read(1010); line_g = reaper.gmem_read(1011); line_b = reaper.gmem_read(1012); line_a = reaper.gmem_read(1013)
            text_r = reaper.gmem_read(1020); text_g = reaper.gmem_read(1021); text_b = reaper.gmem_read(1022); text_a = reaper.gmem_read(1023)

            local c1_r = reaper.gmem_read(1030); local c1_g = reaper.gmem_read(1031); local c1_b = reaper.gmem_read(1032); local c1_a = reaper.gmem_read(1033)
            local c2_r = reaper.gmem_read(1040); local c2_g = reaper.gmem_read(1041); local c2_b = reaper.gmem_read(1042); local c2_a = reaper.gmem_read(1043)
            local c3_r = reaper.gmem_read(1050); local c3_g = reaper.gmem_read(1051); local c3_b = reaper.gmem_read(1052); local c3_a = reaper.gmem_read(1053)
            local c4_r = reaper.gmem_read(1060); local c4_g = reaper.gmem_read(1061); local c4_b = reaper.gmem_read(1062); local c4_a = reaper.gmem_read(1063)

            dot1_r, dot1_g, dot1_b, dot1_a = c1_r, c1_g, c1_b, c1_a
            dot2_r, dot2_g, dot2_b, dot2_a = c2_r, c2_g, c2_b, c2_a
            dot3_r, dot3_g, dot3_b, dot3_a = c3_r, c3_g, c3_b, c3_a
            gr_peak, gg_peak, gb_peak      = c3_r, c3_g, c3_b 

            sym1_r, sym1_g, sym1_b, sym1_a = c1_r, c1_g, c1_b, c1_a
            sym2_r, sym2_g, sym2_b, sym2_a = c2_r, c2_g, c2_b, c2_a
            sym3_r, sym3_g, sym3_b, sym3_a = c3_r, c3_g, c3_b, c3_a

            scp1_r, scp1_g, scp1_b, scp1_a = c1_r, c1_g, c1_b, c1_a
            scp2_r, scp2_g, scp2_b, scp2_a = c2_r, c2_g, c2_b, c2_a
            scp3_r, scp3_g, scp3_b, scp3_a = c3_r, c3_g, c3_b, c3_a

            sptr1_r, sptr1_g, sptr1_b, sptr1_a = c1_r, c1_g, c1_b, c1_a
            sptr2_r, sptr2_g, sptr2_b, sptr2_a = c2_r, c2_g, c2_b, c2_a
            sptr3_r, sptr3_g, sptr3_b, sptr3_a = c3_r, c3_g, c3_b, c3_a
            peak_r, peak_g, peak_b, peak_a = c4_r, c4_g, c4_b, c4_a

            for i=1, 6 do
                local order_val = reaper.gmem_read(1100 + i)
                if order_val > 0 then ui_order[i] = order_val end
            end

            local scale_val = reaper.gmem_read(1300)
            if scale_val > 0 then 
                g_font_scale = scale_val 
            else
                g_font_scale = 1.0
            end
    end

    local function Initialize_System()
        local function load_color(mem_idx, ext_key)
            if reaper.HasExtState(SECTION, "MEM_"..mem_idx) then
                reaper.gmem_write(mem_idx, tonumber(reaper.GetExtState(SECTION, "MEM_"..mem_idx)))
                return true
            end
            return false
        end

        local loaded = load_color(1000, "MEM_1000")
        if reaper.gmem_read(1003) == 0 then
            reaper.gmem_write(2, 0.5) 
            reaper.gmem_write(4, 1.0) 
            reaper.gmem_write(5, 1.0) 
            reaper.gmem_write(1300, 1.0) 
        end

        if reaper.HasExtState(SECTION, "ModuleOrder") then
            local order_str = reaper.GetExtState(SECTION, "ModuleOrder")
            local idx = 1
            for val in string.gmatch(order_str, '([^,]+)') do
                reaper.gmem_write(1100 + idx, tonumber(val))
                idx = idx + 1
            end
        else
            for i=1, 6 do reaper.gmem_write(1100 + i, i) end
        end

        if reaper.HasExtState(SECTION, "ModuleActive") then
            local active_str = reaper.GetExtState(SECTION, "ModuleActive")
            local idx = 1
            for val in string.gmatch(active_str, '([^,]+)') do
                reaper.gmem_write(1150 + idx, (val == "1" and 1 or 0))
                idx = idx + 1
            end
        else
            for i=1, 6 do reaper.gmem_write(1150 + i, 1) end
        end
    end
    Initialize_System()

----------------------------------------------------------
-- UI Loops
----------------------------------------------------------
    local last_signal_time = reaper.time_precise()
    local g_is_standby = false
    local target_fps = 45
    local frame_interval = 1.0 / target_fps
    local last_frame_time = reaper.time_precise()

    function run()
        local char = gfx.getchar()
        if char == 27 then return end 
        if char == 32 then
            reaper.Main_OnCommand(40044, 0) 
        end

        local current_time = reaper.time_precise()
        if (current_time - last_frame_time) < frame_interval then
            reaper.defer(run)
            return
        end
        last_frame_time = current_time

        update_settings_from_gmem()

        if gfx.mouse_cap == 2 then 
            gfx.x, gfx.y = gfx.mouse_x, gfx.mouse_y
            
            local current_dock_state = gfx.dock(-1) 
            local is_docked = current_dock_state > 0
            
            local menu_str = (is_docked and "!" or "") .. "Dock to Docker|"
            menu_str = menu_str .. "#For editing theme, run 'JKK_Visualizer Editor' from Action List"
            
            local selection = gfx.showmenu(menu_str)
            
            if selection == 1 then
                if is_docked then gfx.dock(0) else gfx.dock(513) end
            end
        end

        local wheel_val = gfx.mouse_wheel
        gfx.mouse_wheel = 0

        if wheel_val ~= 0 and gfx.mouse_y < 30 then
            local sensitivity = 0.02
            local change = (wheel_val / 120) * sensitivity 
            if math.abs(change) < 0.01 then change = (wheel_val > 0) and 0.02 or -0.02 end
            
            local target_gmems = {2, 6, 7, 8, 9}
            for _, mem in ipairs(target_gmems) do
                local current_gain = reaper.gmem_read(mem)
                current_gain = math.max(0.0, math.min(1.0, current_gain + change))
                reaper.gmem_write(mem, current_gain)
            end
        end

        local current_time = reaper.time_precise()
        local mom_val = reaper.gmem_read(20)
        local is_mouse_in = (gfx.mouse_x >= 0 and gfx.mouse_x <= gfx.w and gfx.mouse_y >= 0 and gfx.mouse_y <= gfx.h)
        
        if mom_val > -100 or is_mouse_in then
            last_signal_time = current_time
        end
        
        g_is_standby = (current_time - last_signal_time) > 2.0

        if g_is_standby and reaper.GetPlayState() == 0 then
            
            gfx.update()
            reaper.defer(run)
            return 
        end

        gfx.set(bg_r, bg_g, bg_b, bg_a)
        gfx.rect(0, 0, gfx.w, gfx.h)

        -- 6개 모듈의 기본 가로 비율
        local module_widths = {
            [1] = 0.10, [2] = 0.12, [3] = 0.12, [4] = 0.12, [5] = 0.39, [6] = 0.15
        }

        local total_active_ratio = 0
        local active_count = 0
        
        for i = 1, 6 do
            local mod_id = ui_order[i]
            if reaper.gmem_read(1150 + mod_id) == 1 then
                total_active_ratio = total_active_ratio + module_widths[mod_id]
                active_count = active_count + 1
            end
        end

        if total_active_ratio == 0 then total_active_ratio = 1 end

        local current_x = 0
        local drawn_count = 0
        local s2 = reaper.gmem_read(3) 

        for i = 1, 6 do
            local mod_id = ui_order[i]
            local is_active = (reaper.gmem_read(1150 + mod_id) == 1)

            if is_active then
                drawn_count = drawn_count + 1
                
                local ratio = module_widths[mod_id] / total_active_ratio
                local w = math.floor(gfx.w * ratio)
                if drawn_count == active_count then w = gfx.w - current_x end

                if wheel_val ~= 0 and gfx.mouse_y >= 30 and gfx.mouse_x >= current_x and gfx.mouse_x <= current_x + w and gfx.mouse_y <= gfx.h then
                    local target_gmem = nil
                    if mod_id == 2 then target_gmem = 2 
                    elseif mod_id == 3 then target_gmem = 6 
                    elseif mod_id == 4 then target_gmem = 7 
                    elseif mod_id == 5 then target_gmem = 8 
                    elseif mod_id == 6 then target_gmem = 9
                    end

                    if target_gmem then
                        local current_gain = reaper.gmem_read(target_gmem)
                        local sensitivity = 0.02
                        local change = (wheel_val / 120) * sensitivity 
                        if math.abs(change) < 0.01 then change = (wheel_val > 0) and 0.02 or -0.02 end
                        
                        current_gain = math.max(0.0, math.min(1.0, current_gain + change))
                        reaper.gmem_write(target_gmem, current_gain)
                    end
                end

                local mod_raw_gain = 0.5
                if mod_id == 2 then mod_raw_gain = reaper.gmem_read(2)
                elseif mod_id == 3 then mod_raw_gain = reaper.gmem_read(6)
                elseif mod_id == 4 then mod_raw_gain = reaper.gmem_read(7)
                elseif mod_id == 5 then mod_raw_gain = reaper.gmem_read(8)
                elseif mod_id == 6 then mod_raw_gain = reaper.gmem_read(9)
                end

                local specific_gain = g_gain_min + (g_gain_max - g_gain_min) * mod_raw_gain
                local specific_zoom = s_zoom_min + (s_zoom_max - s_zoom_min) * mod_raw_gain
                local specific_ceil = spec_ceil_min + (spec_ceil_max - spec_ceil_min) * mod_raw_gain
                local floor = spec_floor_min + (spec_floor_max - spec_floor_min) * s2
 
                if mod_id == 1 then draw_lufs(current_x, 0, w, gfx.h)
                elseif mod_id == 2 then draw_gonio(current_x, 0, w, gfx.h, specific_gain)
                elseif mod_id == 3 then draw_symbiote(current_x, 0, w, gfx.h, specific_gain)
                elseif mod_id == 4 then draw_scope(current_x, 0, w, gfx.h, specific_zoom)
                elseif mod_id == 5 then draw_spectrum(current_x, 0, w, gfx.h, specific_ceil, floor)
                elseif mod_id == 6 then draw_spectrogram(current_x, 0, w, gfx.h, mod_raw_gain, floor)
                end
                
                if drawn_count == 1 then gfx.set(bg_r, bg_g, bg_b, bg_a) else gfx.set(line_r, line_g, line_b, line_a) end
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
