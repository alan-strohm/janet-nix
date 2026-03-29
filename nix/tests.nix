pkgs: {
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
}
