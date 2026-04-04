#!/bin/bash
# artix-installer.sh
# Artix Linux base installer — dinit + limine + linux-zen
# Run this on the Artix live ISO after manual partitioning

# ─────────────────────────────────────────────
# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ─────────────────────────────────────────────
# Helpers

info()    { echo -e "${CYAN}${BOLD}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}${BOLD}[OK]${NC} $1"; }
warn()    { echo -e "${YELLOW}${BOLD}[WARN]${NC} $1"; }
error()   { echo -e "${RED}${BOLD}[ERROR]${NC} $1"; }

ask() {
    # ask <variable_name> <prompt> [default]
    local varname="$1"
    local prompt="$2"
    local default="$3"
    if [ -n "$default" ]; then
        read -rp "$prompt [default: $default]: " input
        eval "$varname=\"${input:-$default}\""
    else
        read -rp "$prompt: " input
        eval "$varname=\"$input\""
    fi
}

ask_yn() {
    # ask_yn <prompt> <default y|n>
    local prompt="$1"
    local default="$2"
    local input
    read -rp "$prompt [y/n, default: $default]: " input
    input="${input:-$default}"
    [[ "$input" =~ ^[Yy]$ ]]
}

run_step() {
    # run_step <description> <command>
    local desc="$1"
    shift
    while true; do
        info "Running: $desc"
        if "$@"; then
            success "$desc done."
            break
        else
            error "$desc failed."
            if ask_yn "Retry this step?" "y"; then
                warn "Retrying..."
            else
                warn "Skipping step: $desc"
                break
            fi
        fi
    done
}

# ─────────────────────────────────────────────
# STEP 1 — Internet check

echo ""
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}         Artix Linux Installer               ${NC}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

info "Checking internet connection..."
if ping -c 2 -W 3 artixlinux.org &>/dev/null; then
    success "Internet is working."
else
    error "No internet detected."
    warn "Please connect manually using connmanctl before running this script."
    if ! ask_yn "Continue anyway?" "n"; then
        exit 1
    fi
fi

# ─────────────────────────────────────────────
# STEP 2 — Confirm partitioning

echo ""
info "This script assumes you have already run wipefs and cfdisk manually."
if ! ask_yn "Have you completed partitioning?" "n"; then
    warn "Please partition your disk first (wipefs + cfdisk), then re-run this script."
    exit 1
fi

# ─────────────────────────────────────────────
# STEP 3 — Partition names

echo ""
info "Enter your partition names."
ask BOOT_PART "Boot/EFI partition" "/dev/vda1"
ask SWAP_PART "Swap partition (leave blank to skip)" ""
ask ROOT_PART "Root partition" "/dev/vda3"

echo ""
info "Partition summary:"
echo "  Boot : $BOOT_PART"
echo "  Swap : ${SWAP_PART:-none}"
echo "  Root : $ROOT_PART"
echo ""
if ! ask_yn "Does this look correct?" "y"; then
    error "Aborted. Re-run the script and enter correct partition names."
    exit 1
fi

# ─────────────────────────────────────────────
# STEP 4 — Format partitions

echo ""
info "Formatting partitions..."

run_step "Format EFI partition (FAT32)" mkfs.fat -F32 "$BOOT_PART"
run_step "Format root partition (ext4)" mkfs.ext4 -F "$ROOT_PART"

if [ -n "$SWAP_PART" ]; then
    run_step "Format swap" mkswap "$SWAP_PART"
    run_step "Enable swap" swapon "$SWAP_PART"
else
    info "Swap skipped."
fi

# ─────────────────────────────────────────────
# STEP 5 — Mount partitions

echo ""
info "Mounting partitions..."

run_step "Mount root partition" mount "$ROOT_PART" /mnt
run_step "Create /mnt/boot" mkdir -p /mnt/boot
run_step "Mount boot partition" mount "$BOOT_PART" /mnt/boot

# ─────────────────────────────────────────────
# STEP 6 — Package selection

echo ""
DEFAULT_PKGS="base base-devel dinit elogind-dinit linux-zen linux-zen-headers linux-firmware limine efibootmgr nano"
warn "Default packages: $DEFAULT_PKGS"
echo ""
echo "Press Enter to use defaults, or type your own list (this REPLACES the defaults):"
read -rp "Packages: " USER_PKGS

if [ -n "$USER_PKGS" ]; then
    warn "WARNING: Default packages have been overwritten."
    warn "You entered: $USER_PKGS"
    if ! ask_yn "Are you sure you want to use your custom list?" "y"; then
        USER_PKGS=""
        info "Falling back to defaults."
    fi
fi

PACKAGES="${USER_PKGS:-$DEFAULT_PKGS}"

# ─────────────────────────────────────────────
# STEP 7 — basestrap

echo ""
info "Installing packages with basestrap..."
info "Packages: $PACKAGES"
echo ""

run_step "basestrap /mnt" basestrap /mnt $PACKAGES

# ─────────────────────────────────────────────
# STEP 8 — fstab

echo ""
run_step "Generate fstab" bash -c "fstabgen -U /mnt >> /mnt/etc/fstab"
info "fstab contents:"
cat /mnt/etc/fstab

