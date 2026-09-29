{ config
, inputs
, lib
, pkgs
, self
, system
, ...
}:
let
  scriptBody = path: lib.removePrefix "#!/usr/bin/env bash\n" (builtins.readFile path);

  haoInstaller = pkgs.writeShellApplication {
    name = "hao-installer";
    runtimeInputs = with pkgs; [
      bashInteractive
      btrfs-progs
      coreutils
      curl
      cage
      dbus
      dosfstools
      findutils
      gawk
      gnugrep
      gptfdisk
      gum
      jq
      less
      mkpasswd
      mihomo
      networkmanager
      parted
      pciutils
      rsync
      systemd
      util-linux
      localsend
      inputs.disko.packages.${system}.disko
    ];
    text = scriptBody ./scripts/hao-installer.sh;
  };
in
{
  imports = [
    (inputs.nixpkgs + "/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix")
  ];

  networking.hostName = "HAO-INSTALLER";

  # 使用 NetworkManager 提供 nmtui，安装前即可连接 Wi-Fi。
  networking.networkmanager.enable = true;
  networking.wireless.enable = lib.mkForce false;
  networking.firewall.allowedTCPPorts = [ 53317 ];
  networking.firewall.allowedUDPPorts = [ 53317 ];

  # Cage gives LocalSend a temporary graphical session without turning the
  # installer into a full desktop ISO. The session returns to the TUI on exit.
  services.seatd.enable = true;

  nixpkgs.config.allowUnfree = true;
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    accept-flake-config = true;
  };

  environment.systemPackages = [ haoInstaller ];
  environment.etc."hao-installer/config".source = self.outPath;
  environment.etc."hao-installer/geodata/geoip.dat".source = "${pkgs.v2ray-rules-dat}/share/v2ray/geoip.dat";
  environment.etc."hao-installer/geodata/geosite.dat".source = "${pkgs.v2ray-rules-dat}/share/v2ray/geosite.dat";

  systemd.services.hao-installer-mihomo = {
    description = "Temporary Clash proxy for the HAO installer";
    after = [ "NetworkManager.service" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.mihomo}/bin/mihomo -d /run/hao-installer/mihomo -f /run/hao-installer/mihomo/config.yaml";
      Restart = "on-failure";
      RestartSec = 3;
      UMask = "0077";
    };
  };

  # 保留 tty2 作为维修终端，tty1 完全交给安装器。
  systemd.services."getty@tty1".enable = false;
  systemd.services.hao-installer = {
    description = "HAO full-screen NixOS installer";
    wantedBy = [ "multi-user.target" ];
    after = [
      "NetworkManager.service"
      "seatd.service"
      "systemd-vconsole-setup.service"
    ];
    wants = [ "seatd.service" ];
    conflicts = [ "getty@tty1.service" ];
    environment = {
      HAO_CONFIG_SOURCE = "/etc/hao-installer/config";
      HAO_INSTALLER_TTY = "/dev/tty1";
    };
    serviceConfig = {
      Type = "simple";
      ExecStart = "${haoInstaller}/bin/hao-installer";
      StandardInput = "tty";
      StandardOutput = "tty";
      StandardError = "tty";
      TTYPath = "/dev/tty1";
      TTYReset = true;
      TTYVHangup = true;
      TTYVTDisallocate = true;
      Restart = "no";
    };
  };

  boot.kernelParams = [ "consoleblank=0" ];
  console.keyMap = "us";

  # ISO 构建器实际以 baseName 生成产物；extension 由 iso-image 模块补全。
  image.baseName = lib.mkForce "hao-installer-${config.system.nixos.label}-${system}";

  isoImage = {
    volumeID = "HAO_INSTALLER";
    appendToMenuLabel = " HAO Installer";
    makeEfiBootable = true;
    makeUsbBootable = true;
  };
}
