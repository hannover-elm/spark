{ pkgs ? import <nixpkgs> {} }:
let
  app = import ./app.nix {};
  neuron = import ./neuron.nix {};
in
with pkgs; stdenv.mkDerivation {
  name = "spark";
  src = builtins.path { path = ./.; name = "notes"; };
  buildInputs = [ neuron elmPackages.elm ];
  buildPhase = ''
    neuron -d notes rib
  '';
  installPhase = ''
    cp -r notes/.neuron/output $out
    cp ${app}/Main.html $out
  '';
}
