{ lib, pkgs, laptopConfig, desktopConfig }:

let
  firmwareRules = pkgs.writeText "ovmf-test.rules" ((lib.concatStringsSep "\n"
    (lib.filter (rule: lib.hasPrefix "L+ /var/lib/ovmf/" rule) laptopConfig.systemd.tmpfiles.rules)) + "\n");
  kernelConfigs = lib.unique (map (config: config.boot.kernelPackages.kernel.configfile)
    (lib.filter (config: config.modules.desktop.gaming.enable && config.modules.desktop.gaming.ntsync.enable) [ laptopConfig desktopConfig ]));
in
pkgs.runCommand "desktop-support"
{ nativeBuildInputs = [ pkgs.gnugrep ]; }
  ''
    # Evaluation accepts invalid file/child paths; verify the actual inputs.
    for image in OVMF_CODE.fd OVMF_VARS.fd OVMF_VARS.ms.fd; do
      grep -Fq "L+ /var/lib/ovmf/$image " ${firmwareRules}
    done
    while read -r type target mode user group age source; do
      test "$type" = L+
      test -f "$source"
      test -r "$source"
    done < ${firmwareRules}

    # Enabling a module that the locked kernel did not build must fail CI.
    for kernel_config in ${lib.escapeShellArgs (map toString kernelConfigs)}; do
      grep -Eq '^CONFIG_NTSYNC=[ym]$' "$kernel_config"
    done
    touch "$out"
  ''
