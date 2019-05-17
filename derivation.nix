{ system ? builtins.currentSystem
, config ? { android_sdk.accept_license = true; }, overlays ? []
, pkgs ? (import <nixpkgs> { inherit system config overlays; })
, target-os }:

with pkgs;
  let
    platform = callPackage ./nix/platform.nix { inherit target-os; };
    # TODO: Try to use stdenv for iOS. The problem is with building iOS as the build is trying to pass parameters to Apple's ld that are meant for GNU's ld (e.g. -dynamiclib)
    _stdenv = stdenvNoCC;
    gradle = gradle_4_10;
    statusDesktop = callPackage ./nix/desktop { inherit target-os status-go; stdenv = _stdenv; };
    statusMobile = callPackage ./nix/mobile { inherit target-os config status-go gradle; stdenv = _stdenv; };
    status-go = callPackage ./nix/status-go { inherit target-os; inherit (xcodeenv) composeXcodeWrapper; inherit (statusMobile) xcodewrapperArgs; androidPkgs = statusMobile.androidComposition; };
    nodejs' = nodejs-10_x;
    yarn' = yarn.override { nodejs = nodejs'; };
    nodeInputs = import ./nix/global-node-packages/output {
      # The remaining dependencies come from Nixpkgs
      inherit pkgs;
      nodejs = nodejs';
    };
    nodePkgBuildInputs = [
      nodejs'
      python27 # for e.g. gyp
      yarn'
    ] ++ (builtins.attrValues nodeInputs);
    selectedSources =
      lib.optional platform.targetDesktop statusDesktop ++
      lib.optional platform.targetMobile statusMobile;

  in _stdenv.mkDerivation rec {
    name = "status-react-build-env";

    buildInputs = with _stdenv; [
      clojure
      leiningen
      maven
      watchman
    ] ++ nodePkgBuildInputs
      ++ lib.optional isDarwin cocoapods
      ++ lib.optional (isDarwin && !platform.targetIOS) clang
      ++ lib.optional (!isDarwin) gcc7
      ++ lib.catAttrs "buildInputs" selectedSources;
    shellHook = lib.concatStrings (lib.catAttrs "shellHook" selectedSources);
  }
