# nixos-goodix-5125

NixOS flake and package for Goodix fingerprint readers (**27c6:5125** and **27c6:5135**), commonly found in laptops such as **Huawei MateBook (D14/D15/16)**, **Honor MagicBook**, Lenovo, and others.

This flake integrates the open-source driver from [Rockytkg/goodix-linux-27c6-5125](https://github.com/Rockytkg/goodix-linux-27c6-5125) with the community [libfprint-sigfm](https://github.com/goodix-fp-linux-dev/libfprint) fork (OpenCV SIFT geometric voting matcher), providing full integration into NixOS's `fprintd` and PAM authentication.

---

## Features

- **Native fprintd support**: Seamless PAM authentication (`sudo`, lockscreen, login manager).
- **SIGFM matching**: SIFT-based keypoint matcher for small `80×64` ChicagoHS sensor frames.
- **Configurable score threshold**: Tuneable matching threshold via module options or `GOODIX_SCORE_THRESHOLD`.
- **fprintd keep-alive**: Prevents device from going to sleep every 30 seconds, enabling instant response upon finger touch.
- **Standalone `goodix-cli`**: Optional diagnostic and calibration tool.

---

## Installation

### 1. Add to `flake.nix`

Add this repository to your system flake inputs:

```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixos-goodix-5125 = {
      url = "github:paasito/nixos-goodix-5125";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixos-goodix-5125, ... }: {
    nixosConfigurations.desktop = nixpkgs.lib.nixosSystem {
      modules = [
        # ...
        nixos-goodix-5125.nixosModules.default
        ./configuration.nix
      ];
    };
  };
}
```

### 2. Enable in your NixOS configuration

```nix
{ ... }:

{
  hardware.fingerprint.goodix-5125 = {
    enable = true;
    scoreThreshold = 10; # Default: 10 (range: 5 - 20)
    keepAlive = true;     # Keep fprintd running with --no-timeout
    enableDebug = false;  # Set to true to log detailed matching scores in journalctl
  };
}
```

---

## Enrolling & Verification Guidelines

Because the Goodix 5125 sensor is physically small (`80×64` px), proper enrollment technique is crucial for high matching accuracy:

1. **Delete any old prints first**:
   ```bash
   fprintd-delete $USER
   ```

2. **Enroll with spatial variation (3 to 8 touches)**:
   ```bash
   fprintd-enroll -f right-index-finger $USER
   ```
   > **Important**: Do not touch the exact same spot repeatedly! Slightly vary the position for each stage:
   > - Stage 1: Pad center
   > - Stage 2: Fingertip (higher)
   > - Stage 3: Lower pad
   > - Stage 4: Slight tilt left
   > - Stage 5: Slight tilt right
   >
   > The driver dynamically checks coverage and completes once enough distinct keypoint regions have converged.

3. **Verify**:
   ```bash
   fprintd-verify $USER
   ```

4. **Troubleshooting / Tuning**:
   If verification is intermittent, enable debug logging:
   ```nix
   hardware.fingerprint.goodix-5125.enableDebug = true;
   ```
   Rebuild, and monitor journal logs during verification:
   ```bash
   journalctl -u fprintd -f
   ```
   Look for `sigfm score X/10`:
   - `score 0`: The touch position does not overlap enough with registered areas (<5 keypoint matches). Re-enroll with wider finger coverage.
   - `score 5-9`: Partial match below threshold. You can lower `scoreThreshold = 8;` for more tolerance.

---

## Manual Diagnostics (`goodix-cli`)

A dedicated CLI tool `goodix-cli` is included:

```bash
# Stop fprintd first (USB device requires exclusive access):
sudo systemctl stop fprintd

# Inspect sensor info, firmware state, and OTP calibration:
sudo goodix-cli --info

# Test capture a frame to image-0.pgm:
sudo goodix-cli --capture 1

# Restart fprintd after testing:
sudo systemctl start fprintd
```

---

## Credits

- [Rockytkg/goodix-linux-27c6-5125](https://github.com/Rockytkg/goodix-linux-27c6-5125) for the reverse-engineered userspace driver and protocol implementation.
- [goodix-fp-linux-dev/libfprint](https://github.com/goodix-fp-linux-dev/libfprint) community fork for the SIGFM OpenCV matcher.
- [freedesktop libfprint](https://gitlab.freedesktop.org/libfprint/libfprint) upstream project.

## License

GPL-2.0-or-later.
