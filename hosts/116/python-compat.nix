{
  inputs,
  lib,
  pkgs,
  ...
}:

let
  # Codex Base 使用独立实例化的 nixpkgs-tools，主机的 Python overlay 不会影响它。
  toolPkgs =
    inputs.upstream.inputs.codex-base.inputs.nixpkgs-tools.legacyPackages.${pkgs.stdenv.hostPlatform.system};
  leanToolPkgs = toolPkgs.extend (
    _final: prev: {
      pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
        (_pythonFinal: pythonPrev: {
          # 临时规避锁定组合中 aioboto3/Moto 与 aiohttp 3.13.4 的重复 Server 头错误：
          # https://github.com/getmoto/moto/issues/9930（aiohttp 3.13.5 已修复）。
          # FastMCP 仅启用 disk/keyring/memory 后端，不使用 DynamoDB。
          # 0.3.0 的 DynamoDB 测试需要 Docker，在 Nix sandbox 内全部跳过，
          # 但收集测试时仍导入 aioboto3。排除此目录及其测试依赖，保留其他测试。
          py-key-value-aio = pythonPrev.py-key-value-aio.overridePythonAttrs (
            old:
            lib.optionalAttrs (old.version == "0.3.0") {
              nativeCheckInputs = lib.subtractLists pythonPrev.py-key-value-aio.optional-dependencies.dynamodb old.nativeCheckInputs;
              disabledTestPaths = (old.disabledTestPaths or [ ]) ++ [ "tests/stores/dynamodb" ];
            }
          );
        })
      ];
    }
  );
in
{
  # 仅替换 Codex Base 注入的同版本 mcp-nixos，保留其余 package/config/skills。
  # 正常更新 nixpkgs 后应重新评估：临时移除 default.nix 中的本模块 import，
  # 确认原版 mcp-nixos 及完整 116 system build 均通过后，删除本模块和 import。
  # 不应只因版本号变化就扩大此例外；若以后启用 DynamoDB，应恢复其测试依赖和覆盖。
  # 这里只保留当前实际执行的测试，不声称覆盖 DynamoDB。
  home-manager.sharedModules = [
    {
      options.home.packages = lib.mkOption {
        apply =
          packages:
          map (
            package: if toString package == toString toolPkgs.mcp-nixos then leanToolPkgs.mcp-nixos else package
          ) packages;
      };
    }
  ];
}
