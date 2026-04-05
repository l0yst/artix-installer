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
            read -rp "Retry this step? [y/n, default: y]: " input
            input="${input:-y}"
            if [[ "$input" =~ ^[Yy]$ ]]; then
                warn "Retrying..."
            else
                warn "Skipping: $desc"
                break
            fi
        fi
    done
}

# ─────────────────────────────────────────────
# Timezone picker

pick_timezone() {
    while true; do
        echo ""
        echo "Enter timezone (e.g. Asia/Karachi, Europe/London, America/New_York)"
        echo "Press Enter to browse regions."
        read -rp "Timezone: " tz
        if [ -z "$tz" ]; then
            echo ""
            info "Available regions:"
            ls /usr/share/zoneinfo/ | grep -v '[.]' | column
            echo ""
            read -rp "Enter region (e.g. Asia): " region
            if [ -d "/usr/share/zoneinfo/$region" ]; then
                echo ""
                info "Cities in $region:"
                ls "/usr/share/zoneinfo/$region" | column
                echo ""
                read -rp "Enter full timezone (e.g. $region/Karachi): " tz
            else
                error "Region '$region' not found. Try again."
                continue
            fi
        fi
        if [ -f "/usr/share/zoneinfo/$tz" ]; then
            TIMEZONE="$tz"
            success "Timezone set to $TIMEZONE"
            break
        else
            error "Invalid timezone: '$tz'"
            echo "Hint: format is Region/City e.g. Asia/Karachi"
        fi
    done
}

# ─────────────────────────────────────────────
# Confirm screen

show_confirm() {
    echo ""
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}         Review your settings                ${NC}"
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  ${CYAN}[t]${NC} Timezone        : $TIMEZONE"
    echo -e "  ${CYAN}[l]${NC} Locale          : $LOCALE"
    echo -e "  ${CYAN}[k]${NC} Keymap          : $KEYMAP"
    echo -e "  ${CYAN}[h]${NC} Hostname        : $HOSTNAME"
    echo -e "  ${CYAN}[u]${NC} Username        : $USERNAME"
    echo -e "  ${CYAN}[b]${NC} Base packages   : $BASE_PKGS"
    echo -e "  ${CYAN}[a]${NC} Extra packages  : ${EXTRA_PKGS:-none}"
    echo -e "  ${CYAN}[m]${NC} Multilib        : $ENABLE_MULTILIB"
    echo -e "  ${CYAN}[r]${NC} Mirror country  : ${MIRROR_COUNTRY:-skip}"
    echo ""
    echo -e "  ${CYAN}Boot partition ${NC}: $BOOT_PART"
    echo -e "  ${CYAN}Swap partition ${NC}: ${SWAP_PART:-none}"
    echo -e "  ${CYAN}Root partition ${NC}: $ROOT_PART"
    echo -e "  ${CYAN}Bootloader     ${NC}: limine + efibootmgr (fixed)"
    echo ""
    echo -e "  ${GREEN}[y]${NC} Confirm and install"
    echo -e "  ${RED}[n]${NC} Cancel and exit"
    echo ""
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

# ─────────────────────────────────────────────
# HEADER

echo ""
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}         Artix Linux Installer               ${NC}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# ─────────────────────────────────────────────
# STEP 1 — Internet check

info "Checking internet connection..."
if ping -c 2 -W 3 artixlinux.org &>/dev/null; then
    success "Internet is working."
    info "Starting NTP time sync..."
    dinitctl start ntpd &>/dev/null && success "NTP started." || warn "NTP failed to start, continuing anyway."
