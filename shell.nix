let
  pkgs = import <nixpkgs> {};
in
pkgs.mkShell {
  packages = (with pkgs; [
    elmPackages.elm
    elmPackages.elm-format
    elmPackages.elm-language-server
    elmPackages.elm-optimize-level-2
    elmPackages.elm-review
    elmPackages.elm-test
    nodejs
    http-server
    shellcheck
    python3
    graphviz
    pandoc
  ]);

  shellHook =
    ''
    export project="$PWD"
    export build="$project/.build"
    export PATH="$project/bin:$PATH"
    '';
}