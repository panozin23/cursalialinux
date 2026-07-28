#!/bin/bash
# Construye un ISO RÁPIDO (throwaway) desde raiz y captura pantallas del escritorio en vivo.
set -e
R=/home/euflo/cursalialinux-debian/raiz
DEF=/home/euflo/cursalialinux-debian/ligera-xfce/cursalialinux-ligera-def.iso
W=/home/euflo/cursalialinux-debian/vistawork
SP=/tmp/claude-1000/-home-euflo/23a5567c-8927-46d6-9b93-97e255ad8c5b/scratchpad
rm -rf "$W"; mkdir -p "$W/live" "$W/isolinux" "$W/.disk"

echo "== kernel/initrd + squash rápido =="
7z e -y "$DEF" live/vmlinuz live/initrd.img -o"$W/live" >/dev/null 2>&1
touch "$W/.disk/cursalia"; printf 'cursalialinux Live\n' > "$W/.disk/info"
mksquashfs "$R" "$W/live/filesystem.squashfs" -comp gzip -Xcompression-level 1 -noappend -e proc -e sys -e run >/tmp/vmksq.log 2>&1
echo "   squashfs: $(du -h "$W/live/filesystem.squashfs" | cut -f1)"

cp /usr/lib/ISOLINUX/isolinux.bin "$W/isolinux/"
for c in ldlinux libcom32 libutil; do cp /usr/lib/syslinux/modules/bios/$c.c32 "$W/isolinux/"; done
cat > "$W/isolinux/isolinux.cfg" <<'CFG'
DEFAULT live
PROMPT 0
TIMEOUT 10
LABEL live
  KERNEL /live/vmlinuz
  APPEND initrd=/live/initrd.img boot=live components locales=es_ES.UTF-8 keyboard-layouts=latam quiet splash
CFG
xorriso -as mkisofs -iso-level 3 -full-iso9660-filenames -volid CURSALIA_VISTA \
  -isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin \
  -c isolinux/boot.cat -b isolinux/isolinux.bin -no-emul-boot -boot-load-size 4 -boot-info-table \
  -o "$W/test.iso" "$W" >/dev/null 2>&1

echo "== arrancando y capturando escritorio =="
cd "$SP"; rm -f vista_*.png qmpq.sock
qemu-system-x86_64 -enable-kvm -m 4096 -smp 2 -machine pc \
  -cdrom "$W/test.iso" -boot d -vga std -display none \
  -qmp unix:qmpq.sock,server,nowait & QP=$!
sleep 80;  python3 qmp_shot.py qmpq.sock vista_80.png  >/dev/null 2>&1
sleep 20;  python3 qmp_shot.py qmpq.sock vista_100.png >/dev/null 2>&1
kill $QP 2>/dev/null
rm -rf "$W"
echo "== capturas listas =="
ls -la "$SP"/vista_*.png 2>/dev/null | awk '{print "  "$5"  "$9}'