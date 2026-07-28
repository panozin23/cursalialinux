#!/bin/bash
# virt-instalar.sh — SEGUNDO PASO. Instala el conjunto de virtualización KVM.
# Ejecutar SOLO después de haber leído el informe de virt-inspeccionar.sh.
# Uso:  sudo bash virt-instalar.sh
#
# Qué hace:  instala 12 paquetes de Debian, mete a tu usuario en los grupos
#            'kvm' y 'libvirt', enciende el servicio libvirtd y levanta la
#            red virtual por defecto.
# Qué NO hace: no toca particiones, no borra nada, no descarga Windows,
#            no crea ninguna máquina virtual.
set -u

REGISTRO=/tmp/registro-virt-instalar.txt
PAQUETES="qemu-system-x86 qemu-utils libvirt-daemon-system libvirt-clients \
virt-manager swtpm swtpm-tools ovmf bridge-utils dnsmasq-base virtiofsd spice-vdagent"

exec > >(tee "$REGISTRO") 2>&1

echo "══════════════════════════════════════════════"
echo " INSTALAR VIRTUALIZACIÓN — $(date '+%Y-%m-%d %H:%M')"
echo "══════════════════════════════════════════════"

if [ "$(id -u)" -ne 0 ]; then
  echo "ERROR: ejecutar con sudo."
  echo "  sudo bash virt-instalar.sh"
  exit 1
fi

# ── A quién hay que meter en los grupos ──────────────────────────────
USUARIO="${SUDO_USER:-}"
if [ -z "$USUARIO" ] || [ "$USUARIO" = "root" ]; then
  echo "ERROR: no puedo saber tu usuario normal."
  echo "  Ejecuta con 'sudo bash ...' desde tu sesión, no como root directo."
  exit 1
fi

echo
echo "── Lo que voy a hacer ──"
echo
echo "  1. apt update"
echo "  2. Instalar estos 12 paquetes:"
for p in $PAQUETES; do echo "       · $p"; done
echo "  3. Añadir al usuario '$USUARIO' a los grupos: kvm, libvirt"
echo "  4. Activar el servicio libvirtd (arranque automático)"
echo "  5. Levantar la red virtual 'default'"
echo
echo "  Descarga aproximada: 250-400 MB"
echo "  NO se borra nada. NO se tocan particiones."
echo

# ── Confirmación escrita ─────────────────────────────────────────────
printf "Para continuar escribe exactamente  INSTALAR  y pulsa Enter: "
read -r RESPUESTA
if [ "$RESPUESTA" != "INSTALAR" ]; then
  echo
  echo "Cancelado. No se hizo ningún cambio."
  exit 0
fi

echo
echo "── 1. Actualizando la lista de paquetes ──"
if ! apt update; then
  echo "ERROR: falló 'apt update'. Revisa tu conexión y vuelve a intentar."
  exit 1
fi

echo
echo "── 2. Instalando los paquetes ──"
if ! DEBIAN_FRONTEND=noninteractive apt install -y $PAQUETES; then
  echo "ERROR: falló la instalación. Nada más se ha cambiado."
  exit 1
fi

echo
echo "── 3. Añadiendo a '$USUARIO' a los grupos kvm y libvirt ──"
for g in kvm libvirt; do
  if getent group "$g" >/dev/null; then
    usermod -aG "$g" "$USUARIO" && echo "  ✅ $USUARIO añadido a '$g'"
  else
    echo "  ⚠️  el grupo '$g' no existe (raro) — se omite"
  fi
done

echo
echo "── 4. Activando el servicio libvirtd ──"
if systemctl list-unit-files | grep -q '^libvirtd.service'; then
  systemctl enable --now libvirtd
  echo "  Estado: $(systemctl is-active libvirtd)  ·  Arranque: $(systemctl is-enabled libvirtd)"
else
  echo "  ⚠️  no encuentro libvirtd.service; probando los servicios modulares"
  systemctl enable --now virtqemud.socket 2>/dev/null && echo "  virtqemud.socket activado" \
    || echo "  ⚠️  no se pudo activar ningún servicio de libvirt"
fi

echo
echo "── 5. Levantando la red virtual 'default' ──"
sleep 2
virsh net-start    default 2>/dev/null && echo "  ✅ red 'default' iniciada" \
  || echo "  (ya estaba iniciada, o aún no disponible)"
virsh net-autostart default 2>/dev/null && echo "  ✅ arrancará sola en cada inicio" \
  || echo "  (no se pudo marcar el arranque automático)"
echo
virsh net-list --all 2>/dev/null || true

echo
echo "── 6. Comprobación final ──"
[ -e /dev/kvm ] && echo "  ✅ /dev/kvm presente" || echo "  ❌ /dev/kvm ausente"
command -v virt-manager >/dev/null && echo "  ✅ virt-manager instalado"
command -v swtpm        >/dev/null && echo "  ✅ swtpm (TPM 2.0 emulado) instalado"
[ -f /usr/share/OVMF/OVMF_CODE_4M.secboot.fd ] || [ -f /usr/share/OVMF/OVMF_CODE.secboot.fd ] \
  && echo "  ✅ OVMF con Arranque Seguro presente" \
  || echo "  ⚠️  no encuentro el OVMF con Secure Boot — revisa el paquete ovmf"

echo
echo "══════════════════════════════════════════════"
echo " LISTO"
echo "══════════════════════════════════════════════"
echo
echo " ⚠️  IMPORTANTE: CIERRA LA SESIÓN Y VUELVE A ENTRAR."
echo "     Los grupos nuevos (kvm, libvirt) no se aplican hasta entonces."
echo "     Si no lo haces, virt-manager dará errores de permisos."
echo
echo " Después abre:  Gestor de máquinas virtuales  (virt-manager)"
echo
echo " Siguiente paso — descargar lo que hace falta:"
echo "   · Windows 11 ISO ....... microsoft.com/software-download/windows11"
echo "   · Drivers VirtIO ....... el archivo virtio-win.iso (versión estable)"
echo "     https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/"
echo
echo " Y sigue la hoja de configuración:"
echo "   documentacion/GUIA-WINDOWS-EN-CURSALIALINUX.md"
echo
echo " Registro guardado en: $REGISTRO"
echo "══════════════════════════════════════════════"
