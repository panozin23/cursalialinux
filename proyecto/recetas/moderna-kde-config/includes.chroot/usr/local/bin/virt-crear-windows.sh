#!/bin/bash
# virt-crear-windows.sh — Crea una máquina virtual de Windows ya configurada.
# Soporta Windows 7, 8.1, 10 y 11: cada versión necesita ajustes distintos y
# el script los aplica solos.
#
# Uso interactivo (recomendado):
#     sudo bash virt-crear-windows.sh
#
# Uso directo:
#     sudo bash virt-crear-windows.sh --version 11 \
#          --iso /var/lib/libvirt/images/Win11.iso --nombre Windows11-Salud
#
# Qué hace:  crea el disco virtual y DEFINE la máquina (no la enciende).
# Qué NO hace: no la arranca, no instala Windows, no toca tus particiones,
#            no borra nada. Si la máquina ya existe, se detiene sin tocarla.
#
# ⚠️  LICENCIAS: este script solo prepara el hardware virtual. Usar Windows
#     requiere una licencia válida de Microsoft, y conseguirla es
#     responsabilidad tuya. Lee documentacion/LICENCIAS-Y-RESPONSABILIDAD.md
set -u

REGISTRO=/tmp/registro-virt-crear.txt
IMG=/var/lib/libvirt/images
VIRTIO=""          # se detecta abajo

VERSION=""
ISO_WIN=""
NOMBRE=""

# ── Argumentos ───────────────────────────────────────────────────────
while [ $# -gt 0 ]; do
  case "$1" in
    --version) VERSION="${2:-}"; shift 2 ;;
    --iso)     ISO_WIN="${2:-}";  shift 2 ;;
    --nombre)  NOMBRE="${2:-}";   shift 2 ;;
    --ayuda|-h) sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Opción desconocida: $1  (usa --ayuda)"; exit 1 ;;
  esac
done

exec > >(tee "$REGISTRO") 2>&1

echo "══════════════════════════════════════════════"
echo " CREAR MÁQUINA VIRTUAL DE WINDOWS — $(date '+%Y-%m-%d %H:%M')"
echo "══════════════════════════════════════════════"

if [ "$(id -u)" -ne 0 ]; then
  echo "ERROR: ejecutar con sudo."
  echo "  sudo bash virt-crear-windows.sh"
  exit 1
fi

# ── Localizar el CD de drivers VirtIO ────────────────────────────────
for f in "$IMG"/virtio-win*.iso; do
  [ -r "$f" ] && VIRTIO="$f"
done
if [ -z "$VIRTIO" ]; then
  echo "ERROR: no encuentro ningún virtio-win*.iso en $IMG"
  echo "  Descárgalo de:"
  echo "  https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso"
  exit 1
fi

# ── Elegir versión ───────────────────────────────────────────────────
if [ -z "$VERSION" ]; then
  echo
  echo "── ¿Qué versión de Windows vas a instalar? ──"
  echo
  echo "   7    Windows 7        (BIOS antiguo, sin TPM)"
  echo "   8    Windows 8.1      (UEFI, sin TPM)"
  echo "   10   Windows 10       (UEFI + TPM)"
  echo "   11   Windows 11       (UEFI + Arranque Seguro + TPM obligatorio)"
  echo
  printf "Escribe el número y pulsa Enter: "
  read -r VERSION
fi

# Normalizar (8.1 → 8)
case "$VERSION" in
  8.1) VERSION=8 ;;
esac

