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

- Default values for some options are n 
- if the scrpt fails and the user runs again the swap part fails cause it aleady ussed or mounted
- if any disk partition is already mounted it fails to format and mount
- change default basestrap packages
- should run the ntp too after timezone is set
- the default timezone should be none and it should show the list of timzone if user ask like (Timezone? press / to search timzone)
- after it ask me for info about post packages it does just prints and echos the msgs and does not apply these things and shows everytign done wnat to reboot and i get broken system after that
- since it gives many errors on mount make sure to add option or see if there are alreay mounted if they are then dont mount the disk or better remove all mounted drives then mount
