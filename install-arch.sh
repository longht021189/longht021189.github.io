#!/usr/bin/env bash
#
# install-arch.sh — Tự động phân vùng, format, cài base system + Android/Web dev tools
#
# CÁCH DÙNG:
#   1. Boot vào Arch ISO (live environment)
#   2. Sửa các biến trong phần "CẤU HÌNH" bên dưới cho đúng máy bạn
#   3. Copy script lên máy đích (xem hướng dẫn cuối file) rồi chạy:
#        bash install-arch.sh
#
# CẢNH BÁO: Script này sẽ XÓA SẠCH dữ liệu trên ổ DISK bạn khai báo bên dưới.
#           Kiểm tra kỹ bằng `lsblk` trước khi chạy.

set -euo pipefail

# ============================
# CẤU HÌNH — SỬA CÁC DÒNG NÀY
# ============================

DISK="/dev/sda"          # <-- ĐỔI THÀNH TÊN Ổ THẬT CỦA BẠN (xem bằng: lsblk)
HOSTNAME="longdev"            # tên máy
USERNAME="thanhlong"           # user thường sẽ tạo
TIMEZONE="Asia/Ho_Chi_Minh"
LOCALE="en_US.UTF-8"

EFI_SIZE="513MiB"             # điểm kết thúc phân vùng EFI (bắt đầu từ 1MiB)
SWAP_END="16.5GiB"            # điểm kết thúc swap (tùy RAM, xem ghi chú dưới)
ROOT_END="116.5GiB"           # điểm kết thúc root (~100GB)
                               # home sẽ chiếm phần còn lại tới 100%

# Ghi chú tính SWAP_END: EFI_SIZE + kích thước swap mong muốn.
# Ví dụ RAM 16GB -> muốn swap 16GB -> 513MiB + 16GiB ~= 16.5GiB (giá trị trên).
# Nếu RAM 32GB muốn swap 32GB thì đặt SWAP_END="32.5GiB" chẳng hạn.

# ============================
# KHÔNG CẦN SỬA GÌ BÊN DƯỚI
# ============================

echo "=================================================="
echo " Ổ đĩa sẽ bị XÓA SẠCH và cài Arch lên: $DISK"
echo "=================================================="
lsblk "$DISK" || { echo "Không tìm thấy ổ $DISK. Kiểm tra lại bằng lsblk."; exit 1; }
echo
read -rp "Gõ chính xác chữ YES (viết hoa) để xác nhận tiếp tục: " CONFIRM
if [[ "$CONFIRM" != "YES" ]]; then
    echo "Đã hủy. Không có gì bị thay đổi."
    exit 1
fi

# Xác định hậu tố phân vùng: nvme dùng "p1,p2..." còn sdX dùng "1,2..."
if [[ "$DISK" == *nvme* ]]; then
    PART_SUFFIX="p"
else
    PART_SUFFIX=""
fi

EFI_PART="${DISK}${PART_SUFFIX}1"
SWAP_PART="${DISK}${PART_SUFFIX}2"
ROOT_PART="${DISK}${PART_SUFFIX}3"
HOME_PART="${DISK}${PART_SUFFIX}4"

echo "--> Kiểm tra kết nối mạng..."
if ! ping -c1 -W2 archlinux.org &>/dev/null; then
    echo "Chưa có mạng. Nếu dùng wifi, chạy 'iwctl' để kết nối trước rồi chạy lại script."
    exit 1
fi

echo "--> Đồng bộ giờ hệ thống..."
timedatectl set-ntp true

echo "--> Tạo bảng phân vùng GPT trên $DISK..."
parted -s "$DISK" -- mklabel gpt

echo "--> Tạo phân vùng EFI, swap, root, home..."
parted -s "$DISK" -- mkpart ESP fat32 1MiB "$EFI_SIZE"
parted -s "$DISK" -- set 1 esp on
parted -s "$DISK" -- mkpart primary linux-swap "$EFI_SIZE" "$SWAP_END"
parted -s "$DISK" -- mkpart primary ext4 "$SWAP_END" "$ROOT_END"
parted -s "$DISK" -- mkpart primary ext4 "$ROOT_END" 100%

partprobe "$DISK"
sleep 2

echo "--> Format các phân vùng..."
mkfs.fat -F32 "$EFI_PART"
mkswap "$SWAP_PART"
swapon "$SWAP_PART"
mkfs.ext4 -F "$ROOT_PART"
mkfs.ext4 -F "$HOME_PART"

echo "--> Mount..."
mount "$ROOT_PART" /mnt
mount --mkdir "$EFI_PART" /mnt/boot
mount --mkdir "$HOME_PART" /mnt/home

echo "--> Cài base system (pacstrap)... (bước này mất vài phút)"
pacstrap -K /mnt base linux linux-firmware vim networkmanager sudo \
    git base-devel

echo "--> Tạo fstab..."
genfstab -U /mnt >> /mnt/etc/fstab

echo "--> Cấu hình hệ thống trong chroot..."
arch-chroot /mnt /bin/bash <<EOF
set -e

ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc

sed -i "s/^#$LOCALE/$LOCALE/" /etc/locale.gen
locale-gen
echo "LANG=$LOCALE" > /etc/locale.conf

echo "$HOSTNAME" > /etc/hostname
cat >> /etc/hosts <<HOSTS
127.0.0.1   localhost
::1         localhost
127.0.1.1   $HOSTNAME.localdomain $HOSTNAME
HOSTS

echo "--> Đặt mật khẩu root (nhập ngay bây giờ):"
passwd

useradd -m -G wheel,kvm -s /bin/bash $USERNAME
echo "--> Đặt mật khẩu cho user $USERNAME (nhập ngay bây giờ):"
passwd $USERNAME

sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

pacman -S --noconfirm grub efibootmgr
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

systemctl enable NetworkManager
EOF

echo "=================================================="
echo " CÀI XONG BASE SYSTEM. "
echo " Gõ: umount -R /mnt && reboot"
echo " Sau khi reboot, đăng nhập bằng user: $USERNAME"
echo " Rồi chạy script post-install.sh để cài desktop + dev tools."
echo "=================================================="
