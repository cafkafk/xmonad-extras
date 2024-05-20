# This file is stolen from @IvanMalison and @LSLeary (github)
{
  inputs = {
    flake-utils.url = github:numtide/flake-utils;
    git-ignore-nix.url = github:hercules-ci/gitignore.nix/master;
    xmonad.url = github:xmonad/xmonad;
    xmonad-contrib.url = github:xmonad/xmonad-contrib;
  };
  outputs = { self, flake-utils, nixpkgs, git-ignore-nix, xmonad, xmonad-contrib }:
  with xmonad.lib;
  let
    hoverlay = final: prev: hself: hsuper: {
      xmonad-extras = hself.callCabal2nix "xmonad-extras"
        (git-ignore-nix.lib.gitignoreSource ./.) { };
    };
    defComp = if builtins.pathExists ./comp.nix
      then import ./comp.nix
      else { };
    overlay = fromHOL hoverlay defComp;
    overlays = [ overlay (fromHOL xmonad.hoverlay defComp) xmonad-contrib.overlay];
    nixosModule = { config, lib, ... }: with lib;
      let
        cfg = config.services.xserver.windowManager.xmonad;
        comp = { inherit (cfg.flake) prefix compiler; };
      in {
        config = mkIf (cfg.flake.enable && cfg.enableContribAndExtras) {
          nixpkgs.overlays = [ (fromHOL hoverlay comp) ];
        };
      };
    nixosModules = [ nixosModule ] ++ xmonad.nixosModules;
  in flake-utils.lib.eachDefaultSystem (system:
  let
    pkgs = import nixpkgs { inherit system overlays; };
    hpkg = pkgs.lib.attrsets.getAttrFromPath (hpath defComp) pkgs;
    modifyDevShell =
      if builtins.pathExists ./develop.nix
      then import ./develop.nix
      else _: x: x;
  in
  rec {
    devShell = hpkg.shellFor (modifyDevShell pkgs {
      packages = p: [ p.xmonad-extras ];
      nativeBuildInputs = [ pkgs.cabal-install ];
    });
    defaultPackage = hpkg.xmonad-extras;
    packages.default = hpkg.xmonad-extras;
    modernise = xmonad.modernise.${system};
  }) // { inherit hoverlay overlay overlays nixosModule nixosModules; } ;
}
