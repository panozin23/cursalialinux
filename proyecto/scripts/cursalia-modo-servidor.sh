#!/bin/bash
# cursalia-modo-servidor.sh — Convierte este equipo en el servidor del centro.
#
# Pensado para la máquina que aloja la máquina virtual con SALMI/SOAPS/SNIS
# y a la que se conectan los demás consultorios.
#
# Hace cuatro cosas:
#   1. Red en puente   — que el Windows tenga su propia dirección en la red,
#                        visible desde las otras computadoras
#   2. Arranque solo   — que el Windows se encienda con el equipo
#   3. Sin dormir      — que el equipo no se suspenda y deje a todos sin base
#   4. Puerta abierta  — que SSH siga permitido para administrarlo a distancia
#
# Uso:
#   bash cursalia-modo-servidor.sh              → solo mira e informa
#   sudo bash cursalia-modo-servidor.sh --aplicar
#
# Todo lo que cambia es reversible. Al final te dice cómo deshacerlo.
set -u

APLICAR=0
[ "${1:-}" = "--aplicar" ] && APLICAR=1

RESP="/var/backups/cursalialinux"
V=$'\033[0m'; AZ=$'\033[1;34m'; VE=$'\033[1;32m'; RO=$'\033[1;31m'; AM=$'\033[1;33m'

titulo(){ printf "\n${AZ}══════════════════════════════════════════════════════${V}\n"
          printf "${AZ} %s${V}\n" "$1"
          printf "${AZ}══════════════════════════════════════════════════════${V}\n"; }
ok(){   printf "   ${VE}✅${V} %s\n" "$1"; }
mal(){  printf "   ${RO}❌${V} %s\n" "$1"; }
avi(){  printf "   ${AM}⚠️ ${V} %s\n" "$1"; }
dato(){ printf "   %-26s %s\n" "$1" "$2"; }

titulo "MODO SERVIDOR — cursalialinux"
if [ "$APLICAR" = "1" ]; then
  printf "   Modo: ${RO}APLICANDO CAMBIOS${V}\n"
  [ "$(id -u)" != "0" ] && { mal "para aplicar hace falta sudo"; exit 1; }
else
  printf "   Modo: ${VE}solo mirar${V}  (no toca nada)\n"
fi
printf "   Equipo: %s        Fecha: %s\n" "$(hostname)" "$(date '+%d/%m/%Y %H:%M')"

VIRSH="virsh"
[ "$(id -u)" != "0" ] && VIRSH="sudo -n virsh"
$VIRSH list --all >/dev/null 2>&1 || VIRSH="virsh -c qemu:///system"

# ─────────────────────────────────────────────────────────────────────
titulo "1 · LA RED DE ESTE EQUIPO"

RUTA=$(ip route get 1.1.1.1 2>/dev/null | head -1)
IFAZ=$(echo "$RUTA" | grep -oP 'dev \K\S+')
MIIP=$(echo "$RUTA" | grep -oP 'src \K\S+')
PUER=$(echo "$RUTA" | grep -oP 'via \K\S+')

if [ -z "$IFAZ" ]; then
  mal "este equipo no tiene salida a la red"
  echo "      Conéctalo antes de seguir."
  exit 1
fi

dato "Tarjeta en uso:"    "$IFAZ"
dato "Dirección:"         "$MIIP"
dato "Router:"            "$PUER"

if [ -d "/sys/class/net/$IFAZ/wireless" ] || [ -e "/sys/class/net/$IFAZ/phy80211" ]; then
  ESWIFI=1
  avi "está por WIFI"
  echo "      La red en puente NO funciona por wifi: los puntos de acceso"
  echo "      rechazan el tráfico de la máquina virtual."
  echo
  echo "      ${AM}El servidor tiene que ir por cable.${V}"
  echo "      Los demás consultorios sí pueden ir por wifi, sin problema."
else
  ESWIFI=0
  ok "está por cable — sirve para servidor"
fi

