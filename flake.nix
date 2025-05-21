{
  description = "Development environment and package builder with Zig (unstable)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = nixpkgs.legacyPackages.${system};
			zigVersion = "0.14.0";
			zig = pkgs.zig.overrideAttrs (old: {
				version = zigVersion;
				src = pkgs.fetchFromGitHub {
					owner = "ziglang";
					repo = "zig";
					rev = "0.14.0";
					hash = "sha256-VyteIp5ZRt6qNcZR68KmM7CvN2GYf8vj5hP+gHLkuVk=";
				};
			});
    in {
      devShells.default = pkgs.mkShell {
        packages = [ 
					zig
				];
        shellHook = ''
          echo "Zig $(zig version) is ready!"
        '';
      };
			packages.default = pkgs.stdenvNoCC.mkDerivation {
				name = "tblocks";
				src = ./.;
				nativeBuildInputs = [ zig ];
				# Set cache dir explicitly during build
				# preBuild = ''
				# 	export ZIG_GLOBAL_CACHE_DIR="$TMPDIR/zig-cache"
				# 	mkdir -p "$ZIG_GLOBAL_CACHE_DIR"
				# '';
				buildPhase = ''
					zig build --global-cache-dir "$TMPDIR/zig-cache"
				'';
				installPhase = ''
					mkdir -p $out
					mkdir $out/bin
					cp zig-out/bin/* $out/bin/
				'';
			};
    });
}
