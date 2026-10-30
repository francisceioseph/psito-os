#!/bin/bash

set -e

echo "🦜 Create do Psito OS Disk (Debian + QEMU)..."

qemu-img create -f qcow2 qemu/psito-disk.qcow2 20G
