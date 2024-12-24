#!/bin/sh

su -c '
# RETRY LOGIC
retry_pacman() {
  local -r -i max_attempts="$1"
  local -r command="${@:2}"
  local -i attempt_num=1

  until $command
  do
    if (( attempt_num == max_attempts ))
    then
      echo "Attempt $attempt_num failed! No more retries left." >&2
      return 1
    else
      echo "Attempt $attempt_num failed! Retrying in 5 seconds..." >&2
      sleep 5
      attempt_num=$(( attempt_num + 1 ))
    fi
  done
}

### IMPORT KEYS ###

# ALHP
echo -e "\e[1mImporting ALHP keys...\e[0m"
pacman-key --recv-keys E3D0D2CD3952E298 --keyserver keyserver.ubuntu.com; pacman-key --lsign-key E3D0D2CD3952E298

# CACHYOS
echo -e "\e[1mImporting CachyOS keys...\e[0m"
pacman-key --recv-keys F3B607488DB35A47 --keyserver keyserver.ubuntu.com; pacman-key --lsign-key F3B607488DB35A47

# CHAOTIC AUR
echo -e "\e[1mImporting Chaotic AUR keys...\e[0m"
pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com; pacman-key --lsign-key 3056513887B78AEB



# COOLRUNE CHOICE SELECTION
echo "Select a CoolRune Variant"
echo "1. CoolRune-AMD"
echo "2. CoolRune-INTEL"
echo "3. CoolRune-NVIDIA-OPENSOURCE"
echo "4. CoolRune-NVIDIA-PROPRIETARY"

read -p "Enter your choice (1, 2, 3 or 4): " choice

### AMD CHOICE ###
if [ "$choice" = "1" ]; then

# FIRST COMMANDS AND COOLRUNE IMPORT
killall xfce4-screensaver && pacman -Sy --noconfirm --needed p7zip git && mkdir /home/coolrune-files/ && git clone https://github.com/Michael-Sebero/CoolRune /home/coolrune-files/ && cd /home/coolrune-files/files/coolrune-packages/ && 7z e coolrune-pacman-1.7z -o/etc/ -y && pacman -Sy --noconfirm artix-archlinux-support && pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst' && 7z e coolrune-pacman-2.7z -o/etc/ -y && chmod 755 /etc/pacman.conf && pacman-key --populate archlinux artix && retry_pacman 5 pacman -Syyu --noconfirm --needed && mv /home/coolrune-files/files/coolrune-manual/Manual /home/$USER/Desktop/ &&

# REPO PACKAGES REMOVE
pacman -Rdd --noconfirm linux linux-headers pulseaudio pulseaudio-alsa pulseaudio-bluetooth pulseaudio-zeroconf epiphany xfce4-screensaver xfce4-terminal xfce4-screenshooter parole xfce4-taskmanager mousepad leafpad xfburn ristretto xfce4-appfinder atril artix-branding-base artix-grub-theme xfce4-sensors-plugin xfce4-notes-plugin mpv vulkan-intel && 

# REPO PACKAGES INSTALL
retry_pacman 5 pacman -S --noconfirm --needed --ignore=vlc,vlc-git lib32-artix-archlinux-support base-devel flatpak kate librewolf python-pip tmux vulkan-icd-loader lib32-vulkan-icd-loader liferea ksnip kcalc font-manager gwenview gimp gamemode lib32-gamemode fail2ban fail2ban-s6 okular dnscrypt-proxy dnscrypt-proxy-s6 apparmor apparmor-s6 bleachbit blueman bluez-s6 konsole catfish clamav clamav-s6 ark gufw mugshot macchanger networkmanager networkmanager-s6 nm-connection-editor wine-ge-custom wine-mono winetricks ufw-s6 redshift steam lynis element-desktop rkhunter paru proton-ge-custom lib32-mesa lib32-mesa-utils bottles appimagelauncher opendoas linux-cachyos linux-cachyos-headers mate-system-monitor lightdm-gtk-greeter-settings downgrade libreoffice pipewire-pulse pipewire-alsa wireplumber wine-gecko rust python-psutil python-dateutil python-xlib python-pyaudio python-pipenv usbguard usbguard-s6 hunspell-en_us vkbasalt lib32-vkbasalt chkrootkit python-matplotlib python-tqdm python-pillow python-mutagen wget noto-fonts-emoji xfce4-panel-profiles poetry tauon-music-box yt-dlp pyenv lxsession freetube python-magic python-piexif alsa-utils lib32-vulkan-radeon expect inotify-tools preload python-sounddevice python-moviepy python-brotli python-websockets cpupower cpupower-s6 python-librosa python-audioread &&

