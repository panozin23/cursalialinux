#!/bin/bash
set -e
cd /home/euflo/cursalialinux-debian/ligera-xfce
SRC=cursalialinux-ligera-def.iso
RAIZ=/home/euflo/cursalialinux-debian/raiz
OUT=cursalialinux-ligera-1.1.iso
# grub.cfg del lado UEFI (reconstruido el 2026-07-25, ver recetas/)
GRUBCFG=/home/euflo/PROYECTOS-CURSALIA/cursalialinux/recetas/grub-iso-ligera.cfg
W=iso-real
rm -rf $W; mkdir -p $W/live $W/isolinux $W/boot/grub $W/.disk

echo "=== 1) Kernel + initrd LIVE (de raiz/boot: plymouth cursalialinux, sin debian) ==="
cp $RAIZ/boot/vmlinuz-6.12.95+deb13-amd64 $W/live/vmlinuz
cp $RAIZ/boot/initrd.img-6.12.95+deb13-amd64 $W/live/initrd.img
touch $W/.disk/cursalia
printf 'cursalialinux Live\n' > $W/.disk/info

echo "=== 2) Comprimiendo el sistema (CON /boot + fix + marca, zstd) ==="
mksquashfs $RAIZ $W/live/filesystem.squashfs -comp zstd -Xcompression-level 19 -noappend \
  -e proc -e sys -e run >/tmp/mksq-real.log 2>&1
echo "  squashfs: $(du -h $W/live/filesystem.squashfs | cut -f1)"

echo "=== 3) Arranque BIOS (isolinux) ==="
cp /usr/lib/ISOLINUX/isolinux.bin $W/isolinux/
for c in ldlinux libcom32 libutil vesamenu menu; do cp /usr/lib/syslinux/modules/bios/$c.c32 $W/isolinux/; done
cp $RAIZ/usr/share/backgrounds/cursalialinux/boot-bg.png $W/isolinux/boot-bg.png
cat > $W/isolinux/isolinux.cfg <<'CFG'
UI vesamenu.c32
MENU BACKGROUND boot-bg.png
PROMPT 0
TIMEOUT 100
DEFAULT live
MENU VSHIFT 18
MENU ROWS 2
MENU HSHIFT 6
MENU WIDTH 68
MENU MARGIN 4
MENU TABMSGROW 23
MENU TIMEOUTROW 25
MENU COLOR screen       * #00000000 #00000000 none
MENU COLOR border       * #00000000 #00000000 none
MENU COLOR title        * #00000000 #00000000 none
MENU COLOR sel          * #ff05121f #ff22d3ee all
MENU COLOR unsel        * #ffe6f2ff #66000000 none
MENU COLOR tabmsg       * #ff9fc4e8 #00000000 none
MENU COLOR timeout_msg  * #ff9fc4e8 #00000000 none
MENU COLOR timeout      * #ffbfe4ff #00000000 none
LABEL live
  MENU LABEL Probar / Instalar cursalialinux
  KERNEL /live/vmlinuz
  APPEND initrd=/live/initrd.img boot=live components locales=es_MX.UTF-8 keyboard-layouts=latam quiet splash
LABEL safe
  MENU LABEL cursalialinux (graficos seguros)
  KERNEL /live/vmlinuz
  APPEND initrd=/live/initrd.img boot=live components locales=es_MX.UTF-8 keyboard-layouts=latam quiet splash nomodeset
CFG

echo "=== 4) grub.cfg (UEFI) ==="
cp "$GRUBCFG" $W/boot/grub/grub.cfg
# Fuente para el menú gráfico UEFI (sin ella GRUB sale en modo texto y sin fondo)
mkdir -p $W/boot/grub/fonts
cp /usr/share/grub/unicode.pf2 $W/boot/grub/fonts/unicode.pf2

echo "=== 5) GRUB EFI (bootx64.efi) ==="
cat > /tmp/grubembed.cfg <<'GE'
search --set=root --file /.disk/cursalia
set prefix=($root)/boot/grub
configfile /boot/grub/grub.cfg
GE
# Ya NO se usa grub-mkstandalone: generaba un arranque sin firmar.
# Cadena oficial de Debian firmada por Microsoft. Sin esto, los equipos con
# Arranque Seguro activado avisan "no es de confianza" y muchos no arrancan.
SHIM=/usr/lib/shim/shimx64.efi.signed
MOKM=/usr/lib/shim/mmx64.efi.signed
GRUBF=/usr/lib/grub/x86_64-efi-signed/grubx64.efi.signed

for f in "$SHIM" "$MOKM" "$GRUBF"; do
  [ -r "$f" ] || { echo "ERROR: falta $f"; \
    echo "  Instala:  sudo apt install shim-signed grub-efi-amd64-signed"; exit 1; }
done

dd if=/dev/zero of=$W/efi.img bs=1M count=16 status=none
mkfs.vfat -n ESP $W/efi.img >/dev/null 2>&1
mmd -i $W/efi.img ::/EFI ::/EFI/BOOT ::/EFI/debian
mcopy -i $W/efi.img "$SHIM"  ::/EFI/BOOT/BOOTX64.EFI
mcopy -i $W/efi.img "$GRUBF" ::/EFI/BOOT/grubx64.efi
mcopy -i $W/efi.img "$MOKM"  ::/EFI/BOOT/mmx64.efi
mcopy -i $W/efi.img /tmp/grubembed.cfg ::/EFI/debian/grub.cfg
mcopy -i $W/efi.img /tmp/grubembed.cfg ::/EFI/BOOT/grub.cfg

echo "  Cadena firmada lista: shim -> grub -> nucleo firmado de Debian"

echo "=== 7) Armando ISO (BIOS + UEFI, SIN Apple) ==="
rm -f $OUT
xorriso -as mkisofs -iso-level 3 -full-iso9660-filenames \
  -volid CURSALIA_LIGERA \
  -isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin \
  -c isolinux/boot.cat \
  -b isolinux/isolinux.bin \
    -no-emul-boot -boot-load-size 4 -boot-info-table \
  -eltorito-alt-boot \
  -e efi.img \
    -no-emul-boot -isohybrid-gpt-basdat \
  -o $OUT $W 2>&1 | tail -2

echo "=== RESULTADO ==="
ls -lh $OUT | awk '{print "  ISO: "$5}'
fdisk -l $OUT 2>/dev/null | grep -iE "\.iso[0-9]|Apple|HFS|EFI" | sed 's/^/    /'
rm -rf $W /tmp/bootx64.efi /tmp/grubembed.cfg
df -h / | tail -1