RED=$(echo "$MIIP" | cut -d. -f1-3)
dato "Red del centro:"    "$RED.0"

# ─────────────────────────────────────────────────────────────────────
titulo "2 · LAS MÁQUINAS VIRTUALES"

MAQS=$($VIRSH list --all --name 2>/dev/null | grep -v '^$')
if [ -z "$MAQS" ]; then
  mal "no hay ninguna máquina virtual en este equipo"
  echo "      Créala antes con:  virt-crear-windows.sh"
  exit 1
fi

N=0
while read -r m; do
  [ -z "$m" ] && continue
  N=$((N+1))
  EST=$($VIRSH domstate "$m" 2>/dev/null)
  AUTO=$($VIRSH dominfo "$m" 2>/dev/null | grep -i 'Autostart\|Inicio auto' | awk '{print $NF}' | head -1)
  printf "   %d) %-16s estado: %-12s arranque solo: %s\n" "$N" "$m" "$EST" "${AUTO:-?}"
done <<< "$MAQS"

VM=$(echo "$MAQS" | head -1)
if [ "$N" -gt 1 ]; then
  VM="${VM_ELEGIDA:-$VM}"
  avi "hay varias — se trabajará con «$VM»"
  echo "      Para elegir otra:  VM_ELEGIDA=nombre sudo bash $0 --aplicar"
fi

echo
printf "   ${AZ}Máquina elegida: %s${V}\n" "$VM"

# ── Cómo está conectada ahora ──
XML=$($VIRSH dumpxml "$VM" 2>/dev/null)
TIPO=$(echo "$XML" | grep -oP "<interface type='\K[^']+" | head -1)
MAC=$(echo "$XML"  | grep -A4 '<interface' | grep -oP "mac address='\K[^']+" | head -1)
MODELO=$(echo "$XML" | grep -A6 '<interface' | grep -oP "model type='\K[^']+" | head -1)
FUENTE=$(echo "$XML" | grep -A4 '<interface' | grep -oP "(network|dev|bridge)='\K[^']+" | head -1)

echo
dato "Conexión actual:"  "${TIPO:-desconocida}  ($FUENTE)"
dato "Su dirección MAC:" "${MAC:-?}"
dato "Modelo de tarjeta:" "${MODELO:-e1000e}"

case "$TIPO" in
  direct)
    ok "YA está en red en puente — este paso no hace falta"
    PUENTE_HECHO=1 ;;
  bridge)
    ok "YA está en puente clásico — este paso no hace falta"
    PUENTE_HECHO=1 ;;
  *)
    PUENTE_HECHO=0
    avi "está en red privada — los otros consultorios NO la ven"
    echo
    echo "      Ahora:      otros equipos ──✖──  Windows (escondido)"
    echo "      Después:    otros equipos ──✅──  Windows ($RED.x)"
    ;;
esac

# ─────────────────────────────────────────────────────────────────────
titulo "3 · QUÉ SE VA A CAMBIAR"

CAMBIOS=0
pendiente(){ CAMBIOS=$((CAMBIOS+1)); printf "   ${AM}○${V} %s\n" "$1"; }
hecho(){ printf "   ${VE}●${V} %s\n" "$1"; }

# Red
if [ "$PUENTE_HECHO" = "1" ]; then hecho "Red en puente"
elif [ "$ESWIFI" = "1" ]; then     printf "   ${RO}✖${V} Red en puente — imposible por wifi, conecta el cable\n"
else                               pendiente "Red en puente sobre $IFAZ"; fi

# Autoarranque
AUTO=$($VIRSH dominfo "$VM" 2>/dev/null | grep -ci 'autostart:\s*enable\|autom')
if $VIRSH dominfo "$VM" 2>/dev/null | grep -qi 'autostart:\s*enable'; then
  hecho "Windows arranca solo con el equipo"; else
  pendiente "Que Windows arranque solo con el equipo"; fi

