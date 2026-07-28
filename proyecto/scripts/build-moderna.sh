#!/bin/bash
set -e
cd /home/euflo/cursalialinux-debian/moderna-kde
RAIZ=/home/euflo/cursalialinux-debian/moderna-kde/raiz
KERN=/home/euflo/cursalialinux-debian/moderna-kde/kernel
OUT=cursalialinux-moderna-1.1.iso
# grub.cfg del lado UEFI (reconstruido el 2026-07-25, ver recetas/)
GRUBCFG=/home/euflo/PROYECTOS-CURSALIA/cursalialinux/recetas/grub-iso-moderna.cfg
# Carpeta de trabajo. Antes: /run/media/euflo/SANSUNG2/iso-real-build — esa era
# la ruta de montaje del sistema anterior (aquí los discos montan en /media/...) y
# obligaba a tener el disco externo puesto. Ahora usa la partición p6
# (CURSALIA-ISOS, 40 GB libres), que está siempre montada.
W=/home/euflo/PROYECTOS-CURSALIA/cursalialinux/isos/trabajo-moderna
rm -rf $W; mkdir -p $W/live $W/isolinux $W/boot/grub $W/.disk

echo "=== 1) Kernel + initrd LIVE (de la ISO KDE: live-boot) ==="
cp $KERN/vmlinuz $W/live/vmlinuz
cp $KERN/initrd.img $W/live/initrd.img
touch $W/.disk/cursalia
printf 'cursalialinux Moderna Live\n' > $W/.disk/info

echo "=== 2) Comprimiendo el sistema KDE (CON /boot, zstd) ==="
mksquashfs $RAIZ $W/live/filesystem.squashfs -comp zstd -Xcompression-level 19 -noappend \
  -e proc -e sys -e run >/tmp/mksq-kde.log 2>&1
echo "  squashfs: $(du -h $W/live/filesystem.squashfs | cut -f1)"

echo "=== 3) Arranque BIOS (isolinux) ==="
cp /usr/lib/ISOLINUX/isolinux.bin $W/isolinux/
for c in ldlinux libcom32 libutil vesamenu menu; do cp /usr/lib/syslinux/modules/bios/$c.c32 $W/isolinux/; done
cp $RAIZ/usr/share/backgrounds/cursalialinux/boot-bg.png $W/isolinux/boot-bg.png 2>/dev/null || true
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
  MENU LABEL Probar / Instalar cursalialinux Moderna
  KERNEL /live/vmlinuz
  APPEND initrd=/live/initrd.img boot=live components locales=es_MX.UTF-8 keyboard-layouts=latam quiet splash
LABEL safe
  MENU LABEL cursalialinux Moderna (graficos seguros)
  KERNEL /live/vmlinuz
  APPEND initrd=/live/initrd.img boot=live components locales=es_MX.UTF-8 keyboard-layouts=latam quiet splash nomodeset
CFG

echo "=== 4) grub.cfg (UEFI) ==="
cp "$GRUBCFG" $W/boot/grub/grub.cfg
# Fuente para el menú gráfico UEFI (sin ella GRUB sale en modo texto y sin fondo)
mkdir -p $W/boot/grub/fonts
cp /usr/share/grub/unicode.pf2 $W/boot/grub/fonts/unicode.pf2

echo "=== 5) Arranque que salta al menú real del ISO ==="
# Este pedacito de configuración es lo primero que ejecuta el GRUB firmado:
# localiza el ISO por su marca en /.disk/cursalia y carga el menú de verdad.
cat > /tmp/grubembed-kde.cfg <<'GE'
search --set=root --file /.disk/cursalia
set prefix=($root)/boot/grub
configfile /boot/grub/grub.cfg
GE
# Ya NO se usa grub-mkstandalone: generaba un arranque sin firmar que los
# equipos con Arranque Seguro rechazaban. Ver el paso 6.

echo "=== 6) Imagen ESP (16M) — cadena FIRMADA para Arranque Seguro ==="
# Antes se metía un bootx64.efi generado con grub-mkstandalone, que NO va
# firmado. En equipos con Arranque Seguro activado (la mayoría de fábrica)
# el firmware avisaba "no es de confianza" y muchos se negaban a arrancar.
#
# Ahora se usa la cadena oficial de Debian, firmada por Microsoft:
#   BOOTX64.EFI  = shim   (lo que el firmware acepta y verifica)
#   grubx64.efi  = GRUB firmado (lo carga el shim)
#   mmx64.efi    = MokManager (para gestionar claves si hiciera falta)
# El núcleo de Debian ya viene firmado, así que la cadena queda completa.

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

# El GRUB firmado trae fijada su ruta de configuración en /EFI/debian.
# Ahí ponemos el arranque que salta al menú real dentro del ISO.
mcopy -i $W/efi.img /tmp/grubembed-kde.cfg ::/EFI/debian/grub.cfg
mcopy -i $W/efi.img /tmp/grubembed-kde.cfg ::/EFI/BOOT/grub.cfg

echo "  Cadena firmada lista: shim → grub → núcleo firmado de Debian"

echo "=== 7) Armando ISO (BIOS + UEFI, SIN Apple) ==="
rm -f $OUT
xorriso -as mkisofs -iso-level 3 -full-iso9660-filenames \
  -volid CURSALIA_MODERNA \
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
rm -rf $W /tmp/bootx64-kde.efi /tmp/grubembed-kde.cfg
df -h / | tail -1
