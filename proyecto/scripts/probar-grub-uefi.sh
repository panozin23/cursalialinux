#!/bin/bash
# probar-grub-uefi.sh — Comprueba que el grub-iso-*.cfg reconstruido arranca
# de verdad por UEFI, sin tener que construir un ISO completo.
#
#   1. Instala lo que falte para construir: xorriso, isolinux, y para la
#      prueba: qemu-system-x86 + ovmf (firmware UEFI de QEMU).
#   2. Arma un ISO mínimo (kernel + initrd reales + el grub.cfg reconstruido).
#      NO lleva squashfs: la prueba es del MENÚ y del arranque del kernel,
#      no del escritorio; así tarda segundos en vez de media hora.
#   3. Lo arranca en QEMU con firmware UEFI y saca fotos de la pantalla.
#
# No toca ninguna raíz ni ningún ISO existente.
# Uso:  sudo bash probar-grub-uefi.sh  [ligera|moderna]  [std|virtio|qxl|vmware]
#         por defecto: moderna std
#       La tarjeta de vídeo importa: con 'std' salían rayas de colores en el
#       menú de GRUB; repetir con 'virtio' dice si es cosa de QEMU o del cfg.
set -uo pipefail

EDICION="${1:-moderna}"
VGA="${2:-std}"
BASE=/home/euflo/PROYECTOS-CURSALIA/cursalialinux
DUENO="${SUDO_USER:-euflo}"
W="$BASE/isos/trabajo-prueba-uefi"
FOTOS="$BASE/isos/pruebas-uefi"

case "$EDICION" in
  moderna) GRUBCFG="$BASE/recetas/grub-iso-moderna.cfg"
           KVMLINUZ="$BASE/cocina/moderna-kde/kernel/vmlinuz"
           KINITRD="$BASE/cocina/moderna-kde/kernel/initrd.img"
           BG="$BASE/cocina/moderna-kde/raiz/usr/share/backgrounds/cursalialinux/boot-bg.png" ;;
  ligera)  GRUBCFG="$BASE/recetas/grub-iso-ligera.cfg"
           KVMLINUZ="$BASE/cocina/raiz/boot/vmlinuz-6.12.95+deb13-amd64"
           KINITRD="$BASE/cocina/raiz/boot/initrd.img-6.12.95+deb13-amd64"
           BG="$BASE/cocina/raiz/usr/share/backgrounds/cursalialinux/boot-bg.png" ;;
  *) echo "Uso: sudo bash $0 [ligera|moderna] [std|virtio|qxl|vmware]"; exit 1 ;;
esac
case "$VGA" in
  std|virtio|qxl|vmware|cirrus) ;;
  *) echo "Tarjeta de vídeo no reconocida: $VGA (usa std, virtio, qxl o vmware)"; exit 1 ;;
esac
ETIQ="${EDICION}-${VGA}"

rojo()  { printf '\033[1;31m%s\033[0m\n' "$*"; }
verde() { printf '\033[1;32m%s\033[0m\n' "$*"; }
azul()  { printf '\033[1;36m%s\033[0m\n' "$*"; }
abortar() { rojo "ABORTADO: $*"; exit 1; }

[ "$(id -u)" -eq 0 ] || abortar "ejecutar con sudo."
export PATH="$PATH:/usr/sbin:/sbin"

azul "═══ 1/4 · Herramientas ═══"
FALTAN=()
command -v xorriso            >/dev/null || FALTAN+=(xorriso)
[ -e /usr/lib/ISOLINUX/isohdpfx.bin ] || FALTAN+=(isolinux)
command -v qemu-system-x86_64 >/dev/null || FALTAN+=(qemu-system-x86)
ls /usr/share/OVMF/OVMF_CODE*.fd /usr/share/ovmf/OVMF.fd >/dev/null 2>&1 || FALTAN+=(ovmf)