# ── Perfil de cada versión ───────────────────────────────────────────
# Cada Windows necesita un hardware virtual distinto. Estos son los
# ajustes probados que funcionan para cada uno.
case "$VERSION" in
  7)
    ETIQUETA="Windows 7"
    OSINFO="win7"
    MAQUINA_TIPO="pc"            # i440FX: el chipset que Windows 7 conoce
    FIRMWARE="bios"              # UEFI en Windows 7 es problemático
    TPM="no"
    RAM_MB=4096
    DISCO_GB=40
    USB="ehci"                   # Windows 7 no trae driver de USB 3
    DRIVERS="w7"
    SOPORTE="Sin actualizaciones desde enero de 2020"
    ;;
  8)
    ETIQUETA="Windows 8.1"
    OSINFO="win8.1"
    MAQUINA_TIPO="q35"
    FIRMWARE="uefi"              # sin Arranque Seguro
    TPM="no"
    RAM_MB=4096
    DISCO_GB=40
    USB="qemu-xhci"
    DRIVERS="w8.1"
    SOPORTE="Sin actualizaciones desde enero de 2023"
    ;;
  10)
    ETIQUETA="Windows 10"
    OSINFO="win10"
    MAQUINA_TIPO="q35"
    FIRMWARE="uefi"
    TPM="si"
    RAM_MB=4096
    DISCO_GB=64
    USB="qemu-xhci"
    DRIVERS="w10"
    SOPORTE="Sin actualizaciones desde octubre de 2025"
    ;;
  11)
    ETIQUETA="Windows 11"
    OSINFO="win11"
    MAQUINA_TIPO="q35"
    FIRMWARE="uefi-secure"       # con Arranque Seguro y claves de Microsoft
    TPM="si"
    RAM_MB=6144
    DISCO_GB=80
    USB="qemu-xhci"
    DRIVERS="w11"
    SOPORTE="Con soporte actual de Microsoft"
    ;;
  *)
    echo "ERROR: versión no reconocida: «$VERSION»"
    echo "  Válidas: 7, 8, 10, 11"
    exit 1
    ;;
esac