# FLATPAK PACKAGES
flatpak remote-add flathub-beta https://flathub.org/beta-repo/flathub-beta.flatpakrepo && flatpak install -y org.gnome.seahorse.Application/x86_64/stable org.kde.haruna org.jdownloader.JDownloader &&

# COOLRUNE INSTALL
7z x coolrune-dotfiles.7z -o/home/$USER/ -y && 7z x coolrune-root.7z -o/ -y && s6-service add default apparmor && s6-service add default fail2ban && s6-service add default NetworkManager && s6-service add default dnscrypt-proxy && s6-service add default ufw && s6-service add default cpupower && rm /etc/s6/adminsv/default/contents.d/connmand && pacman -Rdd --noconfirm vlc-luajit connman connman-s6 connman-gtk && s6-db-reload && grub-mkconfig -o/boot/grub/grub.cfg &&

# CREATE GAMEMODE GROUP
groupadd gamemode && usermod -aG gamemode $(whoami) &&

# HARDENING SCRIPT
cd /-CoolRune-/Programs/Hardening-Script/ && sh hardening-script.sh && cd / &&

# LAST COMMANDS
chmod 777 -R /home/$USER && mv /etc/profile{,.old} && grub-install && update-grub && rm -rf /home/coolrune-files/ && echo -e "\e[1mCoolRune has been successfully installed\e[0m" && reboot



### INTEL CHOICE ###
elif [ "$choice" = "2" ]; then

# FIRST COMMANDS AND COOLRUNE IMPORT
killall xfce4-screensaver && pacman -Sy --noconfirm --needed p7zip git && mkdir /home/coolrune-files/ && git clone https://github.com/Michael-Sebero/CoolRune /home/coolrune-files/ && cd /home/coolrune-files/files/coolrune-packages/ && 7z e coolrune-pacman-1.7z -o/etc/ -y && pacman -Sy --noconfirm artix-archlinux-support && pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst' && 7z e coolrune-pacman-2.7z -o/etc/ -y && chmod 755 /etc/pacman.conf && pacman-key --populate archlinux artix && retry_pacman 5 pacman -Syyu --noconfirm --needed && mv /home/coolrune-files/files/coolrune-manual/Manual /home/$USER/Desktop/ &&

# REPO PACKAGES REMOVE
pacman -Rdd --noconfirm linux linux-headers pulseaudio pulseaudio-alsa pulseaudio-bluetooth pulseaudio-zeroconf epiphany xfce4-screensaver xfce4-terminal xfce4-screenshooter parole xfce4-taskmanager mousepad leafpad xfburn ristretto xfce4-appfinder atril artix-branding-base artix-grub-theme xfce4-sensors-plugin xfce4-notes-plugin mpv vulkan-radeon && 

