{ config, lib, pkgs, inputs, myvars, ... }:
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.modules.desktop.noctalia;
in
{
  options.modules.desktop = {
    noctalia = {
      enable = mkEnableOption "Noctalia 桌面壳层（bar、dock、通知、锁屏、启动器）";
    };
  };

  config = mkIf cfg.enable {
    # ── 安装 Noctalia 包 + swayidle（空闲锁屏） ──────────────────────
    environment.systemPackages = with pkgs; [
      inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default
      swayidle # 空闲检测 → 自动锁屏
    ];

    # ── Noctalia 依赖的服务 ─────────────────────────────────────────────
    services.upower.enable = true;

    # ── Home Manager 集成 ────────────────────────────────────────────────
    home-manager.users.${myvars.username} = {
      imports = [
        inputs.noctalia.homeModules.default
      ];

      # ── Niri 配置（直接写 KDL，兼容不支持 programs.niri.settings 的版本）
      # ⚠／存在用户配置时 niri 不会合并默认键位，必须自带完整键位：
      # 终端/关窗/焦点/工作区/退出缺一不可，否则登录后无法操作
      xdg.configFile."niri/config.kdl".text = ''
        spawn-at-startup "noctalia-shell"
        spawn-at-startup "swayidle" "-w" "timeout" "300" "noctalia-shell ipc call lockScreen lock" "before-sleep" "noctalia-shell ipc call lockScreen lock"

        prefer-no-csd

        input {
            keyboard {
                xkb {
                }
            }
            touchpad {
                tap
                natural-scroll
            }
        }

        ${lib.optionalString config.modules.desktop.ai-agent.enable ''
          workspace "AI" {}

          // 类似 Omarchy 的下拉 Agent：独立工作区、顶部浮动、保留会话
          window-rule {
              match app-id=r#"^hao-ai$"#
              open-on-workspace "AI"
              open-floating true
              default-floating-position x=0 y=0 relative-to="top"
              default-window-height { proportion 0.5; }
              default-column-width { proportion 0.8; }
          }
        ''}

        binds {
            // ── 基础 ──
            Mod+Shift+Slash { show-hotkey-overlay; }
            Mod+Return { spawn "kitty"; }
            Mod+T { spawn "kitty"; }
            Mod+Q { close-window; }
            Mod+Shift+E { quit; }

            // ── Noctalia ──
            Mod+Space { spawn "noctalia-shell" "ipc" "call" "launcher" "toggle"; }
            Mod+Alt+L { spawn "noctalia-shell" "ipc" "call" "lockScreen" "lock"; }
            ${lib.optionalString config.modules.desktop.ai-agent.enable ''
              Mod+Shift+Ctrl+A hotkey-overlay-title="AI Agent" { spawn "hao-agent-toggle"; }
            ''}

            // ── 焦点移动 ──
            Mod+Left  { focus-column-left; }
            Mod+Right { focus-column-right; }
            Mod+Up    { focus-window-up; }
            Mod+Down  { focus-window-down; }
            Mod+H { focus-column-left; }
            Mod+L { focus-column-right; }
            Mod+K { focus-window-up; }
            Mod+J { focus-window-down; }

            // ── 窗口移动 ──
            Mod+Shift+Left  { move-column-left; }
            Mod+Shift+Right { move-column-right; }
            Mod+Shift+Up    { move-window-up; }
            Mod+Shift+Down  { move-window-down; }
            Mod+Shift+H { move-column-left; }
            Mod+Shift+L { move-column-right; }
            Mod+Shift+K { move-window-up; }
            Mod+Shift+J { move-window-down; }

            // ── 工作区 ──
            Mod+Page_Up   { focus-workspace-up; }
            Mod+Page_Down { focus-workspace-down; }
            Mod+U { focus-workspace-down; }
            Mod+I { focus-workspace-up; }
            Mod+1 { focus-workspace 1; }
            Mod+2 { focus-workspace 2; }
            Mod+3 { focus-workspace 3; }
            Mod+4 { focus-workspace 4; }
            Mod+5 { focus-workspace 5; }
            Mod+6 { focus-workspace 6; }
            Mod+7 { focus-workspace 7; }
            Mod+8 { focus-workspace 8; }
            Mod+9 { focus-workspace 9; }
            Mod+Shift+1 { move-column-to-workspace 1; }
            Mod+Shift+2 { move-column-to-workspace 2; }
            Mod+Shift+3 { move-column-to-workspace 3; }
            Mod+Shift+4 { move-column-to-workspace 4; }
            Mod+Shift+5 { move-column-to-workspace 5; }
            Mod+Shift+6 { move-column-to-workspace 6; }
            Mod+Shift+7 { move-column-to-workspace 7; }
            Mod+Shift+8 { move-column-to-workspace 8; }
            Mod+Shift+9 { move-column-to-workspace 9; }

            // ── 布局 ──
            Mod+R { switch-preset-column-width; }
            Mod+F { maximize-column; }
            Mod+Shift+F { fullscreen-window; }
            Mod+Minus { set-column-width "-10%"; }
            Mod+Equal { set-column-width "+10%"; }
            Mod+Comma  { consume-window-into-column; }
            Mod+Period { expel-window-from-column; }

            // ── 截图 ──
            Print { screenshot; }
            Ctrl+Print { screenshot-screen; }
            Alt+Print { screenshot-window; }

            // ── 音量 / 亮度（Noctalia OSD） ──
            XF86AudioLowerVolume allow-when-locked=true { spawn "noctalia-shell" "ipc" "call" "volume" "decrease"; }
            XF86AudioRaiseVolume allow-when-locked=true { spawn "noctalia-shell" "ipc" "call" "volume" "increase"; }
            XF86AudioMute        allow-when-locked=true { spawn "noctalia-shell" "ipc" "call" "volume" "muteOutput"; }
            XF86MonBrightnessDown allow-when-locked=true { spawn "noctalia-shell" "ipc" "call" "brightness" "decrease"; }
            XF86MonBrightnessUp   allow-when-locked=true { spawn "noctalia-shell" "ipc" "call" "brightness" "increase"; }
        }
      '';

      programs.noctalia-shell = {
        enable = true;

        settings = {
          bar = {
            position = "top";
            density = "default";
            widgets = {
              left = [
                { id = "Launcher"; }
                { id = "Clock"; }
                { id = "Workspace"; }
              ];
              center = [ ];
              right = [
                { id = "Tray"; }
                { id = "Volume"; }
                { id = "Brightness"; }
                { id = "Battery"; }
                { id = "ControlCenter"; }
              ];
            };
          };

          dock = {
            enabled = true;
            position = "bottom";
            displayMode = "auto_hide";
          };

          general = {
            lockOnSuspend = true;
          };

          colorSchemes = {
            darkMode = true;
            predefinedScheme = "Noctalia (default)";
          };

          wallpaper = {
            enabled = true;
            fillMode = "crop";
          };

          # 性能模式：笔记本省电，台式机全开
          # 通过 hosts/<hostname>/default.nix 直接覆盖 home-manager 的 settings
          noctaliaPerformance = {
            disableWallpaper = lib.mkDefault false;
            disableDesktopWidgets = lib.mkDefault false;
          };
        };
      };
    };
  };
}