else
    error "No internet detected."
    warn "Please connect manually using connmanctl before running this script."
    read -rp "Continue anyway? [y/n, default: n]: " input
    input="${input:-n}"
    if [[ ! "$input" =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# ─────────────────────────────────────────────
# STEP 2 — Confirm partitioning done

echo ""
info "This script assumes you have already run wipefs and cfdisk manually."
read -rp "Have you completed partitioning? [y/n, default: n]: " input
input="${input:-n}"
if [[ ! "$input" =~ ^[Yy]$ ]]; then
    warn "Please partition your disk first (wipefs + cfdisk), then re-run this script."
    exit 1
fi

# ─────────────────────────────────────────────
# STEP 3 — Partition names

echo ""
info "Enter your partition names."
read -rp "Boot/EFI partition [default: /dev/vda1]: " BOOT_PART
BOOT_PART="${BOOT_PART:-/dev/vda1}"

read -rp "Swap partition (leave blank to skip): " SWAP_PART

read -rp "Root partition [default: /dev/vda3]: " ROOT_PART
ROOT_PART="${ROOT_PART:-/dev/vda3}"

# ─────────────────────────────────────────────
# STEP 4 — Timezone

echo ""
pick_timezone

# ─────────────────────────────────────────────
# STEP 5 — Multilib

echo ""
read -rp "Enable multilib repository? [y/n, default: n]: " input
input="${input:-n}"
if [[ "$input" =~ ^[Yy]$ ]]; then
    ENABLE_MULTILIB="yes"
    info "Multilib will be enabled."
else
    ENABLE_MULTILIB="no"
    info "Multilib skipped."
fi

# ─────────────────────────────────────────────
# STEP 6 — Locale

echo ""
read -rp "Locale [default: en_US.UTF-8]: " LOCALE
LOCALE="${LOCALE:-en_US.UTF-8}"

# ─────────────────────────────────────────────
# STEP 7 — Keymap

read -rp "Keyboard layout [default: us]: " KEYMAP
KEYMAP="${KEYMAP:-us}"

# ─────────────────────────────────────────────
# STEP 8 — Hostname

read -rp "Hostname [default: artix]: " HOSTNAME
HOSTNAME="${HOSTNAME:-artix}"

# ─────────────────────────────────────────────
# STEP 9 — Username

read -rp "Username: " USERNAME
while [ -z "$USERNAME" ]; do
    warn "Username cannot be empty."
    read -rp "Username: " USERNAME
done

# ─────────────────────────────────────────────
# STEP 10 — Root password

echo ""
info "Set root password:"
while true; do
    read -rsp "Root password: " ROOT_PASS
    echo ""
    read -rsp "Confirm root password: " ROOT_PASS2
    echo ""
    if [ "$ROOT_PASS" = "$ROOT_PASS2" ]; then
        success "Root password set."
        break
    else
        error "Passwords do not match. Try again."
    fi
done

# ─────────────────────────────────────────────
# STEP 11 — User password

echo ""
info "Set password for user $USERNAME:"
while true; do
    read -rsp "User password: " USER_PASS
    echo ""
    read -rsp "Confirm user password: " USER_PASS2
    echo ""
    if [ "$USER_PASS" = "$USER_PASS2" ]; then
        success "User password set."
        break
    else
        error "Passwords do not match. Try again."
    fi
done

# ─────────────────────────────────────────────
# STEP 12 — Bootloader notice

echo ""
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "  Bootloader: ${GREEN}Limine + efibootmgr${NC} (fixed)"
echo -e "  These will be installed automatically."
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
read -rp "Press Enter to continue..."

# ─────────────────────────────────────────────
# STEP 13 — Base packages

echo ""
BASE_PKGS_DEFAULT="base base-devel dinit elogind-dinit linux-zen linux-firmware"
warn "Default base packages: $BASE_PKGS_DEFAULT"
echo "Press Enter to use defaults, or type your own list (REPLACES defaults):"
read -rp "Base packages: " BASE_PKGS_INPUT
if [ -n "$BASE_PKGS_INPUT" ]; then
    warn "WARNING: Default base packages overwritten."
    warn "You entered: $BASE_PKGS_INPUT"
    read -rp "Are you sure? [y/n, default: y]: " input
    input="${input:-y}"
    if [[ ! "$input" =~ ^[Yy]$ ]]; then
        BASE_PKGS_INPUT=""
        info "Falling back to defaults."
    fi
fi
BASE_PKGS="${BASE_PKGS_INPUT:-$BASE_PKGS_DEFAULT}"

# ─────────────────────────────────────────────
# STEP 14 — Extra packages

echo ""
info "Extra packages to install (e.g. networkmanager networkmanager-dinit git)"
info "Leave blank to skip. limine and efibootmgr are always added automatically."
read -rp "Extra packages: " EXTRA_PKGS

# ─────────────────────────────────────────────
# STEP 15 — Mirror country

echo ""
info "Reflector mirror country (e.g. Germany, France, Yemen)"
info "Leave blank to skip mirror refresh."
read -rp "Mirror country: " MIRROR_COUNTRY

# ─────────────────────────────────────────────
# CONFIRM SCREEN — loop until y or n

while true; do
    show_confirm
    read -rsn1 key
    case "$key" in
    t)
        pick_timezone
        ;;
    l)
        echo ""
        read -rp "Locale [default: en_US.UTF-8]: " LOCALE
        LOCALE="${LOCALE:-en_US.UTF-8}"
        success "Locale set to $LOCALE"
        ;;
    k)
        echo ""
        read -rp "Keyboard layout [default: us]: " KEYMAP
        KEYMAP="${KEYMAP:-us}"
        success "Keymap set to $KEYMAP"
        ;;
    h)
        echo ""
        read -rp "Hostname [default: artix]: " HOSTNAME
        HOSTNAME="${HOSTNAME:-artix}"
        success "Hostname set to $HOSTNAME"
        ;;
    u)
        echo ""
        read -rp "Username: " USERNAME
        while [ -z "$USERNAME" ]; do
            warn "Username cannot be empty."
            read -rp "Username: " USERNAME
        done
        success "Username set to $USERNAME"
        ;;
    b)
        echo ""
        warn "Current base packages: $BASE_PKGS"
        echo "Press Enter to keep current, or type new list:"
        read -rp "Base packages: " BASE_PKGS_INPUT
        if [ -n "$BASE_PKGS_INPUT" ]; then
            BASE_PKGS="$BASE_PKGS_INPUT"
            success "Base packages updated."
        else
            info "Kept existing base packages."
        fi
        ;;
    a)
        echo ""
        info "Current extra packages: ${EXTRA_PKGS:-none}"
        echo "Press Enter to keep current, or type new list (blank = none):"
        read -rp "Extra packages: " EXTRA_PKGS
        success "Extra packages updated."
        ;;
    m)
        echo ""
        read -rp "Enable multilib? [y/n, default: n]: " input
        input="${input:-n}"
        if [[ "$input" =~ ^[Yy]$ ]]; then
            ENABLE_MULTILIB="yes"
        else
            ENABLE_MULTILIB="no"
        fi
        success "Multilib set to $ENABLE_MULTILIB"
        ;;
    r)
        echo ""
        read -rp "Mirror country (blank to skip): " MIRROR_COUNTRY
        success "Mirror country set to: ${MIRROR_COUNTRY:-skip}"
        ;;
    y)
        success "Settings confirmed. Starting installation..."
        break
        ;;
    n)
        echo ""
        warn "Installation cancelled."
        exit 0
        ;;
    *)
        # Enter and anything else does nothing
        ;;
    esac
