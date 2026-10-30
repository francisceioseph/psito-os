#!/bin/bash

set -e

echo "🦜 Install Basic do Psito OS (Debian + QEMU)..."

qemu-system-x86_64 \
  -enable-kvm \
  -m 2048 \
  -smp 2 \
  -vga virtio \
  -display gtk,gl=on \
  -drive file=qemu/psito-disk.qcow2,format=qcow2 \
  -cdrom debian/debian-netinst.iso \
  -boot d \
  -net user,hostfwd=tcp::2222-:22 \
  -net nic