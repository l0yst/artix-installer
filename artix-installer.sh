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

info() { echo -e "${CYAN}${BOLD}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}${BOLD}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}${BOLD}[WARN]${NC} $1"; }
error() { echo -e "${RED}${BOLD}[ERROR]${NC} $1"; }

ask() {
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
    local prompt="$1"
    local default="$2"
    local input
    read -rp "$prompt [y/n, default: $default]: " input
    input="${input:-$default}"
    [[ "$input" =~ ^[Yy]$ ]]
}

run_step() {
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
    info "Starting NTP time sync..."
    dinitctl start ntpd &>/dev/null && success "NTP started." || warn "NTP failed to start, continuing anyway."
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

# echo ""
# info "Enter your partition names."
# ask BOOT_PART "Boot/EFI partition" "/dev/vda1"
# ask SWAP_PART "Swap partition (leave blank to skip)" ""
# ask ROOT_PART "Root partition" "/dev/vda3"
#
# echo ""
# info "Partition summary:"
# echo "  Boot : $BOOT_PART"
# echo "  Swap : ${SWAP_PART:-none}"
# echo "  Root : $ROOT_PART"
# echo ""
# if ! ask_yn "Does this look correct?" "y"; then
#     error "Aborted. Re-run the script and enter correct partition names."
#     exit 1
# fi
#
# # ─────────────────────────────────────────────
# # STEP 4 — Clean up any existing mounts
#
# echo ""
# info "Cleaning up any existing mounts before formatting..."
#
# if [ -n "$SWAP_PART" ] && swapon --show | grep -q "$SWAP_PART"; then
#     warn "Swap $SWAP_PART already active, deactivating..."
#     swapoff "$SWAP_PART" || warn "Could not deactivate swap, continuing."
# fi
#
# if mountpoint -q /mnt; then
#     warn "/mnt is already mounted, unmounting..."
#     umount -R /mnt || warn "Could not unmount /mnt cleanly, continuing."
# fi
#
# success "Mount cleanup done."
#
# # ─────────────────────────────────────────────
# # STEP 5 — Format partitions
#
# echo ""
# info "Formatting partitions..."
#
# run_step "Format EFI partition (FAT32)" mkfs.fat -F32 "$BOOT_PART"
# run_step "Format root partition (ext4)" mkfs.ext4 -F "$ROOT_PART"
#
# if [ -n "$SWAP_PART" ]; then
#     run_step "Format swap" mkswap "$SWAP_PART"
#     run_step "Enable swap" swapon "$SWAP_PART"
# else
#     info "Swap skipped."
# fi
#
# # ─────────────────────────────────────────────
# # STEP 6 — Mount partitions
#
# echo ""
# info "Mounting partitions..."
#
# run_step "Mount root partition" mount "$ROOT_PART" /mnt
# run_step "Create /mnt/boot" mkdir -p /mnt/boot
# run_step "Mount boot partition" mount "$BOOT_PART" /mnt/boot
#
# # ─────────────────────────────────────────────
# # STEP 7 — Package selection
#
# echo ""
# DEFAULT_PKGS="base base-devel dinit elogind-dinit linux-zen linux-firmware limine efibootmgr"
# warn "Default packages: $DEFAULT_PKGS"
# echo ""
# echo "Press Enter to use defaults, or type your own list (this REPLACES the defaults):"
# read -rp "Packages: " USER_PKGS
#
# if [ -n "$USER_PKGS" ]; then
#     warn "WARNING: Default packages have been overwritten."
#     warn "You entered: $USER_PKGS"
#     if ! ask_yn "Are you sure you want to use your custom list?" "y"; then
#         USER_PKGS=""
#         info "Falling back to defaults."
#     fi
# fi
#
# PACKAGES="${USER_PKGS:-$DEFAULT_PKGS}"
#
# # ─────────────────────────────────────────────
# # STEP 8 — basestrap
#
# echo ""
# info "Installing packages with basestrap..."
# info "Packages: $PACKAGES"
# echo ""
#
# run_step "basestrap /mnt" basestrap /mnt $PACKAGES
#
# # ─────────────────────────────────────────────
# # STEP 9 — fstab
#
# echo ""
# run_step "Generate fstab" bash -c "fstabgen -U /mnt >> /mnt/etc/fstab"
# info "fstab contents:"
# cat /mnt/etc/fstab

# ─────────────────────────────────────────────
# STEP 10 — Gather system config BEFORE entering chroot

echo ""
info "Gathering system configuration..."
echo ""

# Timezone — no default, validate against real zoneinfo files
echo "Enter your timezone (e.g. Asia/Karachi, Europe/London, America/New_York)"
echo "Press Enter to list available regions first."
read -rp "Timezone: " TIMEZONE
if [ -z "$TIMEZONE" ]; then
    ls /usr/share/zoneinfo/
    echo ""
    read -rp "Timezone: " TIMEZONE
fi
while [ ! -f "/usr/share/zoneinfo/$TIMEZONE" ]; do
    error "Invalid timezone: '$TIMEZONE'"
    echo "Hint: format is Region/City e.g. Asia/Karachi"
    read -rp "Timezone: " TIMEZONE
done
success "Timezone set to $TIMEZONE"

ask LOCALE "Locale" "en_US.UTF-8"
ask KEYMAP "Keyboard layout" "us"
ask HOSTNAME "Hostname" "artix"
ask USERNAME "Username" ""

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
success "Root password set."

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
success "User password set."

# ─────────────────────────────────────────────
# STEP 11 — Post-install packages

echo ""
info "Post-install packages (e.g. networkmanager networkmanager-dinit git)"
info "Leave blank to skip."
read -rp "Post-install packages: " POST_PKGS

# ─────────────────────────────────────────────
# STEP 12 — Multilib

echo ""
if ask_yn "Enable multilib repository?" "n"; then
    ENABLE_MULTILIB=true
    info "Multilib will be enabled."
else
    ENABLE_MULTILIB=false
    info "Multilib skipped."
fi

# ─────────────────────────────────────────────
# Detect kernel

if echo "$PACKAGES" | grep -qw "linux-zen"; then
    KERNEL="linux-zen"
elif echo "$PACKAGES" | grep -qw "linux-lts"; then
    KERNEL="linux-lts"
else
    KERNEL="linux"
fi

VMLINUZ="vmlinuz-${KERNEL}"
INITRAMFS="initramfs-${KERNEL}.img"
info "Detected kernel: $KERNEL"

# ─────────────────────────────────────────────
# STEP 13 — Write chroot script and execute it
# Using a temp script file avoids heredoc variable expansion issues

info "Writing chroot setup script..."

cat >/mnt/artix-chroot-setup.sh <<SCRIPT
#!/bin/bash
set -e

echo "[1/9] Setting timezone..."
ln -sf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime
hwclock --systohc
dinitctl start ntpd 2>/dev/null || true

echo "[2/9] Setting locale..."
sed -i 's/^#${LOCALE} UTF-8/${LOCALE} UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=${LOCALE}" > /etc/locale.conf

echo "[3/9] Setting keymap..."
echo "KEYMAP=${KEYMAP}" > /etc/vconsole.conf

echo "[4/9] Setting hostname and hosts..."
echo "${HOSTNAME}" > /etc/hostname
printf '127.0.0.1\tlocalhost\n::1\t\tlocalhost\n127.0.1.1\t${HOSTNAME}.localdomain ${HOSTNAME}\n' > /etc/hosts

echo "[5/9] Setting passwords and creating user..."
echo "root:${ROOT_PASS}" | chpasswd
useradd -m -G wheel -s /bin/bash "${USERNAME}"
echo "${USERNAME}:${USER_PASS}" | chpasswd

echo "[6/9] Configuring sudo..."
if pacman -Qq sudo &>/dev/null; then
    sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
    echo "  wheel group enabled."
else
    echo "  sudo not installed, skipping."
fi

echo "[7/9] Installing post-install packages..."
if [ -n "${POST_PKGS}" ]; then
    pacman -S --noconfirm ${POST_PKGS}
else
    echo "  none specified, skipping."
fi

echo "[8/9] Multilib and services..."
if [ "${ENABLE_MULTILIB}" = "true" ]; then
    sed -i '/^#\[multilib\]/{s/^#//; n; s/^#Include/Include/}' /etc/pacman.conf
    pacman -Sy
    echo "  multilib enabled."
fi

if pacman -Qq networkmanager &>/dev/null; then
    ln -sf /etc/dinit.d/NetworkManager /etc/dinit.d/boot.d/NetworkManager
    echo "  NetworkManager dinit symlink created."
fi

echo "[9/9] Installing Limine bootloader..."
mkdir -p /boot/EFI/BOOT
cp /usr/share/limine/BOOTX64.EFI /boot/EFI/BOOT/

cat > /boot/limine.conf << 'LIMINEEOF'
timeout: 5

/Artix Linux
    protocol: linux
    path: boot():/VMLINUZ_PLACEHOLDER
    module_path: boot():/INITRAMFS_PLACEHOLDER
    cmdline: root=ROOT_PLACEHOLDER rw quiet
LIMINEEOF

sed -i "s|VMLINUZ_PLACEHOLDER|${VMLINUZ}|" /boot/limine.conf
sed -i "s|INITRAMFS_PLACEHOLDER|${INITRAMFS}|" /boot/limine.conf
sed -i "s|ROOT_PLACEHOLDER|${ROOT_PART}|" /boot/limine.conf

echo ""
echo "  limine.conf:"
cat /boot/limine.conf

echo ""
echo "Chroot setup complete."
SCRIPT

chmod +x /mnt/artix-chroot-setup.sh
run_step "Configure system in chroot" artix-chroot /mnt /artix-chroot-setup.sh
rm -f /mnt/artix-chroot-setup.sh

# ─────────────────────────────────────────────
# STEP 14 — Unmount

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