# libvirtd al arranque
if systemctl is-enabled libvirtd >/dev/null 2>&1; then
  hecho "El motor de virtualización arranca solo"; else
  pendiente "Que el motor de virtualización arranque solo"; fi

# Suspensión
if systemctl is-enabled sleep.target 2>/dev/null | grep -q masked; then
  hecho "El equipo no se duerme"; else
  pendiente "Impedir que el equipo se duerma"; fi

# SSH
if systemctl is-active ssh >/dev/null 2>&1 || systemctl is-active sshd >/dev/null 2>&1; then
  hecho "SSH encendido (administración a distancia)"; else
  pendiente "Encender SSH"; fi

if command -v ufw >/dev/null 2>&1 && ufw status 2>/dev/null | grep -q "^Status: active"; then
  if ufw status 2>/dev/null | grep -qi '22.*ALLOW\|ssh.*ALLOW'; then
    hecho "El cortafuegos deja pasar SSH"; else
    pendiente "Abrir SSH en el cortafuegos"; fi
fi

echo
if [ "$CAMBIOS" = "0" ]; then
  printf "   ${VE}Este equipo ya está en modo servidor. No hay nada que hacer.${V}\n"
  [ "$APLICAR" = "0" ] && exit 0
fi

if [ "$APLICAR" = "0" ]; then
  titulo "PARA APLICARLO"
  echo "   Ejecuta lo mismo añadiendo --aplicar:"
  echo
  printf "      ${AZ}sudo bash %s --aplicar${V}\n" "$0"
  echo
  echo "   Antes de tocar nada guarda una copia de la máquina virtual,"
  echo "   y al terminar te dice cómo deshacerlo."
  exit 0
fi

# ═════════════════════════════════════════════════════════════════════
#  APLICAR
# ═════════════════════════════════════════════════════════════════════
titulo "4 · APLICANDO"

mkdir -p "$RESP"
SELLO=$(date '+%Y%m%d-%H%M')
COPIA="$RESP/$VM-$SELLO.xml"
virsh dumpxml "$VM" > "$COPIA" 2>/dev/null && ok "copia guardada: $COPIA"

# ── 4.1 Red en puente (macvtap) ───────────────────────────────────────
if [ "$PUENTE_HECHO" = "0" ] && [ "$ESWIFI" = "0" ]; then
  echo
  printf "   ${AZ}Red en puente${V}\n"

  ESTADO=$(virsh domstate "$VM" 2>/dev/null)
  if [ "$ESTADO" = "running" ]; then
    mal "Windows está ENCENDIDO — este paso se salta"
    echo
    echo "      Cambiar la tarjeta con la máquina en marcha deja la"
    echo "      configuración a medias y cuesta más entenderla."
    echo
    echo "      ${AM}Apaga el Windows desde dentro (Inicio → Apagar)${V}"
    echo "      y vuelve a ejecutar este mismo comando."
    echo
    echo "      Lo demás sí se aplica ahora."
    SALTADA_RED=1
  else
    BLOQUE="/tmp/cursalia-iface-vieja.xml"
    NUEVA="/tmp/cursalia-iface-nueva.xml"
    virsh dumpxml "$VM" | awk '/<interface /,/<\/interface>/' > "$BLOQUE"

    cat > "$NUEVA" <<XML
<interface type='direct'>
  <mac address='${MAC}'/>
  <source dev='${IFAZ}' mode='bridge'/>
  <model type='${MODELO:-e1000e}'/>
</interface>
XML

    if virsh detach-device "$VM" "$BLOQUE" --config >/dev/null 2>&1; then
      ok "tarjeta anterior desconectada"
      if virsh attach-device "$VM" "$NUEVA" --config >/dev/null 2>&1; then
        ok "tarjeta en puente conectada sobre $IFAZ"
        ok "conserva su misma dirección MAC: $MAC"
      else
        mal "no se pudo conectar la tarjeta en puente"
        echo "      La máquina quedaría SIN RED. Restaurando la copia…"
        virsh define "$COPIA" >/dev/null 2>&1 \
          && ok "restaurada como estaba" \
          || mal "restaura a mano:  sudo virsh define $COPIA"
      fi
    else
      mal "no se pudo desconectar la tarjeta anterior"
      echo "      No se toca nada más de la red. La máquina sigue igual."
    fi
    rm -f "$BLOQUE" "$NUEVA"
  fi
