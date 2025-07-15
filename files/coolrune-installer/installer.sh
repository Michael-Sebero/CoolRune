#!/bin/bash

su -c '
### ROBUST RETRY LOGIC ###

retry_pacman() {
  local max_attempts="$1"
  shift
  local command="$@"
  local attempt_num=1
  
  until $command
  do
    if (( attempt_num == max_attempts ))
    then
      echo "Attempt $attempt_num failed! Trying to continue with available packages..." >&2
      
      # Extract package names from the original command
      local pkg_list=""
      if echo "$command" | grep -q " -S "; then
        pkg_list=$(echo "$command" | sed -E "s/.*pacman -S[[:space:]]+--noconfirm[[:space:]]+--needed([[:space:]]+--ignore=[^[:space:]]+)?[[:space:]]+//")
      else
        echo "Unable to parse package list from command, continuing..." >&2
        return 0
      fi
      
      # Extract the ignore flag if present
      local ignore_flag=""
      if echo "$command" | grep -q -- "--ignore="; then
        ignore_flag=$(echo "$command" | grep -o -- "--ignore=[^ ]*")
      fi
      
      # Get list of unavailable packages
      echo "Testing package availability, please wait..." >&2
      local all_pkgs=($pkg_list)
      local available_pkgs=""
      local failed_pkgs=""
      
      for pkg in "${all_pkgs[@]}"; do
        if [ -z "$pkg" ]; then continue; fi
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
        # Reconstruct the command with available packages
        local new_cmd="pacman -S --noconfirm --needed --overwrite='*' $ignore_flag $available_pkgs"
        echo "Executing modified command: $new_cmd" >&2
        
        # Execute the modified command
        eval $new_cmd && return 0 || return 1
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

### ROBUST PACKAGE REMOVAL ###
robust_remove() {
  local packages="$@"
  echo "Attempting to remove packages: $packages" >&2
  
  # First try normal removal
  if pacman -Rdd --noconfirm $packages 2>/dev/null; then
    echo "Successfully removed: $packages" >&2
    return 0
  fi
  
  # If that fails, try removing one by one
  for pkg in $packages; do
    if pacman -Q "$pkg" &>/dev/null; then
      echo "Attempting to remove individual package: $pkg" >&2
      pacman -Rdd --noconfirm "$pkg" 2>/dev/null || echo "Failed to remove $pkg, continuing..." >&2
    fi
  done
  
  return 0
}

### ROBUST SYSTEM UPDATE ###
robust_update() {
  echo "Performing robust system update..." >&2
  
  # Update package databases
  pacman -Sy --noconfirm
  
  # Handle keyring updates first
  pacman -S --noconfirm --needed --overwrite='*' archlinux-keyring artix-keyring 2>/dev/null || true
  
  # Full system upgrade with conflict resolution
  retry_pacman 5 pacman -Syu --noconfirm --needed --overwrite='*'
  
  # If upgrade fails, try individual updates
  if [ $? -ne 0 ]; then
    echo "Full upgrade failed, attempting package-by-package update..." >&2
    pacman -Qu | cut -d' ' -f1 | while read pkg; do
      if [ -n "$pkg" ]; then
        pacman -S --noconfirm --needed --overwrite='*' "$pkg" 2>/dev/null || echo "Failed to update $pkg" >&2
      fi
    done
  fi
}

### ROBUST FILE OPERATIONS ###
robust_extract() {
  local archive="$1"
  local destination="$2"
  local options="$3"
  
  # Create destination directory if it doesn't exist
  mkdir -p "$destination" 2>/dev/null || true
  
  # Set permissions to allow extraction
  chmod 755 "$destination" 2>/dev/null || true
  
  # Extract with overwrite
  if [[ "$archive" == *.7z ]]; then
    7z x "$archive" -o"$destination" -y $options 2>/dev/null || {
      echo "7z extraction failed for $archive, trying to continue..." >&2
      return 0
    }
  elif [[ "$archive" == *.zip ]]; then
    unzip -o "$archive" -d "$destination" $options 2>/dev/null || {
      echo "Zip extraction failed for $archive, trying to continue..." >&2
      return 0
    }
  fi
  
  return 0
}

### ROBUST SERVICE MANAGEMENT ###
robust_service_add() {
  local service="$1"
  echo "Adding service: $service" >&2
  
  # Check if service exists before adding
  if [ -d "/etc/s6/sv/$service" ] || [ -d "/etc/s6/adminsv/default/contents.d" ]; then
    s6-service add default "$service" 2>/dev/null || echo "Failed to add service $service, continuing..." >&2
  else
    echo "Service $service not found, skipping..." >&2
  fi
}

### COOLRUNE CHOICE SELECTION ###

echo -e "\e[1mSelect a CoolRune Variant\e[0m"
echo "1. AMD-DESKTOP"
echo "2. AMD-LAPTOP"
echo "3. INTEL-DESKTOP"
echo "4. INTEL-LAPTOP"
echo "5. NVIDIA-OPENSOURCE-DESKTOP"
echo "6. NVIDIA-PROPRIETARY-DESKTOP"

read -p "Enter your choice (1-6): " choice

### IMPORT KEYS ###

# Set up keyring properly
pacman-key --init 2>/dev/null || true
pacman-key --populate archlinux artix 2>/dev/null || true

# ALHP
echo -e "\e[1mImporting ALHP keys...\e[0m"
pacman-key --recv-keys 0FE58E8D1B980E51 --keyserver keyserver.ubuntu.com 2>/dev/null || \
pacman-key --recv-keys 0FE58E8D1B980E51 --keyserver hkp://keyserver.ubuntu.com:80 2>/dev/null || \
pacman-key --recv-keys 0FE58E8D1B980E51 --keyserver pgp.mit.edu 2>/dev/null || true
pacman-key --lsign-key 0FE58E8D1B980E51 2>/dev/null || true

# CACHYOS
echo -e "\e[1mImporting CachyOS keys...\e[0m"
pacman-key --recv-keys F3B607488DB35A47 --keyserver keyserver.ubuntu.com 2>/dev/null || \
pacman-key --recv-keys F3B607488DB35A47 --keyserver hkp://keyserver.ubuntu.com:80 2>/dev/null || \
pacman-key --recv-keys F3B607488DB35A47 --keyserver pgp.mit.edu 2>/dev/null || true
pacman-key --lsign-key F3B607488DB35A47 2>/dev/null || true

# CHAOTIC AUR
echo -e "\e[1mImporting Chaotic AUR keys...\e[0m"
pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com 2>/dev/null || \
pacman-key --recv-key 3056513887B78AEB --keyserver hkp://keyserver.ubuntu.com:80 2>/dev/null || \
pacman-key --recv-key 3056513887B78AEB --keyserver pgp.mit.edu 2>/dev/null || true
pacman-key --lsign-key 3056513887B78AEB 2>/dev/null || true

# FIRST COMMANDS AND COOLRUNE IMPORT P1
killall xfce4-screensaver 2>/dev/null || true
robust_update
retry_pacman 5 pacman -S --noconfirm --needed --overwrite='*' p7zip git
mkdir -p /home/coolrune-files/ 2>/dev/null || true
git clone https://github.com/Michael-Sebero/CoolRune /home/coolrune-files/ 2>/dev/null || \
git clone https://github.com/Michael-Sebero/CoolRune /home/coolrune-files/ --depth=1 2>/dev/null || true
cd /home/coolrune-files/files/coolrune-packages/ 2>/dev/null || {
  echo "Failed to access coolrune packages directory, continuing..." >&2
  cd /
}

# Extract configuration files
robust_extract "coolrune-pacman-1.7z" "/etc/" ""
retry_pacman 5 pacman -S --noconfirm --needed --overwrite='*' artix-archlinux-support pacman-contrib artix-keyring

# Install chaotic-aur keyring and mirrorlist
retry_pacman 5 pacman -U --noconfirm --overwrite='*' 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'

robust_extract "coolrune-pacman-2.7z" "/etc/" ""
chmod 755 /etc/pacman.conf 2>/dev/null || true

# Update keyrings
pacman-key --populate archlinux artix 2>/dev/null || true
retry_pacman 5 pacman -S --noconfirm --needed --overwrite='*' alhp-keyring

# Clean up potential conflicts
rm -f /usr/lib/firmware/nvidia/ad10{3,4,5,6,7}* 2>/dev/null || true
robust_remove "lib32-mesa-git mesa"

# FIND QUICKEST MIRRORLIST
echo -e "\e[1mFinding quickest mirrorlist, please wait...\e[0m"
sh -c "rankmirrors -v -n 5 -m 2 /etc/pacman.d/mirrorlist > /etc/pacman.d/mirrorlist.new 2>/dev/null && mv /etc/pacman.d/mirrorlist.new /etc/pacman.d/mirrorlist 2>/dev/null && chmod 644 /etc/pacman.d/mirrorlist 2>/dev/null" || true

# FIRST COMMANDS AND COOLRUNE IMPORT P2
robust_update
mkdir -p /home/$USER/Desktop/ 2>/dev/null || true
mv /home/coolrune-files/files/coolrune-manual/Manual /home/$USER/Desktop/ 2>/dev/null || true

# REPO PACKAGES REMOVE
robust_remove "linux linux-headers pulseaudio pulseaudio-alsa pulseaudio-bluetooth pulseaudio-zeroconf epiphany xfce4-screensaver xfce4-terminal xfce4-screenshooter parole xfce4-taskmanager mousepad leafpad xfburn ristretto xfce4-appfinder atril artix-branding-base artix-grub-theme xfce4-sensors-plugin xfce4-notes-plugin mpv xfce4-dict xfce4-weather-plugin"

# BASE REPO PACKAGES INSTALL
retry_pacman 5 pacman -S --noconfirm --needed --overwrite='*' --ignore=vlc,vlc-git,nvidia-390xx-utils,lib32-nvidia-390xx-utils lib32-artix-archlinux-support base-devel unzip xorg-xrandr unrar flatpak kate librewolf python-pip tmux liferea ksnip kcalc font-manager pix gimp gamemode lib32-gamemode okular dnscrypt-proxy dnscrypt-proxy-s6 apparmor apparmor-s6 bleachbit konsole catfish clamav clamav-s6 ark gufw mugshot macchanger networkmanager networkmanager-s6 nm-connection-editor wine-ge-custom wine-mono winetricks ufw-s6 redshift steam lynis element-desktop rkhunter appimagelauncher opendoas mate-system-monitor lightdm-gtk-greeter-settings downgrade libreoffice pipewire-pulse pipewire-alsa wireplumber wine-gecko rust python-psutil python-dateutil python-xlib python-pyaudio python-pipenv usbguard usbguard-s6 hunspell-en_us chkrootkit python-matplotlib python-tqdm python-pillow python-mutagen wget noto-fonts-emoji xfce4-panel-profiles poetry tauon-music-box yt-dlp pyenv freetube python-magic python-piexif alsa-utils expect inotify-tools preload python-moviepy python-brotli python-websockets cpupower cpupower-s6 python-librosa python-audioread ccache earlyoom earlyoom-s6 python-pypdf2 dialog zramen zramen-s6 zfs-utils tree sof-firmware booster bottles paru

# AMD/INTEL-DESKTOP CHOICE
if [ "$choice" = "1" ] || [ "$choice" = "3" ]; then
  robust_remove "vulkan-intel vulkan-radeon vulkan-swrast xfce4-power-manager xfce4-battery-plugin"
  retry_pacman 5 pacman -S --noconfirm --needed --overwrite='*' linux-cachyos linux-cachyos-headers linux-cachyos-zfs protonup-git vkbasalt lib32-vkbasalt mesa-tkg-git lib32-mesa-tkg-git fail2ban fail2ban-s6
fi

# AMD/INTEL-LAPTOP CHOICE
if [ "$choice" = "2" ] || [ "$choice" = "4" ]; then
  robust_remove "vulkan-intel vulkan-radeon vulkan-swrast"
  retry_pacman 5 pacman -S --noconfirm --needed --overwrite='*' linux-cachyos-eevdf linux-cachyos-eevdf-headers linux-cachyos-eevdf-zfs throttled tlp tlp-s6 blueman bluez bluez-s6 mesa-tkg-git lib32-mesa-tkg-git
fi

# NVIDIA-OPENSOURCE-DESKTOP CHOICE
if [ "$choice" = "5" ]; then
  robust_remove "vulkan-intel vulkan-radeon vulkan-swrast xfce4-power-manager xfce4-battery-plugin"
  retry_pacman 5 pacman -S --noconfirm --needed --overwrite='*' linux-cachyos linux-cachyos-headers linux-cachyos-zfs protonup-git linux-cachyos-nvidia-open nvidia-utils nvidia-utils-s6 lib32-nvidia-utils nvidia-settings mesa-tkg-git lib32-mesa-tkg-git fail2ban fail2ban-s6
fi

# NVIDIA-PROPRIETARY-DESKTOP CHOICE
if [ "$choice" = "6" ]; then
  robust_remove "vulkan-intel vulkan-radeon xfce4-power-manager xfce4-battery-plugin"
  retry_pacman 5 pacman -S --noconfirm --needed --overwrite='*' linux-cachyos linux-cachyos-headers linux-cachyos-zfs protonup-git linux-cachyos-nvidia nvidia-utils nvidia-utils-s6 lib32-nvidia-utils nvidia-settings fail2ban fail2ban-s6
fi

# FLATPAK PACKAGES
flatpak remote-add --if-not-exists flathub-beta https://flathub.org/beta-repo/flathub-beta.flatpakrepo 2>/dev/null || true
flatpak install -y --noninteractive org.gnome.seahorse.Application/x86_64/stable org.kde.haruna org.jdownloader.JDownloader 2>/dev/null || true

# INSTALL PROTON-GE
if pacman -Q protonup-git &>/dev/null; then
    mkdir -p /home/$USER/.local/share/Steam/compatibilitytools.d/ 2>/dev/null || true
    su - "$USER" -c "protonup -d /home/$USER/.local/share/Steam/compatibilitytools.d/ 2>/dev/null && protonup -y 2>/dev/null" || true
fi

### COOLRUNE INSTALL ###

# Change to coolrune packages directory
cd /home/coolrune-files/files/coolrune-packages/ 2>/dev/null || {
  echo "Warning: Could not access coolrune packages directory" >&2
  cd /
}

# AMD/INTEL DESKTOP SELECTION
if [ "$choice" = "1" ] || [ "$choice" = "3" ]; then
  robust_extract "coolrune-dotfiles.7z" "/home/$USER/" ""
  robust_extract "coolrune-root.zip" "/" ""
  robust_service_add "apparmor"
  robust_service_add "fail2ban"
  robust_service_add "NetworkManager"
  robust_service_add "dnscrypt-proxy"
  robust_service_add "ufw"
  robust_service_add "cpupower"
  robust_service_add "earlyoom"
  robust_service_add "zramen"
  rm -f /etc/s6/adminsv/default/contents.d/connmand 2>/dev/null || true
  robust_remove "vlc-luajit connman connman-s6 connman-gtk"
  s6-db-reload 2>/dev/null || true
  grub-mkconfig -o /boot/grub/grub.cfg 2>/dev/null || true
fi

# LAPTOP SELECTION
if [ "$choice" = "2" ] || [ "$choice" = "4" ]; then
  robust_extract "coolrune-dotfiles-laptop.7z" "/home/$USER/" ""
  robust_extract "coolrune-root-laptop.zip" "/" ""
  robust_service_add "cpupower"
  robust_service_add "apparmor"
  robust_service_add "NetworkManager"
  robust_service_add "dnscrypt-proxy"
  robust_service_add "ufw"
  robust_service_add "earlyoom"
  robust_service_add "zramen"
  robust_service_add "tlp"
  rm -f /etc/s6/adminsv/default/contents.d/connmand 2>/dev/null || true
  robust_remove "vlc-luajit connman connman-s6 connman-gtk"
  s6-db-reload 2>/dev/null || true
  grub-mkconfig -o /boot/grub/grub.cfg 2>/dev/null || true
fi

# NVIDIA SELECTION
if [ "$choice" = "5" ] || [ "$choice" = "6" ]; then
  robust_extract "coolrune-dotfiles.7z" "/home/$USER/" ""
  robust_extract "coolrune-root.zip" "/" ""
  robust_extract "coolrune-nvidia-patch.7z" "/" ""
  robust_service_add "apparmor"
  robust_service_add "fail2ban"
  robust_service_add "NetworkManager"
  robust_service_add "dnscrypt-proxy"
  robust_service_add "ufw"
  robust_service_add "cpupower"
  robust_service_add "earlyoom"
  robust_service_add "zramen"
  rm -f /etc/s6/adminsv/default/contents.d/connmand 2>/dev/null || true
  robust_remove "vlc-luajit connman connman-s6 connman-gtk"
  s6-db-reload 2>/dev/null || true
  grub-mkconfig -o /boot/grub/grub.cfg 2>/dev/null || true
fi

# CREATE GAMEMODE GROUP
if [ "$choice" = "1" ] || [ "$choice" = "3" ] || [ "$choice" = "5" ] || [ "$choice" = "6" ]; then
  groupadd -f gamemode 2>/dev/null || true
  TARGET_USER=$USER
  if [ "$TARGET_USER" = "root" ]; then
    TARGET_USER=$(find /home -mindepth 1 -maxdepth 1 -type d -printf "%f\n" 2>/dev/null | head -1)
  fi
  if [ -n "$TARGET_USER" ]; then
    usermod -aG gamemode "$TARGET_USER" 2>/dev/null || true
    echo "Added user $TARGET_USER to gamemode group"
    if id "$TARGET_USER" | grep -o "gamemode" &>/dev/null; then
      echo "Successfully added to gamemode group"
    else
      echo "Failed to add to gamemode group"
    fi
  fi
fi

# RESET PERMISSIONS
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

# HARDENING SCRIPT
if [ -f "/CoolRune/Programs/Hardening-Script/hardening-script.sh" ]; then
  sh /CoolRune/Programs/Hardening-Script/hardening-script.sh 2>/dev/null || true
fi
umask 027 2>/dev/null || true
cd /

# LAST COMMANDS
mv /etc/profile{,.old} 2>/dev/null || true
grub-install 2>/dev/null || true
update-grub 2>/dev/null || true
rm -rf /home/coolrune-files/ 2>/dev/null || true
echo -e "\e[1mCoolRune has been successfully installed\e[0m"
reboot
'
