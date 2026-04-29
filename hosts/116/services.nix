{
  config,
  lib,
  pkgs,
  username,
  ...
}:

let
  mihomoDir = "/etc/sctmes/116/mihomo";
  vllmDir = "/etc/sctmes/116/vllm";
  searxngDir = "/etc/sctmes/116/searxng";
in
{
  options.sctmes.host116.services.searxng.enable = lib.mkEnableOption "SearXNG on host 116";

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
        "d /persist/mihomo 0750 ${username} users -"
      ];

      systemd.services.mihomo-compose = {
        description = "Mihomo via docker-compose";
        after = [ "docker.service" "network-online.target" ];
        requires = [ "docker.service" ];
        wants = [ "network-online.target" ];
        wantedBy = [ "multi-user.target" ];
        unitConfig.ConditionPathExists = "/persist/mihomo/config.yaml";
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          WorkingDirectory = mihomoDir;
          ExecStart = "${pkgs.docker-compose}/bin/docker-compose -f ${mihomoDir}/docker-compose.yml up -d";
          ExecStop = "${pkgs.docker-compose}/bin/docker-compose -f ${mihomoDir}/docker-compose.yml down";
          TimeoutStartSec = "0";
        };
      };

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
              - /data1/ai-serving/models:/models:ro
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
        after = [ "docker.service" "network-online.target" "data1.mount" ];
        requires = [ "docker.service" "data1.mount" ];
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
    }
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
        after = [ "docker.service" "network-online.target" "data1.mount" "jarvis-vllm-compose.service" ];
        requires = [ "docker.service" "data1.mount" ];
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
