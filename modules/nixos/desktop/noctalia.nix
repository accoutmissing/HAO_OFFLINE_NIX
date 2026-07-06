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

    # ── Home Manager 集成 ────────────────────────────────────────────────
    home-manager.users.${myvars.username} = {
      imports = [
        inputs.noctalia.homeModules.default
      ];

      # ── Niri 配置（直接写 KDL，兼容不支持 programs.niri.settings 的版本）
      xdg.configFile."niri/config.kdl".text = ''
        spawn-at-startup "noctalia-shell"
        spawn-at-startup "swayidle" "-w" "timeout" "300" "noctalia-shell ipc call lockScreen lock" "before-sleep" "noctalia-shell ipc call lockScreen lock"

        binds {
          Mod+Space { spawn "noctalia-shell" "ipc" "call" "launcher" "toggle"; }
          Mod+L { spawn "noctalia-shell" "ipc" "call" "lockScreen" "lock"; }
          XF86AudioLowerVolume { spawn "noctalia-shell" "ipc" "call" "volume" "decrease"; }
          XF86AudioRaiseVolume { spawn "noctalia-shell" "ipc" "call" "volume" "increase"; }
          XF86AudioMute { spawn "noctalia-shell" "ipc" "call" "volume" "muteOutput"; }
          XF86MonBrightnessDown { spawn "noctalia-shell" "ipc" "call" "brightness" "decrease"; }
          XF86MonBrightnessUp { spawn "noctalia-shell" "ipc" "call" "brightness" "increase"; }
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
