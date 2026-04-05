# artix-installer

A simple, interactive bash installer for Artix Linux with dinit.

> ⚠️ This script is currently in testing. Bugs and rough edges are expected.
> If you found this repo, feel free to open an issue or PR!

## What it does

- Interactive prompts with sane defaults
- GPT/UEFI partitioning support
- Limine bootloader (auto-configured)
- linux-zen kernel by default
- dinit init system
- Optional: multilib, swap, post-install packages

## Usage

Boot the Artix live ISO, connect to the internet, then:
```bash
curl -O https://raw.githubusercontent.com/l0yst/artix-installer/main/artix-installer.sh
sudo chmod +x artix-installer.sh
bash artix-installer.sh
```

## Notes

- You must partition your disk manually before running
- WiFi on the live ISO must be connected manually via connmanctl or any other wifi options in artix iso 
- Real hardware and VMs both supported

## Bugs
- sudo does not work with user cause user was not added in suders
