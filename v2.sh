#!/bin/bash

# --- SELF-BOOTSTRAP ---
if ! command -v dialog &> /dev/null; then
    echo "Установка интерфейса (dialog)..."
    pacman -Sy --noconfirm dialog || exit 1
fi

# --- ЦВЕТОВАЯ СХЕМА (Фиолетовые тона) ---
export DIALOGRC=$HOME/.dialogrc
cat <<EOF > $DIALOGRC
screen_color = (CYAN,BLUE,ON)
border_color = (MAGENTA,BLACK,ON)
title_color = (MAGENTA,BLACK,ON)
button_active_color = (BLACK,MAGENTA,ON)
button_inactive_color = (MAGENTA,BLACK,ON)
EOF

# --- ФУНКЦИИ-ПОМОЩНИКИ ---
show_error() { dialog --title " ОШИБКА " --msgbox "$1" 10 50; }

# --- 1. ПРОВЕРКИ ---
if [ ! -d "/sys/firmware/efi" ]; then
    show_error "Система не в режиме UEFI! Скрипт поддерживает только GPT/UEFI."
    exit 1
fi

# --- 2. ПЕРСОНАЛИЗАЦИЯ ПОЛЬЗОВАТЕЛЯ ---
USER_NAME=$(dialog --title "ПОЛЬЗОВАТЕЛЬ" --inputbox "Введите имя нового пользователя:" 10 50 "archuser" 3>&1 1>&2 2>&3)
USER_PASS=$(dialog --title "ПАРОЛЬ" --passwordbox "Введите пароль пользователя:" 10 50 3>&1 1>&2 2>&3)
ROOT_PASS=$(dialog --title "ROOT ПАРОЛЬ" --passwordbox "Введите пароль для Root:" 10 50 3>&1 1>&2 2>&3)

IS_SUDO=$(dialog --title "ПРАВА" --yesno "Дать пользователю $USER_NAME права администратора (sudo)?" 7 50; echo $?)

# --- 3. РАБОТА С ДИСКАМИ ---
DEVICES=$(lsblk -dnpno NAME,SIZE | awk '{print $1 " [" $2 "]" " off"}')
DISK=$(dialog --title "ДИСК" --radiolist "Выберите диск для установки:" 15 50 5 $DEVICES 3>&1 1>&2 2>&3)

# Находим все FAT32 разделы на диске для EFI
EFI_LIST=$(lsblk -pno NAME,FSTYPE,SIZE "$DISK" | grep "vfat" | awk '{print $1 " [" $3 "]" " off"}')
EFI_PART=$(dialog --title "EFI РАЗДЕЛ" --radiolist "Выберите существующий EFI раздел:" 15 50 5 $EFI_LIST 3>&1 1>&2 2>&3)

# Выбираем раздел для системы
ROOT_LIST=$(lsblk -pno NAME,FSTYPE,SIZE "$DISK" | awk '{print $1 " [" $3 " " $2 "]" " off"}')
ROOT_PART=$(dialog --title "ROOT РАЗДЕЛ" --radiolist "Выберите раздел для / (БУДЕТ ОПФОРМАТИРОВАН):" 15 50 5 $ROOT_LIST 3>&1 1>&2 2>&3)

# --- 4. ВЫБОР ДРАЙВЕРОВ И СОФТА ---
GPU_TYPE=$(dialog --title "ВИДЕОДРАЙВЕР" --menu "Выберите вашу видеокарту:" 15 55 5 \
    "1" "NVIDIA (Proprietary)" \
    "2" "AMD (Open Source)" \
    "3" "Intel (Integrated)" \
    "4" "VMWare/VirtualBox" 3>&1 1>&2 2>&3)

case $GPU_TYPE in
    1) GPU_PKGS="nvidia nvidia-utils nvidia-settings lib32-nvidia-utils" ;;
    2) GPU_PKGS="xf86-video-amdgpu vulkan-radeon lib32-vulkan-radeon" ;;
    3) GPU_PKGS="xf86-video-intel vulkan-intel lib32-vulkan-intel" ;;
    4) GPU_PKGS="virtualbox-guest-utils" ;;
esac

# --- 5. УСТАНОВКА ---
(
echo 10; echo "XXX\nПодготовка дисков...\nXXX"
mkfs.ext4 -F "$ROOT_PART"
mount "$ROOT_PART" /mnt
mkdir -p /mnt/boot
mount "$EFI_PART" /mnt/boot

echo 30; echo "XXX\nУстановка ядра и KDE Plasma...\nXXX"
pacstrap /mnt base linux linux-firmware base-devel grub efibootmgr os-prober networkmanager \
bluez bluez-utils plasma-desktop sddm konsole dolphin ark gwenview $GPU_PKGS

echo 60; echo "XXX\nУстановка Dev-софта и мессенджеров...\nXXX"
pacstrap /mnt nodejs npm python python-pip git code docker discord telegram-desktop firefox vlc

echo 80; echo "XXX\nТонкая настройка системы...\nXXX"
genfstab -U /mnt >> /mnt/etc/fstab

arch-chroot /mnt /bin/bash <<EOF
# Время и локаль
ln -sf /usr/share/zoneinfo/Europe/Moscow /etc/localtime
hwclock --systohc
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
echo "ru_RU.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en-US_RU.UTF-8" > /etc/locale.conf
echo "arch" > /etc/hostname

# Настройка паролей и пользователей
echo "root:$ROOT_PASS" | chpasswd
useradd -m -s /bin/bash "$USER_NAME"
echo "$USER_NAME:$USER_PASS" | chpasswd

if [ "$IS_SUDO" -eq 0 ]; then
    echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers
    usermod -aG wheel,docker,video,audio "$USER_NAME"
fi

# GRUB и Мультибут
echo "GRUB_DISABLE_OS_PROBER=false" >> /etc/default/grub
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=PURPLE_ARCH
grub-mkconfig -o /boot/grub/grub.cfg

# Включение сервисов
systemctl enable NetworkManager sddm bluetooth docker

# Установка Yay (AUR Helper)
sudo -u "$USER_NAME" bash -c "cd /home/$USER_NAME && git clone https://aur.archlinux.org/yay-bin.git && cd yay-bin && makepkg -si --noconfirm"
EOF

echo 100; echo "XXX\nУстановка завершена успешно!\nXXX"
) | dialog --title "ПРОЦЕСС УСТАНОВКИ" --gauge "Пожалуйста, подождите..." 10 75

clear
echo -e "\e[1;35m====================================================\e[0m"
echo -e "\e[1;35m   PURPLE ARCH УСТАНОВЛЕН! ПЕРЕЗАГРУЗИТЕСЬ.       \e[0m"
echo -e "\e[1;35m   Пользователь: $USER_NAME                       \e[0m"
echo -e "\e[1;35m====================================================\e[0m"