# ── Elegir el ISO ────────────────────────────────────────────────────
if [ -z "$ISO_WIN" ]; then
  echo
  echo "── ISOs disponibles en $IMG ──"
  echo
  N=0
  CANDIDATOS=()
  for f in "$IMG"/*.iso; do
    [ -r "$f" ] || continue
    case "$(basename "$f")" in virtio-win*) continue ;; esac
    N=$((N+1)); CANDIDATOS+=("$f")
    printf "   %d)  %-46s %s\n" "$N" "$(basename "$f")" "$(du -h "$f" | cut -f1)"
  done
  if [ "$N" -eq 0 ]; then
    echo "  (ninguno)"
    echo
    echo "ERROR: no hay ISOs de Windows en $IMG"
    echo "  Descarga el tuyo y muévelo ahí. Recuerda: necesitas una licencia."
    exit 1
  fi
  echo
  printf "Escribe el número del ISO y pulsa Enter: "
  read -r ELEGIDO
  ISO_WIN="${CANDIDATOS[$((ELEGIDO-1))]:-}"
fi

[ -r "$ISO_WIN" ] || { echo "ERROR: no puedo leer «$ISO_WIN»"; exit 1; }

# ── Nombre ───────────────────────────────────────────────────────────
if [ -z "$NOMBRE" ]; then
  echo
  printf "Nombre para la máquina [Windows%s]: " "$VERSION"
  read -r NOMBRE
  NOMBRE="${NOMBRE:-Windows$VERSION}"
fi
NOMBRE=$(echo "$NOMBRE" | tr -c 'A-Za-z0-9._-' '-' | sed 's/-*$//')
DISCO="$IMG/$(echo "$NOMBRE" | tr 'A-Z' 'a-z').qcow2"
XML="/tmp/${NOMBRE}.xml"

# ── Comprobaciones previas ───────────────────────────────────────────
echo
echo "── Comprobaciones previas ──"
echo "  ✅ ISO de Windows: $(basename "$ISO_WIN")  ($(du -h "$ISO_WIN" | cut -f1))"
echo "  ✅ CD de drivers:  $(basename "$VIRTIO")   ($(du -h "$VIRTIO" | cut -f1))"

if virsh -c qemu:///system dominfo "$NOMBRE" >/dev/null 2>&1; then
  echo "  ❌ Ya existe una máquina llamada «$NOMBRE»."
  echo "     Para rehacerla desde cero, bórrala así (en dos pasos):"
  echo "       sudo virsh undefine $NOMBRE --nvram"
  echo "       sudo rm -f $DISCO"
  echo
  echo "     ⚠️  NUNCA uses --remove-all-storage: borra TAMBIÉN los ISOs,"
  echo "         porque para libvirt los CDs conectados cuentan como discos."
  exit 1
fi
echo "  ✅ el nombre «$NOMBRE» está libre"

if [ -e "$DISCO" ]; then
  echo "  ❌ Ya existe el disco $DISCO — no lo sobrescribo."
  exit 1
fi
echo "  ✅ el disco no existe todavía"

LIBRE_GB=$(df -BG --output=avail "$IMG" | tail -1 | tr -dc '0-9')
echo "  Espacio libre: ${LIBRE_GB} GB (el disco crece según se use)"

# ── Resumen ──────────────────────────────────────────────────────────
echo
echo "── Lo que voy a crear ──"
echo
echo "  Sistema ............. $ETIQUETA"
echo "  Nombre .............. $NOMBRE"
echo "  Memoria ............. $RAM_MB MB"
echo "  Procesadores ........ 4  (modo host-passthrough)"
echo "  Chipset ............. $MAQUINA_TIPO"
case "$FIRMWARE" in
  bios)        echo "  Firmware ............ BIOS antiguo (lo que Windows 7 espera)" ;;
  uefi)        echo "  Firmware ............ UEFI sin Arranque Seguro" ;;
  uefi-secure) echo "  Firmware ............ UEFI con Arranque Seguro y claves de Microsoft" ;;
esac
[ "$TPM" = "si" ] && echo "  TPM ................. 2.0 emulado, modelo CRB" \
                  || echo "  TPM ................. ninguno (esta versión no lo pide)"
echo "  Disco ............... ${DISCO_GB} GB qcow2, bus VirtIO"
echo "  Red ................. VirtIO en la red «default»"
echo "  Controlador USB ..... $USB"
echo "  Drivers a cargar .... viostor\\$DRIVERS\\amd64  y  NetKVM\\$DRIVERS\\amd64"
echo
echo "  ── Soporte de Microsoft ──"
echo "  $SOPORTE"
if [ "$VERSION" != "11" ]; then
  echo
  echo "  ⚠️  Este Windows YA NO RECIBE PARCHES DE SEGURIDAD."
  echo "     Úsalo solo para el programa concreto que lo necesita, y"
  echo "     considera dejarlo SIN INTERNET. Ver la nota al final."
fi
echo
echo "  ⚠️  LICENCIA: necesitas una licencia válida de Microsoft para usar"
echo "     Windows. Este script solo prepara el hardware virtual."
echo

printf "Para continuar escribe exactamente  CREAR  y pulsa Enter: "
read -r RESPUESTA
if [ "$RESPUESTA" != "CREAR" ]; then
  echo
  echo "Cancelado. No se creó nada."
  exit 0
fi

# ── 1. Disco virtual ─────────────────────────────────────────────────
echo
echo "── 1. Creando el disco virtual ──"
qemu-img create -f qcow2 "$DISCO" "${DISCO_GB}G" || { echo "ERROR al crear el disco."; exit 1; }
chown libvirt-qemu:kvm "$DISCO" 2>/dev/null || true
chmod 660 "$DISCO"
ls -lh "$DISCO"

# ── 2. Construir los argumentos según la versión ─────────────────────
echo
echo "── 2. Generando la configuración para $ETIQUETA ──"

ARGS=(
  --connect qemu:///system --dry-run --print-xml 1
  --name "$NOMBRE"
  --osinfo "$OSINFO"
  --memory "$RAM_MB"
  --vcpus 4
  --cpu host-passthrough
  --machine "$MAQUINA_TIPO"
  --disk "path=$DISCO,format=qcow2,bus=virtio,cache=writeback,discard=unmap"
  --disk "device=cdrom,path=$ISO_WIN,boot.order=1"
  --disk "device=cdrom,path=$VIRTIO"
  --network network=default,model=virtio
  --controller "type=usb,model=$USB"
  --channel unix,target.type=virtio,target.name=org.qemu.guest_agent.0
  --graphics spice
  --video qxl
  --sound none
  --noautoconsole
)

# Firmware
case "$FIRMWARE" in
  uefi)
    ARGS+=( --boot firmware=efi )
    ;;
  uefi-secure)
    ARGS+=( --boot "firmware=efi,firmware.feature0.name=enrolled-keys,firmware.feature0.enabled=yes,firmware.feature1.name=secure-boot,firmware.feature1.enabled=yes" )
    ;;
  # bios: no se pasa nada, virt-install usa BIOS por defecto
esac

# Mejoras Hyper-V. Se listan una a una a propósito: así NUNCA entra
# <evmcs>, que es la función que impide arrancar en procesadores AMD.
FEATURES="hyperv.relaxed.state=on,hyperv.vapic.state=on,hyperv.spinlocks.state=on,hyperv.spinlocks.retries=8191"
[ "$FIRMWARE" = "uefi-secure" ] && FEATURES="smm.state=on,$FEATURES"
ARGS+=( --features "$FEATURES" )

# TPM
[ "$TPM" = "si" ] && ARGS+=( --tpm backend.type=emulator,backend.version=2.0,model=tpm-crb )

if ! virt-install "${ARGS[@]}" > "$XML"; then
  echo "ERROR: virt-install no pudo generar la configuración."
  echo "  Borrando el disco creado para no dejar basura..."
  rm -f "$DISCO"
  exit 1
fi
echo "  ✅ configuración escrita en $XML"

# ── 3. Verificar antes de definir ────────────────────────────────────
echo
echo "  Comprobando que NO se coló la línea que rompe los AMD:"
if grep -q evmcs "$XML"; then
  echo "  ❌ apareció <evmcs>. NO definas esta máquina."
  rm -f "$DISCO"; exit 1
fi
echo "  ✅ sin <evmcs>"

echo "  Comprobando las piezas clave:"
grep -q "machine=\"$MAQUINA_TIPO\""      "$XML" && echo "    ✅ chipset $MAQUINA_TIPO"
grep -q 'mode="host-passthrough"'        "$XML" && echo "    ✅ CPU host-passthrough"
grep -q 'bus="virtio"'                   "$XML" && echo "    ✅ disco VirtIO"
grep -q 'org.qemu.guest_agent.0'         "$XML" && echo "    ✅ canal del agente invitado"
if [ "$FIRMWARE" != "bios" ]; then
  grep -q 'firmware="efi"'               "$XML" && echo "    ✅ firmware UEFI"
fi
if [ "$FIRMWARE" = "uefi-secure" ]; then
  grep -q 'name="secure-boot"'           "$XML" && echo "    ✅ Arranque Seguro"
  grep -q 'name="enrolled-keys"'         "$XML" && echo "    ✅ claves de Microsoft"
fi
if [ "$TPM" = "si" ]; then
  grep -q 'model="tpm-crb"'              "$XML" && echo "    ✅ TPM 2.0 modelo CRB"
fi

# ── 4. Definir ───────────────────────────────────────────────────────
echo
echo "── 3. Definiendo la máquina en libvirt ──"
virsh -c qemu:///system define "$XML" || { echo "ERROR al definir. El disco queda en $DISCO"; exit 1; }

echo
virsh -c qemu:///system list --all

echo
echo "══════════════════════════════════════════════"
echo " LISTA — pero APAGADA, a propósito"
echo "══════════════════════════════════════════════"
echo
echo " Abre «Gestor de máquinas virtuales», haz DOBLE CLIC en «$NOMBRE»"
echo " para ver su pantalla, y SOLO ENTONCES pulsa ▶ para encender."
echo " Así no se te pasa el aviso «Press any key to boot from CD»,"
echo " que dura unos 5 segundos."
echo
echo " Durante la instalación, la pantalla de discos saldrá VACÍA."
echo " Es normal. Pulsa «Cargar controlador» y busca en el segundo CD:"
echo "     viostor\\$DRIVERS\\amd64     → aparecerá el disco de ${DISCO_GB} GB"
echo "     NetKVM\\$DRIVERS\\amd64      → para la tarjeta de red"
echo
if [ "$VERSION" != "11" ]; then
  echo " ⚠️  $ETIQUETA ya no recibe parches de seguridad."
  echo "     Si solo lo usas para un programa concreto, conviene dejarlo"
  echo "     SIN INTERNET. Primero averigua su dirección MAC:"
  echo "       sudo virsh domiflist $NOMBRE"
  echo "     Y con esa MAC, cortar o devolver la red en caliente:"
  echo "       sudo virsh domif-setlink $NOMBRE LA:MAC:DE:ARRI:BA down"
  echo "       sudo virsh domif-setlink $NOMBRE LA:MAC:DE:ARRI:BA up"
  echo
  echo "     (Usa la MAC, NO 'vnet0': ese nombre se asigna al arrancar,"
  echo "      cambia según las máquinas encendidas y no existe si está"
  echo "      apagada. La MAC es fija.)"
  echo
  echo "     Para pasarle archivos sin red, crea un CD desde una carpeta:"
  echo "       genisoimage -J -r -V DATOS -o $IMG/datos.iso ~/mi-carpeta/"
  echo "     y añádelo como CDROM desde el Gestor."
  echo
fi
echo " Más detalles en:"
echo "   documentacion/GUIA-WINDOWS-EN-CURSALIALINUX.md"
echo "   documentacion/LICENCIAS-Y-RESPONSABILIDAD.md"
echo
echo " Registro guardado en: $REGISTRO"
echo "══════════════════════════════════════════════"
