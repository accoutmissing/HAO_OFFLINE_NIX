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
      swayidle        # 空闲检测 → 自动锁屏
    ];

    # ── Noctalia 依赖的服务 ─────────────────────────────────────────────
    services.upower.enable = true;

    # ── Niri 集成（开机自启 + 快捷键 + 空闲锁屏） ────────────────────
    programs.niri.settings = {
      spawn-at-startup = [
        { command = [ "noctalia-shell" ]; }
        # 空闲 5 分钟后锁屏
        {
          command = [
            "swayidle" "-w"
            "timeout" "300" "noctalia-shell ipc call lockScreen lock"
            "before-sleep" "noctalia-shell ipc call lockScreen lock"
          ];
        }
      ];

      binds = {
        # 启动器
        "Mod+Space".action.spawn = [
          "noctalia-shell" "ipc" "call" "launcher" "toggle"
        ];

        # 锁屏
        "Mod+L".action.spawn = [
          "noctalia-shell" "ipc" "call" "lockScreen" "lock"
        ];

        # 音量
        "XF86AudioLowerVolume".action.spawn = [
          "noctalia-shell" "ipc" "call" "volume" "decrease"
        ];
        "XF86AudioRaiseVolume".action.spawn = [
          "noctalia-shell" "ipc" "call" "volume" "increase"
        ];
        "XF86AudioMute".action.spawn = [
          "noctalia-shell" "ipc" "call" "volume" "muteOutput"
        ];

        # 亮度
        "XF86MonBrightnessDown".action.spawn = [
          "noctalia-shell" "ipc" "call" "brightness" "decrease"
        ];
        "XF86MonBrightnessUp".action.spawn = [
          "noctalia-shell" "ipc" "call" "brightness" "increase"
        ];
      };
    };

    # ── Home Manager 集成 ────────────────────────────────────────────────
    home-manager.users.${myvars.username} = {
      imports = [
        inputs.noctalia.homeModules.default
      ];

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
          # 各主机 default.nix 中通过 modules.desktop.noctalia.performanceMode 覆盖
          noctaliaPerformance = {
            disableWallpaper = lib.mkDefault false;
            disableDesktopWidgets = lib.mkDefault false;
          };
        };
      };
    };
  };
}
