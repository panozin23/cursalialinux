#!/bin/bash

# yad en Wayland avisa "gdk_x11_window_get_xid: assertion failed" porque pide
# un identificador de ventana de X11 que ahí no existe. No rompe nada, pero
# ensucia la terminal. Pasando por XWayland la llamada es válida y calla.
export GDK_BACKEND=x11
# cursalia-windows-control.sh — Panel de control de una máquina virtual Windows.
#
# Botones para lo que se usa a diario y que en virt-manager está escondido:
#   · Cortar o dar internet, en caliente
#   · Pasarle archivos con un CD virtual
#   · Instantáneas: tomar una y volver atrás
#
# Uso:  bash cursalia-windows-control.sh [nombre-de-la-maquina]
#       Si no das nombre, te deja elegir entre las que tengas.
#
# No necesita sudo: basta con pertenecer al grupo 'libvirt'.
set -u

URI="qemu:///system"
COMPARTIDO=/var/lib/libvirt/images/compartido

# El logo se busca primero donde vive en la distro, y si no, en el proyecto.
# Así el mismo archivo sirve en los dos sitios sin editarlo.
for cand in /usr/share/pixmaps/cursalialinux.png \
            "$HOME/PROYECTOS-CURSALIA/cursalialinux/marca/logo-256.png"; do
  [ -f "$cand" ] && { LOGO="$cand"; break; }
done
LOGO="${LOGO:-computer}"

SELF="$(readlink -f "$0")"
MAQUINA="${1:-}"

# ── Utilidades ───────────────────────────────────────────────────────
aviso()  { yad --class=cursaliawin --title="Windows" --center --width=430 \
              --window-icon="$LOGO" --image="${2:-dialog-information}" \
              --text="$1" --button="Entendido:0" 2>/dev/null; }

pregunta(){ yad --class=cursaliawin --title="Windows" --center --width=430 \
              --window-icon="$LOGO" --image=dialog-question \
              --text="$1" --button="Cancelar:1" --button="Sí, adelante:0" 2>/dev/null; }

solo_una(){ pkill -f "class=cursaliawin" 2>/dev/null; sleep 0.15; }

vsh(){ virsh -c "$URI" "$@" 2>/dev/null; }

# ── Elegir máquina ───────────────────────────────────────────────────
if [ -z "$MAQUINA" ]; then
  MAQUINAS=$(vsh list --all --name | grep -v '^$')
  CUANTAS=$(echo "$MAQUINAS" | grep -c . )
  if [ "$CUANTAS" -eq 0 ]; then
    aviso "No hay ninguna máquina virtual creada.\n\nCrea una primero con el script <b>virt-crear-windows.sh</b>" dialog-warning
    exit 1
  elif [ "$CUANTAS" -eq 1 ]; then
    MAQUINA="$MAQUINAS"
  else
    MAQUINA=$(echo "$MAQUINAS" | yad --class=cursaliawin --list --title="Elige la máquina" \
      --center --width=420 --height=280 --window-icon="$LOGO" \
      --column="Máquina virtual" --button="Cancelar:1" --button="Abrir:0" 2>/dev/null | cut -d'|' -f1)
    [ -z "$MAQUINA" ] && exit 0
  fi
fi

vsh dominfo "$MAQUINA" >/dev/null || { aviso "No encuentro la máquina «$MAQUINA»" dialog-error; exit 1; }

# La MAC es el identificador fijo de la tarjeta de red.
# NO usar 'vnet0': ese nombre se asigna al arrancar y cambia.
MAC=$(vsh domiflist "$MAQUINA" | awk 'NR>2 && NF {print $NF}' | head -1)

# ── Estado actual ────────────────────────────────────────────────────
estado_maquina(){
  case "$(vsh domstate "$MAQUINA")" in
    "ejecutando") echo "encendida" ;;
    "en pausa")   echo "en pausa"  ;;
    *)            echo "apagada"   ;;
  esac
}

estado_red(){
  [ -z "$MAC" ] && { echo "sin tarjeta"; return; }
  if [ "$(estado_maquina)" != "encendida" ]; then echo "—"; return; fi
  case "$(vsh domif-getlink "$MAQUINA" "$MAC" | grep -oE 'up|down')" in
    up)   echo "conectada" ;;
    down) echo "cortada"   ;;
    *)    echo "?"         ;;
  esac
}