if [ ${#FALTAN[@]} -gt 0 ]; then
  echo "Faltan: ${FALTAN[*]}"
  echo "Instalando..."
  apt-get install -y "${FALTAN[@]}" || abortar "apt-get falló. ¿Hay red?"
else
  echo "No falta nada."
fi
for c in xorriso qemu-system-x86_64 mksquashfs grub-mkstandalone mkfs.vfat mmd mcopy; do
  command -v "$c" >/dev/null && verde "  ✓ $c" || rojo "  ✗ $c"
done

# Firmware UEFI para QEMU
OVMF_CODE=""
for f in /usr/share/OVMF/OVMF_CODE_4M.fd /usr/share/OVMF/OVMF_CODE.fd /usr/share/ovmf/OVMF.fd; do
  [ -f "$f" ] && { OVMF_CODE="$f"; break; }
done
[ -n "$OVMF_CODE" ] || abortar "no encuentro el firmware OVMF."
verde "  ✓ firmware UEFI: $OVMF_CODE"

azul ""
azul "═══ 2/4 · ISO mínimo de prueba ($EDICION) ═══"
for f in "$GRUBCFG" "$KVMLINUZ" "$KINITRD"; do
  [ -e "$f" ] || abortar "falta $f"
done

rm -rf "$W"; mkdir -p "$W/live" "$W/boot/grub/fonts" "$W/isolinux" "$W/.disk"
cp "$KVMLINUZ" "$W/live/vmlinuz"
cp "$KINITRD"  "$W/live/initrd.img"
touch "$W/.disk/cursalia"
printf 'cursalialinux PRUEBA UEFI\n' > "$W/.disk/info"

# Lo mismo que hacen los build-*.sh en sus pasos 4 y 5
cp "$GRUBCFG" "$W/boot/grub/grub.cfg"
cp /usr/share/grub/unicode.pf2 "$W/boot/grub/fonts/unicode.pf2"
cp "$BG" "$W/isolinux/boot-bg.png" 2>/dev/null && echo "  fondo boot-bg.png incluido" \
  || echo "  (sin fondo: $BG no existe)"

cat > /tmp/grubembed-prueba.cfg <<'GE'
search --set=root --file /.disk/cursalia
set prefix=($root)/boot/grub
configfile /boot/grub/grub.cfg
GE
grub-mkstandalone -O x86_64-efi -o /tmp/bootx64-prueba.efi \
  --modules="part_gpt part_msdos fat iso9660 all_video search normal configfile linux echo gfxterm gfxterm_background gfxterm_menu font png gzio" \
  "boot/grub/grub.cfg=/tmp/grubembed-prueba.cfg" 2>/dev/null \
  || abortar "grub-mkstandalone falló."

dd if=/dev/zero of="$W/efi.img" bs=1M count=16 status=none
mkfs.vfat -n ESP "$W/efi.img" >/dev/null 2>&1
mmd -i "$W/efi.img" ::/EFI ::/EFI/BOOT
mcopy -i "$W/efi.img" /tmp/bootx64-prueba.efi ::/EFI/BOOT/BOOTX64.EFI

ISO="$W/prueba-uefi.iso"
xorriso -as mkisofs -iso-level 3 -full-iso9660-filenames \
  -volid CURSALIA_PRUEBA \
  -e efi.img -no-emul-boot \
  -o "$ISO" "$W" >/dev/null 2>&1 || abortar "xorriso falló."
verde "  ✓ ISO de prueba: $(du -h "$ISO" | cut -f1)"

azul ""
azul "═══ 3/4 · Arrancando en QEMU (UEFI, tarjeta $VGA) ═══"
# Solo borra las fotos de ESTA combinación: las de las otras se conservan
# para poder comparar (edición × tarjeta de vídeo).
mkdir -p "$FOTOS"; rm -f "$FOTOS"/uefi_${ETIQ}_*.png "$FOTOS/serial-${ETIQ}.log"
SOCK=/tmp/qmp-prueba-uefi.sock; rm -f "$SOCK"

QEMU_ARGS=(-m 2048 -smp 2 -vga "$VGA" -display none
           -cdrom "$ISO" -boot d
           -serial "file:$FOTOS/serial-${ETIQ}.log"
           -qmp "unix:$SOCK,server,nowait")
[ -r /dev/kvm ] && QEMU_ARGS=(-enable-kvm "${QEMU_ARGS[@]}") && echo "  con KVM"

# Firmware: OVMF.fd va con -bios; los OVMF_CODE_*.fd necesitan pflash + VARS
case "$OVMF_CODE" in
  */OVMF.fd) QEMU_ARGS+=(-bios "$OVMF_CODE") ;;
  *) VARS_ORIG="${OVMF_CODE/CODE/VARS}"
     [ -f "$VARS_ORIG" ] || abortar "falta $VARS_ORIG"
     cp "$VARS_ORIG" "$W/OVMF_VARS.fd"
     QEMU_ARGS+=(-drive "if=pflash,format=raw,unit=0,readonly=on,file=$OVMF_CODE"
                 -drive "if=pflash,format=raw,unit=1,file=$W/OVMF_VARS.fd") ;;
esac

qemu-system-x86_64 "${QEMU_ARGS[@]}" & QP=$!
sleep 3
[ -S "$SOCK" ] || { kill $QP 2>/dev/null; abortar "QEMU no arrancó (no hay socket QMP)."; }

# t=6s  → el menú de GRUB debe estar en pantalla (timeout del menú: 10s)
# t=18s → ya pasó el timeout: el kernel debe estar cargando
# t=35s → sin squashfs, lo normal es caer al initramfs: eso PRUEBA que arrancó
for t in 6 18 35; do
  [ "$t" = 6 ] && sleep 6 || sleep 12
  python3 "$BASE/scripts/qmp_shot.py" "$SOCK" "$FOTOS/uefi_${ETIQ}_${t}s.png" >/dev/null 2>&1 \
    && echo "  foto a los ${t}s" || echo "  (falló la foto a los ${t}s)"
done
kill $QP 2>/dev/null; wait $QP 2>/dev/null

azul ""
azul "═══ 4/4 · Resultado ═══"
chown -R "$DUENO:$DUENO" "$FOTOS"
ls -lh "$FOTOS"/uefi_${ETIQ}_*.png 2>/dev/null | awk '{print "  "$5"  "$9}'
echo
echo "Consola serie (primeras señales del kernel):"
head -20 "$FOTOS/serial-${ETIQ}.log" 2>/dev/null | sed 's/^/    /' || echo "    (vacía)"
echo
echo "QUÉ MIRAR en las fotos ($FOTOS):"
echo "  6s  → menú azul con 'Probar / Instalar cursalialinux…' y el fondo."
echo "        Si sale en texto blanco sobre negro, el menú funciona pero"
echo "        no cargó fuente/fondo."
echo "  18s → mensajes de carga del kernel (o pantalla de splash)."
echo "  35s → initramfs / 'Unable to find a medium': ESPERADO en esta prueba,"
echo "        porque el ISO mínimo no lleva filesystem.squashfs."
echo "  Lo que NO debe salir: 'error: file not found', 'Shell>' del firmware,"
echo "  o una pantalla negra vacía a los 6s → ahí el grub.cfg estaría mal."
echo
rm -rf "$W" /tmp/bootx64-prueba.efi /tmp/grubembed-prueba.cfg "$SOCK"
verde "Carpeta de trabajo limpiada. Las fotos se quedan."
