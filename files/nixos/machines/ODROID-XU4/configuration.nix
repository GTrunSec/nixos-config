# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ lib, config, pkgs, ... }: let
  interface = "br0";
in {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    
    # Modules without configuration options
    ../../modules/common.nix
    ../../modules/telegraf.nix
#   ../../modules/docker.nix
    ../../modules/openvpn-server.nix

    # Modules with configuration options
    ../../modules/services/continuous-integration/aur-buildbot/worker.nix
  ];
    
  nixpkgs.config.platform = lib.systems.platforms.armv7l-hf-multiplatform // {
    name = "odroid-xu4";
    kernelBaseConfig = "odroidxu4_defconfig";
  };

  boot = {
    loader = {
      grub.enable = false;
      generic-extlinux-compatible.enable = true;
    };
    kernelPackages = lib.mkForce pkgs.linuxPackages_odroid_xu4;
  };

  systemd.network = {
    enable = true;
    networks."${interface}" = {
      name = interface;
      address = [ "192.168.1.3/24" ];
      gateway = [ "192.168.1.1" ];
      dns = [ "192.168.1.2" "2601:18a:0:7829:ba27:ebff:fe5e:6b6e" ];
    };
  };
  networking.hostName = "ODROID-XU4"; # Define your hostname.

  # Use ARM binary cache
  nix.binaryCaches = [ "http://nixos-arm.dezgeg.me/channel" ];
  nix.binaryCachePublicKeys = [ "nixos-arm.dezgeg.me-1:xBaUKS3n17BZPKeyxL4JfbTqECsT+ysbDJz29kLFRW0=%" ];
  
  environment.systemPackages = with pkgs; [
    pkgs.linuxPackages_latest.tmon
  ];
  
  # List services that you want to enable:

  # Serial terminal
  systemd.services."getty@ttySAC2".enable = true;

  # Set SSH port
  services.openssh.ports = [4243];
  
#  services.aur-buildbot-worker = {
#    enable = true;
#    workerPass = "xZdKI5whiX5MNSfWcAJ799Krhq5BZhfe11zBdamx";
#    masterHost = "hp-z420.nsupdate.info";
#  };
  
  # Enable SD card TRIM
  services.fstrim.enable = true;
}