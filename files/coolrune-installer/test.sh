#!/bin/bash

su -c '
### RETRY LOGIC ###

retry_pacman() {
  local max_attempts="$1"
  shift
  local command="$@"
  local attempt_num=1
  
  echo "Executing: $command" >&2
  
  until $command
  do
    local exit_code=$?
    echo "Command failed with exit code: $exit_code" >&2
    
    if (( attempt_num == max_attempts ))
    then
      echo "Attempt $attempt_num failed! Trying to continue with available packages..." >&2
      
      # Extract package names from the original command
      local pkg_list=""
      if echo "$command" | grep -q " -S "; then
        pkg_list=$(echo "$command" | sed -E "s/.*pacman -S[[:space:]]+--noconfirm[[:space:]]+--needed([[:space:]]+--overwrite=[^[:space:]]+)?([[:space:]]+--ignore=[^[:space:]]+)?[[:space:]]+//")
      else
        echo "Unable to parse package list from command, skipping package availability check..." >&2
        echo "Continuing with script execution..." >&2
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
        echo "Checking package: $pkg" >&2
        if timeout 30 pacman -Sp "$pkg" &>/dev/null; then
          available_pkgs="$available_pkgs $pkg"
          echo "Available: $pkg" >&2
        else
          failed_pkgs="$failed_pkgs $pkg"
          echo "Unavailable: $pkg" >&2
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
        local new_cmd="pacman -S --noconfirm --needed --overwrite=\"*\" $ignore_flag $available_pkgs"
        echo "Executing modified command: $new_cmd" >&2
        
        # Execute the modified command
        if eval $new_cmd; then
          echo "Modified command succeeded" >&2
          return 0
        else
          echo "Modified command also failed, continuing anyway..." >&2
          return 0
        fi
      else
        echo "No available packages found, continuing..." >&2
        return 0
      fi
    else
      echo "Attempt $attempt_num failed! Retrying in 10 seconds..." >&2
      sleep 10
      attempt_num=$(( attempt_num + 1 ))
    fi
  done
  
  echo "Command succeeded on attempt $attempt_num" >&2
  return 0
}

### COOLRUNE CHOICE SELECTION ###

echo "Select a CoolRune Variant"
echo "1. AMD-DESKTOP"
echo "2. AMD-LAPTOP"
echo "3. INTEL-DESKTOP"
echo "4. INTEL-LAPTOP"
echo "5. NVIDIA-OPENSOURCE-DESKTOP"
echo "6. NVIDIA-PROPRIETARY-DESKTOP"

read -p "Enter your choice (1-6): " choice

# Validate choice
case "$choice" in
    [1-6]) echo "Selected option: $choice" ;;
    *) echo "Invalid choice. Defaulting to option 1 (AMD-DESKTOP)"; choice=1 ;;
esac

### IMPORT KEYS ###

echo -e "\e[1mImporting ALHP keys...\e[0m"
pacman-key --recv-keys 0FE58E8D1B980E51 --keyserver keyserver.ubuntu.com || echo "Failed to import ALHP keys, continuing..."
pacman-key --lsign-key 0FE58E8D1B980E51 || echo "Failed to sign ALHP keys, continuing..."

echo -e "\e[1mImporting CachyOS keys...\e[0m"
pacman-key --recv-keys F3B607488DB35A47 --keyserver keyserver.ubuntu.com || echo "Failed to import CachyOS keys, continuing..."
pacman-key --lsign-key F3B607488DB35A47 || echo "Failed to sign CachyOS keys, continuing..."

echo -e "\e[1mImporting Chaotic AUR keys...\e[0m"
pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com || echo "Failed to import Chaotic AUR keys, continuing..."
pacman-key --lsign-key 3056513887B78AEB || echo "Failed to sign Chaotic AUR keys, continuing..."

### FIRST COMMANDS AND COOLRUNE IMPORT P1 ###

echo -e "\e[1mStarting initial setup...\e[0m"
killall xfce4-screensaver 2>/dev/null || true

echo -e "\e[1mInstalling initial packages...\e[0m"
pacman -Sy --noconfirm --needed p7zip git || {
    echo "Failed to install initial packages, exiting..."
    exit 1
}

echo -e "\e[1mCloning CoolRune repository...\e[0m"
rm -rf /home/coolrune-files/
mkdir -p /home/coolrune-files/
if ! git clone https://github.com/Michael-Sebero/CoolRune /home/coolrune-files/; then
    echo "Failed to clone CoolRune repository, exiting..."
    exit 1
fi