# ── Acciones ─────────────────────────────────────────────────────────

accion_red(){
  local objetivo="$1"
  if [ "$(estado_maquina)" != "encendida" ]; then
    aviso "La máquina está apagada.\n\nEnciéndela primero: el cable de red solo se puede conectar o desconectar con Windows funcionando." dialog-warning
    return
  fi
  if vsh domif-setlink "$MAQUINA" "$MAC" "$objetivo" >/dev/null; then
    if [ "$objetivo" = "down" ]; then
      aviso "<b>Internet cortado.</b>\n\nWindows verá el cable desconectado.\nTus programas locales siguen funcionando igual." network-offline
    else
      aviso "<b>Internet activado.</b>\n\nWindows tardará unos segundos en reconectar.\n\nRecuerda volver a cortarlo cuando termines." network-transmit-receive
    fi
  else
    aviso "No se pudo cambiar la red.\n\nComprueba que perteneces al grupo <b>libvirt</b>." dialog-error
  fi
}

accion_cd(){
  if [ ! -d "$COMPARTIDO" ] || [ ! -w "$COMPARTIDO" ]; then
    aviso "Falta preparar la carpeta compartida.\n\nEjecuta <b>una sola vez</b> en la terminal:\n\n<tt>sudo mkdir -p $COMPARTIDO\nsudo chown $USER:$USER $COMPARTIDO\nsudo chmod 755 $COMPARTIDO</tt>" dialog-warning
    return
  fi

  local carpeta
  carpeta=$(yad --class=cursaliawin --file --directory --center --width=680 --height=460 \
    --window-icon="$LOGO" --title="¿Qué carpeta le paso a Windows?" \
    --button="Cancelar:1" --button="Crear el CD:0" 2>/dev/null)
  [ -z "$carpeta" ] && return

  local iso="$COMPARTIDO/para-windows.iso"

  # -J -r: nombres largos y con acentos. Sin esto salen recortados y en
  # mayúsculas, como en los CD de 1995.
  if ! genisoimage -J -r -V "PARA-WINDOWS" -o "$iso" "$carpeta" 2>/dev/null; then
    aviso "No se pudo crear el CD.\n\n¿Está instalado <b>genisoimage</b>?" dialog-error
    return
  fi
  chmod 644 "$iso"

  local peso; peso=$(du -h "$iso" | cut -f1)

  # Conectarlo: si ya hay un CD de datos puesto, se reemplaza
  local destino; destino=$(vsh domblklist "$MAQUINA" | awk '/para-windows.iso/{print $1}' | head -1)

  if [ -n "$destino" ]; then
    vsh change-media "$MAQUINA" "$destino" "$iso" --update --live >/dev/null 2>&1 \
      || vsh change-media "$MAQUINA" "$destino" "$iso" --update --config >/dev/null 2>&1
    aviso "<b>CD actualizado</b>  ($peso)\n\nEn Windows, expulsa y vuelve a abrir la unidad\npara ver los archivos nuevos." media-optical
  else
    if vsh attach-disk "$MAQUINA" "$iso" sdc --type cdrom --mode readonly --persistent >/dev/null 2>&1; then
      aviso "<b>CD conectado</b>  ($peso)\n\nAparecerá en Windows como una unidad de CD nueva.\n\nSi no lo ves, apaga y enciende la máquina." media-optical
    else
      aviso "El CD se creó en:\n<tt>$iso</tt>\n\nPero no se pudo conectar solo.\nAñádelo a mano desde el Gestor:\n<i>Añadir hardware → Almacenamiento → CDROM</i>" dialog-warning
    fi
  fi
}

accion_foto(){
  local nombre
  nombre=$(yad --class=cursaliawin --entry --center --width=430 --window-icon="$LOGO" \
    --title="Tomar instantánea" --image=camera-photo \
    --text="<b>Una instantánea guarda el estado completo</b>\nde la máquina para poder volver aquí después.\n\nPonle un nombre que recuerdes:" \
    --entry-text="antes-de-$(date +%d-%m-%Hh%M)" \
    --button="Cancelar:1" --button="Tomar la foto:0" 2>/dev/null)
  [ -z "$nombre" ] && return
  nombre=$(echo "$nombre" | tr -c 'A-Za-z0-9._-' '-')

  if vsh snapshot-create-as "$MAQUINA" "$nombre" "Creada desde el panel de cursalialinux" >/dev/null; then
    aviso "<b>Instantánea «$nombre» guardada.</b>\n\nPuedes volver a este punto cuando quieras,\naunque instales algo que rompa Windows." camera-photo
  else
    aviso "No se pudo crear la instantánea.\n\nEn discos qcow2 debería funcionar siempre." dialog-error
  fi
}

