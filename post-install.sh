#!/usr/bin/env bash
#
# post-install.sh — Chạy SAU KHI reboot vào hệ thống Arch mới, đăng nhập bằng user thường
#
# YÊU CẦU: chạy bằng user thường (không phải root), user đó phải có trong nhóm wheel
#          và đã có mạng (NetworkManager đã bật sẵn từ script cài đặt trước).
#
# CÁCH DÙNG:
#   1. Sửa DESKTOP bên dưới nếu muốn đổi desktop environment
#   2. curl -O https://your-host.com/post-install.sh
#   3. bash post-install.sh

set -euo pipefail

if [[ "$EUID" -eq 0 ]]; then
    echo "Đừng chạy script này bằng root. Đăng nhập bằng user thường rồi chạy lại."
    exit 1
fi

# ============================
# CẤU HÌNH
# ============================

DESKTOP="gnome"    # chọn: "gnome" hoặc "kde"

# ============================

echo "--> Kiểm tra mạng..."
if ! ping -c1 -W2 archlinux.org &>/dev/null; then
    echo "Chưa có mạng. Kết nối wifi bằng 'nmtui' hoặc cắm dây LAN rồi chạy lại."
    exit 1
fi

echo "--> Cập nhật hệ thống..."
sudo pacman -Syu --noconfirm

case "$DESKTOP" in
    gnome)
        echo "--> Cài GNOME..."
        sudo pacman -S --noconfirm gnome gdm
        sudo systemctl enable gdm
        ;;
    kde)
        echo "--> Cài KDE Plasma..."
        sudo pacman -S --noconfirm plasma-desktop sddm konsole dolphin
        sudo systemctl enable sddm
        ;;
    *)
        echo "Giá trị DESKTOP không hợp lệ: $DESKTOP (chỉ nhận gnome hoặc kde)"
        exit 1
        ;;
esac

echo "=================================================="
echo " XONG. Reboot lại để vào desktop environment:"
echo "   reboot"
echo "=================================================="
