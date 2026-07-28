#!/bin/bash
# crear-virtio-reducido.sh — Genera el CD de controladores VirtIO reducido.
#
# El CD original de Red Hat pesa 754 MB, pero el 80% son archivos .pdb:
# símbolos de depuración que solo sirven a quien programa los controladores.
# Quitándolos y dejando solo Windows 7, 8.1, 10 y 11, queda en ~52 MB.
#
# Así el CD entra en la ISO de cursalialinux y el usuario NO tiene que
# descargar nada para crear su máquina de Windows.
#
# Uso:  bash crear-virtio-reducido.sh [ruta/al/virtio-win.iso]
#       Si no se indica ruta, lo busca en /var/lib/libvirt/images
#
# No necesita sudo.
set -u

BASE="$(cd "$(dirname "$0")/.." && pwd)"
SALIDA="$BASE/marca/virtio-cursalia.iso"
TRABAJO=$(mktemp -d)
trap 'chmod -R u+w "$TRABAJO" 2>/dev/null; rm -rf "$TRABAJO"' EXIT

# ── Localizar el CD original ─────────────────────────────────────────
ORIGEN="${1:-}"
if [ -z "$ORIGEN" ]; then
  for c in /var/lib/libvirt/images/virtio-win*.iso \
           /media/*/*/CURSALIALINUX-DEBIAN/isos-windows/virtio-win*.iso \
           "$HOME"/Descargas/virtio-win*.iso; do
    [ -r "$c" ] && { ORIGEN="$c"; break; }
  done
fi

if [ -z "$ORIGEN" ] || [ ! -r "$ORIGEN" ]; then
  echo "ERROR: no encuentro el CD original de VirtIO."
  echo
  echo "  Descárgalo de:"
  echo "  https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso"
  echo
  echo "  Y vuelve a ejecutar indicando la ruta:"
  echo "    bash crear-virtio-reducido.sh ~/Descargas/virtio-win.iso"
  exit 1
fi

command -v 7z >/dev/null          || { echo "ERROR: falta 7z (sudo apt install p7zip-full)"; exit 1; }
command -v genisoimage >/dev/null || { echo "ERROR: falta genisoimage (sudo apt install genisoimage)"; exit 1; }

echo "══════════════════════════════════════════════"
echo " CD DE CONTROLADORES VIRTIO — versión reducida"
echo "══════════════════════════════════════════════"
echo
echo "  Original: $ORIGEN  ($(du -h "$ORIGEN" | cut -f1))"

# ── Extraer solo lo necesario ────────────────────────────────────────
echo
echo "── Extrayendo Windows 7, 8.1, 10 y 11 ──"
PATRONES=()
for d in viostor NetKVM vioscsi Balloon vioserial qxldod; do
  for w in w7 w8.1 w10 w11; do PATRONES+=("$d/$w/*"); done
done
PATRONES+=("virtio-win-guest-tools.exe" "virtio-win_license.txt")

7z x "$ORIGEN" -o"$TRABAJO" "${PATRONES[@]}" -y >/dev/null 2>&1 \
  || { echo "ERROR: no se pudo extraer el contenido."; exit 1; }
chmod -R u+w "$TRABAJO"

# ── Quitar los símbolos de depuración ────────────────────────────────
echo
echo "── Quitando símbolos de depuración ──"
PESO_PDB=$(find "$TRABAJO" -name '*.pdb' -printf '%s\n' 2>/dev/null | awk '{s+=$1} END {printf "%.0f", s/1024/1024}')
find "$TRABAJO" -name '*.pdb' -delete
echo "   liberados ${PESO_PDB:-0} MB"

# ── Instrucciones dentro del propio CD ───────────────────────────────
cat > "$TRABAJO/LEEME.txt" <<'TXT'
Controladores VirtIO para Windows — versión reducida para cursalialinux
========================================================================

Contiene los controladores que Windows necesita para funcionar dentro de una
máquina virtual, en versiones 7, 8.1, 10 y 11 (64 y 32 bits).

DURANTE LA INSTALACIÓN DE WINDOWS
  Si la lista de discos aparece vacía, es normal: Windows todavía no conoce
  este tipo de disco. Pulsa "Cargar controlador" y busca aquí:

      viostor\w11\amd64     (cambia w11 por tu versión de Windows)

  Y para la tarjeta de red:

      NetKVM\w11\amd64

DESPUÉS DE INSTALAR
  Ejecuta virtio-win-guest-tools.exe para que la pantalla vaya fluida, el
  portapapeles se comparta y Windows se apague de forma ordenada.

ORIGEN
  Controladores del proyecto virtio-win de Red Hat/Fedora, software libre.
  Aquí solo se han quitado los archivos .pdb (símbolos de depuración), que
  ocupaban el 80% del original y no hacen falta para usarlos.
  Original completo: https://fedorapeople.org/groups/virt/virtio-win/
  Licencia en virtio-win_license.txt
TXT

# ── Armar el CD ──────────────────────────────────────────────────────
echo
echo "── Armando el CD ──"
genisoimage -J -r -V "VIRTIO-CURSALIA" -o "$SALIDA" "$TRABAJO" 2>/dev/null \
  || { echo "ERROR: no se pudo crear el CD."; exit 1; }

# ── Comprobar ────────────────────────────────────────────────────────
echo
echo "── Comprobación ──"
fallos=0
for f in viostor/w11/amd64/viostor.inf viostor/w10/amd64/viostor.inf \
         viostor/w8.1/amd64/viostor.inf viostor/w7/amd64/viostor.inf \
         NetKVM/w11/amd64/netkvm.inf virtio-win-guest-tools.exe; do
  printf '   %-36s ' "$f"
  if xorriso -indev "$SALIDA" -find "/$f" 2>/dev/null | grep -q .; then echo "✅"
  else echo "❌"; fallos=$((fallos+1)); fi
done

echo
echo "══════════════════════════════════════════════"
if [ "$fallos" -eq 0 ]; then
  echo " ✅ CD listo:  $SALIDA"
  echo "    $(du -h "$ORIGEN" | cut -f1) → $(du -h "$SALIDA" | cut -f1)"
  echo
  echo " Se copiará dentro de la ISO al ejecutar:"
  echo "   sudo bash scripts/preparar-chroot-1.1.sh"
else
  echo " ⚠️  Faltan $fallos controladores. Revisa el CD original."
fi
echo "══════════════════════════════════════════════"
