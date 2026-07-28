#!/bin/bash
# virt-inspeccionar.sh — SOLO LECTURA. No instala, no modifica, no descarga nada.
# Revisa si este equipo puede correr Windows dentro de cursalialinux con KVM.
# Uso:  bash virt-inspeccionar.sh      (NO necesita sudo)
set -u

INFORME=/tmp/informe-virtualizacion.txt
PAQUETES="qemu-system-x86 qemu-utils libvirt-daemon-system libvirt-clients \
virt-manager swtpm swtpm-tools ovmf bridge-utils dnsmasq-base virtiofsd spice-vdagent"

exec > >(tee "$INFORME") 2>&1

echo "══════════════════════════════════════════════"
echo " INFORME VIRTUALIZACIÓN — $(date '+%Y-%m-%d %H:%M')"
echo "══════════════════════════════════════════════"
echo " Este script SOLO MIRA. No cambia nada."

# Contadores del veredicto final
FALLOS=0
AVISOS=0

echo
echo "── 1. Qué sistema es este ──"
grep -E '^(NAME|VERSION|PRETTY_NAME)=' /etc/os-release 2>/dev/null || echo "(sin os-release)"
echo "  Núcleo: $(uname -r)"

echo
echo "── 2. Procesador y virtualización por hardware ──"
grep -m1 'model name' /proc/cpuinfo | cut -d: -f2- | sed 's/^ */  Modelo:/'
echo "  Hilos disponibles: $(nproc)"
if grep -qm1 ' svm ' /proc/cpuinfo; then
  echo "  ✅ AMD-V (svm) presente y activo en la BIOS"
  MARCA=AMD
elif grep -qm1 ' vmx ' /proc/cpuinfo; then
  echo "  ✅ Intel VT-x (vmx) presente y activo en la BIOS"
  MARCA=INTEL
else
  echo "  ❌ Sin virtualización por hardware."
  echo "     O el procesador no la tiene, o está DESACTIVADA en la BIOS."
  echo "     Busca en la BIOS: 'SVM Mode' (AMD) o 'Intel VT-x' y actívala."
  MARCA=NINGUNA
  FALLOS=$((FALLOS+1))
fi

echo
echo "── 3. El dispositivo /dev/kvm ──"
if [ -e /dev/kvm ]; then
  ls -l /dev/kvm
  if [ -r /dev/kvm ] && [ -w /dev/kvm ]; then
    echo "  ✅ existe y tu usuario puede usarlo"
  else
    echo "  ⚠️  existe pero tu usuario AÚN no tiene permiso (falta el grupo kvm)"
    echo "     Lo arregla el script de instalación."
    AVISOS=$((AVISOS+1))
  fi
else
  echo "  ❌ /dev/kvm NO existe. El módulo del núcleo no está cargado."
  FALLOS=$((FALLOS+1))
fi

echo
echo "── 4. Módulos del núcleo cargados ──"
lsmod | grep -E '^(kvm|kvm_amd|kvm_intel)' || echo "  (ninguno cargado)"

echo
echo "── 5. Memoria RAM ──"
free -h | head -2
RAM_MB=$(free -m | awk '/^Mem:/{print $2}')
echo "  Total detectado: ${RAM_MB} MB"
if   [ "$RAM_MB" -ge 12000 ]; then echo "  ✅ de sobra: puedes dar 6-8 GB a la máquina virtual"
elif [ "$RAM_MB" -ge  8000 ]; then echo "  ✅ suficiente: dale 4 GB a la máquina virtual"
else echo "  ⚠️  justo. Windows 11 pide 4 GB y te quedaría poco para cursalialinux."
     AVISOS=$((AVISOS+1)); fi

echo
echo "── 6. Espacio en disco ──"
df -h / /home /var/lib/libvirt 2>/dev/null | sort -u
LIBRE_GB=$(df -BG --output=avail /var/lib 2>/dev/null | tail -1 | tr -dc '0-9')
LIBRE_GB=${LIBRE_GB:-0}
echo "  Libre donde viven las máquinas virtuales: ${LIBRE_GB} GB"
if   [ "$LIBRE_GB" -ge 100 ]; then echo "  ✅ cómodo (Windows + Office + tus programas caben)"
elif [ "$LIBRE_GB" -ge  70 ]; then echo "  ✅ alcanza, sin lujos"
else echo "  ⚠️  poco. Windows 11 pide 64 GB de disco virtual, más Office."
     AVISOS=$((AVISOS+1)); fi

