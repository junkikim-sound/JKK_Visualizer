# JKK_Visualizer
**A Professional Audio Analysis Toolkit for REAPER**

저는 게임 사운드 디자이너 **김준기(Junki Kim)**입니다. 이 스크립트는 REAPER 전용 오디오 시각화 도구입니다. 
저는 전문 프로그래머가 아니라서 오류와 버그의 수정에 자신이 없습니다ㅜㅜ 그래도... 혹시라도 개선사항이 있다면 언제든지 저에게 메일을 보내주세요!

I am **Junki Kim**, a game sound designer. This script is a dedicated audio visualization tool for REAPER. As I am not a professional programmer, I may not be perfect at fixing every error or bug, but I am always open to feedback! If you have any suggestions or improvements, please feel free to email me.

- Contact: junkikim.sound@gmail.com
---

## ⚙️ 1. Installation
ReaImGui must be installed to use JKK_Visualizer.
> ReaImGui is an essential library that allows for modern user interfaces within REAPER. Since this script's UI is entirely built on ReaImGui, it is a required component.
1. **Install [ReaPack](https://reapack.com/)**
   The easiest and safest way to install ReaImGui is through [**ReaPack**](https://reapack.com/). Please refer to [the ReaPack websit](https://reapack.com/) for the installation guide. Once installed, you will see an **Extensions → ReaPack** menu in REAPER's top menu bar.
2. **Install ReaImGui**
    1. Navigate to **Extensions → ReaPack → Browse Packages**.
    2. Search for `ReaImGui`. (If it doesn't appear, follow the guide at [**this site**](https://github.com/cfillion/reaimgui))
    3. Right-click the **ReaImGui / Extensions** package and select **Install**.
    4. Click **Apply** in the bottom right corner.
    5. Restart REAPER after the installation is complete.
3. Verify ReaImGui Installation
    1. Open REAPER’s Action List (Shortcut: `?`).
    2. Search for `ImGui`. If you see a script named **ReaImGui: Demo.lua**, the installation was successful.
4. Import JKK_Visualizer Repository

      <img width="383" height="140" alt="Screenshot 2025-12-30 at 23 00 01" src="https://github.com/user-attachments/assets/3a56e62d-a18f-4477-aaa5-163f6f32048d" />
      
    1. Go to Extensions → ReaPack → Manage repositories.       
    2. Select Import/export... → Import repositories.
    3. Enter the following URL and click OK: 
       > `https://github.com/junkikim-sound/JKK_Visualizer/raw/master/index.xml`
        <img width="490" height="171" alt="Screenshot 2026-01-17 at 16 06 25" src="https://github.com/user-attachments/assets/a01b1d18-7e06-4635-8c12-df5c3fb95ee7" />
    4. Find **JKK_Visualizer** in the package list, right-click to **install**, and click **Apply**.
        <img width="776" height="477" alt="Screenshot 2026-01-17 at 16 06 09" src="https://github.com/user-attachments/assets/b7bc3ceb-e893-4ff8-9f7f-6792095f4317" />
    5. You can now find and run JKK_Visualizer and JKK_Visualizer Editor in your Actions.
        <img width="1269" height="404" alt="Screenshot 2026-01-17 at 16 07 33" src="https://github.com/user-attachments/assets/8d69cccf-43d7-42f7-b6c0-612dcff37e49" />
    6. Add on Master track `JKK_Visualizer`(jsfx file, you can find this in FX window). and Run the Action `JKK_Visualizer`
       <img width="653" height="213" alt="Screenshot 2026-01-22 at 23 43 43" src="https://github.com/user-attachments/assets/9bafe89e-0073-4d46-ade6-843de687d105" />



---
## 🚀 2. Introduction
![Screen Recording 2026-01-17 at 16 08 18_3](https://github.com/user-attachments/assets/908ef485-3651-493e-9ec7-62b69f6dda90)
### Key Features
- **Multi-Module Interface**: Monitor LUFS, Goniometer, Symbiote, Scope, and Spectrum modules simultaneously on a single screen.
- **Dynamic Symbiote**: A unique visualizer that evolves based on low-frequency responses, allowing you to "feel" the sound texture.
- **Customizable Order**: Use the ImGui-based Editor to reorder modules and adjust sensitivity or theme colors in real-time.
- **Global Speed Control**: Manage the Attack/Release response speed of all modules via a single master variable. You can adjust response speed by mouse wheel.

### Technical Details
- Language: Lua 
- Library: REAPER v7.0+ / Dear ImGui 
- Engine: JSFX-to-Lua Data Streaming via gmem 
- Optimization: Optimized for low CPU usage even at a smooth 60FPS

---
## 🌊 About the Author
Junki Kim Game Sound Designer Specializing in game audio implementation and REAPER workflow optimization.
