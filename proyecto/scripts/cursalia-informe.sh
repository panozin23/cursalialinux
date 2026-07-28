#!/bin/bash
# cursalia-informe.sh — Radiografía de un equipo para virtualización.
#
# Recoge en un solo texto TODO lo que hace falta saber para crear una máquina
# de Windows en este equipo concreto. Se pega en el chat y ya no hay que
# adivinar nada.
#
# Nació el 2026-07-27, después de una tarde entera corrigiendo errores a
# ciegas en dos PCs de escritorio: cada intento fallaba por algo distinto
# que no se podía ver desde fuera.
#
# Uso:  cursalia-informe.sh
#       No modifica nada. Solo mira.
set -u

echo "═══════════════════════════════════════════════════"
echo " INFORME DEL EQUIPO — $(date '+%Y-%m-%d %H:%M')"
echo "═══════════════════════════════════════════════════"

# ── Identidad ────────────────────────────────────────────────────────
echo
echo "── SISTEMA ──"
printf '  %-22s %s\n' "Equipo:"  "$(hostname)"
printf '  %-22s %s\n' "Sistema:" "$(grep -oP 'PRETTY_NAME="\K[^"]+' /etc/os-release 2>/dev/null)"
printf '  %-22s %s\n' "Núcleo:"  "$(uname -r)"
printf '  %-22s %s\n' "Escritorio:" "${XDG_CURRENT_DESKTOP:-?} / ${XDG_SESSION_TYPE:-?}"
printf '  %-22s %s\n' "cursalialinux-escritorio:" \
  "$(dpkg-query -W -f='${Version}' cursalialinux-escritorio 2>/dev/null || echo 'no instalado')"

# ── Hardware ─────────────────────────────────────────────────────────
echo
echo "── PROCESADOR Y MEMORIA ──"
printf '  %-22s %s\n' "Modelo:" "$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2- | sed 's/^ *//')"
printf '  %-22s %s\n' "Hilos:"  "$(nproc)"
if grep -qm1 ' svm ' /proc/cpuinfo; then
  printf '  %-22s %s\n' "Virtualización:" "AMD-V (svm) activa"
elif grep -qm1 ' vmx ' /proc/cpuinfo; then
  printf '  %-22s %s\n' "Virtualización:" "Intel VT-x (vmx) activa"
else
  printf '  %-22s %s\n' "Virtualización:" "❌ NO disponible (revisar BIOS)"
fi
printf '  %-22s %s\n' "Memoria:" "$(free -h | awk '/^Mem:/{print $2" total, "$7" disponible"}')"
printf '  %-22s %s\n' "/dev/kvm:" "$([ -e /dev/kvm ] && echo 'presente' || echo '❌ ausente')"
printf '  %-22s %s\n' "TPM del equipo:" "$(ls /dev/tpm* >/dev/null 2>&1 && echo 'sí' || echo 'no (se emula igual)')"

echo
echo "── DISCO ──"
df -h /var/lib/libvirt/images 2>/dev/null | tail -1 | awk '{printf "  libre: %s de %s\n", $4, $2}'

# ── Paquetes ─────────────────────────────────────────────────────────
echo
echo "── PAQUETES DE VIRTUALIZACIÓN ──"
for p in qemu-system-x86 qemu-system-gui qemu-utils libvirt-daemon-system \
         libvirt-clients virt-manager virt-viewer swtpm ovmf genisoimage yad; do
  v=$(dpkg-query -W -f='${Version}' "$p" 2>/dev/null)
  printf '  %-24s %s\n' "$p" "${v:-❌ FALTA}"
done

# ── Servicios ────────────────────────────────────────────────────────
echo
echo "── SERVICIOS ──"
printf '  %-22s %s\n' "libvirtd:" "$(systemctl is-active libvirtd 2>/dev/null) / $(systemctl is-enabled libvirtd 2>/dev/null)"
printf '  %-22s %s\n' "Tu usuario:" "$(id -un)"
printf '  %-22s %s\n' "Grupos:" "$(id -nG)"
for g in libvirt kvm; do
  id -nG | tr ' ' '\n' | grep -qx "$g" \
    && printf '  %-22s ✅\n' "grupo $g:" \
    || printf '  %-22s ❌ falta (usermod -aG %s \$USER)\n' "grupo $g:" "$g"
done

# ── Lo que de verdad decide: qué acepta libvirt ──────────────────────
echo
echo "── QUÉ ACEPTA LIBVIRT EN ESTE EQUIPO ──"
echo "   (esto es lo que causó todos los problemas del 2026-07-27)"
CAPS=$(virsh -c qemu:///system domcapabilities 2>/dev/null)
if [ -z "$CAPS" ]; then
  echo "  ❌ libvirt no responde. ¿Está encendido el servicio?"
else
  printf '  %-22s %s\n' "Pantalla SPICE:" "$(echo "$CAPS" | grep -q '<value>spice</value>' && echo 'sí' || echo 'NO → usar VNC')"
  printf '  %-22s %s\n' "Pantalla VNC:"   "$(echo "$CAPS" | grep -q '<value>vnc</value>'   && echo 'sí' || echo 'no')"
  printf '  %-22s %s\n' "Vídeo disponible:" \
    "$(echo "$CAPS" | sed -n '/modelType/,/\/enum/p' | grep -oP '(?<=<value>)[a-z0-9]+' | tr '\n' ' ')"
  printf '  %-22s %s\n' "Firmware UEFI:" "$(echo "$CAPS" | grep -q 'efi' && echo 'sí' || echo 'no')"
  printf '  %-22s %s\n' "TPM emulado:" "$(echo "$CAPS" | grep -q 'tpm' && echo 'sí' || echo 'no')"
fi

echo
echo "── RED VIRTUAL ──"
virsh -c qemu:///system net-list --all 2>/dev/null | sed -n '3,6p' | sed 's/^/  /' \
  || echo "  (no se pudo consultar)"

echo
echo "── MÁQUINAS EXISTENTES ──"
virsh -c qemu:///system list --all 2>/dev/null | sed -n '3,10p' | grep . | sed 's/^/  /' \
  || echo "  (ninguna)"

echo
echo "── IMÁGENES DISPONIBLES ──"
ls -lh /var/lib/libvirt/images/*.iso /var/lib/libvirt/images/*.qcow2 2>/dev/null \
  | awk '{printf "  %-46s %s\n", $9, $5}' | sed 's|/var/lib/libvirt/images/||' \
  || echo "  (ninguna)"

echo
echo "═══════════════════════════════════════════════════"
echo " Copia TODO este texto y pégalo en el chat."
echo " Con esto se diseña para lo que hay, sin suponer."
echo "═══════════════════════════════════════════════════"
