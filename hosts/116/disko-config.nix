{
  disko.devices = {
    disk.main = {
      type = "disk";
      device = "/dev/disk/by-id/ata-INTEL_SSDSC2KB019T8_PHYF110300SW1P9DGN";
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            priority = 1;
            start = "1M";
            end = "1G";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [ "umask=0077" ];
            };
          };
          root = {
            size = "100%";
            content = {
              type = "btrfs";
              extraArgs = [ "-f" ];
              subvolumes = {
                "/nix" = {
                  mountpoint = "/nix";
                  mountOptions = [
                    "compress=zstd:1"
                    "noatime"
                    "discard=async"
                    "space_cache=v2"
                  ];
                };
                "/persist" = {
                  mountpoint = "/persist";
                  mountOptions = [
                    "compress=zstd:1"
                    "noatime"
                    "discard=async"
                    "space_cache=v2"
                  ];
                };
                "/home" = {
                  mountpoint = "/home";
                  mountOptions = [
                    "compress=zstd:1"
                    "noatime"
                    "discard=async"
                    "space_cache=v2"
                  ];
                };
                "/swap" = {
                  mountpoint = "/swap";
                  mountOptions = [
                    "noatime"
                    "discard=async"
                    "space_cache=v2"
                  ];
                  swap.swapfile = {
                    size = "16G";
                    path = "swapfile";
                  };
                };
              };
            };
          };
        };
      };
    };

    nodev."/" = {
      fsType = "tmpfs";
      mountOptions = [
        "defaults"
        "size=8G"
        "mode=755"
        "noatime"
      ];
    };
  };
}
