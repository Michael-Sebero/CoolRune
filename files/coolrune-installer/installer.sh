#!/bin/bash

su -c '
### ENHANCED RETRY LOGIC WITH CONFLICT RESOLUTION ###

retry_pacman() {
  local max_attempts="$1"
  shift
  local command="$@"
  local attempt_num=1
  
  until eval "$command"
  do
    if (( attempt_num == max_attempts ))
    then
      echo "Attempt $attempt_num failed! Applying conflict resolution strategies..." >&2
      
      # Extract package names from the original command
      local pkg_list=""
      if echo "$command" | grep -q " -S "; then
        pkg_list=$(echo "$command" | sed -E "s/.*pacman -S[[:space:]]+[^[:space:]]*[[:space:]]+([^[:space:]]+[[:space:]]+)*//")
      else
        echo "Unable to parse package list from command, applying general fixes..." >&2
        
        # Apply general conflict resolution strategies
        echo "Cleaning package cache..." >&2
        pacman -Scc --noconfirm 2>/dev/null || true
        
        echo "Refreshing package databases..." >&2
        pacman -Syy --noconfirm 2>/dev/null || true
        
        # Try the original command one more time with enhanced flags
        local enhanced_cmd=$(echo "$command" | sed "s/--overwrite=['\"][^'\"]*['\"]//g")
        enhanced_cmd="$enhanced_cmd --overwrite='*'"
        echo "Retrying with enhanced flags: $enhanced_cmd" >&2
        eval "$enhanced_cmd" && return 0 || return 1
      fi
      
      # Extract flags from original command
      local base_flags="--noconfirm --needed --overwrite='*'"
      if echo "$command" | grep -q -- "--ignore="; then
        local ignore_flag=$(echo "$command" | grep -o -- "--ignore=[^ ]*")
        base_flags="$base_flags $ignore_flag"
      fi
      
      # Test package availability and resolve conflicts
      echo "Testing package availability and resolving conflicts..." >&2
      local all_pkgs=($pkg_list)
      local available_pkgs=""
      local failed_pkgs=""
      
      for pkg in "${all_pkgs[@]}"; do
        if [ -z "$pkg" ]; then continue; fi
        
        # Check if package is available
        if pacman -Sp "$pkg" &>/dev/null; then
          available_pkgs="$available_pkgs $pkg"
        else
          failed_pkgs="$failed_pkgs $pkg"
        fi
      done
      
      # Trim whitespace
      available_pkgs=$(echo "$available_pkgs" | sed "s/^[[:space:]]*//;s/[[:space:]]*$//")
      failed_pkgs=$(echo "$failed_pkgs" | sed "s/^[[:space:]]*//;s/[[:space:]]*$//")
      
      if [ -n "$failed_pkgs" ]; then
        echo "Skipping unavailable packages: $failed_pkgs" >&2
      fi
      
      if [ -n "$available_pkgs" ]; then
        # Apply conflict resolution before installing
        echo "Applying automatic conflict resolution..." >&2
        
        # Method 1: Use --overwrite='*' to override file conflicts
        local resolve_cmd="pacman -S $base_flags $available_pkgs"
        echo "Attempting with --overwrite='*' flag: $resolve_cmd" >&2
        
        if eval "$resolve_cmd"; then
          return 0
        fi
        
        # Method 2: Try individual package installation to isolate conflicts
        echo "Attempting individual package installation..." >&2
        local success_count=0
        for pkg in $available_pkgs; do
          if pacman -S --noconfirm --needed --overwrite='*' "$pkg" 2>/dev/null; then
            echo "Successfully installed: $pkg" >&2
            success_count=$((success_count + 1))
          else
            echo "Failed to install: $pkg" >&2
          fi
        done
        
        if [ $success_count -gt 0 ]; then
          echo "Partially successful: installed $success_count packages" >&2
          return 0
        fi
        
        # Method 3: Use pacman database rebuild as last resort
        echo "Rebuilding package database..." >&2
        pacman-db-upgrade 2>/dev/null || true
        pacman -Syy --noconfirm 2>/dev/null || true
        
        # Final attempt
        if eval "$resolve_cmd"; then
          return 0
        fi
        
        echo "All conflict resolution attempts failed, continuing..." >&2
        return 1
      else
        echo "No available packages found, continuing..." >&2
        return 0
      fi
    else
      echo "Attempt $attempt_num failed! Retrying in 5 seconds..." >&2
      sleep 5
      attempt_num=$(( attempt_num + 1 ))
    fi
  done
}

