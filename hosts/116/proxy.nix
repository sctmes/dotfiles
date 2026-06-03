{
  inputs,
  ...
}:

{
  imports = [ inputs.upstream.nixosModules.nixNetwork ];

  dotfiles.nixNetwork = {
    profile = "china";
    proxy = {
      enable = true;
      url = "http://127.0.0.1:7890";
    };
    nameservers = [
      "127.0.0.1"
      "192.168.0.1"
    ];
  };
}
