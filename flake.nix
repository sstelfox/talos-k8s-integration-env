{
  description = "development and deployment environment for the firmament cluster";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };

        promptColor = "\\[\\033[1;36m\\]"; # Cyan
        resetColor = "\\[\\033[0m\\]";

        customBash = pkgs.writeShellScriptBin "enter-firmament-env" ''
          export PS1="${promptColor}[firmament]$resetColor \\u@\\h:\\w\\$ "
          exec ${pkgs.bash}/bin/bash "$@"
        '';

      in {
        devShells.default = pkgs.mkShell {
          name = "firmament-environment";

          buildInputs = with pkgs; [
            cilium-cli
            coreutils
            curl
            git
            iproute2
            iputils
            jq
            kubectl
            kubernetes-helm
            kyverno
            nettools
            skopeo
            yq

            customBash
          ];

          shellHook = ''
            export PS1="${promptColor}[firmament]${resetColor} \\u@\\h:\\w\\$ "
          '';
        };
      }
    );
}
