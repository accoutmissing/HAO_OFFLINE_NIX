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
      dosfstools
      findutils
      gawk
      gnugrep
      gptfdisk
      gum
      jq
      less
      mkpasswd
      networkmanager
      parted
      pciutils
      rsync
      systemd
      util-linux
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

  # 保留 tty2 作为维修终端，tty1 完全交给安装器。
  systemd.services."getty@tty1".enable = false;
  systemd.services.hao-installer = {
    description = "HAO full-screen NixOS installer";
    wantedBy = [ "multi-user.target" ];
    after = [
      "NetworkManager.service"
      "systemd-vconsole-setup.service"
    ];
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
