#!/bin/bash

su -c '
### RETRY LOGIC ###

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
killall xfce4-screensaver
pacman -Sy --noconfirm --needed p7zip git
mkdir /home/coolrune-files/
git clone https://github.com/Michael-Sebero/CoolRune /home/coolrune-files/
cd /home/coolrune-files/files/coolrune-packages/
7z e coolrune-pacman-1.7z -o/etc/ -y
pacman -Sy --noconfirm artix-archlinux-support pacman-contrib artix-keyring
pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'
7z e coolrune-pacman-2.7z -o/etc/ -y
chmod 755 /etc/pacman.conf
pacman-key --populate archlinux artix
pacman -Sy --noconfirm alhp-keyring
rm -rf /usr/lib/firmware/nvidia/ad10{3,4,5,6,7} || true

# FIND QUICKEST MIRRORLIST
echo -e "\e[1mFinding quickest mirrorlist, please wait...\e[0m"
sh -c "rankmirrors -v -n 5 -m 2 /etc/pacman.d/mirrorlist > /etc/pacman.d/mirrorlist.new && mv /etc/pacman.d/mirrorlist.new /etc/pacman.d/mirrorlist && chmod 644 /etc/pacman.d/mirrorlist"

# FIRST COMMANDS AND COOLRUNE IMPORT P2
retry_pacman 5 pacman -Syyu --noconfirm --needed --overwrite='*'
mv /home/coolrune-files/files/coolrune-manual/Manual /home/$USER/Desktop/

# REPO PACKAGES REMOVE P1
pacman -Rdd --noconfirm linux linux-headers pulseaudio pulseaudio-alsa pulseaudio-bluetooth pulseaudio-zeroconf epiphany xfce4-screensaver xfce4-terminal xfce4-screenshooter parole xfce4-taskmanager mousepad leafpad xfburn ristretto xfce4-appfinder atril artix-branding-base artix-grub-theme xfce4-sensors-plugin xfce4-notes-plugin mpv xfce4-dict xfce4-weather-plugin

# BASE REPO PACKAGES INSTALL
retry_pacman 5 pacman -S --noconfirm --needed --overwrite='*' --ignore=vlc,vlc-git,nvidia-390xx-utils,lib32-nvidia-390xx-utils lib32-artix-archlinux-support base-devel unzip xorg-xrandr unrar flatpak kate librewolf python-pip tmux liferea ksnip kcalc font-manager pix gimp gamemode lib32-gamemode okular dnscrypt-proxy dnscrypt-proxy-s6 apparmor apparmor-s6 bleachbit konsole catfish clamav clamav-s6 ark gufw mugshot macchanger networkmanager networkmanager-s6 nm-connection-editor wine-ge-custom wine-mono winetricks ufw-s6 redshift steam lynis element-desktop rkhunter appimagelauncher opendoas mate-system-monitor lightdm-gtk-greeter-settings downgrade libreoffice pipewire-pulse pipewire-alsa wireplumber wine-gecko rust python-psutil python-dateutil python-xlib python-pyaudio python-pipenv usbguard usbguard-s6 hunspell-en_us chkrootkit python-matplotlib python-tqdm python-pillow python-mutagen wget noto-fonts-emoji xfce4-panel-profiles poetry tauon-music-box yt-dlp pyenv freetube python-magic python-piexif alsa-utils expect inotify-tools preload python-moviepy python-brotli python-websockets cpupower cpupower-s6 python-librosa python-audioread ccache earlyoom earlyoom-s6 python-pypdf2 dialog zramen zramen-s6 zfs-utils tree sof-firmware booster bottles paru

# REPO PACKAGES REMOVE P2
pacman -Rdd --noconfirm mesa vulkan-intel vulkan-radeon vulkan-swrast lib32-mesa-git || true

# AMD/INTEL-DESKTOP CHOICE
if [ "$choice" = "1" ] || [ "$choice" = "3" ]; then
  pacman -Rdd --noconfirm xfce4-power-manager xfce4-battery-plugin && retry_pacman 5 pacman -S --noconfirm --needed --overwrite='*' linux-cachyos linux-cachyos-headers linux-cachyos-zfs protonup-git vkbasalt lib32-vkbasalt mesa-tkg-git lib32-mesa-tkg-git fail2ban fail2ban-s6
fi

# AMD/INTEL-LAPTOP CHOICE
if [ "$choice" = "2" ] || [ "$choice" = "4" ]; then
  retry_pacman 5 pacman -S --noconfirm --needed --overwrite='*' linux-cachyos-eevdf linux-cachyos-eevdf-headers linux-cachyos-eevdf-zfs throttled tlp tlp-s6 blueman bluez bluez-s6 mesa-tkg-git lib32-mesa-tkg-git
fi

# NVIDIA-OPENSOURCE-DESKTOP CHOICE
if [ "$choice" = "5" ]; then
  pacman -Rdd --noconfirm xfce4-power-manager xfce4-battery-plugin && retry_pacman 5 pacman -S --noconfirm --needed --overwrite='*' linux-cachyos linux-cachyos-headers linux-cachyos-zfs protonup-git linux-cachyos-nvidia-open nvidia-utils nvidia-utils-s6 lib32-nvidia-utils nvidia-settings mesa-tkg-git lib32-mesa-tkg-git fail2ban fail2ban-s6
fi