accion_volver(){
  local lista; lista=$(vsh snapshot-list --name "$MAQUINA" | grep -v '^$')
  if [ -z "$lista" ]; then
    aviso "Todavía no hay ninguna instantánea.\n\nToma una antes de instalar algo dudoso:\nes tu red de seguridad." dialog-information
    return
  fi
  local elegida
  elegida=$(echo "$lista" | yad --class=cursaliawin --list --center --width=460 --height=320 \
    --window-icon="$LOGO" --title="Volver a una instantánea" \
    --text="<b>Elige a qué momento quieres volver</b>\nTodo lo hecho después se perderá." \
    --column="Instantánea" --button="Cancelar:1" --button="Volver ahí:0" 2>/dev/null | cut -d'|' -f1)
  [ -z "$elegida" ] && return

  pregunta "¿Seguro que quieres volver a «<b>$elegida</b>»?\n\n<b>Se perderá todo lo hecho después</b>\nde ese momento. No se puede deshacer." || return

  if vsh snapshot-revert "$MAQUINA" "$elegida" >/dev/null; then
    aviso "<b>Listo.</b> La máquina volvió a «$elegida».\n\nEs como si lo posterior nunca hubiera pasado." edit-undo
  else
    aviso "No se pudo volver a esa instantánea." dialog-error
  fi
}

# ── Menú principal ───────────────────────────────────────────────────
menu(){
  solo_una
  local em er icono_red texto_red accion_boton
  em=$(estado_maquina); er=$(estado_red)

  case "$er" in
    conectada) icono_red="network-transmit-receive"
               texto_red="🔌   Cortar internet  —  ahora está <b>conectada</b>"
               accion_boton="red-down" ;;
    cortada)   icono_red="network-offline"
               texto_red="🌐   Dar internet  —  ahora está <b>cortada</b>"
               accion_boton="red-up" ;;
    *)         icono_red="network-offline"
               texto_red="🌐   Internet  —  <i>enciende la máquina primero</i>"
               accion_boton="red-nada" ;;
  esac

  yad --class=cursaliawin --title="Panel de $MAQUINA — cursalialinux" \
    --center --width=620 --height=440 --window-icon="$LOGO" \
    --image="$LOGO" --image-on-top \
    --text="<big><b>🪟  $MAQUINA</b></big>\nMáquina <b>$em</b>  ·  Red: <b>$er</b>" \
    --form --columns=1 \
    --field="$texto_red!$icono_red:fbtn"                            "bash -c '$SELF $MAQUINA $accion_boton'" \
    --field="💿   Pasarle archivos con un CD virtual!media-optical:fbtn" "bash -c '$SELF $MAQUINA cd'" \
    --field="📸   Tomar una instantánea!camera-photo:fbtn"          "bash -c '$SELF $MAQUINA foto'" \
    --field="↩️    Volver a una instantánea!edit-undo:fbtn"          "bash -c '$SELF $MAQUINA volver'" \
    --field="🔧   Abrir el Gestor (USB y ajustes)!virt-manager:fbtn" "bash -c 'virt-manager --connect $URI --show-domain-console $MAQUINA &'" \
    --button="Actualizar:bash -c '$SELF $MAQUINA &'" \
    --button="Cerrar:1" 2>/dev/null
}

# ── Despacho ─────────────────────────────────────────────────────────
case "${2:-menu}" in
  red-down) accion_red down; exec "$SELF" "$MAQUINA" ;;
  red-up)   accion_red up;   exec "$SELF" "$MAQUINA" ;;
  red-nada) aviso "La máquina está apagada.\n\nEnciéndela y vuelve a abrir este panel." dialog-warning
            exec "$SELF" "$MAQUINA" ;;
  cd)       accion_cd;       exec "$SELF" "$MAQUINA" ;;
  foto)     accion_foto;     exec "$SELF" "$MAQUINA" ;;
  volver)   accion_volver;   exec "$SELF" "$MAQUINA" ;;
  menu|*)   menu ;;
esac