# REPO PACKAGES INSTALL
retry_pacman 5 pacman -S --noconfirm --needed --ignore=vlc,vlc-git lib32-artix-archlinux-support base-devel flatpak kate librewolf python-pip tmux vulkan-icd-loader lib32-vulkan-icd-loader liferea ksnip kcalc font-manager gwenview gimp gamemode lib32-gamemode fail2ban fail2ban-s6 okular dnscrypt-proxy dnscrypt-proxy-s6 apparmor apparmor-s6 bleachbit blueman bluez-s6 konsole catfish clamav clamav-s6 ark gufw mugshot macchanger networkmanager networkmanager-s6 nm-connection-editor wine-ge-custom wine-mono winetricks ufw-s6 redshift steam lynis element-desktop rkhunter paru proton-ge-custom lib32-mesa lib32-mesa-utils bottles appimagelauncher opendoas linux-cachyos linux-cachyos-headers mate-system-monitor lightdm-gtk-greeter-settings downgrade libreoffice pipewire-pulse pipewire-alsa wireplumber wine-gecko rust python-psutil python-dateutil python-xlib python-pyaudio python-pipenv usbguard usbguard-s6 hunspell-en_us vkbasalt lib32-vkbasalt chkrootkit python-matplotlib python-tqdm python-pillow python-mutagen wget noto-fonts-emoji xfce4-panel-profiles poetry tauon-music-box yt-dlp pyenv lxsession freetube python-magic python-piexif alsa-utils intel-media-driver lib32-vulkan-intel expect inotify-tools preload python-sounddevice python-moviepy python-brotli python-websockets cpupower cpupower-s6 python-librosa python-audioread &&

# FLATPAK PACKAGES
flatpak remote-add flathub-beta https://flathub.org/beta-repo/flathub-beta.flatpakrepo && flatpak install -y org.gnome.seahorse.Application/x86_64/stable org.kde.haruna org.jdownloader.JDownloader &&

# COOLRUNE INSTALL
7z x coolrune-dotfiles.7z -o/home/$USER/ -y && 7z x coolrune-root.7z -o/ -y && s6-service add default apparmor && s6-service add default fail2ban && s6-service add default NetworkManager && s6-service add default dnscrypt-proxy && s6-service add default ufw && s6-service add default cpupower && rm /etc/s6/adminsv/default/contents.d/connmand && pacman -Rdd --noconfirm vlc-luajit connman connman-s6 connman-gtk && s6-db-reload && grub-mkconfig -o/boot/grub/grub.cfg &&

# CREATE GAMEMODE GROUP
groupadd gamemode && usermod -aG gamemode $(whoami) &&

# HARDENING SCRIPT
cd /-CoolRune-/Programs/Hardening-Script/ && sh hardening-script.sh && cd / &&

# LAST COMMANDS
chmod 777 -R /home/$USER && mv /etc/profile{,.old} && grub-install && update-grub && rm -rf /home/coolrune-files/ && echo -e "\e[1mCoolRune has been successfully installed\e[0m" && reboot



### NVIDIA OPENSOURCE CHOICE ###
elif [ "$choice" = "3" ]; then

# FIRST COMMANDS AND COOLRUNE IMPORT
killall xfce4-screensaver && pacman -Sy --noconfirm --needed p7zip git && mkdir /home/coolrune-files/ && git clone https://github.com/Michael-Sebero/CoolRune /home/coolrune-files/ && cd /home/coolrune-files/files/coolrune-packages/ && 7z e coolrune-pacman-1.7z -o/etc/ -y && pacman -Sy --noconfirm artix-archlinux-support && pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst' && 7z e coolrune-pacman-2.7z -o/etc/ -y && chmod 755 /etc/pacman.conf && pacman-key --populate archlinux artix && retry_pacman 5 pacman -Syyu --noconfirm --needed && mv /home/coolrune-files/files/coolrune-manual/Manual /home/$USER/Desktop/ &&

# REPO PACKAGES REMOVE
pacman -Rdd --noconfirm linux linux-headers pulseaudio pulseaudio-alsa pulseaudio-bluetooth pulseaudio-zeroconf epiphany xfce4-screensaver xfce4-terminal xfce4-screenshooter parole xfce4-taskmanager mousepad leafpad xfburn ristretto xfce4-appfinder atril artix-branding-base artix-grub-theme xfce4-sensors-plugin xfce4-notes-plugin mpv && 