# NVIDIA-PROPRIETARY-DESKTOP CHOICE
if [ "$choice" = "6" ]; then
  pacman -Rdd --noconfirm xfce4-power-manager xfce4-battery-plugin && retry_pacman 5 pacman -S --noconfirm --needed --overwrite='*' linux-cachyos linux-cachyos-headers linux-cachyos-zfs protonup-git linux-cachyos-nvidia nvidia-utils nvidia-utils-s6 lib32-nvidia-utils nvidia-settings fail2ban fail2ban-s6
fi

# FLATPAK PACKAGES
flatpak remote-add flathub-beta https://flathub.org/beta-repo/flathub-beta.flatpakrepo
flatpak install -y org.gnome.seahorse.Application/x86_64/stable org.kde.haruna org.jdownloader.JDownloader

# INSTALL PROTON-GE
if pacman -Q protonup-git &>/dev/null; then
    su - "$USER" -c "protonup -d /home/$USER/.local/share/Steam/compatibilitytools.d/ && protonup -y"
fi

### COOLRUNE INSTALL ###

# AMD/INTEL DESKTOP SELECTION
if [ "$choice" = "1" ] || [ "$choice" = "3" ]; then
  7z x coolrune-dotfiles.7z -o/home/$USER/ -y
  unzip -o coolrune-main.zip -d /
  unzip -o coolrune-root.zip -d /
  s6-service add default apparmor
  s6-service add default fail2ban
  s6-service add default NetworkManager
  s6-service add default dnscrypt-proxy
  s6-service add default ufw
  s6-service add default cpupower
  s6-service add default earlyoom
  s6-service add default zramen
  rm /etc/s6/adminsv/default/contents.d/connmand
  pacman -Rdd --noconfirm connman connman-s6 connman-gtk
  s6-db-reload
  grub-mkconfig -o /boot/grub/grub.cfg
fi

# LAPTOP SELECTION
if [ "$choice" = "2" ] || [ "$choice" = "4" ]; then
  7z x coolrune-dotfiles-laptop.7z -o/home/$USER/ -y
  unzip -o coolrune-main.zip -d /
  unzip -o coolrune-root-laptop.zip -d /
  s6-service add default cpupower
  s6-service add default apparmor
  s6-service add default NetworkManager
  s6-service add default dnscrypt-proxy
  s6-service add default ufw
  s6-service add default earlyoom
  s6-service add default zramen
  s6-service add default tlp
  rm /etc/s6/adminsv/default/contents.d/connmand
  pacman -Rdd --noconfirm connman connman-s6 connman-gtk
  s6-db-reload
  grub-mkconfig -o /boot/grub/grub.cfg
fi

# NVIDIA SELECTION
if [ "$choice" = "5" ] || [ "$choice" = "6" ]; then
  7z x coolrune-dotfiles.7z -o/home/$USER/ -y
  unzip -o coolrune-main.zip -d /
  unzip -o coolrune-root.zip -d /
  7z x coolrune-nvidia-patch.7z -o/ -y
  s6-service add default apparmor
  s6-service add default fail2ban
  s6-service add default NetworkManager
  s6-service add default dnscrypt-proxy
  s6-service add default ufw
  s6-service add default cpupower
  s6-service add default earlyoom
  s6-service add default zramen
  rm /etc/s6/adminsv/default/contents.d/connmand
  pacman -Rdd --noconfirm connman connman-s6 connman-gtk
  s6-db-reload
  grub-mkconfig -o /boot/grub/grub.cfg
fi

# CREATE GAMEMODE GROUP
if [ "$choice" = "1" ] || [ "$choice" = "3" ] || [ "$choice" = "5" ] || [ "$choice" = "6" ]; then
  groupadd -f gamemode
  TARGET_USER=$USER
  if [ "$TARGET_USER" = "root" ]; then
    TARGET_USER=$(find /home -mindepth 1 -maxdepth 1 -type d -printf "%f\n" | head -1)
  fi
  usermod -aG gamemode "$TARGET_USER"
  echo "Added user $TARGET_USER to gamemode group"
  if id "$TARGET_USER" | grep -o "gamemode" &>/dev/null; then
    echo "Successfully added to gamemode group"
  else
    echo "Failed to add to gamemode group"
  fi
fi

# RESET PERMISSIONS
chmod -R 755 /home/$USER
chmod -R 755 /etc
chmod -R 755 /usr/share/backgrounds
chmod -R 755 /usr/share/icons
chmod -R 755 /usr/share/pictures
chmod -R 755 /usr/share/themes
chmod 644 /etc/udev/udev.conf
chmod -R 777 /home/$USER/.var/
chmod -R 777 /home/$USER/.config
chmod 700 /etc/cron.d /etc/cron.daily /etc/cron.hourly /etc/cron.weekly /etc/cron.monthly
chmod 600 /etc/cron.deny
chmod 644 /etc/issue
chmod 600 /etc/shadow
chmod -R 777 /home/$USER/.local/
chmod 755 /home/$USER/.nvidia-settings-rc

# HARDENING SCRIPT
sh /CoolRune/Programs/Hardening-Script/hardening-script.sh && umask 027
cd /

# LAST COMMANDS
mv /etc/profile{,.old}
grub-install || true
update-grub
rm -rf /home/coolrune-files/
echo -e "\e[1mCoolRune has been successfully installed\e[0m"
reboot
'
