{ lib, pkgs, disko, installerConfig }:
let
  # The locked VM launcher starts virtiofsd asynchronously. Wait for its
  # sockets so QEMU cannot exit before the file-sharing daemons are ready.
  qemuWithReadyShares = pkgs.symlinkJoin {
    name = "qemu-for-installer-tests";
    paths = [
      (pkgs.writeShellScriptBin "qemu-system-x86_64" ''
        set -euo pipefail
        for arg in "$@"; do
          case "$arg" in
            socket,id=nix-store,path=*|socket,id=shared,path=*|socket,id=xchg,path=*)
              socket_path="''${arg#*path=}"
              socket_path="''${socket_path%%,*}"
              for _ in $(seq 1 100); do
                [[ ! -S $socket_path ]] || break
                sleep 0.05
              done
              [[ -S $socket_path ]] || exit 1
              ;;
          esac
        done
        exec ${pkgs.qemu_test}/bin/qemu-system-x86_64 "$@"
      '')
      pkgs.qemu_test
    ];
  };
  target = lib.nixosSystem {
    system = pkgs.stdenv.hostPlatform.system;
    modules = [
      {
        networking.hostName = "hao-install-test";
        system.stateVersion = "26.05";
        boot.loader.systemd-boot.enable = true;
        boot.loader.efi.canTouchEfiVariables = false;
        boot.initrd.availableKernelModules = [ "virtio_pci" "virtio_blk" ];
        fileSystems."/" = {
          device = "/dev/disk/by-label/NIXOS";
          fsType = "btrfs";
          options = [ "subvol=@" ];
        };
        fileSystems."/home" = {
          device = "/dev/disk/by-label/NIXOS";
          fsType = "btrfs";
          options = [ "subvol=@home" ];
        };
        fileSystems."/boot" = {
          device = "/dev/disk/by-label/BOOT";
          fsType = "vfat";
        };
        users.mutableUsers = false;
        users.users.root.hashedPassword = "!";
        users.users.admin = {
          isNormalUser = true;
          extraGroups = [ "wheel" ];
          hashedPasswordFile = "/var/lib/hao-secrets/admin-password-hash";
        };
      }
    ];
  };
  fixtureFlake = pkgs.writeText "flake.nix" ''
    { description = "Installer test fixture"; outputs = _: {}; }
  '';
  fixtureSource = pkgs.runCommand "installer-fixture" { } ''
    mkdir -p "$out/installer"
    cp ${fixtureFlake} "$out/flake.nix"
    cp ${../installer/disko-full-disk.nix} "$out/installer/disko-full-disk.nix"
  '';
  preview = pkgs.writeShellApplication {
    name = "hao-installer-preview";
    runtimeInputs = [ pkgs.bash pkgs.gum pkgs.coreutils pkgs.gnused pkgs.ncurses ];
    text = ''
      # shellcheck disable=SC1091
      source ${../installer/scripts/hao-installer.sh}
      trap - ERR
      welcome
      sleep infinity
    '';
  };
  installFixture = pkgs.writeShellScript "install-fixture" ''
    set -Eeuo pipefail
    export HAO_INSTALLER_STATE_DIR=/run/hao-installer-test
    export HAO_INSTALLER_TTY=/dev/null
    source ${../installer/scripts/hao-installer.sh}
    trap - ERR
    mkdir -p "$STATE_DIR"
    : >"$LOG_FILE"
    failure_menu() { echo "$1"; cat "$LOG_FILE"; exit 1; }
    screen_header() { :; }
    render_progress() { :; }
    gum() { :; }
    # /dev/vda is the test driver's root disk, not an ISO; the only disk the
    # test permits Disko to format is its new, empty 64 GiB /dev/vdb image.
    detect_boot_disk() { printf '/dev/vda\n'; }
    BOOT_DISK=/dev/vda
    TARGET_DISK=/dev/vdb
    TARGET_DISK_ID="$(disk_identity "$TARGET_DISK")"
    TARGET_DISK_SIZE="$(lsblk -dnbo SIZE "$TARGET_DISK")"
    TARGET_DISK_SERIAL="$(lsblk -dnro SERIAL "$TARGET_DISK" | xargs)"
    TARGET_DISK_WWN="$(lsblk -dnro WWN "$TARGET_DISK" | xargs)"
    NIX_OPTIONS=(--option substituters "" --option extra-substituters "")
    select_host
    configure_network
    mkdir -p /etc/NetworkManager/system-connections
    printf '[connection]\nid=fixture-wifi\ntype=wifi\n[wifi-security]\npsk=fixture-password\n' \
      > /etc/NetworkManager/system-connections/fixture.nmconnection
    chmod 600 /etc/NetworkManager/system-connections/fixture.nmconnection
    PASSWORD_HASH="$(printf 'fixture-password\n' | mkpasswd -m yescrypt -s)"
    run_phase 1 6 "Prepare" build_target_before_erase
    run_phase 2 6 "Partition" partition_disk
    run_phase 3 6 "Copy" copy_configuration
    run_phase 4 6 "Password" prepare_target_configuration
    PASSWORD_HASH=""
    run_phase 5 6 "Install" install_system
    run_phase 6 6 "Sync" sync
  '';