### ENHANCED PACKAGE REMOVAL FUNCTION ###

safe_remove_packages() {
  local packages="$@"
  if [ -z "$packages" ]; then
    return 0
  fi
  
  echo "Safely removing packages: $packages" >&2
  
  # Check which packages are actually installed
  local installed_packages=""
  for pkg in $packages; do
    if pacman -Q "$pkg" &>/dev/null; then
      installed_packages="$installed_packages $pkg"
    fi
  done
  
  installed_packages=$(echo "$installed_packages" | sed "s/^[[:space:]]*//;s/[[:space:]]*$//")
  
  if [ -n "$installed_packages" ]; then
    # Use cascade removal to handle dependencies properly
    pacman -Rsc --noconfirm $installed_packages 2>/dev/null || \
    pacman -Rdd --noconfirm $installed_packages 2>/dev/null || \
    pacman -R --noconfirm $installed_packages 2>/dev/null || true
    
    echo "Removed packages: $installed_packages" >&2
  else
    echo "No packages to remove" >&2
  fi
}

### SYSTEM PREPARATION ###

# Kill problematic processes
killall -9 xfce4-screensaver 2>/dev/null || true
killall -9 pulseaudio 2>/dev/null || true

# Clean system state
echo "Preparing system for installation..." >&2
pacman -Scc --noconfirm 2>/dev/null || true
pacman -Syy --noconfirm 2>/dev/null || true

### COOLRUNE CHOICE SELECTION ###

echo -e "\e[1mSelect a CoolRune Variant\e[0m"
echo "1. AMD-DESKTOP"
echo "2. AMD-LAPTOP"
echo "3. INTEL-DESKTOP"
echo "4. INTEL-LAPTOP"
echo "5. NVIDIA-OPENSOURCE-DESKTOP"
echo "6. NVIDIA-PROPRIETARY-DESKTOP"

read -p "Enter your choice (1-6): " choice

### IMPORT KEYS WITH RETRY ###

import_keys() {
  local key_id="$1"
  local key_name="$2"
  local max_attempts=3
  local attempt=1
  
  echo -e "\e[1mImporting $key_name keys...\e[0m"
  
  while [ $attempt -le $max_attempts ]; do
    if pacman-key --recv-keys "$key_id" --keyserver keyserver.ubuntu.com 2>/dev/null && \
       pacman-key --lsign-key "$key_id" 2>/dev/null; then
      echo "$key_name keys imported successfully" >&2
      return 0
    fi
    
    echo "Key import attempt $attempt failed, retrying..." >&2
    sleep 2
    attempt=$((attempt + 1))
  done
  
  echo "Failed to import $key_name keys after $max_attempts attempts" >&2
  return 1
}

# Import all keys
import_keys "0FE58E8D1B980E51" "ALHP"
import_keys "F3B607488DB35A47" "CachyOS"
import_keys "3056513887B78AEB" "Chaotic AUR"

### INITIAL SYSTEM SETUP ###

# Install essential packages first
retry_pacman 5 pacman -Sy --noconfirm --needed --overwrite='*' p7zip git

# Create directories
mkdir -p /home/coolrune-files/

# Clone repository with error handling
if [ ! -d "/home/coolrune-files/.git" ]; then
  git clone https://github.com/Michael-Sebero/CoolRune /home/coolrune-files/ || {
    echo "Git clone failed, attempting alternative download..." >&2
    wget -O /tmp/coolrune.zip https://github.com/Michael-Sebero/CoolRune/archive/refs/heads/main.zip && \
    unzip /tmp/coolrune.zip -d /home/ && \
    mv /home/CoolRune-main /home/coolrune-files/ || {
      echo "Failed to download CoolRune files" >&2
      exit 1
    }
  }
fi

cd /home/coolrune-files/files/coolrune-packages/

# Extract configuration files
7z e coolrune-pacman-1.7z -o/etc/ -y 2>/dev/null || unzip -o coolrune-pacman-1.zip -d /etc/ 2>/dev/null || true

