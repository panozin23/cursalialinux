#!/bin/bash
# Arranca el ISO final y captura: menú de arranque, plymouth, escritorio.
# Deja la VM viva (detach) para revisar el Centro después.
ISO=/home/euflo/cursalialinux-debian/ligera-xfce/cursalialinux-ligera-1.0.iso
SP=/tmp/claude-1000/-home-euflo/23a5567c-8927-46d6-9b93-97e255ad8c5b/scratchpad
SOCK=/home/euflo/cursalialinux-debian/verify.sock
rm -f "$SOCK" "$SP"/ver_*.png
setsid qemu-system-x86_64 -enable-kvm -m 4096 -smp 2 -machine pc \
  -cdrom "$ISO" -boot d -vga std -display none -usb -device usb-tablet \
  -qmp unix:"$SOCK",server,nowait -name verify >/dev/null 2>&1 &
# esperar socket
for i in $(seq 1 20); do [ -S "$SOCK" ] && break; sleep 0.5; done
sleep 4;  python3 "$SP/qmp_ctl.py" "$SOCK" shot "$SP/ver_menu.png"     >/dev/null 2>&1
sleep 8;  python3 "$SP/qmp_ctl.py" "$SOCK" shot "$SP/ver_ply1.png"     >/dev/null 2>&1
sleep 6;  python3 "$SP/qmp_ctl.py" "$SOCK" shot "$SP/ver_ply2.png"     >/dev/null 2>&1
sleep 65; python3 "$SP/qmp_ctl.py" "$SOCK" shot "$SP/ver_desktop.png"  >/dev/null 2>&1
echo "capturas: $(ls "$SP"/ver_*.png 2>/dev/null | wc -l) — VM sigue viva en $SOCK"