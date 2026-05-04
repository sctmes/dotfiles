{
  ...
}:

{
  boot.swraid.mdadmConf = ''
    MAILADDR root
    ARRAY /dev/md/raid-data1 UUID=d3818b39:8ab2ff8b:0c735c67:1ec5c9d8 name=bigdick:0
  '';

  fileSystems."/data1" = {
    device = "/dev/disk/by-uuid/16530ffc-a911-476d-a071-9e368d236e57";
    fsType = "ext4";
    options = [ "defaults" "noatime" ];
  };

  systemd.tmpfiles.rules = [
    "d /data1/backups 0755 root root -"
  ];
}