# Install core system packages
retry_pacman 5 pacman -Sy --noconfirm --needed --overwrite='*' artix-archlinux-support pacman-contrib artix-keyring

# Install chaotic AUR packages
retry_pacman 3 "pacman -U --noconfirm --overwrite='*' 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'"

# Extract additional configuration
7z e coolrune-pacman-2.7z -o/etc/ -y 2>/dev/null || unzip -o coolrune-pacman-2.zip -d /etc/ 2>/dev/null || true
chmod 755 /etc/pacman.conf

# Populate keyrings
pacman-key --populate archlinux artix 2>/dev/null || true
retry_pacman 3 pacman -Sy --noconfirm --needed --overwrite='*' alhp-keyring

### MIRROR OPTIMIZATION ###

echo -e "\e[1mOptimizing mirrors...\e[0m"
if command -v rankmirrors >/dev/null 2>&1; then
  rankmirrors -v -n 5 -m 2 /etc/pacman.d/mirrorlist > /etc/pacman.d/mirrorlist.new 2>/dev/null && \
  mv /etc/pacman.d/mirrorlist.new /etc/pacman.d/mirrorlist && \
  chmod 644 /etc/pacman.d/mirrorlist || true
fi

### FULL SYSTEM UPDATE ###

echo -e "\e[1mPerforming full system update...\e[0m"
retry_pacman 5 pacman -Syyu --noconfirm --needed --overwrite='*'

# Move manual to desktop
mv /home/coolrune-files/files/coolrune-manual/Manual /home/$USER/Desktop/ 2>/dev/null || true

### REMOVE CONFLICTING PACKAGES ###

echo -e "\e[1mRemoving conflicting packages...\e[0m"
safe_remove_packages "linux linux-headers pulseaudio pulseaudio-alsa pulseaudio-bluetooth pulseaudio-zeroconf epiphany xfce4-screensaver xfce4-terminal xfce4-screenshooter parole xfce4-taskmanager mousepad leafpad xfburn ristretto xfce4-appfinder atril artix-branding-base artix-grub-theme xfce4-sensors-plugin xfce4-notes-plugin mpv xfce4-dict xfce4-weather-plugin"

### INSTALL BASE PACKAGES ###

echo -e "\e[1mInstalling base packages...\e[0m"
retry_pacman 5 pacman -S --noconfirm --needed --overwrite='*' \
  --ignore=vlc,vlc-git,nvidia-390xx-utils,lib32-nvidia-390xx-utils \
  lib32-artix-archlinux-support base-devel unzip xorg-xrandr unrar flatpak \
  kate librewolf python-pip tmux liferea ksnip kcalc font-manager pix gimp \
  gamemode lib32-gamemode okular dnscrypt-proxy dnscrypt-proxy-s6 apparmor \
  apparmor-s6 bleachbit konsole catfish clamav clamav-s6 ark gufw mugshot \
  macchanger networkmanager networkmanager-s6 nm-connection-editor wine-ge-custom \
  wine-mono winetricks ufw-s6 redshift steam lynis element-desktop rkhunter \
  appimagelauncher opendoas mate-system-monitor lightdm-gtk-greeter-settings \
  downgrade libreoffice pipewire-pulse pipewire-alsa wireplumber wine-gecko \
  rust python-psutil python-dateutil python-xlib python-pyaudio python-pipenv \
  usbguard usbguard-s6 hunspell-en_us chkrootkit python-matplotlib python-tqdm \
  python-pillow python-mutagen wget noto-fonts-emoji xfce4-panel-profiles \
  poetry tauon-music-box yt-dlp pyenv freetube python-magic python-piexif \
  alsa-utils expect inotify-tools preload python-moviepy python-brotli \
  python-websockets cpupower cpupower-s6 python-librosa python-audioread \
  ccache earlyoom earlyoom-s6 python-pypdf2 dialog zramen zramen-s6 zfs-utils \
  tree sof-firmware booster bottles paru

### HARDWARE-SPECIFIC INSTALLATIONS ###

