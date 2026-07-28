#!/bin/bash

# yad en Wayland avisa de un identificador de ventana X11 que ahí no existe.
# No rompe nada, pero ensucia la terminal. Por XWayland la llamada es válida.
export GDK_BACKEND=x11

# cursalia-windows-iso.sh — Ayuda a conseguir y colocar la imagen de Windows.
#
# El usuario no tiene por qué saber que existe /var/lib/libvirt/images ni que
# hace falta sudo para escribir ahí. Este asistente le abre la página oficial
# de Microsoft, busca después el archivo descargado y lo coloca en su sitio.
#
# Uso:  cursalia-windows-iso.sh
#
# No necesita sudo: pide la contraseña solo al momento de mover el archivo.
set -u

DESTINO=/var/lib/libvirt/images
SELF="$(readlink -f "$0")"

for cand in /usr/share/pixmaps/cursalialinux.png \
            "$HOME/PROYECTOS-CURSALIA/cursalialinux/marca/logo-256.png"; do
  [ -f "$cand" ] && { LOGO="$cand"; break; }
done
LOGO="${LOGO:-computer}"

for cand in /usr/share/cursalialinux/centro.css \
            "$HOME/PROYECTOS-CURSALIA/cursalialinux/marca/centro.css"; do
  [ -f "$cand" ] && { GTKRC="--gtkrc=$cand"; break; }
done
GTKRC="${GTKRC:-}"

WIN_ICO=/usr/share/icons/Papirus/64x64/apps/distributor-logo-windows.svg
[ -f "$WIN_ICO" ] || WIN_ICO=media-optical

sola(){ pkill -f "class=cursaliawiso" 2>/dev/null; sleep 0.15; }

aviso(){ yad --class=cursaliawiso $GTKRC --borders=14 --title="Imagen de Windows" \
    --center --width=470 --window-icon="$LOGO" --image="${2:-dialog-information}" \
    --text="$1" --button="Entendido:0" 2>/dev/null; }

# ── ¿Es de verdad un instalador de Windows? ──────────────────────────
# Microsoft nombra sus volúmenes con patrones como CCCOMA_X64FRE_ES-MX_DV9.
# Ese "X64FRE" o "X86FRE" es la firma que buscamos.
es_windows(){
  local f="$1"
  [ -r "$f" ] || return 1
  local etiqueta
  etiqueta=$(isoinfo -d -i "$f" 2>/dev/null | grep -i '^Volume id:' | cut -d: -f2- | tr -d ' ')
  echo "$etiqueta" | grep -qiE 'X64FRE|X86FRE|CCCOMA|CPBA|SSS_|_WINDOWS|IR[0-9]_CC' && return 0
  # Algunos instaladores antiguos usan otras etiquetas: aceptamos por tamaño
  local mb=$(( $(stat -c %s "$f") / 1024 / 1024 ))
  [ "$mb" -ge 2500 ] && return 0
  return 1
}

etiqueta_de(){ isoinfo -d -i "$1" 2>/dev/null | grep -i '^Volume id:' | cut -d: -f2- | sed 's/^ *//'; }

