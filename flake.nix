{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      supportedSystems = [ "x86_64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forAllSystems = f:
        nixpkgs.lib.genAttrs supportedSystems (system: f system);
      nixpkgsFor = forAllSystems (system:
        import nixpkgs {
          inherit system;
          overlays = [ self.overlay ];
        });
      mkJanetInternal = { pkgs, name, src, main ? null, quickbin ? null, version ? null
        , bin ? null, buildInputs ? [ ], runtimeInputs ? [ ], jpmTree ? "" }:
          with pkgs;
          let
            runtimePath = lib.makeBinPath runtimeInputs;
            runtimePathFlag = lib.optionalString (runtimeInputs != [])
              ''--prefix PATH : "${runtimePath}"'';
          in stdenv.mkDerivation {
            inherit name version src main quickbin bin;

            nativeBuildInputs = [ makeWrapper ];
            buildInputs = [ janet jpm ] ++ buildInputs;

            buildPhase = ''
              # localize jpm dependency paths
              export JANET_PATH="$PWD/.jpm"
              export JANET_TREE="$JANET_PATH/jpm_tree"
              export JANET_LIBPATH="${pkgs.janet}/lib"
              export JANET_HEADERPATH="${pkgs.janet}/include/janet"
              export JANET_BUILDPATH="$JANET_PATH/build"
              export PATH="$PATH:$JANET_TREE/bin"
              mkdir -p "$JANET_TREE"
              mkdir -p "$JANET_BUILDPATH"
              mkdir -p "$PWD/.pkgs"

              if [ -n "${jpmTree}" ]; then
                cp -r ${jpmTree}/. "$JANET_TREE"
                chmod -R u+w "$JANET_TREE"
              fi

              # if passed a main script, copy it into the project and use it for quickbin
              if [ -n "$main" ]; then
                quickbin=janet-nix-main.janet
                echo "$main" > $quickbin
              fi

              if [ -n "$quickbin" ]; then
                jpm quickbin "$quickbin" quickbin-out
              else
                jpm install
              fi
            '';

            installPhase = ''
              cp -rL "$JANET_TREE/." $out
              mkdir -p $out/bin

              # if we have quickbin output, use that as the result
              if [ -f "quickbin-out" ]; then
                install -m 755 quickbin-out $out/bin/$name
              # else if a binary is explicitly passed to mkJanet, use that
              elif [ -n "$bin" ]; then
                install -m 755 "$JANET_TREE/bin/$bin" $out/bin/$name
              fi

              for file in "$out/bin/"*; do
                [ -f "$file" ] || continue
                chmod +x "$file"

                if isScript "$file"; then
                  # If :hardcode-syspath is true, jpm hardcodes our local
                  # syspath which we need to replace with our output path.
                  #
                  # Rather than checking to see if that option is set, we use
                  # --replace which doesn't report an error if no substitution
                  # is made.
                  substituteInPlace "$file" \
                    --replace "$JANET_TREE/lib" "$out/lib"
                  wrapProgram "$file" --set JANET_PATH "$out/lib" ${runtimePathFlag}
                ${lib.optionalString (runtimeInputs != []) ''
                else
                  wrapProgram "$file" ${runtimePathFlag}
                ''}
                fi
              done
            '';
          };
    in {
      overlay = final: prev: {
        janet-nix = final.mkJanet {
          name = "janet-nix";
          src = ./.;
          quickbin = "main.janet";
        };

        mkJanet = { name, src, main ? null, quickbin ? null, version ? null
          , bin ? null, buildInputs ? [ ], extraDeps ? [ ], extraSources ? [ ], runtimeInputs ? [ ] }:
          let
            pkgs = final;
            deps = if builtins.pathExists (src + "/lockfile.jdn")
              then import (pkgs.runCommandLocal "run-janet-nix" {
                lockfile = src + "/lockfile.jdn";
                buildInputs = [ pkgs.janet-nix ];
              } ''
                cp "$lockfile" lockfile.jdn
                janet-nix > $out
              '')
              else [];
            sources = (builtins.map builtins.fetchGit (deps ++ extraDeps)) ++ extraSources;
            perDepDrvs = map (src: mkJanetInternal {
              inherit pkgs src buildInputs;
              name = "janet-dep-${builtins.baseNameOf (toString src)}";
            }) sources;
            jpmTree = pkgs.symlinkJoin {
              name = "jpm_tree";
              paths = perDepDrvs;
            };
          in
          mkJanetInternal {
            inherit pkgs name src main quickbin version bin buildInputs runtimeInputs jpmTree;
          };
      };

      templates = {
        default = {
          path = ./templates/default;
          description = "A simple janet-nix project";
        };
        full = {
          path = ./templates/full;
          description = "A janet-nix project with dev tools";
        };
      };

      checks = forAllSystems (system: import ./nix/tests.nix nixpkgsFor.${system});

      packages = forAllSystems (system: {
        janet-nix = nixpkgsFor.${system}.janet-nix;
      });

      legacyPackages = forAllSystems (system: {
        inherit (nixpkgsFor.${system}) mkJanet;
      });

      defaultPackage =
        forAllSystems (system: self.packages.${system}.janet-nix);

      devShell = forAllSystems (system:
        with nixpkgsFor.${system};
        mkShell {
          packages = [ janet jpm ];
          buildInputs = [ janet ];
          shellHook = ''
            # localize jpm dependency paths
            export JANET_PATH="$PWD/.jpm"
            export JANET_TREE="$JANET_PATH/jpm_tree"
            export JANET_LIBPATH="${pkgs.janet}/lib"
            export JANET_HEADERPATH="${pkgs.janet}/include/janet"
            export JANET_BUILDPATH="$JANET_PATH/build"
            export PATH="$PATH:$JANET_TREE/bin"
            mkdir -p "$JANET_TREE"
            mkdir -p "$JANET_BUILDPATH"
          '';
        });
    };
}
