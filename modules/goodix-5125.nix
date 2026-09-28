{ config, lib, pkgs, ... }:

let
  cfg = config.hardware.fingerprint.goodix-5125;
in
{
  options.hardware.fingerprint.goodix-5125 = {
    enable = lib.mkEnableOption "Goodix 27c6:5125 / 27c6:5135 fingerprint reader support";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.libfprint-goodix-5125;
      defaultText = lib.literalExpression "pkgs.libfprint-goodix-5125";
      description = "libfprint package built with goodixgf driver.";
    };

    scoreThreshold = lib.mkOption {
      type = lib.types.int;
      default = 10;
      description = ''
        SIGFM match score threshold.
        Lower values (e.g. 8-12) are more forgiving for varied finger touches.
        Higher values (e.g. 20) are stricter.
      '';
    };

    keepAlive = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Run fprintd with --no-timeout so the Goodix device remains initialized
        and ready for instantaneous fingerprint verification without sleep lag.
      '';
    };

    enableDebug = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Enable detailed libfprint & SIGFM score logging in journalctl.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.fprintd = {
      enable = true;
      package = pkgs.fprintd.override {
        libfprint = cfg.package;
      };
    };

    services.udev.packages = [ cfg.package ];

    environment.systemPackages = [ cfg.package ];

    systemd.services.fprintd = {
      environment = lib.mkMerge [
        { GOODIX_SCORE_THRESHOLD = toString cfg.scoreThreshold; }
        (lib.mkIf cfg.enableDebug { G_MESSAGES_DEBUG = "all"; })
      ];
      serviceConfig.ExecStart = lib.mkIf cfg.keepAlive [
        ""
        "${config.services.fprintd.package}/libexec/fprintd -t"
      ];
    };
  };
}