done

# ─────────────────────────────────────────────
# FROM HERE — apply everything

# ─────────────────────────────────────────────
# Mirrorlist on live ISO

if [ -n "$MIRROR_COUNTRY" ]; then
    echo ""
    info "Refreshing mirrorlist with reflector..."
    if ! command -v reflector &>/dev/null; then
        info "Installing reflector..."
        pacman -Sy --noconfirm reflector || warn "Could not install reflector, skipping mirror refresh."
    fi
    if command -v reflector &>/dev/null; then
        reflector --country "$MIRROR_COUNTRY" --latest 10 --sort rate \
            --save /etc/pacman.d/mirrorlist && success "Mirrorlist updated." ||
            warn "Reflector failed, using existing mirrorlist."
    fi
else
    info "Skipping mirror refresh."
fi

# ─────────────────────────────────────────────
# Clean up existing mounts

echo ""
info "Cleaning up any existing mounts..."
if [ -n "$SWAP_PART" ] && swapon --show | grep -q "$SWAP_PART"; then
    warn "Swap already active, deactivating..."
    swapoff "$SWAP_PART" || warn "Could not deactivate swap."
fi
if mountpoint -q /mnt; then
    warn "/mnt already mounted, unmounting..."
    umount -R /mnt || warn "Could not unmount /mnt cleanly."
fi
success "Cleanup done."

# ─────────────────────────────────────────────
# Format partitions

echo ""
info "Formatting partitions..."
run_step "Format EFI (FAT32)" mkfs.fat -F32 "$BOOT_PART"
run_step "Format root (ext4)" mkfs.ext4 -F "$ROOT_PART"
if [ -n "$SWAP_PART" ]; then
    run_step "Format swap" mkswap "$SWAP_PART"
    run_step "Enable swap" swapon "$SWAP_PART"
else
    info "Swap skipped."
fi

# ─────────────────────────────────────────────
# Mount partitions

echo ""
info "Mounting partitions..."
run_step "Mount root" mount "$ROOT_PART" /mnt
run_step "Create /mnt/boot" mkdir -p /mnt/boot
run_step "Mount boot" mount "$BOOT_PART" /mnt/boot

# ─────────────────────────────────────────────
# Base basestrap

echo ""
info "Installing base packages..."
info "Packages: $BASE_PKGS"
run_step "basestrap base" basestrap /mnt $BASE_PKGS

# ─────────────────────────────────────────────
# Extra basestrap (always includes limine + efibootmgr)

FULL_EXTRA="limine efibootmgr nano sudo ${EXTRA_PKGS}"
echo ""
info "Installing extra packages..."
info "Packages: $FULL_EXTRA"
run_step "basestrap extra" basestrap /mnt $FULL_EXTRA

# ─────────────────────────────────────────────
# fstab

echo ""
run_step "Generate fstab" bash -c "fstabgen -U /mnt >> /mnt/etc/fstab"
info "fstab:"
cat /mnt/etc/fstab

# ─────────────────────────────────────────────
# Copy fresh mirrorlist to installed system

