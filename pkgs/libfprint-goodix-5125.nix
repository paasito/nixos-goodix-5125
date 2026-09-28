{
  lib,
  stdenv,
  fetchFromGitHub,
  pkg-config,
  meson,
  ninja,
  gobject-introspection,
  python3,
  gusb,
  pixman,
  glib,
  cairo,
  libgudev,
  openssl,
  mbedtls,
  opencv,
  doctest,
  zlib,
  libusb1,
}:

let
  srcDriver = fetchFromGitHub {
    owner = "Rockytkg";
    repo = "goodix-linux-27c6-5125";
    rev = "227eba219fa9e3fbac5bd59aca79f624f67cd11b";
    hash = "sha256-10FItQvRt7vE/mwOSYcIsJOwJobBPdE+HVeS6J75jVE=";
  };
in
stdenv.mkDerivation (finalAttrs: {
  pname = "libfprint-goodix-5125";
  version = "1.94.4-sigfm-goodixgf";

  src = fetchFromGitHub {
    owner = "goodix-fp-linux-dev";
    repo = "libfprint";
    rev = "7ebe0c809b4d1df3400e84299a4ec4acdea84590";
    hash = "sha256-Xm0ijZQsY1uQsvJNKj3wYbfghOPceW2vFEczj6PP0GU=";
  };

  nativeBuildInputs = [
    pkg-config
    meson
    ninja
    gobject-introspection
    python3
  ];

  buildInputs = [
    gusb
    pixman
    glib
    cairo
    libgudev
    openssl
    mbedtls
    opencv
    doctest
    zlib
    libusb1
  ];

  postPatch = ''
    # Integrate goodixgf driver into libfprint tree
    mkdir -p libfprint/drivers/goodixgf/core
    cp ${srcDriver}/src/goodixgf.c libfprint/drivers/goodixgf/
    cp ${srcDriver}/src/transport.c \
       ${srcDriver}/src/goodix_frame.c \
       ${srcDriver}/src/goodix_cmd.c \
       ${srcDriver}/src/goodix_psk.c \
       ${srcDriver}/src/goodix_tls.c \
       ${srcDriver}/src/goodix_fwupdate.c \
       ${srcDriver}/src/goodix_init.c \
       ${srcDriver}/src/goodix_capture.c \
       ${srcDriver}/src/goodix_base.c \
       ${srcDriver}/src/goodix_otp.c \
       ${srcDriver}/src/goodix_imgproc.c \
       ${srcDriver}/src/goodix_crc.c \
       libfprint/drivers/goodixgf/core/
    cp ${srcDriver}/include/goodix.h \
       ${srcDriver}/include/goodix_imgproc.h \
       ${srcDriver}/include/goodix_fw.h \
       libfprint/drivers/goodixgf/core/
    chmod -R u+w libfprint/drivers/goodixgf

    # Bump version to satisfy fprintd's minimum requirement (>=1.94.9)
    # and add FP_DEVICE_RETRY_TOO_FAST enum value introduced in 1.94.9
    sed -i "s/version: '1.94.5'/version: '1.94.100'/" meson.build
    sed -i '/FP_DEVICE_RETRY_REMOVE_FINGER,/a \  FP_DEVICE_RETRY_TOO_FAST,' libfprint/fp-device.h

    # Lower default threshold from 20 to 10 and allow runtime override via GOODIX_SCORE_THRESHOLD
    sed -i 's/#define GF_SIGFM_SCORE_THRESHOLD 20/#define GF_SIGFM_SCORE_THRESHOLD 10/' libfprint/drivers/goodixgf/goodixgf.c
    python3 - <<'EOF'
with open('libfprint/drivers/goodixgf/goodixgf.c', 'r') as f:
    s = f.read()

anchor = "gf_img_open (FpImageDevice *dev)\n{\n"
patch = """gf_img_open (FpImageDevice *dev)
{
  const char *env_th = getenv ("GOODIX_SCORE_THRESHOLD");
  if (env_th && *env_th)
    {
      int th = atoi (env_th);
      if (th > 0)
        fpi_image_device_set_score_threshold (dev, th);
    }
"""
if anchor not in s:
    raise RuntimeError("anchor not found in goodixgf.c")
s = s.replace(anchor, patch, 1)
with open('libfprint/drivers/goodixgf/goodixgf.c', 'w') as f:
    f.write(s)
EOF

    # Patch root meson.build to link mbedtls, crypto, m, z for goodixgf
    python3 - <<'EOF'
with open('meson.build', 'r') as f:
    s = f.read()

anchor = "if udev_rules.disabled()\n"
block = """
if 'goodixgf' in drivers
  optional_deps += [
    cc.find_library('mbedtls'),
    cc.find_library('mbedx509'),
    cc.find_library('mbedcrypto'),
    cc.find_library('crypto'),
    cc.find_library('m', required: false),
    cc.find_library('z', required: false),
  ]
endif
"""
if anchor not in s:
    raise RuntimeError("anchor not found in meson.build")
s = s.replace(anchor, block + anchor, 1)

with open('meson.build', 'w') as f:
    f.write(s)
EOF

    # Patch libfprint/meson.build to add driver_sources entry for goodixgf
    python3 - <<'EOF'
with open('libfprint/meson.build', 'r') as f:
    s = f.read()

anchor = "    'goodixmoc' :\n        [ 'drivers/goodixmoc/goodix.c', 'drivers/goodixmoc/goodix_proto.c' ],\n"
entry = """    'goodixgf' :
        [ 'drivers/goodixgf/goodixgf.c',
          'drivers/goodixgf/core/transport.c',
          'drivers/goodixgf/core/goodix_frame.c',
          'drivers/goodixgf/core/goodix_cmd.c',
          'drivers/goodixgf/core/goodix_psk.c',
          'drivers/goodixgf/core/goodix_tls.c',
          'drivers/goodixgf/core/goodix_fwupdate.c',
          'drivers/goodixgf/core/goodix_init.c',
          'drivers/goodixgf/core/goodix_capture.c',
          'drivers/goodixgf/core/goodix_base.c',
          'drivers/goodixgf/core/goodix_otp.c',
          'drivers/goodixgf/core/goodix_imgproc.c',
          'drivers/goodixgf/core/goodix_crc.c' ],
"""
if anchor not in s:
    raise RuntimeError("anchor not found in libfprint/meson.build")
s = s.replace(anchor, anchor + entry, 1)

with open('libfprint/meson.build', 'w') as f:
    f.write(s)
EOF
  '';

  mesonFlags = [
    "-Dudev_rules_dir=${placeholder "out"}/lib/udev/rules.d"
    "-Dudev_hwdb_dir=${placeholder "out"}/lib/udev/hwdb.d"
    "-Ddrivers=goodixgf"
    "-Ddoc=false"
    "-Dintrospection=true"
  ];

  doCheck = false;

  postInstall = ''
    install -D -m 0644 ${srcDriver}/70-goodix.rules $out/lib/udev/rules.d/70-goodix.rules
    install -D -m 0644 ../libfprint/sigfm/sigfm.h $out/include/libfprint-2/sigfm/sigfm.h

    # Build and install goodix-cli calibration & diagnostics tool
    $CC -O2 -Wall -I${srcDriver}/include $(pkg-config --cflags libusb-1.0 openssl) \
      ${srcDriver}/src/transport.c ${srcDriver}/src/goodix_frame.c ${srcDriver}/src/goodix_cmd.c \
      ${srcDriver}/src/goodix_psk.c ${srcDriver}/src/goodix_tls.c ${srcDriver}/src/goodix_fwupdate.c \
      ${srcDriver}/src/goodix_init.c ${srcDriver}/src/goodix_capture.c ${srcDriver}/src/goodix_base.c \
      ${srcDriver}/src/goodix_otp.c ${srcDriver}/src/goodix_imgproc.c ${srcDriver}/src/goodix_crc.c ${srcDriver}/src/main.c \
      $(pkg-config --libs libusb-1.0 openssl) -lmbedtls -lmbedx509 -lmbedcrypto -lz -lm \
      -o goodix-cli
    install -D -m 0755 goodix-cli $out/bin/goodix-cli
  '';

  meta = with lib; {
    description = "libfprint with Goodix 27c6:5125/5135 driver and SIGFM matcher, including goodix-cli";
    homepage = "https://github.com/Rockytkg/goodix-linux-27c6-5125";
    license = licenses.gpl2Plus;
    platforms = platforms.linux;
  };
})
