{
  lib,
  stdenv,
  fetchFromGitHub,
  pkg-config,
  libusb1,
  openssl,
  mbedtls,
  zlib,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "goodix-cli";
  version = "1.0.0";

  src = fetchFromGitHub {
    owner = "Rockytkg";
    repo = "goodix-linux-27c6-5125";
    rev = "227eba219fa9e3fbac5bd59aca79f624f67cd11b";
    hash = "sha256-10FItQvRt7vE/mwOSYcIsJOwJobBPdE+HVeS6J75jVE=";
  };

  nativeBuildInputs = [ pkg-config ];
  buildInputs = [
    libusb1
    openssl
    mbedtls
    zlib
  ];

  buildPhase = ''
    runHook preBuild
    $CC -O2 -Wall -Iinclude $(pkg-config --cflags libusb-1.0 openssl) \
      src/transport.c src/goodix_frame.c src/goodix_cmd.c \
      src/goodix_psk.c src/goodix_tls.c src/goodix_fwupdate.c \
      src/goodix_init.c src/goodix_capture.c src/goodix_base.c \
      src/goodix_otp.c src/goodix_imgproc.c src/goodix_crc.c src/main.c \
      $(pkg-config --libs libusb-1.0 openssl) -lmbedtls -lmbedx509 -lmbedcrypto -lz -lm \
      -o goodix-cli
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -D -m 0755 goodix-cli $out/bin/goodix-cli
    install -D -m 0644 70-goodix.rules $out/lib/udev/rules.d/70-goodix.rules
    runHook postInstall
  '';

  meta = with lib; {
    description = "CLI diagnostic and calibration tool for Goodix 27c6:5125/5135 fingerprint sensors";
    homepage = "https://github.com/Rockytkg/goodix-linux-27c6-5125";
    license = licenses.gpl2Plus;
    platforms = platforms.linux;
    mainProgram = "goodix-cli";
  };
})
