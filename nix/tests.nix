pkgs:
let
  # With-deps: jfmt has a lockfile with real Janet deps
  jfmt = pkgs.mkJanet {
    name = "jfmt";
    src = builtins.fetchGit {
      url = "https://github.com/andrewchambers/jfmt.git";
      rev = "b27dff6bb32b89b20462eec33f50c1583c301b0a";
    };
    bin = "jfmt";
  };

  # With-deps and quickbin.
  jfmt-quickbin = pkgs.mkJanet {
    name = "jfmt";
    src = builtins.fetchGit {
      url = "https://github.com/andrewchambers/jfmt.git";
      rev = "b27dff6bb32b89b20462eec33f50c1583c301b0a";
    };
    quickbin = "./jfmt.janet";
  };
in
{
  # Verify jfmt builds and produces an executable binary
  jfmt-with-deps = pkgs.runCommand "jfmt-with-deps-check" { } ''
    [ -x "${jfmt}/bin/jfmt" ] || (echo "jfmt binary not found or not executable"; exit 1)
    touch $out
  '';

  # Verify jfmt builds and produces an executable binary
  jfmt-quickbin = pkgs.runCommand "jfmt-quickbin" { } ''
    [ -x "${jfmt-quickbin}/bin/jfmt" ] || (echo "jfmt binary not found or not executable"; exit 1)
    touch $out
  '';

  quickbin =
    let
      src = pkgs.writeTextDir "src/test.janet" ''
        (defn main [& args] (print "quickbin"))
      '';
      pkg = pkgs.mkJanet {
        inherit src;
        name = "test";
        quickbin = "src/test.janet";
      };
    in
    pkgs.runCommand "quickbin" { } ''
      output=$(${pkg}/bin/test)
      [ "$output" = "quickbin" ] || (echo "Unexpected output: $output"; exit 1)
      touch $out
    '';

  quickbin-local-import =
    let
      src = pkgs.symlinkJoin {
        name = "src";
        paths = [
          (pkgs.writeTextDir "src/helper.janet" ''
            (defn greeting [] "quickbin-local-import")
          '')
          (pkgs.writeTextDir "src/main.janet" ''
            (import ./helper)
            (defn main [& args] (print (helper/greeting)))
          '')
        ];
      };
      pkg = pkgs.mkJanet {
        inherit src;
        name = "test";
        quickbin = "src/main.janet";
      };
    in
    pkgs.runCommand "quickbin-local-import" { } ''
      output=$(${pkg}/bin/test)
      [ "$output" = "quickbin-local-import" ] || (echo "Unexpected output: $output"; exit 1)
      touch $out
    '';

  executable-bin =
    let
      src = pkgs.symlinkJoin {
        name = "src";
        paths = [
          (pkgs.writeTextDir "project.janet" ''
            (declare-project :name "myproj")
            (declare-executable :name "test" :entry "src/main.janet" :install true)
          '')
          (pkgs.writeTextDir "src/main.janet" ''
            (defn main [& args] (print "executable-bin"))
          '')
        ];
      };
      pkg = pkgs.mkJanet {
        inherit src;
        name = "test";
        bin = "test";
      };
    in
    pkgs.runCommand "executable-bin" { } ''
      output=$(${pkg}/bin/test)
      [ "$output" = "executable-bin" ] || (echo "Unexpected output: $output"; exit 1)
      touch $out
    '';

  executable-local-import =
    let
      src = pkgs.symlinkJoin {
        name = "src";
        paths = [
          (pkgs.writeTextDir "project.janet" ''
            (declare-project :name "myproj")
            (declare-source :source [ "src/helper.janet" ])
            (declare-executable :name "test" :entry "src/main.janet" :install true)
          '')
          (pkgs.writeTextDir "src/helper.janet" ''
            (defn greeting [] "executable-local-import")
          '')
          (pkgs.writeTextDir "src/main.janet" ''
            (import ./helper)
            (defn main [& args] (print (helper/greeting)))
          '')
        ];
      };
      pkg = pkgs.mkJanet {
        inherit src;
        name = "test";
        bin = "test";
      };
    in
    pkgs.runCommand "project-bin" { } ''
      output=$(${pkg}/bin/test)
      [ "$output" = "executable-local-import" ] || (echo "Unexpected output: $output"; exit 1)
      touch $out
    '';

  binscript-bin =
    let
      src = pkgs.symlinkJoin {
        name = "src";
        paths = [
          (pkgs.writeTextDir "project.janet" ''
            (declare-project :name "myproj")
            (declare-binscript :main "src/test")
          '')
          (pkgs.writeTextDir "src/test" ''
            #!/usr/bin/env janet
            (defn main [& args] (print "binscript-bin"))
          '')
        ];
      };
      pkg = pkgs.mkJanet {
        inherit src;
        name = "test";
        bin = "test";
      };
    in
    pkgs.runCommand "binscript-bin" { } ''
      output=$(${pkg}/bin/test)
      [ "$output" = "binscript-bin" ] || (echo "Unexpected output: $output"; exit 1)
      touch $out
    '';

  binscript-import =
    let
      src = pkgs.symlinkJoin {
        name = "src";
        paths = [
          (pkgs.writeTextDir "project.janet" ''
            (declare-project :name "myproj")
            (declare-source :source [ "src/helper.janet" ])
            (declare-binscript :main "src/test")
          '')
          (pkgs.writeTextDir "src/helper.janet" ''
            (defn greeting [] "binscript-import")
          '')
          (pkgs.writeTextDir "src/test" ''
            #!/usr/bin/env janet
            (import helper)
            (defn main [& args] (print (helper/greeting)))
          '')
        ];
      };
      pkg = pkgs.mkJanet {
        inherit src;
        name = "test";
        bin = "test";
      };
    in
    pkgs.runCommand "binscript-import" { } ''
      output=$(${pkg}/bin/test)
      [ "$output" = "binscript-import" ] || (echo "Unexpected output: $output"; exit 1)
      touch $out
    '';

  binscript-hardcode-syspath =
    let
      src = pkgs.symlinkJoin {
        name = "src";
        paths = [
          (pkgs.writeTextDir "project.janet" ''
            (declare-project :name "myproj")
            (declare-source :source [ "src/helper.janet" ])
            (declare-binscript :main "src/test" :hardcode-syspath true)
          '')
          (pkgs.writeTextDir "src/helper.janet" ''
            (defn greeting [] "binscript-hardcode-syspath")
          '')
          (pkgs.writeTextDir "src/test" ''
            #!/usr/bin/env janet
            (import helper)
            (defn main [& args] (print (helper/greeting)))
          '')
        ];
      };
      pkg = pkgs.mkJanet {
        inherit src;
        name = "test";
        bin = "test";
      };
    in
    pkgs.runCommand "binscript-hardcode-syspath" { } ''
      output=$(${pkg}/bin/test)
      [ "$output" = "binscript-hardcode-syspath" ] || (echo "Unexpected output: $output"; exit 1)
      touch $out
    '';

  quickbin-runtime-dep =
    let
      src = pkgs.writeTextDir "main.janet" ''
        (defn main [& _] (os/execute ["hello"] :p))
      '';
      pkg = pkgs.mkJanet {
        inherit src;
        name = "quickbin-runtime-dep";
        quickbin = "main.janet";
        runtimeInputs = [ pkgs.hello ];
      };
    in
    pkgs.runCommand "quickbin-runtime-dep" { } ''
      output=$(${pkg}/bin/quickbin-runtime-dep)
      [ "$output" = "Hello, world!" ] || (echo "Unexpected output: $output"; exit 1)
      touch $out
    '';

  executable-runtime-dep =
    let
      src = pkgs.symlinkJoin {
        name = "src";
        paths = [
          (pkgs.writeTextDir "project.janet" ''
            (declare-project :name "myproj")
            (declare-executable :name "test" :entry "src/main.janet" :install true)
          '')
          (pkgs.writeTextDir "src/main.janet" ''
            (defn main [& _] (os/execute ["hello"] :p))
          '')
        ];
      };
      pkg = pkgs.mkJanet {
        inherit src;
        name = "executable-runtime-dep";
        bin = "test";
        runtimeInputs = [ pkgs.hello ];
      };
    in
    pkgs.runCommand "executable-runtime-dep" { } ''
      output=$(${pkg}/bin/executable-runtime-dep)
      [ "$output" = "Hello, world!" ] || (echo "Unexpected output: $output"; exit 1)
      touch $out
    '';

  binscript-runtime-dep =
    let
      src = pkgs.symlinkJoin {
        name = "src";
        paths = [
          (pkgs.writeTextDir "project.janet" ''
            (declare-project :name "myproj")
            (declare-binscript :main "src/test")
          '')
          (pkgs.writeTextDir "src/test" ''
            #!/usr/bin/env janet
            (os/execute ["hello"] :p)
          '')
        ];
      };
      pkg = pkgs.mkJanet {
        inherit src;
        name = "binscript-runtime-dep";
        bin = "test";
        runtimeInputs = [ pkgs.hello ];
      };
    in
    pkgs.runCommand "binscript-runtime-dep" { } ''
      output=$(${pkg}/bin/binscript-runtime-dep)
      [ "$output" = "Hello, world!" ] || (echo "Unexpected output: $output"; exit 1)
      touch $out
    '';

  # Verify extraSources dep is available at build time
  extra-sources =
    let
      # extra: a pre-fetched source tree (e.g. a flake input) passed directly
      extra = pkgs.symlinkJoin {
        name = "src";
        paths = [
          (pkgs.writeTextDir "project.janet" ''
            (declare-project :name "greetlib")
            (declare-source :source ["greetlib.janet"])
          '')
          (pkgs.writeTextDir "greetlib.janet" ''
            (defn greet [] "extra-sources")
          '')
        ];
      };
      pkg = pkgs.mkJanet {
        name = "extra-sources";
        src = pkgs.writeTextDir "main.janet" ''
          (import greetlib)
          (defn main [& args] (print (greetlib/greet)))
        '';
        quickbin = "main.janet";
        extraSources = [ extra ];
      };
    in
    pkgs.runCommand "extra-sources-check" { } ''
      output=$(${pkg}/bin/extra-sources)
      [ "$output" = "extra-sources" ] || (echo "Unexpected output: $output"; exit 1)
      touch $out
    '';

  # Ensure that scripts in dependencies get a wrapped path giving them access
  # to runtimeInputs.
  dep-binscript-runtime-inputs =
    let
      dep = pkgs.symlinkJoin {
        name = "dep-src";
        paths = [
          (pkgs.writeTextDir "project.janet" ''
            (declare-project :name "deptool")
            (declare-binscript :main "src/deptool")
          '')
          (pkgs.writeTextDir "src/deptool" ''
            #!/usr/bin/env janet
            (os/execute ["hello"] :p)
          '')
        ];
      };
      pkg = pkgs.mkJanet {
        name = "main";
        src = pkgs.writeTextDir "main.janet" ''
          (defn main [& args] (print "main"))
        '';
        quickbin = "main.janet";
        extraSources = [ dep ];
        runtimeInputs = [ pkgs.hello ];
      };
    in
    pkgs.runCommand "dep-binscript-runtime-inputs" { } ''
      output=$(${pkg}/bin/deptool)
      [ "$output" = "Hello, world!" ] || (echo "Unexpected output from deptool: $output"; exit 1)
      touch $out
    '';

  # Ensure that scripts in dependencies get their syspath replaced with the one
  # from the final package.
  dep-binscript-hardcode-syspath =
    let
      dep = pkgs.symlinkJoin {
        name = "dep-src";
        paths = [
          (pkgs.writeTextDir "project.janet" ''
            (declare-project :name "deptool")
            (declare-source :source [ "src/greetlib.janet" ])
            (declare-binscript :main "src/deptool" :hardcode-syspath true)
          '')
          (pkgs.writeTextDir "src/greetlib.janet" ''
            (defn greet [] "dep-binscript-hardcode-syspath")
          '')
          (pkgs.writeTextDir "src/deptool" ''
            #!/usr/bin/env janet
            (import greetlib)
            (defn main [& args] (print (greetlib/greet)))
          '')
        ];
      };
      pkg = pkgs.mkJanet {
        name = "main";
        src = pkgs.writeTextDir "main.janet" ''
          (defn main [& args] (print "main"))
        '';
        quickbin = "main.janet";
        extraSources = [ dep ];
      };
    in
    pkgs.runCommand "dep-binscript-hardcode-syspath" { } ''
      output=$(${pkg}/bin/deptool)
      [ "$output" = "dep-binscript-hardcode-syspath" ] || (echo "Unexpected output from deptool: $output"; exit 1)
      touch $out
    '';
}
