{
  description = "Development environment with Zig (unstable)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      devShells.default = pkgs.mkShell {
        packages = [ 
					pkgs.zig
					pkgs.SDL2
				];
        
        # Optional: Environment variables
        shellHook = ''
          echo "Zig $(zig version) is ready!"
        '';
      };
    });
}
