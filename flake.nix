{
  description = "Example for SSE pubsub dev environment";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nix-gleam.url = "github:arnarg/nix-gleam";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    nix-gleam,
  }: (
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs {
        inherit system;
        overlays = [
          nix-gleam.overlays.default
        ];
      };
    in {
      packages.default = pkgs.buildGleamApplication {
        src = ./.;

        # Overrides the rebar3 package used, adding
        # plugins using `rebar3WithPlugins`.
        rebar3Package = pkgs.rebar3WithPlugins {
          plugins = with pkgs.beamPackages; [pc];
        };
      };
      devShells = {
        default = pkgs.mkShell {
          nativeBuildInputs = with pkgs; [
            gleam
            erlang
            rebar3
          ];
        };
      };

    })
  );
}