cd /home/coolrune-files/files/coolrune-packages/ || {
    echo "Failed to navigate to coolrune-packages directory, exiting..."
    exit 1
}

echo -e "\e[1mExtracting pacman configuration (part 1)...\e[0m"
7z e coolrune-pacman-1.7z -o/etc/ -y || echo "Failed to extract coolrune-pacman-1.7z, continuing..."

echo -e "\e[1mInstalling Artix and Chaotic AUR support...\e[0m"
pacman -Sy --noconfirm artix-archlinux-support pacman-contrib || echo "Failed to install artix support, continuing..."

echo -e "\e[1mInstalling Chaotic AUR keyrings...\e[0m"
pacman -U --noconfirm \
    "https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst" \
    "https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst" || echo "Failed to install Chaotic AUR keyrings, continuing..."

echo -e "\e[1mExtracting pacman configuration (part 2)...\e[0m"
7z e coolrune-pacman-2.7z -o/etc/ -y || echo "Failed to extract coolrune-pacman-2.7z, continuing..."
chmod 755 /etc/pacman.conf

echo -e "\e[1mPopulating keyrings...\e[0m"
pacman-key --populate archlinux artix || echo "Failed to populate keyrings, continuing..."
pacman -Sy --noconfirm alhp-keyring || echo "Failed to install ALHP keyring, continuing..."

### FIND QUICKEST MIRRORLIST ###

echo -e "\e[1mFinding quickest mirrorlist, please wait...\e[0m"
if command -v rankmirrors >/dev/null 2>&1; then
    timeout 300 sh -c "rankmirrors -v -n 5 -m 2 /etc/pacman.d/mirrorlist > /etc/pacman.d/mirrorlist.new && mv /etc/pacman.d/mirrorlist.new /etc/pacman.d/mirrorlist && chmod 644 /etc/pacman.d/mirrorlist" || echo "Failed to rank mirrors, using existing mirrorlist..."
else
    echo "rankmirrors not available, using existing mirrorlist..."
fi

### FIRST COMMANDS AND COOLRUNE IMPORT P2 ###

echo -e "\e[1mPerforming system update...\e[0m"
retry_pacman 3 pacman -Syyu --noconfirm --needed --overwrite="*"

echo -e "\e[1mCopying manual to desktop...\e[0m"
if [ -d "/home/coolrune-files/files/coolrune-manual/" ]; then
    cp -r /home/coolrune-files/files/coolrune-manual/Manual /home/$USER/Desktop/ 2>/dev/null || echo "Failed to copy manual, continuing..."
fi

echo -e "\e[1mTesting audio...\e[0m"
timeout 0.5 speaker-test -t sine > /dev/null 2>&1 || true

### REPO PACKAGES REMOVE ###

echo -e "\e[1mRemoving unwanted packages...\e[0m"
pacman -Rdd --noconfirm linux linux-headers pulseaudio pulseaudio-alsa pulseaudio-bluetooth pulseaudio-zeroconf epiphany xfce4-screensaver xfce4-terminal xfce4-screenshooter parole xfce4-taskmanager mousepad leafpad xfburn ristretto xfce4-appfinder atril artix-branding-base artix-grub-theme xfce4-sensors-plugin xfce4-notes-plugin mpv xfce4-power-manager xfce4-battery-plugin xfce4-dict xfce4-weather-plugin 2>/dev/null || echo "Some packages were not installed or could not be removed, continuing..."

### BASE REPO PACKAGES INSTALL ###

echo -e "\e[1mInstalling base packages...\e[0m"
retry_pacman 3 pacman -S --noconfirm --needed --overwrite="*" --ignore=vlc,vlc-git,nvidia-390xx-utils,lib32-nvidia-390xx-utils lib32-artix-archlinux-support base-devel unzip xorg-xrandr unrar flatpak kate librewolf python-pip tmux liferea ksnip kcalc font-manager pix gimp gamemode lib32-gamemode fail2ban fail2ban-s6 okular dnscrypt-proxy dnscrypt-proxy-s6 apparmor apparmor-s6 bleachbit konsole catfish clamav clamav-s6 ark gufw mugshot macchanger networkmanager networkmanager-s6 nm-connection-editor wine-ge-custom wine-mono winetricks ufw-s6 redshift steam lynis element-desktop rkhunter lib32-mesa lib32-mesa-utils appimagelauncher opendoas mate-system-monitor lightdm-gtk-greeter-settings downgrade libreoffice pipewire-pulse pipewire-alsa wireplumber wine-gecko rust python-psutil python-dateutil python-xlib python-pyaudio python-pipenv usbguard usbguard-s6 hunspell-en_us chkrootkit python-matplotlib python-tqdm python-pillow python-mutagen wget noto-fonts-emoji xfce4-panel-profiles poetry tauon-music-box yt-dlp pyenv freetube python-magic python-piexif alsa-utils expect inotify-tools preload python-moviepy python-brotli python-websockets cpupower cpupower-s6 python-librosa python-audioread ccache earlyoom earlyoom-s6 python-pypdf2 dialog zramen zramen-s6 zfs-utils tree sof-firmware booster bottles paru