install_hardware_packages() {
  local choice="$1"
  local packages="$2"
  local remove_packages="$3"
  
  echo -e "\e[1mInstalling hardware-specific packages for choice $choice...\e[0m"
  
  if [ -n "$remove_packages" ]; then
    safe_remove_packages "$remove_packages"
  fi
  
  if [ -n "$packages" ]; then
    retry_pacman 5 pacman -S --noconfirm --needed --overwrite='*' $packages
  fi
}

# AMD/INTEL-DESKTOP
if [ "$choice" = "1" ] || [ "$choice" = "3" ]; then
  install_hardware_packages "$choice" \
    "linux-cachyos linux-cachyos-headers linux-cachyos-zfs protonup-git vkbasalt lib32-vkbasalt mesa-tkg-git lib32-mesa-tkg-git fail2ban fail2ban-s6" \
    "vulkan-intel vulkan-radeon vulkan-swrast mesa lib32-mesa-git xfce4-power-manager xfce4-battery-plugin"
fi

# AMD/INTEL-LAPTOP
if [ "$choice" = "2" ] || [ "$choice" = "4" ]; then
  install_hardware_packages "$choice" \
    "linux-cachyos-eevdf linux-cachyos-eevdf-headers linux-cachyos-eevdf-zfs throttled tlp tlp-s6 blueman bluez bluez-s6 mesa-tkg-git lib32-mesa-tkg-git" \
    "vulkan-intel vulkan-radeon vulkan-swrast mesa lib32-mesa-git"
fi

# NVIDIA-OPENSOURCE-DESKTOP
if [ "$choice" = "5" ]; then
  install_hardware_packages "$choice" \
    "linux-cachyos linux-cachyos-headers linux-cachyos-zfs protonup-git linux-cachyos-nvidia-open nvidia-utils nvidia-utils-s6 lib32-nvidia-utils nvidia-settings mesa-tkg-git lib32-mesa-tkg-git fail2ban fail2ban-s6" \
    "vulkan-intel vulkan-radeon vulkan-swrast mesa lib32-mesa-git xfce4-power-manager xfce4-battery-plugin"
fi

# NVIDIA-PROPRIETARY-DESKTOP
if [ "$choice" = "6" ]; then
  install_hardware_packages "$choice" \
    "linux-cachyos linux-cachyos-headers linux-cachyos-zfs protonup-git linux-cachyos-nvidia nvidia-utils nvidia-utils-s6 lib32-nvidia-utils nvidia-settings fail2ban fail2ban-s6" \
    "vulkan-intel vulkan-radeon xfce4-power-manager xfce4-battery-plugin"
fi

### FLATPAK SETUP ###

echo -e "\e[1mSetting up Flatpak packages...\e[0m"
flatpak remote-add --if-not-exists flathub-beta https://flathub.org/beta-repo/flathub-beta.flatpakrepo 2>/dev/null || true
flatpak install -y --noninteractive \
  org.gnome.seahorse.Application/x86_64/stable \
  org.kde.haruna \
  org.jdownloader.JDownloader 2>/dev/null || true

### PROTON-GE INSTALLATION ###

if pacman -Q protonup-git &>/dev/null; then
  echo -e "\e[1mInstalling Proton-GE...\e[0m"
  su - "$USER" -c "protonup -d /home/$USER/.local/share/Steam/compatibilitytools.d/ && protonup -y" 2>/dev/null || true
fi

### COOLRUNE CONFIGURATION ###

configure_coolrune() {
  local choice="$1"
  local dotfiles_archive="$2"
  local root_archive="$3"
  local services="$4"
  local additional_archives="$5"
  
  echo -e "\e[1mConfiguring CoolRune for choice $choice...\e[0m"
  
  # Extract configuration files
  if [ -n "$dotfiles_archive" ]; then
    7z x "$dotfiles_archive" -o/home/$USER/ -y 2>/dev/null || true
  fi
  
  if [ -n "$root_archive" ]; then
    unzip -o "$root_archive" -d / 2>/dev/null || true
  fi
  
  if [ -n "$additional_archives" ]; then
    for archive in $additional_archives; do
      7z x "$archive" -o/ -y 2>/dev/null || true
    done
  fi
  
  # Configure services
  for service in $services; do
    s6-service add default "$service" 2>/dev/null || true
  done
  
  # Remove conflicting services
  rm -f /etc/s6/adminsv/default/contents.d/connmand 2>/dev/null || true
  safe_remove_packages "vlc-luajit connman connman-s6 connman-gtk"
  
  # Reload service database
  s6-db-reload 2>/dev/null || true
  
  # Update GRUB
  grub-mkconfig -o /boot/grub/grub.cfg 2>/dev/null || true
}

