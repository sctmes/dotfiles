{
  autoPatchelfHook,
  fetchurl,
  lib,
  makeWrapper,
  stdenv,
  zlib,
}:

stdenv.mkDerivation rec {
  pname = "futu-opend";
  version = "10.8.6818";

  src = fetchurl {
    url = "https://softwaredownload.futunn.com/Futu_OpenD_${version}_Ubuntu18.04.tar.gz";
    hash = "sha256-m/H1DNydstAwvSwdtNr04JbWgQoeW9sGO5OV+UBR5xY=";
  };

  sourceRoot = "Futu_OpenD_${version}_Ubuntu18.04/Futu_OpenD_${version}_Ubuntu18.04";

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];

  buildInputs = [
    stdenv.cc.cc.lib
    zlib
  ];

  installPhase = ''
    runHook preInstall

    install -dm755 "$out/share/futu-opend" "$out/bin"
    cp -a . "$out/share/futu-opend/"

    makeWrapper "$out/share/futu-opend/FutuOpenD" "$out/bin/futu-opend" \
      --chdir "$out/share/futu-opend"

    runHook postInstall
  '';

  meta = {
    description = "Futu OpenD command line gateway";
    homepage = "https://openapi.futunn.com/futu-api-doc/en/opend/opend-cmd.html";
    license = lib.licenses.unfree;
    mainProgram = "futu-opend";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
