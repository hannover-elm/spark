{ pkgs ? import <nixpkgs> {} }:
let
  neuron = import ./neuron.nix {};
in
with pkgs; mkShell {
  buildInputs = [ neuron elmPackages.elm elm2nix ];
}