# REPO PACKAGES INSTALL
retry_pacman 5 pacman -S --noconfirm --needed --ignore=nvidia-390xx-utils,lib32-nvidia-390xx-utils,vlc,vlc-git lib32-artix-archlinux-support base-devel flatpak kate librewolf python-pip tmux vulkan-icd-loader lib32-vulkan-icd-loader liferea ksnip kcalc font-manager gwenview gimp gamemode lib32-gamemode fail2ban fail2ban-s6 okular dnscrypt-proxy dnscrypt-proxy-s6 apparmor apparmor-s6 bleachbit blueman bluez-s6 konsole catfish clamav clamav-s6 ark gufw mugshot macchanger networkmanager networkmanager-s6 nm-connection-editor wine-ge-custom wine-mono winetricks ufw-s6 redshift steam lynis element-desktop rkhunter paru proton-ge-custom linux-cachyos-nvidia-open nvidia-utils nvidia-utils-s6 lib32-nvidia-utils nvidia-settings bottles appimagelauncher opendoas linux-cachyos linux-cachyos-headers mate-system-monitor lightdm-gtk-greeter-settings downgrade libreoffice pipewire-pulse pipewire-alsa wireplumber wine-gecko rust python-psutil python-dateutil python-xlib python-pyaudio python-pipenv usbguard usbguard-s6 hunspell-en_us vkbasalt lib32-vkbasalt chkrootkit python-matplotlib python-tqdm python-pillow python-mutagen wget noto-fonts-emoji xfce4-panel-profiles poetry tauon-music-box yt-dlp pyenv lxsession freetube python-magic python-piexif alsa-utils expect inotify-tools preload python-sounddevice python-moviepy python-brotli python-websockets cpupower cpupower-s6 python-librosa python-audioread &&

# FLATPAK PACKAGES
flatpak remote-add flathub-beta https://flathub.org/beta-repo/flathub-beta.flatpakrepo && flatpak install -y org.gnome.seahorse.Application/x86_64/stable org.kde.haruna org.jdownloader.JDownloader &&

# COOLRUNE INSTALL
7z x coolrune-dotfiles.7z -o/home/$USER/ -y && 7z x coolrune-root.7z -o/ -y && 7z x coolrune-nvidia-patch.7z -o/ -y && s6-service add default apparmor && s6-service add default fail2ban && s6-service add default NetworkManager && s6-service add default dnscrypt-proxy && s6-service add default ufw && s6-service add default cpupower && rm /etc/s6/adminsv/default/contents.d/connmand && pacman -Rdd --noconfirm vlc-luajit connman connman-s6 connman-gtk && s6-db-reload && grub-mkconfig -o/boot/grub/grub.cfg &&

# CREATE GAMEMODE GROUP
groupadd gamemode && usermod -aG gamemode $(whoami) &&

# HARDENING SCRIPT
cd /-CoolRune-/Programs/Hardening-Script/ && sh hardening-script.sh && cd / &&

# LAST COMMANDS
chmod 777 -R /home/$USER && mv /etc/profile{,.old} && grub-install && update-grub && rm -rf /home/coolrune-files/ && echo -e "\e[1mCoolRune has been successfully installed\e[0m" && reboot



### NVIDIA PROPRIETARY CHOICE ###
elif [ "$choice" = "4" ]; then

# FIRST COMMANDS AND COOLRUNE IMPORT
killall xfce4-screensaver && pacman -Sy --noconfirm --needed p7zip git && mkdir /home/coolrune-files/ && git clone https://github.com/Michael-Sebero/CoolRune /home/coolrune-files/ && cd /home/coolrune-files/files/coolrune-packages/ && 7z e coolrune-pacman-1.7z -o/etc/ -y && pacman -Sy --noconfirm artix-archlinux-support && pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst' && 7z e coolrune-pacman-2.7z -o/etc/ -y && chmod 755 /etc/pacman.conf && pacman-key --populate archlinux artix && retry_pacman 5 pacman -Syyu --noconfirm --needed && mv /home/coolrune-files/files/coolrune-manual/Manual /home/$USER/Desktop/ &&