# ── ¿Ya hay alguna imagen colocada? ──────────────────────────────────
ya_hay(){
  for f in "$DESTINO"/*.iso; do
    case "$(basename "$f")" in virtio*) continue ;; esac
    [ -r "$f" ] && { echo "$f"; return 0; }
  done
  return 1
}

# ═══ DESCARGAR ═════════════════════════════════════════════════════
descargar(){
  sola
  yad --class=cursaliawiso $GTKRC --borders=14 --title="Descargar Windows" \
    --center --width=650 --height=470 --window-icon="$LOGO" \
    --image="$WIN_ICO" --image-on-top \
    --text="<span size=\"x-large\"><b>Descargar la imagen de Windows</b></span>

Elige la versión que necesitas. Se abrirá la <b>página oficial
de Microsoft</b> en tu navegador.

Ahí eliges idioma y descargas el archivo. Cuando termine,
vuelve aquí y pulsa <b>«Ya lo descargué»</b>: yo me encargo
del resto.

<i>La descarga son varios GB y puede tardar.</i>" \
    --form --columns=1 \
    --field="Windows 11  —  el recomendado, con soporte actual!$WIN_ICO:fbtn" \
        "bash -c 'xdg-open https://www.microsoft.com/software-download/windows11 &'" \
    --field="Windows 10  —  para equipos o programas más antiguos!$WIN_ICO:fbtn" \
        "bash -c 'xdg-open https://www.microsoft.com/software-download/windows10 &'" \
    --field="Otras versiones  —  página de descargas de Microsoft!web-browser:fbtn" \
        "bash -c 'xdg-open https://www.microsoft.com/software-download/ &'" \
    --field="✔   Ya lo descargué  —  buscar el archivo!document-open:fbtn" \
        "bash -c '$SELF buscar'" \
    --button="⬅ Volver:bash -c '$SELF'" \
    --button="Cerrar:1" 2>/dev/null
}

# ═══ BUSCAR Y COLOCAR ══════════════════════════════════════════════
buscar(){
  sola
  local elegido=""

  # Primero miramos en Descargas, que es donde cae el 95% de las veces
  local sugerido=""
  for f in "$HOME"/Descargas/*.iso "$HOME"/Downloads/*.iso; do
    [ -r "$f" ] && es_windows "$f" && { sugerido="$f"; break; }
  done

  if [ -n "$sugerido" ]; then
    if yad --class=cursaliawiso $GTKRC --borders=14 --title="Imagen encontrada" \
        --center --width=520 --window-icon="$LOGO" --image="$WIN_ICO" \
        --text="<b>Encontré esta imagen en tus Descargas:</b>

<tt>$(basename "$sugerido")</tt>
Tamaño: $(du -h "$sugerido" | cut -f1)
Volumen: $(etiqueta_de "$sugerido")

¿La uso?" \
        --button="Buscar otra:1" --button="Sí, usar esta:0" 2>/dev/null; then
      elegido="$sugerido"
    fi
  fi

  if [ -z "$elegido" ]; then
    elegido=$(yad --class=cursaliawiso $GTKRC --file --center --width=760 --height=500 \
      --window-icon="$LOGO" --title="¿Dónde está la imagen de Windows?" \
      --file-filter="Imágenes de disco | *.iso *.ISO" \
      --button="Cancelar:1" --button="Usar esta:0" 2>/dev/null)
  fi

  [ -z "$elegido" ] && { menu; return; }

  if ! es_windows "$elegido"; then
    aviso "<b>Ese archivo no parece un instalador de Windows.</b>

<tt>$(basename "$elegido")</tt>
Volumen: $(etiqueta_de "$elegido")

Los instaladores de Microsoft tienen una etiqueta que
incluye <b>X64FRE</b> o similar, y pesan varios GB.

Si estás seguro de que es correcto, cópialo a mano:
<tt>sudo cp \"$elegido\" $DESTINO/</tt>" dialog-warning
    menu; return
  fi

  # ── Colocarlo ──
  local nombre; nombre=$(basename "$elegido")
  local libre; libre=$(df -BG --output=avail "$DESTINO" 2>/dev/null | tail -1 | tr -dc '0-9')
  local pesa;  pesa=$(( $(stat -c %s "$elegido") / 1024 / 1024 / 1024 ))

  if [ "${libre:-0}" -lt $(( pesa + 5 )) ]; then
    aviso "<b>No hay espacio suficiente.</b>

La imagen ocupa ${pesa} GB y solo quedan ${libre} GB libres
en el disco. Libera espacio y vuelve a intentarlo." dialog-error
    menu; return
  fi

  ( echo "10"; echo "# Copiando $nombre…"
    pkexec install -m 644 "$elegido" "$DESTINO/$nombre" 2>/dev/null && echo "100" || echo "100"
  ) | yad --class=cursaliawiso $GTKRC --progress --auto-close --center --width=440 \
        --window-icon="$LOGO" --title="Colocando la imagen" \
        --text="Copiando la imagen de Windows a su sitio…" --no-buttons 2>/dev/null

  if [ -r "$DESTINO/$nombre" ]; then
    yad --class=cursaliawiso $GTKRC --borders=14 --title="Todo listo" \
      --center --width=520 --window-icon="$LOGO" --image=emblem-default \
      --text="<span size=\"x-large\"><b>Imagen lista</b></span>

<tt>$nombre</tt>
ya está en su sitio.

Los controladores que Windows necesita <b>ya vienen incluidos</b>
en cursalialinux, así que no tienes que descargar nada más.

Ya puedes crear tu máquina de Windows." \
      --button="Cerrar:1" --button="Crear la máquina ahora:0" 2>/dev/null \
      && x-terminal-emulator -e bash -c "sudo virt-crear-windows.sh; echo; read -p 'Pulsa Enter para cerrar'" &
  else
    aviso "<b>No se pudo copiar la imagen.</b>

Puede que hayas cancelado la petición de contraseña.
Inténtalo otra vez, o cópiala a mano:

<tt>sudo cp \"$elegido\" $DESTINO/</tt>" dialog-error
    menu
  fi
}

# ═══ MENÚ ══════════════════════════════════════════════════════════
menu(){
  sola
  local actual estado
  if actual=$(ya_hay); then
    estado="<b>Ya tienes una imagen lista:</b>
<tt>$(basename "$actual")</tt>  ($(du -h "$actual" | cut -f1))"
  else
    estado="<i>Todavía no hay ninguna imagen de Windows.</i>"
  fi

  yad --class=cursaliawiso $GTKRC --borders=14 --title="Imagen de Windows — cursalialinux" \
    --center --width=650 --height=430 --window-icon="$LOGO" \
    --image="$WIN_ICO" --image-on-top \
    --text="<span size=\"x-large\"><b>La imagen de Windows</b></span>

Para crear tu máquina necesitas el archivo de instalación
de Windows. Microsoft lo entrega sin costo desde su web.

$estado" \
    --form --columns=1 \
    --field="⬇   Descargar Windows  —  abre la página oficial!$WIN_ICO:fbtn" \
        "bash -c '$SELF descargar'" \
    --field="📂   Ya tengo el archivo  —  buscarlo y colocarlo!document-open:fbtn" \
        "bash -c '$SELF buscar'" \
    --button="Cerrar:1" 2>/dev/null
}

case "${1:-menu}" in
  descargar) descargar ;;
  buscar)    buscar ;;
  menu|*)    menu ;;
esac
