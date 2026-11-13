{ config, lib, pkgs, inputs, myvars, ... }:
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.modules.desktop.noctalia;
  system = pkgs.stdenv.hostPlatform.system;
  # Qt 6.12 MOC fix from https://github.com/quickshell-mirror/quickshell/commit/5d5d49873fe8cf1f99ddfd5006ceb2057c5c9b13, adjusted for locked noctalia-qs f308426.
  quickshellQt612 = inputs.noctalia.inputs.noctalia-qs.packages.${system}.default.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ../../../qt612-f308426.patch ];
  });
  # 与运行时验证过的 fork 保持一致：Noctalia 的 `Color` 单例在 Qt 6.12 /
  # Quickshell 下会与类型解析冲突，统一重命名为 `HaoColor`（含所有引用）。
  noctaliaShellQt612 = (inputs.noctalia.packages.${system}.default.override {
    quickshell = quickshellQt612;
  }).overrideAttrs (old: {
    installPhase = (old.installPhase or "") + ''
      shellDir="$out/share/noctalia-shell"
      mv "$shellDir/Commons/Color.qml" "$shellDir/Commons/HaoColor.qml"
      find "$shellDir" -type f -name '*.qml' -exec sed -i \
        -e 's/\bColor\./HaoColor./g' \
        -e 's/target: Color\b/target: HaoColor/g' {} +
    '';
  });
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
      noctaliaShellQt612
      swayidle # 空闲检测 → 自动锁屏
      tmux # HAO AI 面板的持久会话（收起面板不丢 agent）
    ];

    # ── Noctalia 依赖的服务 ─────────────────────────────────────────────
    services.upower.enable = true;

    # ── 登录界面（ReGreet）对齐 Noctalia 锁屏 ──────────────────────────
    # 背景复用 Noctalia 的壁纸；配色/圆角取自 Noctalia 默认方案
    # （mSurface/mPrimary/mOutline），让登录页与锁屏观感一致。
    services.displayManager.regreet = {
      theme = {
        name = "adw-gtk3-dark";
        package = pkgs.adw-gtk3;
      };
      font = {
        name = "Noto Sans CJK SC";
        size = 15;
      };
      settings = {
        background = {
          path = "${noctaliaShellQt612}/share/noctalia-shell/Assets/Wallpaper/noctalia.png";
          fit = "Cover";
        };
        GTK.application_prefer_dark_theme = true;
      };
      extraCss = ''
        /* Noctalia 锁屏配色：surface #070722 / primary #fff59b / outline #21215F */
        window { background-color: #070722; }

        frame.background, frame.background > border {
          background-color: rgba(7, 7, 34, 0.74);
          border: 1px solid rgba(33, 33, 95, 0.85);
          border-radius: 20px;
          box-shadow: 0 24px 64px rgba(0, 0, 0, 0.45);
        }

        label { color: rgba(243, 237, 247, 0.92); }

        entry, passwordentry {
          background-color: rgba(17, 17, 45, 0.55);
          border: 1px solid rgba(33, 33, 95, 0.80);
          border-radius: 12px;
          min-height: 40px;
          padding: 8px 14px;
          color: #f3edf7;
          caret-color: #fff59b;
        }
        entry:focus-within, passwordentry:focus-within {
          border: 2px solid #fff59b;
          box-shadow: 0 0 0 1px rgba(255, 245, 155, 0.30);
        }
        entry selection, passwordentry selection {
          background-color: #fff59b;
          color: #0e0e43;
        }

        button, comboboxtext button, button.toggle {
          background-color: rgba(17, 17, 45, 0.55);
          border: 1px solid rgba(33, 33, 95, 0.80);
          border-radius: 12px;
          min-height: 40px;
          padding: 8px 18px;
          color: #f3edf7;
        }
        button:hover, comboboxtext button:hover, button.toggle:hover {
          background-color: rgba(155, 254, 206, 0.12);
          border-color: rgba(155, 254, 206, 0.40);
        }
        button.suggested-action {
          background-color: #fff59b;
          border-color: #fff59b;
          color: #0e0e43;
          font-weight: 700;
        }
        button.suggested-action:hover {
          background-color: #fffa9f;
        }
        button.destructive-action {
          background-color: rgba(253, 70, 99, 0.14);
          border-color: rgba(253, 70, 99, 0.55);
          color: #fd4663;
        }
        button.destructive-action:hover {
          background-color: rgba(253, 70, 99, 0.24);
        }
      '';
    };


    # ── Home Manager 集成 ────────────────────────────────────────────────
    home-manager.users.${myvars.username} = {
      programs.noctalia-shell.package = noctaliaShellQt612;

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
          // AI 工作区保留原名（当前就是主工作区），面板不再固定打开到这里
          workspace "AI" {}
        ''}

        // 所有窗口统一 8px 圆角（边框/焦点环同步），并裁剪窗口内容到圆角
        window-rule {
            geometry-corner-radius 8
            clip-to-geometry true
        }

        ${lib.optionalString config.modules.desktop.ai-agent.enable ''
          // HAO AI 面板：右侧悬浮卡片，外观对齐 Noctalia 面板
          // （Noctalia radiusL = 20、backgroundOpacity = 0.93、默认开启模糊）
          // 必须放在上面的 8px 通配规则之后：后定义的同名属性才会覆盖先定义的。
          window-rule {
              match app-id=r#"^hao-ai$"#
              open-floating true
              default-floating-position x=13 y=13 relative-to="top-right"
              default-column-width { fixed 720; }
              default-window-height { proportion 0.9; }
              geometry-corner-radius 20
              clip-to-geometry true
              opacity 0.93
              background-effect { blur true; }
              focus-ring { off; }
              border { off; }
              shadow { off; }
          }
        ''}

        layout {
            // 焦点环和边框都改为 1px
            focus-ring {
                width 1
            }
            border {
                width 1
            }
        }

        // 打开/关闭动画对齐 Noctalia 面板的节奏（全局生效）
        animations {
            window-open {
                duration-ms 220
                curve "cubic-bezier" 0.05 0.7 0.1 1
            }
            window-close {
                duration-ms 150
                curve "ease-out-quad"
            }
        }

        // hotkey-overlay-title 决定快捷键提示浮层里显示的文字；
        // 未自定义时 niri 会用英文动作名，这里统一改成中文。
        binds {
            // ── 基础 ──
            Mod+Shift+Slash hotkey-overlay-title="显示快捷键提示" { show-hotkey-overlay; }
            Mod+Return hotkey-overlay-title="打开终端" { spawn "kitty"; }
            Mod+T hotkey-overlay-title="打开终端（备用键）" { spawn "kitty"; }
            Mod+Q hotkey-overlay-title="关闭窗口" { close-window; }
            Mod+Shift+E hotkey-overlay-title="退出 niri" { quit; }

            // ── Noctalia ──
            Mod+Space hotkey-overlay-title="打开应用启动器" { spawn "noctalia-shell" "ipc" "call" "launcher" "toggle"; }
            Mod+Alt+L hotkey-overlay-title="锁屏" { spawn "noctalia-shell" "ipc" "call" "lockScreen" "lock"; }
            ${lib.optionalString config.modules.desktop.ai-agent.enable ''
              Mod+grave hotkey-overlay-title="呼出 / 收起 AI Agent" { spawn "hao-agent-toggle"; }
              Mod+Shift+Ctrl+A hotkey-overlay-title="AI Agent（备用键）" { spawn "hao-agent-toggle"; }
            ''}

            // ── 焦点移动 ──
            Mod+Left  hotkey-overlay-title="焦点左移" { focus-column-left; }
            Mod+Right hotkey-overlay-title="焦点右移" { focus-column-right; }
            Mod+Up    hotkey-overlay-title="焦点上移" { focus-window-up; }
            Mod+Down  hotkey-overlay-title="焦点下移" { focus-window-down; }
            Mod+H hotkey-overlay-title="焦点左移（备用键）" { focus-column-left; }
            Mod+L hotkey-overlay-title="焦点右移（备用键）" { focus-column-right; }
            Mod+K hotkey-overlay-title="焦点上移（备用键）" { focus-window-up; }
            Mod+J hotkey-overlay-title="焦点下移（备用键）" { focus-window-down; }

            // ── 窗口移动 ──
            Mod+Shift+Left  hotkey-overlay-title="当前列左移" { move-column-left; }
            Mod+Shift+Right hotkey-overlay-title="当前列右移" { move-column-right; }
            Mod+Shift+Up    hotkey-overlay-title="窗口上移" { move-window-up; }
            Mod+Shift+Down  hotkey-overlay-title="窗口下移" { move-window-down; }
            Mod+Shift+H hotkey-overlay-title="当前列左移（备用键）" { move-column-left; }
            Mod+Shift+L hotkey-overlay-title="当前列右移（备用键）" { move-column-right; }
            Mod+Shift+K hotkey-overlay-title="窗口上移（备用键）" { move-window-up; }
            Mod+Shift+J hotkey-overlay-title="窗口下移（备用键）" { move-window-down; }

            // ── 工作区 ──
            Mod+Page_Up   hotkey-overlay-title="上一个工作区" { focus-workspace-up; }
            Mod+Page_Down hotkey-overlay-title="下一个工作区" { focus-workspace-down; }
            Mod+U hotkey-overlay-title="下一个工作区（备用键）" { focus-workspace-down; }
            Mod+I hotkey-overlay-title="上一个工作区（备用键）" { focus-workspace-up; }
            Mod+1 hotkey-overlay-title="切换到工作区 1" { focus-workspace 1; }
            Mod+2 hotkey-overlay-title="切换到工作区 2" { focus-workspace 2; }
            Mod+3 hotkey-overlay-title="切换到工作区 3" { focus-workspace 3; }
            Mod+4 hotkey-overlay-title="切换到工作区 4" { focus-workspace 4; }
            Mod+5 hotkey-overlay-title="切换到工作区 5" { focus-workspace 5; }
            Mod+6 hotkey-overlay-title="切换到工作区 6" { focus-workspace 6; }
            Mod+7 hotkey-overlay-title="切换到工作区 7" { focus-workspace 7; }
            Mod+8 hotkey-overlay-title="切换到工作区 8" { focus-workspace 8; }
            Mod+9 hotkey-overlay-title="切换到工作区 9" { focus-workspace 9; }
            Mod+Shift+1 hotkey-overlay-title="当前列移到工作区 1" { move-column-to-workspace 1; }
            Mod+Shift+2 hotkey-overlay-title="当前列移到工作区 2" { move-column-to-workspace 2; }
            Mod+Shift+3 hotkey-overlay-title="当前列移到工作区 3" { move-column-to-workspace 3; }
            Mod+Shift+4 hotkey-overlay-title="当前列移到工作区 4" { move-column-to-workspace 4; }
            Mod+Shift+5 hotkey-overlay-title="当前列移到工作区 5" { move-column-to-workspace 5; }
            Mod+Shift+6 hotkey-overlay-title="当前列移到工作区 6" { move-column-to-workspace 6; }
            Mod+Shift+7 hotkey-overlay-title="当前列移到工作区 7" { move-column-to-workspace 7; }
            Mod+Shift+8 hotkey-overlay-title="当前列移到工作区 8" { move-column-to-workspace 8; }
            Mod+Shift+9 hotkey-overlay-title="当前列移到工作区 9" { move-column-to-workspace 9; }

            // ── 布局 ──
            Mod+R hotkey-overlay-title="切换预设列宽" { switch-preset-column-width; }
            Mod+F hotkey-overlay-title="最大化当前列" { maximize-column; }
            Mod+Shift+F hotkey-overlay-title="窗口全屏" { fullscreen-window; }
            Mod+Minus hotkey-overlay-title="列宽 -10%" { set-column-width "-10%"; }
            Mod+Equal hotkey-overlay-title="列宽 +10%" { set-column-width "+10%"; }
            // 窗口高度调整：同一列里堆叠多个窗口时才有效
            Mod+Shift+Minus hotkey-overlay-title="窗口高度 -10%" { set-window-height "-10%"; }
            Mod+Shift+Equal hotkey-overlay-title="窗口高度 +10%" { set-window-height "+10%"; }
            Mod+Ctrl+Shift+R hotkey-overlay-title="切换预设窗口高度" { switch-preset-window-height; }
            Mod+Ctrl+R hotkey-overlay-title="重置窗口高度" { reset-window-height; }
            Mod+Comma  hotkey-overlay-title="把窗口并入当前列" { consume-window-into-column; }
            Mod+Period hotkey-overlay-title="把窗口移出当前列" { expel-window-from-column; }

            // ── 截图 ──
            Print hotkey-overlay-title="截图" { screenshot; }
            Ctrl+Print hotkey-overlay-title="全屏截图" { screenshot-screen; }
            Alt+Print hotkey-overlay-title="窗口截图" { screenshot-window; }

            // ── 音量 / 亮度（Noctalia OSD） ──
            XF86AudioLowerVolume hotkey-overlay-title="音量 -" allow-when-locked=true { spawn "noctalia-shell" "ipc" "call" "volume" "decrease"; }
            XF86AudioRaiseVolume hotkey-overlay-title="音量 +" allow-when-locked=true { spawn "noctalia-shell" "ipc" "call" "volume" "increase"; }
            XF86AudioMute        hotkey-overlay-title="静音" allow-when-locked=true { spawn "noctalia-shell" "ipc" "call" "volume" "muteOutput"; }
            XF86MonBrightnessDown hotkey-overlay-title="亮度 -" allow-when-locked=true { spawn "noctalia-shell" "ipc" "call" "brightness" "decrease"; }
            XF86MonBrightnessUp   hotkey-overlay-title="亮度 +" allow-when-locked=true { spawn "noctalia-shell" "ipc" "call" "brightness" "increase"; }
        }
      '';

      # ── HAO AI 面板的 tmux 会话配置 ──────────────────────────────────
      # 只给 AI 面板用（kitty 启动时通过 -f 指定），不影响普通终端。
      xdg.configFile."tmux/hao-ai.conf".text = ''
        # 面板形态：不要底部状态栏，保留鼠标与真彩色
        set -g status off
        set -g mouse on
        set -g escape-time 0
        set -g focus-events on
        set -g allow-passthrough on
        set -g history-limit 10000
        set -g default-terminal "tmux-256color"
        set -sg terminal-features ",*:RGB"
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
                {
                  # HAO AI 入口：左键呼出/收起，文字显示当前 agent，开启时高亮
                  id = "CustomButton";
                  icon = "robot";
                  leftClickExec = "hao-agent-toggle";
                  generalTooltipText = "AI Agent（左键呼出 / 收起）";
                  textCommand = "hao-agent-status";
                  textIntervalMs = 2000;
                  parseJson = true;
                }
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

          # GTK 应用（Thunar 等）跟随全局主题：生成 ~/.config/gtk-{3,4}.0/noctalia.css，
          # 并通过 dconf 同步 gtk-theme = adw-gtk3[-dark] 与 color-scheme。
          templates.activeTemplates = [
            {
              id = "gtk";
              enabled = true;
            }
          ];

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
