#!/usr/bin/env python3
"""在 116 的交互终端中隐藏输入 runtime key，并只通过 stdin 交给 SOPS。"""
import getpass
import json
import os
from pathlib import Path
import subprocess
import sys
import warnings


def main():
    if not sys.stdin.isatty():
        sys.exit("请在 116 的交互终端运行；拒绝非 TTY 输入。")
    warnings.simplefilter("error", getpass.GetPassWarning)
    repo = Path(__file__).resolve().parents[1]
    target = repo / "secrets/hosts/116.yaml"
    if not target.is_file():
        sys.exit("找不到预期的 SOPS 文件；未读取密钥。")
    # 先确认 sudo 已可用，避免输入秘密后再等待交互认证。
    if subprocess.run(["sudo", "-n", "true"], capture_output=True).returncode:
        sys.exit("需要现有 sudo 权限；未读取密钥。")
    secret = getpass.getpass("116 dotlink runtime key（不回显）: ").strip()
    if not secret.startswith("sk-") or any(c.isspace() for c in secret):
        sys.exit("输入不是预期的 OpenAI key 格式；未写入。")
    payload = json.dumps(secret).encode()
    del secret
    result = subprocess.run([
        "sudo", "-n", "env", "SOPS_AGE_KEY_FILE=/persist/var/lib/sops-nix/key.txt",
        "/etc/profiles/per-user/ysun/bin/sops", "set", "--value-stdin",
        str(target), '["dotlink-runtime-api-key"]',
    ], input=payload, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
    del payload
    if result.returncode:
        sys.exit("SOPS 写入失败；未展示可能含敏感内容的错误。请检查凭据和文件权限。")
    print("runtime key 已通过 SOPS 加密写入；未创建服务或启用隧道。")


if __name__ == "__main__":
    main()