echo -e "\e[1mBase packages installation completed\e[0m"

### HARDWARE-SPECIFIC PACKAGES ###

case "$choice" in
    1) # AMD-DESKTOP
        echo -e "\e[1mInstalling AMD Desktop packages...\e[0m"
        retry_pacman 3 pacman -S --noconfirm --needed --overwrite="*" linux-cachyos linux-cachyos-headers linux-cachyos-zfs vulkan-icd-loader lib32-vulkan-icd-loader lib32-vulkan-radeon protonup-git
        ;;
    2) # AMD-LAPTOP
        echo -e "\e[1mInstalling AMD Laptop packages...\e[0m"
        retry_pacman 3 pacman -S --noconfirm --needed --overwrite="*" linux-cachyos-eevdf linux-cachyos-eevdf-headers linux-cachyos-eevdf-zfs vulkan-icd-loader lib32-vulkan-icd-loader lib32-vulkan-radeon throttled tlp tlp-s6 blueman bluez bluez-s6
        ;;
    3) # INTEL-DESKTOP
        echo -e "\e[1mInstalling Intel Desktop packages...\e[0m"
        retry_pacman 3 pacman -S --noconfirm --needed --overwrite="*" linux-cachyos linux-cachyos-headers linux-cachyos-zfs vulkan-icd-loader lib32-vulkan-icd-loader protonup-git
        ;;
    4) # INTEL-LAPTOP
        echo -e "\e[1mInstalling Intel Laptop packages...\e[0m"
        retry_pacman 3 pacman -S --noconfirm --needed --overwrite="*" linux-cachyos-eevdf linux-cachyos-eevdf-headers linux-cachyos-eevdf-zfs vulkan-icd-loader lib32-vulkan-icd-loader throttled tlp tlp-s6 blueman bluez bluez-s6
        ;;
    5) # NVIDIA-OPENSOURCE-DESKTOP
        echo -e "\e[1mInstalling NVIDIA Open Source Desktop packages...\e[0m"
        retry_pacman 3 pacman -S --noconfirm --needed --overwrite="*" linux-cachyos linux-cachyos-headers linux-cachyos-zfs protonup-git linux-cachyos-nvidia-open nvidia-utils nvidia-utils-s6 lib32-nvidia-utils nvidia-settings
        ;;
    6) # NVIDIA-PROPRIETARY-DESKTOP
        echo -e "\e[1mInstalling NVIDIA Proprietary Desktop packages...\e[0m"
        retry_pacman 3 pacman -S --noconfirm --needed --overwrite="*" linux-cachyos linux-cachyos-headers linux-cachyos-zfs protonup-git linux-cachyos-nvidia nvidia-utils nvidia-utils-s6 lib32-nvidia-utils nvidia-settings
        ;;
esac

echo -e "\e[1mHardware-specific packages installation completed\e[0m"

### FLATPAK PACKAGES ###

echo -e "\e[1mSetting up Flatpak...\e[0m"
flatpak remote-add --if-not-exists flathub-beta https://flathub.org/beta-repo/flathub-beta.flatpakrepo || echo "Failed to add flathub-beta, continuing..."
flatpak install -y org.gnome.seahorse.Application/x86_64/stable org.kde.haruna org.jdownloader.JDownloader || echo "Some Flatpak packages failed to install, continuing..."

### INSTALL PROTON-GE ###

echo -e "\e[1mInstalling Proton-GE...\e[0m"
if pacman -Q protonup-git &>/dev/null; then
    su - "$USER" -c "protonup -d /home/$USER/.local/share/Steam/compatibilitytools.d/ && protonup -y" || echo "Failed to install Proton-GE, continuing..."
fi

### COOLRUNE INSTALL ###

echo -e "\e[1mInstalling CoolRune configuration files...\e[0m"