echo
echo "── 7. Chip TPM de este equipo (informativo) ──"
if ls /dev/tpm* >/dev/null 2>&1; then
  ls -l /dev/tpm* 2>/dev/null
  echo "  ✅ el equipo tiene TPM propio (fTPM activado en la BIOS)"
else
  echo "  (sin /dev/tpm — el fTPM está apagado en la BIOS, o no lo tiene)"
  echo "  NO IMPORTA: la máquina virtual usará un TPM 2.0 emulado por"
  echo "  software (swtpm). Ese es justamente el truco del método."
fi

echo
echo "── 8. Paquetes de virtualización ──"
FALTAN=""
for p in $PAQUETES; do
  if dpkg-query -W -f='${Status}' "$p" 2>/dev/null | grep -q "install ok installed"; then
    printf '  ✅ %-24s %s\n' "$p" "$(dpkg-query -W -f='${Version}' "$p" 2>/dev/null)"
  else
    printf '  ▫️  %-24s (falta)\n' "$p"
    FALTAN="$FALTAN $p"
  fi
done
if [ -n "$FALTAN" ]; then
  echo
  echo "  Faltan por instalar:$FALTAN"
else
  echo
  echo "  ✅ están todos"
fi

echo
echo "── 9. Servicio libvirtd ──"
if systemctl list-unit-files 2>/dev/null | grep -q '^libvirtd.service'; then
  echo "  Instalado.  Activo: $(systemctl is-active libvirtd 2>/dev/null)  ·  Arranque: $(systemctl is-enabled libvirtd 2>/dev/null)"
else
  echo "  (aún no instalado — llega con libvirt-daemon-system)"
fi

echo
echo "── 10. Tus grupos ──"
echo "  Usuario: $(id -un)"
echo "  Grupos:  $(id -nG)"
for g in kvm libvirt; do
  if id -nG | tr ' ' '\n' | grep -qx "$g"; then
    echo "  ✅ perteneces al grupo '$g'"
  else
    echo "  ▫️  te falta el grupo '$g' (lo añade el script de instalación)"
  fi
done

echo
echo "── 11. Escritorio y sesión gráfica ──"
echo "  Sesión: ${XDG_SESSION_TYPE:-desconocida}   Escritorio: ${XDG_CURRENT_DESKTOP:-desconocido}"
if [ "${XDG_SESSION_TYPE:-}" = "wayland" ]; then
  echo "  Nota: en Wayland virt-manager funciona bien para trabajo de oficina."
  echo "  Los límites aparecen solo con juegos o gráficos 3D pesados."
fi

echo
echo "── 12. Conexión a internet (para descargar Windows y los drivers) ──"
if ping -c1 -W3 deb.debian.org >/dev/null 2>&1; then
  echo "  ✅ hay conexión"
else
  echo "  ⚠️  sin respuesta de deb.debian.org — revisa la red antes de instalar"
  AVISOS=$((AVISOS+1))
fi

echo
echo "══════════════════════════════════════════════"
echo " VEREDICTO"
echo "══════════════════════════════════════════════"
if [ "$FALLOS" -gt 0 ]; then
  echo " ❌ NO se puede continuar todavía: $FALLOS problema(s) de fondo."
  echo "    Revisa arriba las líneas con ❌ antes de seguir."
elif [ "$AVISOS" -gt 0 ]; then
  echo " ✅ Este equipo SÍ puede virtualizar Windows."
  echo "    Hay $AVISOS aviso(s) menores señalados con ⚠️ — léelos, pero"
  echo "    ninguno impide continuar."
else
  echo " ✅ Todo en orden. Este equipo puede virtualizar Windows sin problemas."
fi
echo
echo " Marca del procesador: $MARCA"
if [ "$MARCA" = "AMD" ]; then
  echo " ⚠️  IMPORTANTE PARA AMD: al crear la máquina virtual hay que QUITAR"
  echo "     la línea  <evmcs state=\"on\"/>  del XML de Hyper-V."
  echo "     Si se deja, la máquina virtual no arranca. Está en la guía."
fi
echo
echo " Informe guardado en: $INFORME"
echo " NADA fue modificado."
echo "══════════════════════════════════════════════"