# REPO PACKAGES REMOVE
pacman -Rdd --noconfirm linux linux-headers pulseaudio pulseaudio-alsa pulseaudio-bluetooth pulseaudio-zeroconf epiphany xfce4-screensaver xfce4-terminal xfce4-screenshooter parole xfce4-taskmanager mousepad leafpad xfburn ristretto xfce4-appfinder atril artix-branding-base artix-grub-theme xfce4-sensors-plugin xfce4-notes-plugin mpv && 

# REPO PACKAGES INSTALL
retry_pacman 5 pacman -S --noconfirm --needed --ignore=nvidia-390xx-utils,lib32-nvidia-390xx-utils,vlc,vlc-git lib32-artix-archlinux-support base-devel flatpak kate librewolf python-pip tmux vulkan-icd-loader lib32-vulkan-icd-loader liferea ksnip kcalc font-manager gwenview gimp gamemode lib32-gamemode fail2ban fail2ban-s6 okular dnscrypt-proxy dnscrypt-proxy-s6 apparmor apparmor-s6 bleachbit blueman bluez-s6 konsole catfish clamav clamav-s6 ark gufw mugshot macchanger networkmanager networkmanager-s6 nm-connection-editor wine-ge-custom wine-mono winetricks ufw-s6 redshift steam lynis element-desktop rkhunter paru proton-ge-custom linux-cachyos-nvidia nvidia-utils nvidia-utils-s6 lib32-nvidia-utils nvidia-settings bottles appimagelauncher opendoas linux-cachyos linux-cachyos-headers mate-system-monitor lightdm-gtk-greeter-settings downgrade libreoffice pipewire-pulse pipewire-alsa wireplumber wine-gecko rust python-psutil python-dateutil python-xlib python-pyaudio python-pipenv usbguard usbguard-s6 hunspell-en_us vkbasalt lib32-vkbasalt chkrootkit python-matplotlib python-tqdm python-pillow python-mutagen wget noto-fonts-emoji xfce4-panel-profiles poetry tauon-music-box yt-dlp pyenv lxsession freetube python-magic python-piexif alsa-utils expect inotify-tools preload python-sounddevice python-moviepy python-brotli python-websockets cpupower cpupower-s6 python-librosa python-audioread &&

# FLATPAK PACKAGES
flatpak remote-add flathub-beta https://flathub.org/beta-repo/flathub-beta.flatpakrepo && flatpak install -y org.gnome.seahorse.Application/x86_64/stable org.kde.haruna org.jdownloader.JDownloader &&

# COOLRUNE INSTALL
7z x coolrune-dotfiles.7z -o/home/$USER/ -y && 7z x coolrune-root.7z -o/ -y && 7z x coolrune-nvidia-patch.7z -o/ -y && s6-service add default apparmor && s6-service add default fail2ban && s6-service add default NetworkManager && s6-service add default dnscrypt-proxy && s6-service add default ufw && s6-service add default cpupower && rm /etc/s6/adminsv/default/contents.d/connmand && pacman -Rdd --noconfirm vlc-luajit connman connman-s6 connman-gtk && s6-db-reload && grub-mkconfig -o/boot/grub/grub.cfg &&

# CREATE GAMEMODE GROUP
groupadd gamemode && usermod -aG gamemode $(whoami) &&

# HARDENING SCRIPT
cd /-CoolRune-/Programs/Hardening-Script/ && sh hardening-script.sh && cd / &&

# LAST COMMANDS
chmod 777 -R /home/$USER && mv /etc/profile{,.old} && grub-install && update-grub && rm -rf /home/coolrune-files/ && echo -e "\e[1mCoolRune has been successfully installed\e[0m" && reboot
fi
'
