#!/bin/bash
set -e

### НАСТРОЙКИ (ПРОВЕРЬ!)
ROOT_PART="/dev/sdb3"
EFI_PART="/dev/sda1"
HOSTNAME="arch"
TIMEZONE="Europe/Moscow"
LOCALE="ru_RU.UTF-8"

echo "=== Arch Linux installer ==="
echo "ROOT: $ROOT_PART"
echo "EFI : $EFI_PART"
sleep 3

### 1. Форматирование ROOT (ТОЛЬКО ОН!)
mkfs.ext4 -F $ROOT_PART

### 2. Монтирование
mount $ROOT_PART /mnt
mkdir -p /mnt/boot/efi
mount $EFI_PART /mnt/boot/efi

### 3. Установка базовой системы
pacstrap /mnt base linux linux-firmware nano networkmanager grub efibootmgr os-prober

### 4. fstab
genfstab -U /mnt >> /mnt/etc/fstab

### 5. Настройка системы
arch-chroot /mnt /bin/bash <<EOF

ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc

sed -i "s/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/" /etc/locale.gen
sed -i "s/#$LOCALE UTF-8/$LOCALE UTF-8/" /etc/locale.gen
locale-gen

echo "LANG=$LOCALE" > /etc/locale.conf
echo "$HOSTNAME" > /etc/hostname

systemctl enable NetworkManager

echo "root:root" | chpasswd

sed -i 's/#GRUB_DISABLE_OS_PROBER=false/GRUB_DISABLE_OS_PROBER=false/' /etc/default/grub

grub-install --target=x86_64-efi \
  --efi-directory=/boot/efi \
  --bootloader-id=Arch

grub-mkconfig -o /boot/grub/grub.cfg

EOF

### 6. Завершение
umount -R /mnt

echo "=================================="
echo " УСТАНОВКА ЗАВЕРШЕНА"
echo " root пароль: root"
echo " Перезагрузи ПК"
echo "=================================="