# ─────────────────────────────────────────────
# STEP 9 — System config (inside chroot via heredoc)

echo ""
info "Gathering system configuration..."
echo ""

ask TIMEZONE   "Timezone"        "Asia/Baghdad"
ask LOCALE     "Locale"          "en_US.UTF-8"
ask KEYMAP     "Keyboard layout" "us"
ask HOSTNAME   "Hostname"        "artix"
ask USERNAME  "Username" ""

while [ -z "$USERNAME" ]; do
    warn "Username cannot be empty."
    ask USERNAME "Username" ""
done

echo ""
info "Set root password:"
read -rsp "Root password: " ROOT_PASS
echo ""
read -rsp "Confirm root password: " ROOT_PASS2
echo ""
while [ "$ROOT_PASS" != "$ROOT_PASS2" ]; do
    error "Passwords do not match. Try again."
    read -rsp "Root password: " ROOT_PASS
    echo ""
    read -rsp "Confirm root password: " ROOT_PASS2
    echo ""
done

echo ""
info "Set password for user $USERNAME:"
read -rsp "User password: " USER_PASS
echo ""
read -rsp "Confirm user password: " USER_PASS2
echo ""
while [ "$USER_PASS" != "$USER_PASS2" ]; do
    error "Passwords do not match. Try again."
    read -rsp "User password: " USER_PASS
    echo ""
    read -rsp "Confirm user password: " USER_PASS2
    echo ""
done

# ─────────────────────────────────────────────
# STEP 10 — Post-install packages

echo ""
info "Post-install packages (e.g. networkmanager sudo git)"
info "Leave blank to skip."
read -rp "Post-install packages: " POST_PKGS

# ─────────────────────────────────────────────
# STEP 10b — Multilib

echo ""
if ask_yn "Enable multilib repository? (needed for 32-bit software like Steam, Wine)" "n"; then
    ENABLE_MULTILIB=true
    info "Multilib will be enabled."
else
    ENABLE_MULTILIB=false
    info "Multilib skipped."
fi

# ─────────────────────────────────────────────
# Detect kernel for limine.conf

if echo "$PACKAGES" | grep -qw "linux-zen"; then
    KERNEL="linux-zen"
elif echo "$PACKAGES" | grep -qw "linux-lts"; then
    KERNEL="linux-lts"
else
    KERNEL="linux"
fi

info "Detected kernel: $KERNEL"

# ─────────────────────────────────────────────
# STEP 11 + 12 — chroot script

info "Entering chroot to configure system..."

artix-chroot /mnt /bin/bash <<CHROOT
set -e

# Timezone
ln -sf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime
hwclock --systohc

# Locale
sed -i "s/^#${LOCALE} UTF-8/${LOCALE} UTF-8/" /etc/locale.gen
locale-gen
echo "LANG=${LOCALE}" > /etc/locale.conf

# Keyboard layout
echo "KEYMAP=${KEYMAP}" > /etc/vconsole.conf

# Hostname
echo "${HOSTNAME}" > /etc/hostname

# Root password
echo "root:${ROOT_PASS}" | chpasswd

# User
useradd -m -G wheel -s /bin/bash "${USERNAME}"
echo "${USERNAME}:${USER_PASS}" | chpasswd

# Sudo — auto configure wheel if sudo is installed
if command -v sudo &>/dev/null || pacman -Qq sudo &>/dev/null 2>&1; then
    sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
    echo "[sudo] wheel group enabled."
fi

# Post-install packages
if [ -n "${POST_PKGS}" ]; then
    pacman -S --noconfirm ${POST_PKGS}
fi

# Multilib
if [ "${ENABLE_MULTILIB}" = "true" ]; then
    sed -i '/^#\[multilib\]/{s/^#//; n; s/^#Include/Include/}' /etc/pacman.conf
    pacman -Sy
    echo "[multilib] Enabled and synced."
fi

# NetworkManager dinit symlink — auto if installed
if pacman -Qq networkmanager &>/dev/null 2>&1; then
    ln -sf /etc/dinit.d/NetworkManager /etc/dinit.d/boot.d/NetworkManager
    echo "[dinit] NetworkManager enabled."
fi

# Limine bootloader
mkdir -p /boot/EFI/BOOT
cp /usr/share/limine/BOOTX64.EFI /boot/EFI/BOOT/

cat > /boot/limine.conf <<EOF
timeout: 5

/Artix Linux
    protocol: linux
    path: boot():/${KERNEL == "linux" ? "vmlinuz-linux" : "vmlinuz-${KERNEL}"}
    module_path: boot():/initramfs-${KERNEL}.img
    cmdline: root=${ROOT_PART} rw quiet
EOF

echo "[limine] Config written for kernel: ${KERNEL}"
echo "[limine] BOOTX64.EFI deployed."

echo ""
echo "Chroot configuration complete."
CHROOT

# ─────────────────────────────────────────────
# STEP 13 — Unmount

echo ""
run_step "Unmount all partitions" umount -R /mnt

# ─────────────────────────────────────────────
# Done

echo ""
echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}${BOLD}   Installation complete! Remove ISO and reboot.${NC}"
echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

if ask_yn "Reboot now?" "y"; then
    reboot
fi
