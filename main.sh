#!/bin/bash
set -e

### НАСТРОЙКИ
ROOT_PART="/dev/sdb3"
EFI_PART="/dev/sda1"
HOSTNAME="arch"
TIMEZONE="Asia/Krasnoyarsk"
LOCALE="en_US.UTF-8"
USERNAME="timex"
PASSWORD="123"

echo "=== ARCH INSTALLER ==="
echo "ROOT: $ROOT_PART"
echo "EFI : $EFI_PART"
sleep 3

### 1. Форматируем ТОЛЬКО ROOT
mkfs.ext4 -F $ROOT_PART

### 2. Монтируем
mount $ROOT_PART /mnt
mkdir -p /mnt/boot/efi
mount $EFI_PART /mnt/boot/efi

### 3. Установка системы + KDE
pacstrap /mnt \
  base linux linux-firmware \
  nano sudo networkmanager \
  grub efibootmgr os-prober \
  xorg plasma kde-applications \
  sddm

### 4. fstab
genfstab -U /mnt >> /mnt/etc/fstab

### 5. Настройка системы
arch-chroot /mnt /bin/bash <<EOF

ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc

sed -i "s/#$LOCALE UTF-8/$LOCALE UTF-8/" /etc/locale.gen
locale-gen
echo "LANG=$LOCALE" > /etc/locale.conf

echo "$HOSTNAME" > /etc/hostname

systemctl enable NetworkManager
systemctl enable sddm

### root пароль
echo "root:$PASSWORD" | chpasswd

### пользователь
useradd -m -G wheel -s /bin/bash $USERNAME
echo "$USERNAME:$PASSWORD" | chpasswd

### sudo
sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

### GRUB
sed -i 's/#GRUB_DISABLE_OS_PROBER=false/GRUB_DISABLE_OS_PROBER=false/' /etc/default/grub

grub-install --target=x86_64-efi \
  --efi-directory=/boot/efi \
  --bootloader-id=Arch

grub-mkconfig -o /boot/grub/grub.cfg

EOF

### 6. Завершение
umount -R /mnt

echo "=================================="
echo " ГОТОВО!"
echo " Пользователь: timex"
echo " Пароль: 123"
echo " KDE Plasma установлена"
echo " Перезагрузи ПК"
echo "=================================="
