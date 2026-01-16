--========================================================
-- @title JKK_Theme
-- @author Junki Kim
-- @noindex
--========================================================

function ApplyTheme(ctx)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_Alpha(),                       1)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_DisabledAlpha(),               0.6)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowPadding(),               8, 8)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowRounding(),              8)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowBorderSize(),            1)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowMinSize(),               32, 32)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowTitleAlign(),            0, 0.5)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ChildRounding(),               12)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ChildBorderSize(),             1)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_PopupRounding(),               8)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_PopupBorderSize(),             1)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FramePadding(),                4, 3)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameRounding(),               12)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameBorderSize(),             0)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ItemSpacing(),                 8, 4)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ItemInnerSpacing(),            4, 4)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_IndentSpacing(),               22)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_CellPadding(),                 0, 2)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ScrollbarSize(),               14)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ScrollbarRounding(),           12)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_GrabMinSize(),                 15)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_GrabRounding(),                12)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ImageBorderSize(),             0)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_TabRounding(),                 6)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_TabBorderSize(),               0)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_TabBarBorderSize(),            1)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_TabBarOverlineSize(),          1)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_TableAngledHeadersAngle(),     0.610865)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_TableAngledHeadersTextAlign(), 0.5, 0)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_TreeLinesSize(),               1)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_TreeLinesRounding(),           12)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ButtonTextAlign(),             0.5, 0.5)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_SelectableTextAlign(),         0, 0)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_SeparatorTextBorderSize(),     2)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_SeparatorTextAlign(),          0, 0.5)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_SeparatorTextPadding(),        20, 3)

    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(),                      0xedededFF) ---
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TextDisabled(),              0x808080FF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_WindowBg(),                  0x252525FF) ---
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ChildBg(),                   0x00000000)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_PopupBg(),                   0x141414F0)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Border(),                    0x505050FF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_BorderShadow(),              0x808080FF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_FrameBg(),                   0x353535FF) ---
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_FrameBgHovered(),            0x454545FF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_FrameBgActive(),             0x555555FF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TitleBg(),                   0x252525FF) ---
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TitleBgActive(),             0x191919FF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TitleBgCollapsed(),          0x00000082)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_MenuBarBg(),                 0x353535FF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ScrollbarBg(),               0x00000000)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ScrollbarGrab(),             0x068FC3FF) ---
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ScrollbarGrabHovered(),      0x49B6CCFF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ScrollbarGrabActive(),       0x053359FF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_CheckMark(),                 0x068FC3FF) ---
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_SliderGrab(),                0x068FC3FF) ---
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_SliderGrabActive(),          0x49B6CCFF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(),                    0x353535FF) ---
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(),             0x454545FF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(),              0x555555FF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Header(),                    0x252525FF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_HeaderHovered(),             0x414141FF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_HeaderActive(),              0x4C4C4CFF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Separator(),                 0x323232FF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_SeparatorHovered(),          0x323232FF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_SeparatorActive(),           0x323232FF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ResizeGrip(),                0x1492B6F1)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ResizeGripHovered(),         0x49B6CCFF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ResizeGripActive(),          0x49B6CCFF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_InputTextCursor(),           0xEFE7DAFF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TabHovered(),                0x555555FF) 
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Tab(),                       0x353535FF) ---
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TabSelected(),               0x068FC3FF) 
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TabSelectedOverline(),       0x555555FF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TabDimmed(),                 0x111A26F8)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TabDimmedSelected(),         0x23436CFF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TabDimmedSelectedOverline(), 0x80808000)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_DockingPreview(),            0x179C80B3)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_DockingEmptyBg(),            0x333333FF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_PlotLines(),                 0x9C9C9CFF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_PlotLinesHovered(),          0xB06C58FF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_PlotHistogram(),             0xB29859FF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_PlotHistogramHovered(),      0x5A9752FF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TableHeaderBg(),             0x252525FF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TableBorderStrong(),         0x4C4C4CFF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TableBorderLight(),          0x414141FF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TableRowBg(),                0x00000000)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TableRowBgAlt(),             0xFFFFFF0F)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TextLink(),                  0xA0A0E6FF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TextSelectedBg(),            0x4296FA59)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TreeLines(),                 0x6E6E8080)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_DragDropTarget(),            0xB29859FF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_NavCursor(),                 0x179C80FF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_NavWindowingHighlight(),     0xFFFFFFB3)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_NavWindowingDimBg(),         0xCCCCCC33)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ModalWindowDimBg(),          0xCCCCCC59)

    return 36, 60
end


return { ApplyTheme = ApplyTheme }
