{
  config,
  lib,
  pkgs,
  username,
  ...
}:

let
  labelStudioDataDir = "/var/lib/label-studio";
  labelStudioHost = "https://label.bigdick.live:2053";
  labelStudioDomain = "label.bigdick.live";
  labelStudioAdminEmail = "ysun@sctmes.com";
  ddnsGoIpv6Regex = ".*:3e7c:3fff:fed3:88b7$";
  mihomoDir = "/etc/sctmes/116/mihomo";
  mihomoDefaultConfig = pkgs.writeText "mihomo-default-config.yaml" ''
    mixed-port: 7890
    allow-lan: true
    external-controller: 0.0.0.0:9090

    external-ui: ./ui
    external-ui-name: metacubexd
    external-ui-url: https://github.com/MetaCubeX/metacubexd/archive/refs/heads/gh-pages.zip

    tun:
      enable: true

    dns:
      enable: true
      listen: 0.0.0.0:53
      enhanced-mode: fake-ip
      fake-ip-range: 198.18.0.1/16
      default-nameserver:
        - 192.168.0.1
      nameserver:
        - 192.168.0.1
        - https://dns.alidns.com/dns-query
        - https://dns.google/dns-query
  '';
  enforceMihomoRoutingPolicy = pkgs.writeShellApplication {
    name = "enforce-mihomo-routing-policy";
    runtimeInputs = with pkgs; [
      coreutils
      yq-go
      mihomo
    ];
    excludeShellChecks = [ "SC2016" ];
    text = ''
      set -euo pipefail

      usage='usage: enforce-mihomo-routing-policy [--check|--apply] CONFIG_PATH'
      if [ "$#" -ne 2 ]; then
        printf '%s\n' "$usage" >&2
        exit 64
      fi

      case "$1" in
        --check|--apply)
          mode="$1"
          ;;
        *)
          printf '%s\n' "$usage" >&2
          exit 64
          ;;
      esac
      config_input="$2"

      fail() {
        printf '%s\n' "$1" >&2
        exit 1
      }

      if [ ! -f "$config_input" ]; then
        fail 'error: config is not a regular file'
      fi
      if ! config_path="$(realpath -- "$config_input" 2>/dev/null)"; then
        fail 'error: cannot resolve config'
      fi
      config_dir="$(dirname -- "$config_path")"

      if yq eval -e '((.["proxy-providers"] // {}) | keys | length) == 0' "$config_path" >/dev/null 2>&1; then
        printf '%s\n' 'ready: WestWorld Japan matches=0'
        exit 0
      fi

      if ! yq eval -e '
        (.["proxy-providers"] // {}) as $providers |
        (.["proxy-groups"] // []) as $groups |
        [
          (($providers | to_entries | map(select(.key == "WestWorld")) | length) == 1),
          (($groups | map(select(.name == "Proxy")) | length) == 1),
          (($groups | map(select(.name == "WestWorld Auto")) | length) == 1),
          (($groups | map(select(.name == "YToo Backup")) | length) <= 1)
        ] | all
      ' "$config_path" >/dev/null 2>&1; then
        fail 'error: required Mihomo routing structure is invalid'
      fi

      if ! yq eval -e '
        (.["proxy-providers"].WestWorld.path | tag) == "!!str"
        and (.["proxy-providers"].WestWorld.path | length) > 0
      ' "$config_path" >/dev/null 2>&1; then
        fail 'error: WestWorld provider path is invalid'
      fi
      if ! provider_path="$(yq eval -r '.["proxy-providers"].WestWorld.path' "$config_path" 2>/dev/null)"; then
        fail 'error: WestWorld provider path is invalid'
      fi
      case "$provider_path" in
        ""|/*)
          fail 'error: WestWorld provider path is invalid'
          ;;
      esac
      if ! provider_cache="$(realpath -m -- "$config_dir/$provider_path" 2>/dev/null)"; then
        fail 'error: WestWorld provider cache is unavailable'
      fi
      case "$provider_cache" in
        "$config_dir"/*)
          ;;
        *)
          fail 'error: WestWorld provider path is unsafe'
          ;;
      esac
      if [ ! -f "$provider_cache" ] || [ ! -r "$provider_cache" ]; then
        fail 'error: WestWorld provider cache is unavailable'
      fi

      count_japan_matches() {
        yq eval '[.proxies[]? | select(.name | test("(?i)(日本|🇯🇵|\\bJP\\b)"))] | length' "$provider_cache" 2>/dev/null
      }

      if ! japan_matches="$(count_japan_matches)"; then
        fail 'error: cannot inspect WestWorld provider cache'
      fi
      if ! [[ "$japan_matches" =~ ^[0-9]+$ ]] || [ "$japan_matches" -le 0 ]; then
        fail 'error: WestWorld provider cache has no eligible Japan nodes'
      fi
      printf 'ready: WestWorld Japan matches=%s\n' "$japan_matches"

      if [ "$mode" = '--check' ]; then
        exit 0
      fi

      target_state_matches() {
        yq eval -e '
          (.["proxy-groups"] // []) as $groups |
          ($groups | map(select(.name == "Proxy"))) as $proxy |
          ($groups | map(select(.name == "WestWorld Auto"))) as $westworld |
          ($groups | map(select(.name == "YToo Backup"))) as $backup |
          [
            (($proxy | length) == 1),
            ($proxy[0].type == "select"),
            (($proxy[0].proxies | length) == 1),
            ($proxy[0].proxies[0] == "WestWorld Auto"),
            ($proxy[0] | (
              has("use")
              or has("url")
              or has("interval")
              or has("tolerance")
              or has("lazy")
              or has("filter")
              or has("exclude-filter")
            ) | not),
            (($westworld | length) == 1),
            ($westworld[0].type == "url-test"),
            (($westworld[0].use | length) == 1),
            ($westworld[0].use[0] == "WestWorld"),
            ($westworld[0].url == "https://www.gstatic.com/generate_204"),
            ($westworld[0].interval == 1800),
            ($westworld[0].tolerance == 0),
            ($westworld[0] | has("lazy")),
            ($westworld[0].lazy == false),
            ($westworld[0].filter == "(?i)(日本|🇯🇵|\\bJP\\b)"),
            ($westworld[0] | (has("proxies") or has("exclude-filter")) | not),
            (($backup | length) == 0)
          ] | all
        ' "$1" >/dev/null 2>&1
      }

      if target_state_matches "$config_path"; then
        exit 0
      fi

      if ! original_metadata="$(stat -c '%a %u %g' -- "$config_path" 2>/dev/null)"; then
        fail 'error: cannot read config metadata'
      fi
      read -r original_mode original_uid original_gid <<< "$original_metadata"

      backup_path="$config_path.before-westworld-japan-policy"
      if [ ! -e "$backup_path" ] && [ ! -L "$backup_path" ]; then
        if ! cp --no-clobber --preserve=mode,ownership -- "$config_path" "$backup_path" 2>/dev/null; then
          fail 'error: cannot create routing-policy backup'
        fi
      fi

      if ! tmp_file="$(mktemp "$config_dir/.mihomo-routing-policy.XXXXXX" 2>/dev/null)"; then
        fail 'error: cannot create temporary config'
      fi
      cleanup() {
        if [ -n "$tmp_file" ]; then
          rm -f -- "$tmp_file"
        fi
      }
      trap cleanup EXIT

      if ! yq eval --output-format=yaml '
        (.["proxy-groups"][] | select(.name == "Proxy")) |= (
          .type = "select"
          | .proxies = ["WestWorld Auto"]
          | del(.use, .url, .interval, .tolerance, .lazy, .filter, .["exclude-filter"])
        )
        | (.["proxy-groups"][] | select(.name == "WestWorld Auto")) |= (
          .type = "url-test"
          | .use = ["WestWorld"]
          | .url = "https://www.gstatic.com/generate_204"
          | .interval = 1800
          | .tolerance = 0
          | .lazy = false
          | .filter = "(?i)(日本|🇯🇵|\\bJP\\b)"
          | del(.proxies, .["exclude-filter"])
        )
        | .["proxy-groups"] |= map(select(.name != "YToo Backup"))
      ' "$config_path" > "$tmp_file" 2>/dev/null; then
        fail 'error: cannot transform routing policy'
      fi

      if ! target_state_matches "$tmp_file"; then
        fail 'error: transformed routing policy does not match target'
      fi
      if ! japan_matches_after="$(count_japan_matches)"; then
        fail 'error: cannot recheck WestWorld provider cache'
      fi
      if ! [[ "$japan_matches_after" =~ ^[0-9]+$ ]] || [ "$japan_matches_after" -le 0 ]; then
        fail 'error: WestWorld provider cache has no eligible Japan nodes'
      fi
      if ! mihomo -t -d "$config_dir" -f "$tmp_file" >/dev/null 2>&1; then
        fail 'error: transformed Mihomo config is invalid'
      fi
      if ! chown "$original_uid:$original_gid" "$tmp_file" 2>/dev/null \
        || ! chmod "$original_mode" "$tmp_file" 2>/dev/null; then
        fail 'error: cannot prepare transformed config metadata'
      fi
      if ! mv -f -- "$tmp_file" "$config_path" 2>/dev/null; then
        fail 'error: cannot replace Mihomo config'
      fi
      tmp_file=""
    '';
  };
  aiServingDir = "/var/lib/ai-serving";
  vllmDir = "/etc/sctmes/116/vllm";
  searxngDir = "/etc/sctmes/116/searxng";
in
{
  options.sctmes.host116.services = {
    jarvisVllm.enable = lib.mkEnableOption "Jarvis Gemma stack on host 116";
    searxng.enable = lib.mkEnableOption "SearXNG on host 116";
  };

  config = lib.mkMerge [
    {
      environment.etc."sctmes/116/mihomo/docker-compose.yml".text = ''
        services:
          mihomo:
            image: docker.io/metacubex/mihomo:latest
            container_name: mihomo
            network_mode: host
            pid: host
            cap_add:
              - ALL
            volumes:
              - /persist/mihomo:/root/.config/mihomo
              - /dev/net/tun:/dev/net/tun
            restart: unless-stopped
      '';

      systemd.tmpfiles.rules = [
        "d ${labelStudioDataDir} 0755 root root -"
        "d ${labelStudioDataDir}/data 0755 1001 1001 -"
        "d ${labelStudioDataDir}/postgres 0700 70 70 -"
        "z ${labelStudioDataDir} 0755 root root -"
        "Z ${labelStudioDataDir}/data 0755 1001 root -"
        "Z ${labelStudioDataDir}/postgres 0700 70 70 -"
        "d /persist/mihomo 0750 ${username} users -"
        "d ${aiServingDir}/models 0755 root root -"
        "d ${aiServingDir}/searxng 0755 root root -"
        "d ${aiServingDir}/cache 0755 root root -"
      ];

      sops.secrets.cloudflare-ddns-token = { };
      sops.secrets.label-studio-admin-password = { };
      sops.secrets.label-studio-postgres-password = { };
      sops.secrets.mihomo-controller-secret = { };

      services.caddy = {
        enable = true;
        virtualHosts."${labelStudioDomain}:2053".extraConfig = ''
          tls internal
          reverse_proxy 127.0.0.1:18080
        '';
      };

      sops.templates."cloudflare-ddns-compose.yml".content = ''
        services:
          ddns-go:
            image: jeessy/ddns-go
            container_name: ddns-go
            network_mode: host
            read_only: true
            cap_drop:
              - ALL
            security_opt:
              - no-new-privileges:true
            volumes:
              - ${config.sops.templates."ddns-go-config.yaml".path}:/root/.ddns_go_config.yaml:ro
            command:
              - -noweb
              - -f
              - "300"
              - -cacheTimes
              - "5"
              - -c
              - /root/.ddns_go_config.yaml
            restart: unless-stopped
      '';

      sops.templates."ddns-go-config.yaml".content = ''
        dnsconf:
          - name: cloudflare
            ipv4:
              enable: false
              gettype: url
              url: ""
              netinterface: ""
              cmd: ""
              domains:
                - ""
            ipv6:
              enable: true
              gettype: netInterface
              url: ""
              netinterface: enp6s0
              cmd: ""
              ipv6reg: "${ddnsGoIpv6Regex}"
              domains:
                - "${labelStudioDomain}?proxied=true"
            dns:
              name: cloudflare
              id: ""
              secret: ${config.sops.placeholder."cloudflare-ddns-token"}
            ttl: "1"
        user:
          username: ""
          password: ""
        webhook:
          webhookurl: ""
          webhookrequestbody: ""
          webhookheaders: ""
        notallowwanaccess: true
        lang: zh
      '';

      sops.templates."label-studio-compose.yml".content = ''
        services:
          nginx:
            image: heartexlabs/label-studio:latest
            container_name: label-studio-nginx
            ports:
              - "127.0.0.1:18080:8085"
            depends_on:
              - app
            environment:
              - LABEL_STUDIO_HOST=${labelStudioHost}
            volumes:
              - ${labelStudioDataDir}/data:/label-studio/data:rw
            command: nginx
            restart: unless-stopped

          app:
            image: heartexlabs/label-studio:latest
            container_name: label-studio-app
            expose:
              - "8000"
            depends_on:
              - db
            environment:
              - DJANGO_DB=default
              - POSTGRE_NAME=postgres
              - POSTGRE_USER=postgres
              - POSTGRE_PASSWORD=${config.sops.placeholder."label-studio-postgres-password"}
              - POSTGRE_PORT=5432
              - POSTGRE_HOST=db
              - LABEL_STUDIO_HOST=${labelStudioHost}
              - CSRF_TRUSTED_ORIGINS=${labelStudioHost}
              - LABEL_STUDIO_DISABLE_SIGNUP_WITHOUT_LINK=true
              - LABEL_STUDIO_USERNAME=${labelStudioAdminEmail}
              - LABEL_STUDIO_PASSWORD=${config.sops.placeholder."label-studio-admin-password"}
              - JSON_LOG=1
            volumes:
              - ${labelStudioDataDir}/data:/label-studio/data:rw
            command: label-studio-uwsgi
            restart: unless-stopped

          db:
            image: pgautoupgrade/pgautoupgrade:17-alpine
            container_name: label-studio-db
            hostname: db
            environment:
              - POSTGRES_USER=postgres
              - POSTGRES_PASSWORD=${config.sops.placeholder."label-studio-postgres-password"}
            volumes:
              - ${labelStudioDataDir}/postgres:/var/lib/postgresql/data
            restart: unless-stopped
      '';

      systemd.services.cloudflare-ddns-compose = {
        description = "Cloudflare DDNS via ddns-go";
        after = [ "docker.service" "network-online.target" ];
        requires = [ "docker.service" ];
        wants = [ "network-online.target" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          WorkingDirectory = "/tmp";
          ExecStart = "${pkgs.docker-compose}/bin/docker-compose -p cloudflare-ddns -f ${config.sops.templates."cloudflare-ddns-compose.yml".path} up -d --remove-orphans";
          ExecStop = "${pkgs.docker-compose}/bin/docker-compose -p cloudflare-ddns -f ${config.sops.templates."cloudflare-ddns-compose.yml".path} down";
          TimeoutStartSec = "0";
        };
      };

      systemd.services.label-studio-compose = {
        description = "Label Studio via docker-compose";
        after = [ "docker.service" "network-online.target" ];
        requires = [ "docker.service" ];
        wants = [ "network-online.target" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          WorkingDirectory = "/tmp";
          ExecStart = "${pkgs.docker-compose}/bin/docker-compose -p label-studio -f ${config.sops.templates."label-studio-compose.yml".path} up -d";
          ExecStop = "${pkgs.docker-compose}/bin/docker-compose -p label-studio -f ${config.sops.templates."label-studio-compose.yml".path} down";
          TimeoutStartSec = "0";
        };
      };

      systemd.services.mihomo-config-bootstrap = {
        description = "Bootstrap local Mihomo config";
        before = [ "mihomo-compose.service" ];
        requiredBy = [ "mihomo-compose.service" ];
        path = [ enforceMihomoRoutingPolicy ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = ''
          set -euo pipefail

          install -d -m 0750 -o ${username} -g users /persist/mihomo

          if [ ! -e /persist/mihomo/config.yaml ]; then
            install -m 0640 -o ${username} -g users ${mihomoDefaultConfig} /persist/mihomo/config.yaml
          fi

          secret="$(${pkgs.coreutils}/bin/cat ${config.sops.secrets.mihomo-controller-secret.path})"
          escaped_secret="$(printf '%s' "$secret" | ${pkgs.gnused}/bin/sed 's/[\/&]/\\&/g')"
          if ${pkgs.gnugrep}/bin/grep -q '^secret:' /persist/mihomo/config.yaml; then
            ${pkgs.gnused}/bin/sed -i "s/^secret:.*/secret: $escaped_secret/" /persist/mihomo/config.yaml
          else
            ${pkgs.gnused}/bin/sed -i "/^external-controller:/a secret: $escaped_secret" /persist/mihomo/config.yaml
          fi

          if ! ${pkgs.gnugrep}/bin/grep -q '^dns:' /persist/mihomo/config.yaml; then
            cat >> /persist/mihomo/config.yaml <<'EOF'

dns:
  enable: true
  listen: 0.0.0.0:53
  enhanced-mode: fake-ip
  fake-ip-range: 198.18.0.1/16
  default-nameserver:
    - 192.168.0.1
  nameserver:
    - 192.168.0.1
    - https://dns.alidns.com/dns-query
    - https://dns.google/dns-query
EOF
          fi

          enforce-mihomo-routing-policy --apply /persist/mihomo/config.yaml
        '';
      };

      systemd.services.mihomo-compose = {
        description = "Mihomo via docker-compose";
        after = [ "docker.service" "network-online.target" ];
        requires = [ "docker.service" ];
        wants = [ "network-online.target" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          WorkingDirectory = mihomoDir;
          ExecStart = "${pkgs.docker-compose}/bin/docker-compose -f ${mihomoDir}/docker-compose.yml up -d";
          ExecStop = "${pkgs.docker-compose}/bin/docker-compose -f ${mihomoDir}/docker-compose.yml down";
          ExecStopPost = "-${pkgs.iproute2}/bin/ip link delete Meta";
          TimeoutStartSec = "0";
        };
      };
    }
    (lib.mkIf config.sctmes.host116.services.jarvisVllm.enable {
      environment.etc."sctmes/116/vllm/Dockerfile".text = ''
        FROM vllm/vllm-openai:gemma4

        USER root
        RUN apt-get update \
            && apt-get install -y --no-install-recommends ffmpeg libsndfile1 \
            && rm -rf /var/lib/apt/lists/* \
            && pip install --no-cache-dir "vllm[audio]" \
            && pip install --no-cache-dir --upgrade https://github.com/huggingface/transformers/archive/refs/heads/main.zip
      '';

      environment.etc."sctmes/116/vllm/transcription-shim/app.py".text = ''
        from __future__ import annotations

        import base64
        import mimetypes
        import os
        from typing import Any

        import httpx
        from fastapi import FastAPI, File, Form, HTTPException, UploadFile
        from fastapi.responses import JSONResponse, PlainTextResponse

        app = FastAPI()

        OPENAI_BASE_URL = os.getenv("OPENAI_BASE_URL", "http://vllm:8080/v1").rstrip("/")
        OPENAI_MODEL = os.getenv("OPENAI_MODEL", "google/gemma-4-E4B-it")
        DEFAULT_PROMPT = os.getenv(
            "TRANSCRIPTION_PROMPT",
            "Provide a verbatim transcription of the audio. Return only the transcript.",
        )
        DEFAULT_MAX_TOKENS = int(os.getenv("MAX_TOKENS", "1024"))


        @app.get("/healthz")
        async def healthz() -> dict[str, str]:
            return {"status": "ok"}


        @app.post("/v1/audio/transcriptions")
        async def transcriptions(
            file: UploadFile = File(...),
            model: str | None = Form(None),
            prompt: str | None = Form(None),
            language: str | None = Form(None),
            response_format: str | None = Form(None),
            temperature: float | None = Form(None),
            max_tokens: int | None = Form(None),
            **_: Any,
        ):
            audio = await file.read()
            if not audio:
                raise HTTPException(status_code=400, detail="uploaded audio file is empty")

            mime = file.content_type or mimetypes.guess_type(file.filename or "")[0] or "application/octet-stream"
            audio_url = f"data:{mime};base64,{base64.b64encode(audio).decode()}"

            instruction = prompt.strip() if prompt else DEFAULT_PROMPT
            if language:
                instruction = f"The audio language is {language}. {instruction}"

            payload = {
                "model": model or OPENAI_MODEL,
                "messages": [
                    {
                        "role": "user",
                        "content": [
                            {"type": "audio_url", "audio_url": {"url": audio_url}},
                            {"type": "text", "text": instruction},
                        ],
                    }
                ],
                "max_tokens": max_tokens or DEFAULT_MAX_TOKENS,
                "temperature": 0 if temperature is None else temperature,
            }

            try:
                async with httpx.AsyncClient(timeout=httpx.Timeout(600.0)) as client:
                    upstream = await client.post(f"{OPENAI_BASE_URL}/chat/completions", json=payload)
            except httpx.HTTPError as exc:
                raise HTTPException(status_code=502, detail=f"upstream request failed: {exc}") from exc

            if upstream.status_code != 200:
                raise HTTPException(status_code=upstream.status_code, detail=upstream.text)

            body = upstream.json()
            text = body["choices"][0]["message"]["content"]

            if response_format == "text":
                return PlainTextResponse(text)

            return JSONResponse({"text": text})
      '';

      sops.templates."jarvis-vllm-compose.yml".content = ''
        services:
          vllm:
            image: vllm/vllm-openai:gemma4-audio
            build:
              context: ${vllmDir}
              dockerfile: Dockerfile
            ipc: host
            ports:
              - "8080:8080"
            volumes:
              - ${aiServingDir}/models:/models:ro
            environment:
              - NVIDIA_VISIBLE_DEVICES=0
              - PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True
            command: >
              --model /models/gemma-4-E4B-it
              --served-model-name google/gemma-4-E4B-it
              --max-model-len 8192
              --gpu-memory-utilization 0.85
              --host 0.0.0.0
              --port 8080
            restart: unless-stopped
            deploy:
              resources:
                reservations:
                  devices:
                    - driver: nvidia
                      device_ids: ["0"]
                      capabilities: [gpu]

          transcription:
            image: ${config.sops.placeholder."docker-registry-host-ghcr"}/speaches-ai/speaches:latest-cuda-12.6.3
            container_name: transcription-shim
            ports:
              - "8090:8000"
            volumes:
              - ${vllmDir}/transcription-shim/app.py:/home/ubuntu/speaches/app.py:ro
            working_dir: /home/ubuntu/speaches
            command: >
              uvicorn app:app
              --host 0.0.0.0
              --port 8000
            environment:
              - NVIDIA_VISIBLE_DEVICES=1
              - NVIDIA_DRIVER_CAPABILITIES=compute,utility
              - OPENAI_BASE_URL=http://vllm:8080/v1
              - OPENAI_MODEL=google/gemma-4-E4B-it
              - TRANSCRIPTION_PROMPT=Provide a verbatim transcription of the audio. Return only the transcript.
              - MAX_TOKENS=1024
            depends_on:
              - vllm
            restart: unless-stopped
      '';

      systemd.services.jarvis-vllm-compose = {
        description = "Jarvis Gemma stack via docker-compose";
        after = [ "docker.service" "network-online.target" ];
        requires = [ "docker.service" ];
        wants = [ "network-online.target" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          WorkingDirectory = vllmDir;
          ExecStart = "${pkgs.docker-compose}/bin/docker-compose -f ${config.sops.templates."jarvis-vllm-compose.yml".path} up -d --build";
          ExecStop = "${pkgs.docker-compose}/bin/docker-compose -f ${config.sops.templates."jarvis-vllm-compose.yml".path} down";
          TimeoutStartSec = "0";
        };
      };
    })
    (lib.mkIf config.sctmes.host116.services.searxng.enable {
      sops.templates."jarvis-searxng-settings.yml" = {
        content = ''
          use_default_settings:
            engines:
              remove:
                - wikidata
                - startpage
                - duckduckgo
                - karmasearch
                - karmasearch images
                - karmasearch news
                - karmasearch videos

          server:
            secret_key: "${config.sops.placeholder."jarvis-searxng-secret-key"}"
            bind_address: "0.0.0.0"
            port: 8080
            limiter: false

          search:
            safe_search: 0
            autocomplete: ""
            default_lang: ""
            formats:
              - html
              - json

          engines:
            - name: google
              engine: google
              shortcut: g
              disabled: false
            - name: bing
              engine: bing
              shortcut: b
              disabled: false
            - name: wikipedia
              engine: wikipedia
              shortcut: wp
              disabled: false
        '';
      };

      environment.etc."sctmes/116/searxng/docker-compose.yml".text = ''
        services:
          searxng:
            image: searxng/searxng:latest
            container_name: searxng
            ports:
              - "8888:8080"
            volumes:
              - ${config.sops.templates."jarvis-searxng-settings.yml".path}:/etc/searxng/settings.yml:ro
            environment:
              - SEARXNG_BASE_URL=http://192.168.0.116:8888/
              - HTTP_PROXY=http://192.168.0.116:7890
              - HTTPS_PROXY=http://192.168.0.116:7890
              - ALL_PROXY=http://192.168.0.116:7890
            restart: unless-stopped
      '';

      systemd.services.jarvis-searxng-compose = {
        description = "Jarvis SearXNG via docker-compose";
        after = [ "docker.service" "network-online.target" "jarvis-vllm-compose.service" ];
        requires = [ "docker.service" ];
        wants = [ "network-online.target" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          WorkingDirectory = searxngDir;
          ExecStart = "${pkgs.docker-compose}/bin/docker-compose -f ${searxngDir}/docker-compose.yml up -d";
          ExecStop = "${pkgs.docker-compose}/bin/docker-compose -f ${searxngDir}/docker-compose.yml down";
          TimeoutStartSec = "0";
        };
      };
    })
  ];
}