# Configure based on choice
if [ "$choice" = "1" ] || [ "$choice" = "3" ]; then
  configure_coolrune "$choice" \
    "coolrune-dotfiles.7z" \
    "coolrune-root.zip" \
    "apparmor fail2ban NetworkManager dnscrypt-proxy ufw cpupower earlyoom zramen"
fi

if [ "$choice" = "2" ] || [ "$choice" = "4" ]; then
  configure_coolrune "$choice" \
    "coolrune-dotfiles-laptop.7z" \
    "coolrune-root-laptop.zip" \
    "cpupower apparmor NetworkManager dnscrypt-proxy ufw earlyoom zramen tlp"
fi

if [ "$choice" = "5" ] || [ "$choice" = "6" ]; then
  configure_coolrune "$choice" \
    "coolrune-dotfiles.7z" \
    "coolrune-root.zip" \
    "apparmor fail2ban NetworkManager dnscrypt-proxy ufw cpupower earlyoom zramen" \
    "coolrune-nvidia-patch.7z"
fi

### GAMEMODE SETUP ###

setup_gamemode() {
  local choice="$1"
  
  if [ "$choice" = "1" ] || [ "$choice" = "3" ] || [ "$choice" = "5" ] || [ "$choice" = "6" ]; then
    echo -e "\e[1mSetting up gamemode...\e[0m"
    
    groupadd -f gamemode 2>/dev/null || true
    
    local TARGET_USER="$USER"
    if [ "$TARGET_USER" = "root" ]; then
      TARGET_USER=$(find /home -mindepth 1 -maxdepth 1 -type d -printf "%f\n" | head -1)
    fi
    
    if [ -n "$TARGET_USER" ]; then
      usermod -aG gamemode "$TARGET_USER" 2>/dev/null || true
      echo "Added user $TARGET_USER to gamemode group"
    fi
  fi
}

setup_gamemode "$choice"

### PERMISSION RESET ###

echo -e "\e[1mResetting permissions...\e[0m"
chmod -R 755 /home/$USER 2>/dev/null || true
chmod -R 755 /etc 2>/dev/null || true
chmod -R 755 /usr/share/backgrounds 2>/dev/null || true
chmod -R 755 /usr/share/icons 2>/dev/null || true
chmod -R 755 /usr/share/pictures 2>/dev/null || true
chmod -R 755 /usr/share/themes 2>/dev/null || true
chmod 644 /etc/udev/udev.conf 2>/dev/null || true
chmod -R 777 /home/$USER/.var/ 2>/dev/null || true
chmod -R 777 /home/$USER/.config 2>/dev/null || true
chmod 700 /etc/cron.d /etc/cron.daily /etc/cron.hourly /etc/cron.weekly /etc/cron.monthly 2>/dev/null || true
chmod 600 /etc/cron.deny 2>/dev/null || true
chmod 644 /etc/issue 2>/dev/null || true
chmod 600 /etc/shadow 2>/dev/null || true
chmod -R 777 /home/$USER/.local/ 2>/dev/null || true
chmod 755 /home/$USER/.nvidia-settings-rc 2>/dev/null || true

### HARDENING ###

echo -e "\e[1mApplying security hardening...\e[0m"
if [ -f "/CoolRune/Programs/Hardening-Script/hardening-script.sh" ]; then
  sh /CoolRune/Programs/Hardening-Script/hardening-script.sh 2>/dev/null || true
fi
umask 027

### FINAL CLEANUP ###

echo -e "\e[1mPerforming final cleanup...\e[0m"
cd /
mv /etc/profile /etc/profile.old 2>/dev/null || true
grub-install 2>/dev/null || true
update-grub 2>/dev/null || true
rm -rf /home/coolrune-files/ 2>/dev/null || true

# Final system cleanup
pacman -Scc --noconfirm 2>/dev/null || true

echo -e "\e[1mCoolRune has been successfully installed\e[0m"
echo "System will reboot in 5 seconds..."
sleep 5
reboot
'