in
pkgs.testers.runNixOSTest {
  name = "hao-installer-offline-and-chinese-ui";
  nodes.machine = {
    virtualisation = {
      qemu.package = lib.mkForce qemuWithReadyShares;
      memorySize = 3072;
      graphics = true;
      resolution = { x = 1280; y = 800; };
      emptyDiskImages = [ 65536 ];
    };
    hardware.graphics.enable = true;
    fonts = { inherit (installerConfig.fonts) packages; };
    i18n = { inherit (installerConfig.i18n) supportedLocales; };
    services.seatd.enable = true;
    users.users.nixos = {
      isNormalUser = true;
      extraGroups = [ "wheel" "seat" ];
    };
    security.sudo.wheelNeedsPassword = false;
    environment.systemPackages = installerConfig.environment.systemPackages ++ [
      pkgs.btrfs-progs
      pkgs.dosfstools
      pkgs.jq
      pkgs.mkpasswd
      pkgs.parted
      pkgs.gptfdisk
      pkgs.rsync
      pkgs.nixos-install
      pkgs.nixos-enter
      pkgs.nix
      pkgs.gawk
      disko
    ];
    environment.etc = {
      "systemd/system/getty@tty1.service" = installerConfig.environment.etc."systemd/system/getty@tty1.service";
      "hao-installer/kitty.conf" = installerConfig.environment.etc."hao-installer/kitty.conf";
      "hao-installer/config".source = fixtureSource;
      "hao-installer/partition-disk" = installerConfig.environment.etc."hao-installer/partition-disk";
      "hao-installer/offline-host".text = "HAO_DESKTOP\n";
      "hao-installer/offline-system".text = "${target.config.system.build.toplevel}\n";
    };
    nix.settings.experimental-features = [ "nix-command" "flakes" ];
    systemd.services."getty@tty1".enable = false;
    systemd.services.hao-installer = {
      wantedBy = [ "multi-user.target" ];
      conflicts = [ "getty@tty1.service" ];
      after = [ "seatd.service" "systemd-vconsole-setup.service" ];
      wants = [ "seatd.service" ];
      environment = {
        HAO_INSTALLER_BIN = "${preview}/bin/hao-installer-preview";
        WLR_RENDERER = installerConfig.systemd.services.hao-installer.environment.WLR_RENDERER;
      };
      serviceConfig = {
        ExecStart = installerConfig.systemd.services.hao-installer.serviceConfig.ExecStart;
        StandardInput = "tty";
        StandardOutput = "tty";
        StandardError = "tty";
        TTYPath = "/dev/tty1";
        TTYReset = true;
      };
    };
  };
  testScript = ''
    from datetime import timedelta
    machine.start()
    machine.wait_for_unit("multi-user.target")
    machine.wait_until_succeeds("pgrep -f '[k]itty.*--config'", timeout=timedelta(seconds=45))
    machine.wait_until_succeeds("pgrep -f '[g]um confirm'", timeout=timedelta(seconds=45))
    machine.screenshot("installer-zh")
    machine.succeed("${installFixture}", timeout=timedelta(seconds=600))
    machine.succeed("test -e /mnt/boot/EFI/BOOT/BOOTX64.EFI")
    machine.succeed("test -x /mnt/nix/var/nix/profiles/system/bin/switch-to-configuration")
    machine.succeed("test $(stat -c %a /mnt/var/lib/hao-secrets/admin-password-hash) = 600")
    machine.succeed("test $(stat -c %a /mnt/var/lib/hao-secrets) = 700")
    machine.succeed("test $(stat -c %a /mnt/etc/NetworkManager/system-connections/fixture.nmconnection) = 600")
    machine.succeed("test $(stat -c %a /mnt/etc/NetworkManager/system-connections) = 700")
    machine.succeed("test -w /mnt/etc/nixos/flake.nix; test $(stat -c %a /mnt/etc/nixos/flake.nix) = 644")
    machine.succeed("grep -q '^admin:' /mnt/etc/shadow")
    machine.succeed("! grep -q 'fixture-password' /run/hao-installer-test/install.log")
    machine.succeed("test $(jq -r .status /run/hao-installer-test/state.json) = complete")
  '';
}
