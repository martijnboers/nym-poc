{
  config,
  pkgs,
  lib,
  ...
}:

with lib;

let
  cfg = config.services.nymvpn;
in
{
  options.services.nymvpn = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable the NymVPN daemon (nym-vpnd) service.";
    };

    package = mkOption {
      type = types.package;
      default = pkgs.callPackage ../pkgs/nym-vpnd/default.nix {
        src = nymRepo;
        nym-libwg = null;
        rustPlatform = pkgs.rustPlatform;
        protobuf = pkgs.protobuf;
        pkg-config = pkgs.pkg-config;
        cacert = pkgs.cacert;
      };
      description = "Override package providing nym-vpnd binary.";
    };

    socksPort = mkOption {
      type = types.int;
      default = 1080;
      description = "Local SOCKS5 listen port (bound to 127.0.0.1).";
    };

    configDir = mkOption {
      type = types.path;
      default = "/etc/nym";
      description = "Configuration directory for nym-vpnd (maps to NYM_VPND_CONFIG_DIR).";
    };

    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/nym-vpnd";
      description = "Data directory for nym-vpnd (maps to NYM_VPND_DATA_DIR).";
    };

    logDir = mkOption {
      type = types.path;
      default = "/var/log/nym-vpnd";
      description = "Log directory for nym-vpnd (maps to NYM_VPND_LOG_DIR).";
    };

  };

  config = mkIf cfg.enable {
    systemd.services.nym-vpnd = {
      description = "NymVPN daemon";
      wantedBy = [ "multi-user.target" ];
      after = [
        "network-online.target"
        "NetworkManager.service"
        "systemd-resolved.service"
      ];
      serviceConfig = {
        ExecStart = "${cfg.package}/bin/nym-vpnd -v run-as-service";
        Restart = "always";
        RestartSec = "2";
        WorkingDirectory = "/";
        Environment = lib.concatStringsSep " " [
          "NYM_VPND_CONFIG_DIR=${cfg.configDir}"
          "NYM_VPND_DATA_DIR=${cfg.dataDir}"
          "NYM_VPND_LOG_DIR=${cfg.logDir}"
          "NYM_VPND_SOCKS_LISTEN=127.0.0.1:${toString cfg.socksPort}"
        ];
      };
      serviceConfig.RuntimeDirectory = "nym-vpnd";
      serviceConfig.StateDirectory = "nym-vpnd";
      serviceConfig.PIDsDirectory = "nym-vpnd";
      install.wantedBy = [ "multi-user.target" ];
    };

    # Provide nym-vpnc as a system package for admin use
    environment.systemPackages = with pkgs; [
      (cfg.package)
      pkgs.which
    ];
  };
}
