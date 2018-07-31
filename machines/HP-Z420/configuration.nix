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
    # "ip=${address}::${gateway}:255.255.255.0::eth0:none"
    kernelParams = [ "ip=:::::eth0:dhcp" "intel_iommu=on" ];
  };

  boot.secrets = secrets.mkSecret secrets.HP-Z420.tinyssh.hostKey {};

  modules.openvpnClientHomeNetwork = {
    enable = true;
    macAddress = "a0:d3:c1:20:da:3f";
  };
  systemd.network = {
    enable = true;

    networks.openvpn-client-home-network = {
      address = [ "${address}/24" ];
      extraConfig = ''
        [IPv6AcceptRA]
        UseDNS=false
      '';
    };

    # Home network
    #networks."${interface}" = {
    #  name = interface;
    #  address = [ "${address}/24" ];
    #  gateway = [ gateway ];
    #  dns = [ "192.168.1.2" "2601:18a:0:7829:ba27:ebff:fe5e:6b6e" ];
    #  extraConfig = ''
    #    [IPv6AcceptRA]
    #    UseDNS=no
    #  '';
    #};

    # Dartmouth network
    networks."50-${interface}" = {
      name = interface;
      DHCP = "v4";
    };
    # Use a different MAC address on physical interface, because the normal MAC
    # is used on the VPN in order to get the same IPv6 address as when at home.
    links."50-eth0" = {
      matchConfig = {
        MACAddress = "a0:d3:c1:20:da:3f";
        # VPN interface has the same MAC, so also match the driver
        Driver = "e1000e";
      };
      linkConfig.MACAddress = "ea:d3:5b:d6:a0:6b";
    };

    netdevs."50-${interface}".netdevConfig = {
      Name = interface;
      Kind = "bridge";
    };
    networks."50-eth0" = {
      name = "eth0";
      networkConfig.Bridge = interface;
    };
  };
  networking.hostName = "HP-Z420"; # Define your hostname.
  networking.hostId = "5e9c1aa3";
  # Enable telegraf metrics for this interface
  services.telegraf.inputs.net.interfaces = [ interface ];

  # ARM binfmt-misc support
  #environment.etc = {
  #  "binfmt.d/qemu-aarch64.conf".text = ''
  #    :qemu-aarch64:M::\x7fELF\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\xb7:\xff\xff\xff\xff\xff\xff\xff\x00\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff:${pkgs.qemu}/bin/qemu-aarch64:OC
  #  '';
  #  "binfmt.d/qemu-armv7l.conf".text = ''
  #    :qemu-armv7l:M::\x7fELF\x01\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\x28\x00:\xff\xff\xff\xff\xff\xff\xff\x00\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff\xff:${pkgs.qemu}/bin/qemu-arm:
  #  '';
  #};

  environment.systemPackages = with pkgs; [
  ];

  # List services that you want to enable:

  # Set SSH port
  services.openssh.ports = [4245];

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
        recursive = true;
        processChildrenOnly = true;
        useTemplate = [ "local" ];
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
      "backup/backups/P-3400" = {
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
    } {
      source = "backup/backups/P-3400";
      target = "${remote}:backup/backups/P-3400";
      recursive = true;
    } ];
  };

  # Libvirt
  virtualisation.libvirtd = {
    enable = true;
    onShutdown = "shutdown";
  };
  users.extraUsers.ben.extraGroups = [ "libvirtd" ];

  # VFIO/PCI Passthrough
  # These modules must come before early modesetting
  boot.kernelModules = [ "vfio" "vfio_iommu_type1" "vfio_pci" "vfio_virqfd" ];
  # Quadro K4000
  boot.extraModprobeConfig ="options vfio-pci ids=10de:11fa,10de:0e0b";

  modules.syncthingBackup = {
    enable = true;
    virtualHost = "syncthing.hp-z420.benwolsieffer.com";
  };

  /*services.dnsupdate = {
    enable = true;
    addressProvider = {
      ipv4 = {
        type = "Local";
        args.interface = "eth0";
      };
    };

    dnsServices = [
    ];
  };*/

  modules.doorman.enable = true;

  networking.firewall.allowedTCPPorts = [
    8086 # InfluxDB
    22000 # Syncthing port
  ];
}
