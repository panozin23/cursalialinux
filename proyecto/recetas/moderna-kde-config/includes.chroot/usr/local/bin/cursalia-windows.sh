#!/bin/bash

# yad en Wayland avisa "gdk_x11_window_get_xid: assertion failed" porque pide
# un identificador de ventana de X11 que ahí no existe. No rompe nada, pero
# ensucia la terminal. Pasando por XWayland la llamada es válida y calla.
export GDK_BACKEND=x11
# cursalia-windows.sh — Abre Windows como si fuera un programa más.
#
# Enciende la máquina virtual (o la despierta del estado guardado), abre SOLO su
# pantalla —sin el gestor ni listas— y al cerrar la ventana guarda el estado en
# vez de apagar. La próxima vez abre en segundos, justo donde lo dejaste.
#
# Uso:  cursalia-windows.sh [nombre]        → guardar estado al cerrar (normal)
#       cursalia-windows.sh [nombre] --apagar   → apagar del todo al cerrar
#       cursalia-windows.sh [nombre] --dejar    → dejarla encendida al cerrar
#
# Si no das nombre, detecta las máquinas que haya. Si no hay ninguna, te lleva
# al Windows Studio del Centro cursalialinux para crear la primera.
#
# No necesita sudo: basta con pertenecer al grupo 'libvirt'.
set -u

URI="qemu:///system"
AL_CERRAR="guardar"

# El logo se busca primero donde vive en la distro, y si no, en el proyecto.
for cand in /usr/share/pixmaps/cursalialinux.png \
            "$HOME/PROYECTOS-CURSALIA/cursalialinux/marca/logo-256.png"; do
  [ -f "$cand" ] && { LOGO="$cand"; break; }
done
LOGO="${LOGO:-computer}"

MAQUINA=""
for arg in "$@"; do
  case "$arg" in
    --apagar) AL_CERRAR="apagar" ;;
    --dejar)  AL_CERRAR="dejar"  ;;
    --ayuda|-h) sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*) ;;
    *) MAQUINA="$arg" ;;
  esac
done

# ── Avisos en pantalla ───────────────────────────────────────────────
avisar() {
  command -v notify-send >/dev/null 2>&1 \
    && notify-send -a "Windows" -i "$LOGO" "$1" "${2:-}"
  echo "» $1 ${2:-}"
}

ventana() {
  if command -v yad >/dev/null 2>&1; then
    yad --class=cursaliawin --title="Windows — cursalialinux" --center --width=470 \
        --window-icon="$LOGO" --image="${3:-dialog-information}" \
        --text="$1" --button="${2:-Entendido}:0" 2>/dev/null
  else
    echo "$1" | sed 's/<[^>]*>//g'
  fi
}

vsh(){ virsh -c "$URI" "$@" 2>/dev/null; }

# ── ¿Hay virtualización instalada? ───────────────────────────────────
if ! command -v virt-viewer >/dev/null 2>&1 || ! command -v virsh >/dev/null 2>&1; then
  ventana "<b>Todavía no están las herramientas de virtualización.</b>

Ábrelas desde el <b>Centro cursalialinux</b>:
<i>🪟 Windows Studio → Instalar las herramientas</i>

Es un solo clic y se encarga de todo." "Abrir el Centro" dialog-warning
  command -v centro-cursalialinux >/dev/null 2>&1 && centro-cursalialinux windows &
  exit 0
fi

# ── Elegir la máquina ────────────────────────────────────────────────
if [ -z "$MAQUINA" ]; then
  MAQUINAS=$(vsh list --all --name | grep -v '^$')
  CUANTAS=$(echo "$MAQUINAS" | grep -c .)

  if [ "$CUANTAS" -eq 0 ]; then
    ventana "<b>Todavía no has creado ninguna máquina de Windows.</b>

Ve al <b>Centro cursalialinux</b>:
<i>🪟 Windows Studio → Crear una máquina de Windows</i>

Te guía paso a paso: elige la versión, el archivo de
instalación, y el resto lo hace solo." "Abrir el Centro" dialog-information
    command -v centro-cursalialinux >/dev/null 2>&1 && centro-cursalialinux windows &
    exit 0

  elif [ "$CUANTAS" -eq 1 ]; then
    MAQUINA="$MAQUINAS"

  else
    MAQUINA=$(echo "$MAQUINAS" | yad --class=cursaliawin --list \
      --title="¿Cuál abro?" --center --width=430 --height=300 \
      --window-icon="$LOGO" --image="$LOGO" --image-on-top \
      --text="<b>Tienes varias máquinas virtuales</b>" \
      --column="Máquina" --button="Cancelar:1" --button="Abrir:0" 2>/dev/null | cut -d'|' -f1)
    [ -z "$MAQUINA" ] && exit 0
  fi
fi

vsh dominfo "$MAQUINA" >/dev/null || {
  ventana "No encuentro la máquina «<b>$MAQUINA</b>»." "Cerrar" dialog-error; exit 1; }

# ── Encender o despertar ─────────────────────────────────────────────
case "$(vsh domstate "$MAQUINA")" in
  "ejecutando")
    echo "» ya estaba encendida" ;;
  "en pausa")
    echo "» estaba en pausa, la despierto"
    vsh resume "$MAQUINA" >/dev/null ;;
  *)
    if vsh dominfo "$MAQUINA" | grep -qiE 'administrado: *s|managed save: *y'; then
      avisar "Despertando $MAQUINA…" "Vuelve donde lo dejaste"
    else
      avisar "Encendiendo $MAQUINA…" "Arranque completo, tarda un poco"
    fi
    vsh start "$MAQUINA" >/dev/null || {
      ventana "No se pudo encender «<b>$MAQUINA</b>».

Comprueba que perteneces al grupo <b>libvirt</b>
y que el servicio está activo." "Cerrar" dialog-error
      exit 1; } ;;
esac

# ── Abrir la pantalla ────────────────────────────────────────────────
virt-viewer --connect "$URI" --wait "$MAQUINA"

# ── Al cerrar la ventana ─────────────────────────────────────────────
ESTADO=$(vsh domstate "$MAQUINA" || echo desconocido)

if [ "$ESTADO" != "ejecutando" ] && [ "$ESTADO" != "en pausa" ]; then
  echo "» ya estaba apagada ($ESTADO)"
  exit 0
fi

case "$AL_CERRAR" in
  guardar)
    avisar "Guardando el estado de $MAQUINA…" "No apagues el equipo todavía"
    if vsh managedsave "$MAQUINA" >/dev/null; then
      avisar "$MAQUINA guardado" "La próxima vez abre en segundos"
    else
      echo "AVISO: no se pudo guardar; la máquina sigue encendida." >&2
      echo "       Para apagarla: virsh -c $URI shutdown $MAQUINA" >&2
    fi ;;
  apagar)
    avisar "Apagando $MAQUINA…" "Puede tardar medio minuto"
    vsh shutdown "$MAQUINA" >/dev/null ;;
  dejar)
    echo "» queda encendida en segundo plano" ;;
esac
