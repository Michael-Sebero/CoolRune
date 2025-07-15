#!/bin/bash

su -c '
### ENHANCED RETRY LOGIC WITH CONFLICT RESOLUTION ###

retry_pacman() {
  local max_attempts="$1"
  shift
  local command="$@"
  local attempt_num=1
  
  until $command
  do
    if (( attempt_num == max_attempts ))
    then
      echo "Attempt $attempt_num failed! Applying conflict resolution strategies..." >&2
      
      # Extract package names from the original command
      local pkg_list=""
      if echo "$command" | grep -q " -S "; then
        pkg_list=$(echo "$command" | sed -E "s/.*pacman -S[[:space:]]+--noconfirm[[:space:]]+--needed([[:space:]]+--ignore=[^[:space:]]+)?[[:space:]]+([^[:space:]]+[[:space:]]+)?//")
      else
        echo "Unable to parse package list from command, continuing..." >&2
        return 0
      fi
      
      # Extract the ignore flag if present
      local ignore_flag=""
      if echo "$command" | grep -q -- "--ignore="; then
        ignore_flag=$(echo "$command" | grep -o -- "--ignore=[^ ]*")
      fi
      
      # Advanced conflict resolution
      echo "Resolving package conflicts..." >&2
      
      # Force remove conflicting packages that commonly cause issues
      pacman -Rdd --noconfirm lib32-mesa mesa libxml2 poppler poppler-glib vulkan-intel vulkan-radeon vulkan-swrast 2>/dev/null || true
      
      # Clear package cache to avoid corrupted files
      pacman -Scc --noconfirm 2>/dev/null || true
      
      # Update package databases
      pacman -Sy --noconfirm 2>/dev/null || true
      
      # Test package availability and resolve dependencies
      echo "Testing package availability and resolving dependencies..." >&2
      local all_pkgs=($pkg_list)
      local available_pkgs=""
      local failed_pkgs=""
      
      for pkg in "${all_pkgs[@]}"; do
        if [ -z "$pkg" ]; then continue; fi
        
        # Check if package exists and can be installed
        if pacman -Sp "$pkg" &>/dev/null; then
          # Check for dependency conflicts
          if pacman -T "$pkg" &>/dev/null; then
            available_pkgs="$available_pkgs $pkg"
          else
            # Try to resolve dependency issues
            echo "Resolving dependencies for $pkg..." >&2
            if pacman -S --noconfirm --asdeps $(pacman -T "$pkg" 2>/dev/null | tr '\n' ' ') &>/dev/null; then
              available_pkgs="$available_pkgs $pkg"
            else
              failed_pkgs="$failed_pkgs $pkg"
            fi
          fi
        else
          failed_pkgs="$failed_pkgs $pkg"
        fi
      done
      
      # Trim whitespace
      available_pkgs=$(echo "$available_pkgs" | sed "s/^[[:space:]]*//;s/[[:space:]]*$//")
      failed_pkgs=$(echo "$failed_pkgs" | sed "s/^[[:space:]]*//;s/[[:space:]]*$//")
      
      if [ -n "$failed_pkgs" ]; then
        echo "Deferring problematic packages: $failed_pkgs" >&2
        
        # Store failed packages for later retry
        echo "$failed_pkgs" >> /tmp/deferred_packages.txt
      fi
      
      if [ -n "$available_pkgs" ]; then
        # Reconstruct the command with available packages and enhanced flags
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

# Function to install deferred packages
install_deferred_packages() {
  if [ -f /tmp/deferred_packages.txt ]; then
    echo "Attempting to install previously deferred packages..." >&2
    local deferred_pkgs=$(cat /tmp/deferred_packages.txt | tr '\n' ' ')
    if [ -n "$deferred_pkgs" ]; then
      # Clear conflicts again
      pacman -Rdd --noconfirm lib32-mesa mesa libxml2 poppler poppler-glib vulkan-intel vulkan-radeon vulkan-swrast 2>/dev/null || true
      pacman -Sy --noconfirm
      
      # Try installing deferred packages one by one
      for pkg in $deferred_pkgs; do
        if [ -n "$pkg" ]; then
          echo "Attempting to install deferred package: $pkg" >&2
          pacman -S --noconfirm --needed --overwrite='*' "$pkg" 2>/dev/null || echo "Still unable to install $pkg, skipping..." >&2
        fi
      done
    fi
    rm -f /tmp/deferred_packages.txt
  fi
}

# Function to handle system upgrade with conflict resolution
safe_system_upgrade() {
  echo "Performing safe system upgrade..." >&2
  
  # Clear package cache
  pacman -Scc --noconfirm 2>/dev/null || true
  
  # Update package databases
  pacman -Sy --noconfirm
  
  # Pre-emptively remove known problematic packages
  pacman -Rdd --noconfirm lib32-mesa mesa libxml2 poppler poppler-glib vulkan-intel vulkan-radeon vulkan-swrast 2>/dev/null || true
  
  # Perform upgrade with conflict resolution
  pacman -Syu --noconfirm --overwrite='*' 2>/dev/null || {
    echo "Standard upgrade failed, applying conflict resolution..." >&2
    
    # More aggressive conflict resolution
    pacman -Rdd --noconfirm $(pacman -Qtdq) 2>/dev/null || true  # Remove orphaned packages
    pacman -Sc --noconfirm 2>/dev/null || true  # Clear cache
    
    # Try upgrade again
    pacman -Syu --noconfirm --overwrite='*'
  }
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

# ALHP
echo -e "\e[1mImporting ALHP keys...\e[0m"
pacman-key --recv-keys 0FE58E8D1B980E51 --keyserver keyserver.ubuntu.com; pacman-key --lsign-key 0FE58E8D1B980E51

# CACHYOS
echo -e "\e[1mImporting CachyOS keys...\e[0m"
pacman-key --recv-keys F3B607488DB35A47 --keyserver keyserver.ubuntu.com; pacman-key --lsign-key F3B607488DB35A47

# CHAOTIC AUR
echo -e "\e[1mImporting Chaotic AUR keys...\e[0m"
pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com; pacman-key --lsign-key 3056513887B78AEB

# FIRST COMMANDS AND COOLRUNE IMPORT P1
killall xfce4-screensaver 2>/dev/null || true
pacman -Sy --noconfirm --needed p7zip git
mkdir -p /home/coolrune-files/
git clone https://github.com/Michael-Sebero/CoolRune /home/coolrune-files/
cd /home/coolrune-files/files/coolrune-packages/
7z e coolrune-pacman-1.7z -o/etc/ -y
pacman -Sy --noconfirm artix-archlinux-support pacman-contrib artix-keyring
pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'
7z e coolrune-pacman-2.7z -o/etc/ -y
chmod 755 /etc/pacman.conf
pacman-key --populate archlinux artix
pacman -Sy --noconfirm alhp-keyring

# FIND QUICKEST MIRRORLIST
echo -e "\e[1mFinding quickest mirrorlist, please wait...\e[0m"
sh -c "rankmirrors -v -n 5 -m 2 /etc/pacman.d/mirrorlist > /etc/pacman.d/mirrorlist.new && mv /etc/pacman.d/mirrorlist.new /etc/pacman.d/mirrorlist && chmod 644 /etc/pacman.d/mirrorlist"

# FIRST COMMANDS AND COOLRUNE IMPORT P2
safe_system_upgrade
mv /home/coolrune-files/files/coolrune-manual/Manual /home/$USER/Desktop/

# REPO PACKAGES REMOVE
pacman -Rdd --noconfirm linux linux-headers pulseaudio pulseaudio-alsa pulseaudio-bluetooth pulseaudio-zeroconf epiphany xfce4-screensaver xfce4-terminal xfce4-screenshooter parole xfce4-taskmanager mousepad leafpad xfburn ristretto xfce4-appfinder atril artix-branding-base artix-grub-theme xfce4-sensors-plugin xfce4-notes-plugin mpv xfce4-dict xfce4-weather-plugin 2>/dev/null || true

# BASE REPO PACKAGES INSTALL
retry_pacman 5 pacman -S --noconfirm --needed --overwrite='*' --ignore=vlc,vlc-git,nvidia-390xx-utils,lib32-nvidia-390xx-utils lib32-artix-archlinux-support base-devel unzip xorg-xrandr unrar flatpak kate librewolf python-pip tmux liferea ksnip kcalc font-manager pix gimp gamemode lib32-gamemode okular dnscrypt-proxy dnscrypt-proxy-s6 apparmor apparmor-s6 bleachbit konsole catfish clamav clamav-s6 ark gufw mugshot macchanger networkmanager networkmanager-s6 nm-connection-editor wine-ge-custom wine-mono winetricks ufw-s6 redshift steam lynis element-desktop rkhunter appimagelauncher opendoas mate-system-monitor lightdm-gtk-greeter-settings downgrade libreoffice pipewire-pulse pipewire-alsa wireplumber wine-gecko rust python-psutil python-dateutil python-xlib python-pyaudio python-pipenv usbguard usbguard-s6 hunspell-en_us chkrootkit python-matplotlib python-tqdm python-pillow python-mutagen wget noto-fonts-emoji xfce4-panel-profiles poetry tauon-music-box yt-dlp pyenv freetube python-magic python-piexif alsa-utils expect inotify-tools preload python-moviepy python-brotli python-websockets cpupower cpupower-s6 python-librosa python-audioread ccache earlyoom earlyoom-s6 python-pypdf2 dialog zramen zramen-s6 zfs-utils tree sof-firmware booster bottles paru

# AMD/INTEL-DESKTOP CHOICE
if [ "$choice" = "1" ] || [ "$choice" = "3" ]; then
  pacman -Rdd --noconfirm vulkan-intel vulkan-radeon vulkan-swrast mesa lib32-mesa-git xfce4-power-manager xfce4-battery-plugin 2>/dev/null || true
  retry_pacman 5 pacman -S --noconfirm --needed --overwrite='*' linux-cachyos linux-cachyos-headers linux-cachyos-zfs protonup-git vkbasalt lib32-vkbasalt mesa-tkg-git lib32-mesa-tkg-git fail2ban fail2ban-s6
fi

# AMD/INTEL-LAPTOP CHOICE
if [ "$choice" = "2" ] || [ "$choice" = "4" ]; then
  pacman -Rdd --noconfirm vulkan-intel vulkan-radeon vulkan-swrast mesa lib32-mesa-git 2>/dev/null || true
  retry_pacman 5 pacman -S --noconfirm --needed --overwrite='*' linux-cachyos-eevdf linux-cachyos-eevdf-headers linux-cachyos-eevdf-zfs throttled tlp tlp-s6 blueman bluez bluez-s6 mesa-tkg-git lib32-mesa-tkg-git
fi

# NVIDIA-OPENSOURCE-DESKTOP CHOICE
if [ "$choice" = "5" ]; then
  pacman -Rdd --noconfirm vulkan-intel vulkan-radeon vulkan-swrast mesa lib32-mesa-git xfce4-power-manager xfce4-battery-plugin 2>/dev/null || true
  retry_pacman 5 pacman -S --noconfirm --needed --overwrite='*' linux-cachyos linux-cachyos-headers linux-cachyos-zfs protonup-git linux-cachyos-nvidia-open nvidia-utils nvidia-utils-s6 lib32-nvidia-utils nvidia-settings mesa-tkg-git lib32-mesa-tkg-git fail2ban fail2ban-s6
fi

# NVIDIA-PROPRIETARY-DESKTOP CHOICE
if [ "$choice" = "6" ]; then
  pacman -Rdd --noconfirm vulkan-intel vulkan-radeon xfce4-power-manager xfce4-battery-plugin 2>/dev/null || true
  retry_pacman 5 pacman -S --noconfirm --needed --overwrite='*' linux-cachyos linux-cachyos-headers linux-cachyos-zfs protonup-git linux-cachyos-nvidia nvidia-utils nvidia-utils-s6 lib32-nvidia-utils nvidia-settings fail2ban fail2ban-s6
fi

# ATTEMPT TO INSTALL ANY DEFERRED PACKAGES
install_deferred_packages

# FLATPAK PACKAGES
flatpak remote-add flathub-beta https://flathub.org/beta-repo/flathub-beta.flatpakrepo 2>/dev/null || true
flatpak install -y org.gnome.seahorse.Application/x86_64/stable org.kde.haruna org.jdownloader.JDownloader 2>/dev/null || true

# INSTALL PROTON-GE
if pacman -Q protonup-git &>/dev/null; then
    su - "$USER" -c "protonup -d /home/$USER/.local/share/Steam/compatibilitytools.d/ && protonup -y" 2>/dev/null || true
fi

### COOLRUNE INSTALL ###

# AMD/INTEL DESKTOP SELECTION
if [ "$choice" = "1" ] || [ "$choice" = "3" ]; then
  7z x coolrune-dotfiles.7z -o/home/$USER/ -y
  unzip -o coolrune-root.zip -d /
  s6-service add default apparmor 2>/dev/null || true
  s6-service add default fail2ban 2>/dev/null || true
  s6-service add default NetworkManager 2>/dev/null || true
  s6-service add default dnscrypt-proxy 2>/dev/null || true
  s6-service add default ufw 2>/dev/null || true
  s6-service add default cpupower 2>/dev/null || true
  s6-service add default earlyoom 2>/dev/null || true
  s6-service add default zramen 2>/dev/null || true
  rm -f /etc/s6/adminsv/default/contents.d/connmand
  pacman -Rdd --noconfirm vlc-luajit connman connman-s6 connman-gtk 2>/dev/null || true
  s6-db-reload 2>/dev/null || true
  grub-mkconfig -o /boot/grub/grub.cfg 2>/dev/null || true
fi

# LAPTOP SELECTION
if [ "$choice" = "2" ] || [ "$choice" = "4" ]; then
  7z x coolrune-dotfiles-laptop.7z -o/home/$USER/ -y
  unzip -o coolrune-root-laptop.zip -d /
  s6-service add default cpupower 2>/dev/null || true
  s6-service add default apparmor 2>/dev/null || true
  s6-service add default NetworkManager 2>/dev/null || true
  s6-service add default dnscrypt-proxy 2>/dev/null || true
  s6-service add default ufw 2>/dev/null || true
  s6-service add default earlyoom 2>/dev/null || true
  s6-service add default zramen 2>/dev/null || true
  s6-service add default tlp 2>/dev/null || true
  rm -f /etc/s6/adminsv/default/contents.d/connmand
  pacman -Rdd --noconfirm vlc-luajit connman connman-s6 connman-gtk 2>/dev/null || true
  s6-db-reload 2>/dev/null || true
  grub-mkconfig -o /boot/grub/grub.cfg 2>/dev/null || true
fi

# NVIDIA SELECTION
if [ "$choice" = "5" ] || [ "$choice" = "6" ]; then
  7z x coolrune-dotfiles.7z -o/home/$USER/ -y
  unzip -o coolrune-root.zip -d /
  7z x coolrune-nvidia-patch.7z -o/ -y
  s6-service add default apparmor 2>/dev/null || true
  s6-service add default fail2ban 2>/dev/null || true
  s6-service add default NetworkManager 2>/dev/null || true
  s6-service add default dnscrypt-proxy 2>/dev/null || true
  s6-service add default ufw 2>/dev/null || true
  s6-service add default cpupower 2>/dev/null || true
  s6-service add default earlyoom 2>/dev/null || true
  s6-service add default zramen 2>/dev/null || true
  rm -f /etc/s6/adminsv/default/contents.d/connmand
  pacman -Rdd --noconfirm vlc-luajit connman connman-s6 connman-gtk 2>/dev/null || true
  s6-db-reload 2>/dev/null || true
  grub-mkconfig -o /boot/grub/grub.cfg 2>/dev/null || true
fi

# CREATE GAMEMODE GROUP
if [ "$choice" = "1" ] || [ "$choice" = "3" ] || [ "$choice" = "5" ] || [ "$choice" = "6" ]; then
  groupadd -f gamemode 2>/dev/null || true
  TARGET_USER=$USER
  if [ "$TARGET_USER" = "root" ]; then
    TARGET_USER=$(find /home -mindepth 1 -maxdepth 1 -type d -printf "%f\n" | head -1)
  fi
  usermod -aG gamemode "$TARGET_USER" 2>/dev/null || true
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
sh /CoolRune/Programs/Hardening-Script/hardening-script.sh && umask 027 2>/dev/null || true
cd /

# LAST COMMANDS
mv /etc/profile{,.old} 2>/dev/null || true
grub-install 2>/dev/null || true
update-grub 2>/dev/null || true
rm -rf /home/coolrune-files/
echo -e "\e[1mCoolRune has been successfully installed\e[0m"
reboot
'
