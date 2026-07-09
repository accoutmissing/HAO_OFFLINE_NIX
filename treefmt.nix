{
  projectRootFile = "flake.nix";

  programs.nixpkgs-fmt.enable = true;
  programs.deadnix.enable = true;
  programs.statix.enable = true;

  programs.shellcheck.enable = true;
  programs.shfmt.enable = true;
}