if [ -n "$MIRROR_COUNTRY" ]; then
    info "Copying mirrorlist to installed system..."
    cp /etc/pacman.d/mirrorlist /mnt/etc/pacman.d/mirrorlist &&
        success "Mirrorlist copied." || warn "Could not copy mirrorlist."
fi

# ─────────────────────────────────────────────
# Write and run chroot script

info "Writing chroot setup script..."

cat >/mnt/artix-chroot-setup.sh <<SCRIPT
#!/bin/bash

echo "[1/9] Setting timezone..."
ln -sf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime
hwclock --systohc
dinitctl start ntpd 2>/dev/null || true

echo "[2/9] Setting locale..."
if ! grep -q "^${LOCALE} UTF-8" /etc/locale.gen; then
    sed -i 's/^#${LOCALE} UTF-8/${LOCALE} UTF-8/' /etc/locale.gen
fi
locale-gen
echo "LANG=${LOCALE}" > /etc/locale.conf

echo "[3/9] Setting keymap..."
echo "KEYMAP=${KEYMAP}" > /etc/vconsole.conf

echo "[4/9] Setting hostname and hosts..."
echo "${HOSTNAME}" > /etc/hostname
printf '127.0.0.1\tlocalhost\n::1\t\tlocalhost\n127.0.1.1\t${HOSTNAME}.localdomain ${HOSTNAME}\n' > /etc/hosts

echo "[5/9] Setting passwords and creating user..."
echo "root:${ROOT_PASS}" | chpasswd
if ! id "${USERNAME}" &>/dev/null; then
    useradd -m -G wheel -s /bin/bash "${USERNAME}"
    echo "  user ${USERNAME} created."
else
    echo "  user ${USERNAME} already exists, skipping useradd."
fi
echo "${USERNAME}:${USER_PASS}" | chpasswd

echo "[6/9] Configuring sudo..."
if pacman -Qq sudo &>/dev/null; then
    if ! grep -q "^%wheel ALL=(ALL:ALL) ALL" /etc/sudoers; then
        sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
        echo "  wheel group enabled."
    else
        echo "  wheel already enabled, skipping."
    fi
else
    echo "  sudo not installed, skipping."
fi

echo "[7/9] Multilib and services..."
if [ "${ENABLE_MULTILIB}" = "yes" ]; then
    if ! grep -q "^\[multilib\]" /etc/pacman.conf; then
        sed -i '/^#\[multilib\]/{s/^#//; n; s/^#Include/Include/}' /etc/pacman.conf
        echo "  multilib enabled."
    else
        echo "  multilib already enabled, skipping."
    fi
    pacman -Sy
fi

if pacman -Qq networkmanager &>/dev/null; then
    if [ ! -L /etc/dinit.d/boot.d/NetworkManager ]; then
        ln -sf /etc/dinit.d/NetworkManager /etc/dinit.d/boot.d/NetworkManager
        echo "  NetworkManager dinit symlink created."
    else
        echo "  NetworkManager symlink already exists, skipping."
    fi
fi

echo "[8/9] Installing Limine bootloader..."
mkdir -p /boot/EFI/BOOT
cp /usr/share/limine/BOOTX64.EFI /boot/EFI/BOOT/

VMLINUZ=\$(ls /boot/vmlinuz-* 2>/dev/null | head -1 | xargs basename)
INITRAMFS=\$(ls /boot/initramfs-*.img 2>/dev/null | grep -v fallback | head -1 | xargs basename)

if [ -z "\$VMLINUZ" ] || [ -z "\$INITRAMFS" ]; then
    echo "  ERROR: Could not find kernel or initramfs in /boot"
    ls /boot/
    exit 1
fi

echo "  Kernel   : \$VMLINUZ"
echo "  Initramfs: \$INITRAMFS"

cat > /boot/limine.conf << LIMINEEOF
timeout: 5

/Artix Linux
    protocol: linux
    path: boot():/\${VMLINUZ}
    module_path: boot():/\${INITRAMFS}
    cmdline: root=${ROOT_PART} rw quiet
LIMINEEOF

echo ""
echo "  limine.conf:"
cat /boot/limine.conf

echo "[9/9] Done."
echo ""
echo "Chroot setup complete."
SCRIPT

chmod +x /mnt/artix-chroot-setup.sh
run_step "Configure system in chroot" artix-chroot /mnt /artix-chroot-setup.sh
rm -f /mnt/artix-chroot-setup.sh

# ─────────────────────────────────────────────
# Unmount

echo ""
run_step "Unmount all partitions" umount -R /mnt

# ─────────────────────────────────────────────
# Done

echo ""
echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}${BOLD}   Installation complete! Remove ISO and reboot.${NC}"
echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

read -rp "Reboot now? [y/n, default: y]: " input
input="${input:-y}"
if [[ "$input" =~ ^[Yy]$ ]]; then
    reboot
fi
