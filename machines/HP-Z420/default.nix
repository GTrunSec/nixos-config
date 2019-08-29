# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ lib, config, pkgs, secrets, ... }:
let

interface = "br0";
address = "192.168.1.5";
gateway = "192.168.1.1";

in rec {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ../../modules/config/telegraf.nix
    ../../modules/config/zfs-backup.nix
    ../../modules/config/docker.nix
    ../../modules/config/hydra.nix
    ../../modules/config/hacker-hats.nix
    ../../modules/config/aur-buildbot.nix
    ../../modules/config/influxdb
    ../../modules/config/grafana

    ../../modules
  ];

  boot = {
    # Use systemd-boot
    loader = {
      systemd-boot.enable = true;
      efi = {
        canTouchEfiVariables = true;
        efiSysMountPoint = "/boot/esp";
      };
    };
    initrd = {
      availableKernelModules = [ "e1000e" ];
      luks.devices.root.device = "/dev/disk/by-uuid/0deb8a8e-13ea-4d58-aaa8-aaf444385843";
      network = {
        enable = true;
        tinyssh = {
          port = lib.head config.services.openssh.ports;
          authorizedKeys = config.users.extraUsers.ben.openssh.authorizedKeys.keys;
          hostEd25519Key = secrets.getBootSecret secrets.HP-Z420.tinyssh.hostKey;
        };
        decryptssh.enable = true;
      };
    };
    # "ip=:::::eth0:dhcp" "intel_iommu=on"
    kernelParams = [ "ip=${address}::${gateway}:255.255.255.0::eth0:none" ];
  };

  boot.secrets = secrets.mkSecret secrets.HP-Z420.tinyssh.hostKey {};

  local.networking.vpn.dartmouth.enable = true;

  /*local.networking.vpn.home.tap.client = {
    enable = true;
    macAddress = "a0:d3:c1:20:da:3f";
    certificate = ./vpn/home/client.crt;
    privateKey = secrets.getSecret secrets.HP-Z420.vpn.home.privateKey;
  };*/
  systemd.network = {
    enable = true;

    # Dartmouth network
    /*networks."50-${interface}" = {
      name = interface;
      DHCP = "v4";
    };

    networks."50-vpn-home-tap-client" = {
      address = [ "${address}/24" ];
      extraConfig = ''
        [IPv6AcceptRA]
        UseDNS=false
      '';
    };*/

    # Home network
    networks."50-${interface}" = {
      name = interface;
      address = [ "${address}/24" ];
      gateway = [ gateway ];
      dns = [ "192.168.1.2" "2601:18a:0:7723:ba27:ebff:fe5e:6b6e" ];
      dhcpConfig.UseDNS = false;
      extraConfig = ''
        [IPv6AcceptRA]
        UseDNS=no
      '';
    };

    # Use physical interface MAC on bridge to get same IPs
    netdevs."50-${interface}".netdevConfig = {
      Name = interface;
      Kind = "bridge";
      MACAddress = "a0:d3:c1:20:da:3f";
    };

    # Attach the physical interface to the bridge
    #
    # Use a different MAC address on physical interface, because the normal MAC
    # is used on the VPN and bridge in order to get consistent IPs.
    networks."50-eth0" = {
      name = "eth0";
      networkConfig.Bridge = interface;
      linkConfig.MACAddress = "ea:d3:5b:d6:a0:6b";
    };
  };
  networking = {
    hostName = "HP-Z420"; # Define your hostname.
    hostId = "5e9c1aa3";
  };
  # Enable telegraf metrics for this interface
  services.telegraf.inputs.net.interfaces = [ interface ];

  # List services that you want to enable:

  # Set SSH port
  services.openssh.ports = [4245];

  # Restricted key for use with sftp only (from my phone)
  # sshd is configured to not use ~/.ssh/authorized_keys, so this can't be
  # bypassed by adding a new key to that file
  users.users.ben.openssh.authorizedKeys.keys = [ "restrict,command=\"${pkgs.openssh}/libexec/sftp-server\" ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDAex1EmjrC/chhr58KDRLWwLD4AtVLArdN82hMT6mhWQF5TqKidRheoEhzlkBQ/yTa2AMB9SY6TxlaHbYD0iJbUePHGAtGqiig7A52z+r+Q3+8Gm7LAEHbaXN80aEbnUA0Rr39zVUwM9LwGiVjKmSqL7Fbn2t+1qvj8g4yOF40dIYz/WXCUBLr/JRUFNDK02KScEYEe5b8eCNS+FoT2xhQuZKsC9z0zYuEhGffIVX9OT7IDO6tI+mXOsuukRMiEmb/ocSOmD4LrAMrhSWUvbh2FahaB166xLBCns+fX8/CwSGdyoQrquI5QiyvO/PsK9b2bn7OK72NFoNwZG3zQ/XWDFo+HF79KXQ5QngU7gTx9O5poghGMqtXz37sWJWI3l7EhYN83/CfnaytebJ8wfPcEnVyi1QAlG8S8yaw961uTzFPbQEyB+O9uI0+yPv9cN5W2cEGwDSSmdNi8bJpxkEh3eFno1yAm5GRq5aYboMhZ/VkRNCvgfrSNIpda/xLVF2Bu7umbS63YCDnWW8fUpZJEZ4BWXo4wBzO+kgPqHXxi6eTGdRxYBAIxH+cZ7eX/dd5s3fcXrHWpJKXxHMqiRXXun5SzMtC4jyHsrH2qX/hWtwVsJl1I4Mk5cbmjJ3S45hAU+d5h0lLT65zi6kXnYlsyZkHBVgHvetfOwRyz2ceKQ== ce:84:83:be:0c:ab:55:67:74:84:17:6d:e3:a9:e3:92 GalaxyS5_sftp.id_rsa" ];

  services.aur-buildbot-worker = {
    enable = true;
    workerPassFile = secrets.getSecret secrets.HP-Z420.aurBuildbot.password;
    masterHost = "hp-z420.benwolsieffer.com";
    adminMessage = "Ben Wolsieffer <benwolsieffer@gmail.com>";
  };

  services.sanoid = {
    datasets = {
      "root/root" = {
        useTemplate = [ "local" ];
      };
      "root/home" = {
        useTemplate = [ "local" ];
      };
      "root/vm" = {
        useTemplate = [ "local" ];
        recursive = true;
        processChildrenOnly = true;
      };
      # Each backup node takes its own snapshots of data
      "backup/data" = {
        useTemplate = [ "backup" ];
        autosnap = true;
        recursive = true;
        processChildrenOnly = true;
      };
      # Prune all backups with one rule
      "backup/backups" = {
        useTemplate = [ "backup" ];
        recursive = true;
        processChildrenOnly = true;
      };

      # Snapshots of non-ZFS devices that backup to this node
      "backup/backups/Dell-Inspiron-15" = {
        useTemplate = [ "backup" ];
        autosnap = true;
        recursive = true;
        processChildrenOnly = true;
      };
      "backup/backups/Dell-Inspiron-15-Windows" = {
        useTemplate = [ "backup" ];
        autosnap = true;
        recursive = true;
      };
    };
  };

  services.syncoid = let
    remote = "backup@rock64.benwolsieffer.com";
  in {
    defaultArguments = "--sshport 4246";
    commands = [ {
      source = "root/root";
      target = "backup/backups/HP-Z420/root";
    } {
      source = "root/home";
      target = "backup/backups/HP-Z420/home";
    } {
      source = "root/vm";
      target = "backup/backups/HP-Z420/vm";
      recursive = true;
    } {
      source = "backup/backups/HP-Z420";
      target = "${remote}:backup/backups/HP-Z420";
      recursive = true;
    } {
      source = "backup/backups/Dell-Inspiron-15";
      target = "${remote}:backup/backups/Dell-Inspiron-15";
      recursive = true;
    } {
      source = "backup/backups/Dell-Inspiron-15-Windows";
      target = "${remote}:backup/backups/Dell-Inspiron-15-Windows";
      recursive = true;
    } ];
  };

  # Libvirt
  virtualisation.libvirtd = {
    enable = true;
    onShutdown = "shutdown";
  };
  users.users.ben.extraGroups = [ "libvirtd" ];

  # VFIO/PCI Passthrough
  # These modules must come before early modesetting
  boot.kernelModules = [ "vfio" "vfio_iommu_type1" "vfio_pci" "vfio_virqfd" ];
  # Quadro K4000
  boot.extraModprobeConfig ="options vfio-pci ids=10de:11fa,10de:0e0b";

  modules.syncthingBackup = {
    enable = true;
    virtualHost = "syncthing.hp-z420.benwolsieffer.com";
  };

  networking.firewall.allowedTCPPorts = [
    8086 # InfluxDB
    22000 # Syncthing port
  ];

  environment.secrets = secrets.mkSecret secrets.HP-Z420.vpn.home.privateKey {};
}