case "$choice" in
    1|3) # AMD/INTEL DESKTOP
        echo -e "\e[1mConfiguring for desktop...\e[0m"
        7z x coolrune-dotfiles.7z -o/home/$USER/ -y || echo "Failed to extract dotfiles, continuing..."
        unzip -o coolrune-root.zip -d / || echo "Failed to extract root files, continuing..."
        ;;
    2|4) # LAPTOP
        echo -e "\e[1mConfiguring for laptop...\e[0m"
        7z x coolrune-dotfiles-laptop.7z -o/home/$USER/ -y || echo "Failed to extract laptop dotfiles, continuing..."
        unzip -o coolrune-root-laptop.zip -d / || echo "Failed to extract laptop root files, continuing..."
        ;;
    5|6) # NVIDIA
        echo -e "\e[1mConfiguring for NVIDIA...\e[0m"
        7z x coolrune-dotfiles.7z -o/home/$USER/ -y || echo "Failed to extract NVIDIA dotfiles, continuing..."
        unzip -o coolrune-root.zip -d / || echo "Failed to extract NVIDIA root files, continuing..."
        7z x coolrune-nvidia-patch.7z -o/ -y || echo "Failed to extract NVIDIA patch, continuing..."
        ;;
esac

### CONFIGURE SERVICES ###

echo -e "\e[1mConfiguring services...\e[0m"
s6-service add default apparmor || echo "Failed to add apparmor service, continuing..."
s6-service add default fail2ban || echo "Failed to add fail2ban service, continuing..."
s6-service add default NetworkManager || echo "Failed to add NetworkManager service, continuing..."
s6-service add default dnscrypt-proxy || echo "Failed to add dnscrypt-proxy service, continuing..."
s6-service add default ufw || echo "Failed to add ufw service, continuing..."
s6-service add default cpupower || echo "Failed to add cpupower service, continuing..."
s6-service add default earlyoom || echo "Failed to add earlyoom service, continuing..."
s6-service add default zramen || echo "Failed to add zramen service, continuing..."

# Add TLP for laptops
if [ "$choice" = "2" ] || [ "$choice" = "4" ]; then
    s6-service add default tlp || echo "Failed to add tlp service, continuing..."
fi

# Remove connman
rm -f /etc/s6/adminsv/default/contents.d/connmand || echo "connmand not found, continuing..."
pacman -Rdd --noconfirm vlc-luajit connman connman-s6 connman-gtk 2>/dev/null || echo "Some connman packages were not installed, continuing..."
s6-db-reload || echo "Failed to reload s6 database, continuing..."

### CREATE GAMEMODE GROUP (DESKTOP ONLY) ###

if [ "$choice" = "1" ] || [ "$choice" = "3" ] || [ "$choice" = "5" ] || [ "$choice" = "6" ]; then
    echo -e "\e[1mConfiguring gamemode group...\e[0m"
    groupadd -f gamemode
    TARGET_USER=$USER
    if [ "$TARGET_USER" = "root" ]; then
        TARGET_USER=$(find /home -mindepth 1 -maxdepth 1 -type d -printf "%f\n" | head -1)
    fi
    if [ -n "$TARGET_USER" ]; then
        usermod -aG gamemode "$TARGET_USER" || echo "Failed to add user to gamemode group, continuing..."
        echo "Added user $TARGET_USER to gamemode group"
    fi
fi

### RESET PERMISSIONS ###

echo -e "\e[1mResetting permissions...\e[0m"
chmod -R 755 /home/$USER 2>/dev/null || echo "Failed to set some home directory permissions, continuing..."
chmod -R 755 /etc 2>/dev/null || echo "Failed to set some etc permissions, continuing..."
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

### HARDENING SCRIPT ###

echo -e "\e[1mRunning hardening script...\e[0m"
if [ -d "/CoolRune/Programs/Hardening-Script/" ]; then
    cd /CoolRune/Programs/Hardening-Script/
    sh hardening-script.sh || echo "Hardening script failed, continuing..."
    cd /
fi
umask 027

### LAST COMMANDS ###

echo -e "\e[1mFinalizing installation...\e[0m"
mv /etc/profile /etc/profile.old 2>/dev/null || true
grub-install 2>/dev/null || echo "GRUB install failed or not needed, continuing..."
update-grub || grub-mkconfig -o /boot/grub/grub.cfg || echo "Failed to update GRUB config, continuing..."

# Cleanup
rm -rf /home/coolrune-files/

echo -e "\e[1;32mCoolRune has been successfully installed!\e[0m"
echo -e "\e[1;33mSystem will reboot in 10 seconds. Press Ctrl+C to cancel.\e[0m"

# Give user a chance to cancel the reboot
sleep 10

echo -e "\e[1mRebooting system...\e[0m"
reboot
'
