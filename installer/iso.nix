{ config
, inputs
, lib
, pkgs
, self
, system
, offlineHost ? null
, ...
}:
let
  scriptBody = path: lib.removePrefix "#!/usr/bin/env bash\n" (builtins.readFile path);
  # Include transitive locked sources too. fetchTree can reuse their narHash
  # from the ISO store, so evaluation does not need to reach GitHub.
  bundledInputs = builtins.genericClosure {
    startSet = map (input: { key = input.outPath; inherit input; })
      (builtins.attrValues (builtins.removeAttrs inputs [ "self" ]));
    operator = node: map (input: { key = input.outPath; inherit input; })
      (builtins.attrValues (node.input.inputs or { }));
  };
  formatDisk = (import (inputs.disko + "/lib") { inherit lib; })._cliDestroyFormatMount
    (import ./disko-full-disk.nix { device = "/dev/hao-installer-target"; })
    pkgs;
  partitionDisk = pkgs.writeShellApplication {
    name = "hao-partition-disk";
    runtimeInputs = [ pkgs.bash pkgs.gnused ];
    text = ''
      # Only the disk verified by the installer may replace the placeholder.
      [[ $# == 1 && $1 =~ ^/dev/[a-zA-Z0-9/_-]+$ && -b $1 ]] || exit 1
      sed "s|/dev/hao-installer-target|$1|g" ${formatDisk}/bin/disko-destroy-format-mount \
        | bash -s -- --yes-wipe-all-disks
    '';
  };

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
      gnused
      gptfdisk
      gum
      jq
      less
      mkpasswd
      mihomo
      networkmanager
      ncurses
      parted
      pciutils
      rsync
      systemd
      util-linux
      localsend
      yq-go
      config.nix.package
      config.system.build.nixos-install
      inputs.disko.packages.${system}.disko
    ];
    text = scriptBody ./scripts/hao-installer.sh;
  };
  haoInstallerTerminal = pkgs.writeShellApplication {
    name = "hao-installer-terminal";
    text = scriptBody ./scripts/hao-installer-terminal.sh;
  };
  haoInstallerSession = pkgs.writeShellApplication {
    name = "hao-installer-session";
    runtimeInputs = [ pkgs.coreutils pkgs.util-linux pkgs.systemd pkgs.dbus pkgs.cage pkgs.kitty haoInstallerTerminal ];
    text = scriptBody ./scripts/hao-installer-session.sh;
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
  users.users.nixos.extraGroups = [ "seat" ];
  hardware.graphics.enable = true;

  nixpkgs.config.allowUnfree = true;
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    accept-flake-config = true;
    substituters = (import ../vars { }).cachixSubstituters;
    trusted-public-keys = (import ../vars { }).cachixTrustedPublicKeys;
    connect-timeout = 5;
    download-attempts = 2;
  };

  environment.systemPackages = [ haoInstaller haoInstallerSession ];
  isoImage.storeContents = map (node: node.key) bundledInputs;
  environment.etc."hao-installer/config".source = self.outPath;
  environment.etc."hao-installer/partition-disk".source = "${partitionDisk}/bin/hao-partition-disk";
  environment.etc."hao-installer/offline-host" = lib.mkIf (offlineHost != null) {
    text = "${offlineHost}\n";
  };
  environment.etc."hao-installer/offline-system" = lib.mkIf (offlineHost != null) {
    text = "${self.nixosConfigurations.${offlineHost}.config.system.build.toplevel}\n";
  };
  fonts.packages = [ pkgs.dejavu_fonts pkgs.noto-fonts-cjk-sans ];
  i18n.supportedLocales = [ "en_US.UTF-8/UTF-8" "zh_CN.UTF-8/UTF-8" ];
  environment.etc."hao-installer/kitty.conf".text = ''
    font_family DejaVu Sans Mono
    font_size 13
    linux_display_server wayland
    window_padding_width 12
    confirm_os_window_close -1
    background #101318
    foreground #f0f2f5
    enable_audio_bell no
  '';
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
  # Also mask the template instance created by systemd-getty-generator.
  environment.etc."systemd/system/getty@tty1.service".source = "/dev/null";
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
      HAO_INSTALLER_BIN = "${haoInstaller}/bin/hao-installer";
      # The simple setup window can use software rendering before the target
      # NVIDIA driver is installed; this is also used by the VM check.
      WLR_RENDERER = "pixman";
    };
    serviceConfig = {
      Type = "simple";
      ExecStart = "${haoInstallerSession}/bin/hao-installer-session";
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
  image.baseName = lib.mkForce
    "hao-installer${lib.optionalString (offlineHost != null) "-offline-${offlineHost}"}-${config.system.nixos.label}-${system}";

  isoImage = {
    volumeID = "HAO_INSTALLER";
    appendToMenuLabel = " HAO Installer";
    makeEfiBootable = true;
    makeUsbBootable = true;
  };
}