fi

# ── 4.2 Que arranque solo ─────────────────────────────────────────────
echo
printf "   ${AZ}Arranque automático${V}\n"
systemctl enable libvirtd >/dev/null 2>&1 && ok "motor de virtualización activado al inicio"
systemctl start  libvirtd >/dev/null 2>&1
virsh autostart "$VM" >/dev/null 2>&1 && ok "«$VM» arrancará sola con el equipo"

# ── 4.3 Que no se duerma ──────────────────────────────────────────────
echo
printf "   ${AZ}Sin suspensión${V}\n"
systemctl mask sleep.target suspend.target hibernate.target \
               hybrid-sleep.target >/dev/null 2>&1 \
  && ok "el equipo ya no se suspenderá" \
  || avi "no se pudo bloquear la suspensión"

# Y que la pantalla apagada no arrastre al equipo (KDE guarda esto por usuario)
for h in /home/*; do
  u=$(basename "$h"); id "$u" >/dev/null 2>&1 || continue
  d="$h/.config"; [ -d "$d" ] || continue
  cat > "$d/powermanagementprofilesrc" <<'CFG'
[AC][SuspendSession]
idleTime=0
suspendType=0
CFG
  chown "$u:$u" "$d/powermanagementprofilesrc" 2>/dev/null
done
ok "ahorro de energía ajustado para todos los usuarios"

# ── 4.4 Administración a distancia ────────────────────────────────────
echo
printf "   ${AZ}Administración a distancia${V}\n"
systemctl enable --now ssh  >/dev/null 2>&1 || systemctl enable --now sshd >/dev/null 2>&1
systemctl is-active ssh >/dev/null 2>&1 || systemctl is-active sshd >/dev/null 2>&1 \
  && ok "SSH encendido" || avi "revisa SSH a mano"

if command -v ufw >/dev/null 2>&1 && ufw status 2>/dev/null | grep -q "^Status: active"; then
  ufw allow from "$RED.0/24" to any port 22 proto tcp >/dev/null 2>&1 \
    && ok "SSH permitido desde la red del centro ($RED.0/24)"
fi

# ─────────────────────────────────────────────────────────────────────
titulo "✅ LISTO — QUÉ HACER AHORA"

cat <<FIN

   ${AZ}Paso 1 · Reinicia el Windows${V}
   Si estaba encendido, apágalo y vuelve a encenderlo. La tarjeta
   nueva solo entra al arrancar.

   ${AZ}Paso 2 · Ponle dirección fija dentro de Windows${V}
   Un servidor no puede cambiar de número. Dentro del Windows:

      Configuración → Red e Internet → Ethernet
      Asignación de IP → Editar → Manual → IPv4 activado

      Dirección IP        $RED.50
      Máscara             255.255.255.0
      Puerta de enlace    $PUER
      DNS                 $PUER

   Elige un número alto (.50, .60) para que el router no se lo dé a otro.

   ${AZ}Paso 3 · Comprueba que se ve desde fuera${V}
   Desde tu portátil, en la terminal:

      ping -c3 $RED.50

   Si responde, los demás consultorios ya pueden conectarse a SALMI.

   ${AZ}Paso 4 · Instala SALMI como servidor${V}
   Dentro de este Windows. Cuando pregunte la dirección del servidor,
   los clientes pondrán:  $RED.50

   ─────────────────────────────────────────────────────

   ${AM}Para deshacer todo:${V}

      sudo virsh define $COPIA
      sudo virsh autostart --disable $VM
      sudo systemctl unmask sleep.target suspend.target \\
                            hibernate.target hybrid-sleep.target

FIN
