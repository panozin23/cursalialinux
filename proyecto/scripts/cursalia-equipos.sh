#!/bin/bash

# yad en Wayland avisa de un identificador X11 que ahí no existe. Por
# XWayland la llamada es válida y no ensucia la terminal.
export GDK_BACKEND=x11

# cursalia-equipos.sh — Equipos en Red
#
# Administra otras computadoras con cursalialinux desde esta, sin escribir
# un solo comando: ver su informe, abrir sus máquinas de Windows,
# actualizarlas, enviarles archivos.
#
# Nació el 2026-07-28. euflo administra varios equipos —consultorios de un
# centro de salud— y hasta ahora tenía que sentarse delante de cada uno.
#
# Uso:  cursalia-equipos.sh
#       No necesita sudo. La primera vez pide UNA contraseña por equipo,
#       para dejar la llave; después nunca más.
set -u

CONF="$HOME/.config/cursalialinux"
EQUIPOS="$CONF/equipos.conf"
SELF="$(readlink -f "$0")"
mkdir -p "$CONF"

for c in /usr/share/pixmaps/cursalialinux.png \
         "$HOME/PROYECTOS-CURSALIA/cursalialinux/marca/logo-256.png"; do
  [ -f "$c" ] && { LOGO="$c"; break; }
done
LOGO="${LOGO:-network-workgroup}"

# Logo reducido para las cabeceras: el de 256 px se come media ventana.
LOGO_CAB="/usr/share/pixmaps/cursalialinux-96.png"
[ -f "$LOGO_CAB" ] || LOGO_CAB="$HOME/PROYECTOS-CURSALIA/cursalialinux/marca/logo-96.png"
[ -f "$LOGO_CAB" ] || LOGO_CAB="$LOGO"

for c in /usr/share/cursalialinux/centro.css \
         "$HOME/PROYECTOS-CURSALIA/cursalialinux/marca/centro.css"; do
  [ -f "$c" ] && { GTKRC="--gtkrc=$c"; break; }
done
GTKRC="${GTKRC:-}"

sola(){ pkill -f 'class=cursaliaeq' 2>/dev/null; sleep 0.15; }

aviso(){ yad --class=cursaliaeq $GTKRC --borders=14 --title="Equipos en Red" \
    --center --width=480 --window-icon="$LOGO" --image="${2:-dialog-information}" \
    --text="$1" --button="Entendido:0" 2>/dev/null; }

pregunta(){ yad --class=cursaliaeq $GTKRC --borders=14 --title="Equipos en Red" \
    --center --width=480 --window-icon="$LOGO" --image=dialog-question \
    --text="$1" --button="Cancelar:1" --button="Sí, adelante:0" 2>/dev/null; }

# ── Estado de un equipo ──────────────────────────────────────────────
# Tres situaciones distintas que hoy se confunden entre sí:
#   apagado        no responde a nada
#   cortafuegos    responde al ping pero cierra el puerto 22
#   sin permiso    SSH abierto pero aún no tiene nuestra llave
estado_de(){
  local ip="$1"
  ping -c1 -W2 "$ip" >/dev/null 2>&1 || { echo "apagado"; return; }
  timeout 3 bash -c "echo > /dev/tcp/$ip/22" 2>/dev/null || { echo "cortafuegos"; return; }
  local u; u=$(usuario_de "$ip")
  timeout 6 ssh -o BatchMode=yes -o ConnectTimeout=4 -o StrictHostKeyChecking=accept-new \
    "$u@$ip" 'exit' >/dev/null 2>&1 && echo "listo" || echo "sin-permiso"
}

icono_de(){
  case "$1" in
    listo)       echo "🟢" ;;
    sin-permiso) echo "🔴" ;;
    cortafuegos) echo "🟠" ;;
    *)           echo "⚪" ;;
  esac
}

texto_de(){
  case "$1" in
    listo)       echo "Listo" ;;
    sin-permiso) echo "Falta permiso" ;;
    cortafuegos) echo "Cortafuegos" ;;
    *)           echo "Apagado" ;;
  esac
}

# ── El archivo de equipos: ip|usuario|nombre ─────────────────────────
usuario_de(){ awk -F'|' -v i="$1" '$1==i{print $2}' "$EQUIPOS" 2>/dev/null | head -1 || echo "$USER"; }
nombre_de(){  awk -F'|' -v i="$1" '$1==i{print $3}' "$EQUIPOS" 2>/dev/null | head -1; }

guardar(){   # ip usuario nombre
  touch "$EQUIPOS"
  grep -v "^$1|" "$EQUIPOS" > "$EQUIPOS.tmp" 2>/dev/null || true
  printf '%s|%s|%s\n' "$1" "$2" "$3" >> "$EQUIPOS.tmp"
  sort -t. -k4 -n "$EQUIPOS.tmp" -o "$EQUIPOS"; rm -f "$EQUIPOS.tmp"
}

olvidar(){ grep -v "^$1|" "$EQUIPOS" > "$EQUIPOS.tmp" 2>/dev/null; mv "$EQUIPOS.tmp" "$EQUIPOS"; }

version_de(){
  local ip="$1" u; u=$(usuario_de "$ip")
  timeout 8 ssh -o BatchMode=yes -o ConnectTimeout=5 "$u@$ip" \
    'dpkg-query -W -f="\${Version}" cursalialinux-escritorio 2>/dev/null' 2>/dev/null
}

# ═══ BUSCAR EQUIPOS ════════════════════════════════════════════════
buscar(){
  sola
  local red; red=$(ip -4 route 2>/dev/null | awk '/proto kernel/ && /192\.168\./ {print $1; exit}')
  [ -n "$red" ] || red=$(ip -4 route | awk '/proto kernel/ {print $1; exit}')

  if [ -z "$red" ]; then
    aviso "<b>No estás conectado a ninguna red.</b>

Conéctate al wifi o al cable y vuelve a intentarlo." dialog-warning
    menu; return
  fi

  ( echo "5";  echo "# Recorriendo $red…"
    if command -v nmap >/dev/null 2>&1; then
      nmap -n -p22 --open -T4 "$red" -oG - 2>/dev/null | awk '/22\/open/{print $2}' > /tmp/cursalia-eq-encontrados
    else
      : > /tmp/cursalia-eq-encontrados
      base="${red%.*}"
      for n in $(seq 1 254); do
        ( timeout 1 bash -c "echo > /dev/tcp/$base.$n/22" 2>/dev/null && echo "$base.$n" >> /tmp/cursalia-eq-encontrados ) &
      done; wait
    fi
    echo "60"; echo "# Preguntando quién es cada uno…"

    MI_IP=$(ip -4 addr show | grep -oE 'inet [0-9.]+' | awk '{print $2}' | grep -v '^127' | head -1)
    : > /tmp/cursalia-eq-nuevos
    while read -r ip; do
      [ -z "$ip" ] && continue
      [ "$ip" = "$MI_IP" ] && continue
      grep -q "^$ip|" "$EQUIPOS" 2>/dev/null && continue
      nom=$(timeout 3 avahi-resolve -a "$ip" 2>/dev/null | awk '{print $2}' | sed 's/\.local$//')
      [ -z "$nom" ] && nom="equipo-${ip##*.}"
      printf '%s|%s\n' "$ip" "$nom" >> /tmp/cursalia-eq-nuevos
    done < /tmp/cursalia-eq-encontrados
    echo "100"
  ) | yad --class=cursaliaeq $GTKRC --progress --auto-close --center --width=460 \
        --window-icon="$LOGO" --title="Buscando equipos" \
        --text="Buscando computadoras en tu red…" --no-buttons 2>/dev/null

  local n; n=$(grep -c . /tmp/cursalia-eq-nuevos 2>/dev/null || echo 0)
  if [ "$n" -eq 0 ]; then
    aviso "<b>No se encontraron equipos nuevos.</b>

Puede que ya estén todos en tu lista, o que los otros
equipos estén apagados.

<i>Si sabes la dirección de uno, añádelo a mano.</i>" dialog-information
    menu; return
  fi

  local args=() ip nom
  while IFS='|' read -r ip nom; do
    args+=(FALSE "$ip" "$nom")
  done < /tmp/cursalia-eq-nuevos

  local elegidos
  elegidos=$(yad --class=cursaliaeq $GTKRC --borders=14 --list --checklist \
    --title="Equipos encontrados" --center --width=560 --height=380 \
    --window-icon="$LOGO" --image="$LOGO_CAB" --image-on-top \
    --text="<b>Encontré $n equipo(s) con SSH abierto</b>
Marca los que quieras añadir a tu lista:" \
    --column="" --column="Dirección" --column="Nombre" \
    --print-column=2 --separator=$'\n' \
    "${args[@]}" --button="Cancelar:1" --button="Añadir los marcados:0" 2>/dev/null)

  local u
  while read -r ip; do
    [ -z "$ip" ] && continue
    nom=$(awk -F'|' -v i="$ip" '$1==i{print $2}' /tmp/cursalia-eq-nuevos)
    u=$(yad --class=cursaliaeq $GTKRC --entry --center --width=440 \
      --window-icon="$LOGO" --title="Usuario de $nom" \
      --text="<b>¿Con qué usuario entras a $nom?</b>
<i>$ip</i>

Es el nombre que aparece antes de la arroba
en la terminal de ese equipo." \
      --entry-text="$USER" --button="Cancelar:1" --button="Guardar:0" 2>/dev/null)
    [ -n "$u" ] && guardar "$ip" "$u" "$nom"
  done <<< "$elegidos"

  menu
}

# ═══ AÑADIR A MANO ═════════════════════════════════════════════════
anadir(){
  sola
  local datos
  datos=$(yad --class=cursaliaeq $GTKRC --borders=14 --form --center --width=460 \
    --window-icon="$LOGO" --title="Añadir un equipo" --image="$LOGO_CAB" --image-on-top \
    --text="<b>Añadir un equipo a mano</b>
Útil si conoces su dirección y no aparece al buscar." \
    --field="Dirección  (ejemplo 192.168.1.100)" "" \
    --field="Usuario de ese equipo" "$USER" \
    --field="Nombre para reconocerlo" "" \
    --separator='|' --button="Cancelar:1" --button="Añadir:0" 2>/dev/null)
  [ -z "$datos" ] && { menu; return; }

  local ip u nom
  ip=$(echo "$datos" | cut -d'|' -f1); u=$(echo "$datos" | cut -d'|' -f2); nom=$(echo "$datos" | cut -d'|' -f3)
  [ -z "$ip" ] && { menu; return; }
  [ -z "$u" ] && u="$USER"
  [ -z "$nom" ] && nom="equipo-${ip##*.}"
  guardar "$ip" "$u" "$nom"
  menu
}

# ═══ DAR PERMISO (copiar la llave) ═════════════════════════════════
dar_permiso(){
  local ip="$1" u; u=$(usuario_de "$ip")
  [ -f "$HOME/.ssh/id_ed25519.pub" ] || ssh-keygen -t ed25519 -N "" -f "$HOME/.ssh/id_ed25519" -q

  aviso "<b>Voy a pedirte la contraseña de $(nombre_de "$ip")</b>

Es la contraseña del usuario <b>$u</b> en ese equipo.

Se pide <b>una sola vez</b>: después queda una llave guardada
y no volverá a pedírtela nunca." dialog-password

  x-terminal-emulator -e bash -c \
    "echo 'Escribe la contraseña de $u@$ip'; echo; ssh-copy-id -o StrictHostKeyChecking=accept-new $u@$ip; echo; read -p 'Pulsa Enter para cerrar'" 2>/dev/null
  menu
}

# ═══ ABRIR EL CORTAFUEGOS ══════════════════════════════════════════
abrir_cortafuegos(){
  local ip="$1" u; u=$(usuario_de "$ip")
  aviso "<b>Ese equipo responde, pero tiene el puerto cerrado.</b>

cursalialinux activa el cortafuegos de fábrica, y eso
bloquea la administración remota.

Voy a abrir una terminal para arreglarlo. Te pedirá
la contraseña de <b>$u</b> en ese equipo." dialog-warning

  x-terminal-emulator -e bash -c \
    "echo 'Abriendo el puerto SSH en $ip…'; echo; ssh -t $u@$ip 'sudo ufw allow ssh && sudo ufw reload && sudo systemctl enable --now ssh'; echo; read -p 'Pulsa Enter para cerrar'" 2>/dev/null
  menu
}

# ═══ ACCIONES SOBRE UN EQUIPO ══════════════════════════════════════
acciones(){
  sola
  local ip="$1" u nom est ver
  u=$(usuario_de "$ip"); nom=$(nombre_de "$ip")
  est=$(estado_de "$ip")

  if [ "$est" = "apagado" ]; then
    aviso "<b>$nom está apagado</b> o fuera de alcance.

<tt>$ip</tt>

Enciéndelo y vuelve a intentarlo." dialog-warning
    menu; return
  fi

  # Si algo falla, ofrecer también corregir el usuario: puede ser justo
  # la causa. Antes se iba directo a "dar permiso" y no había forma de
  # llegar a la pantalla de edición.
  if [ "$est" = "cortafuegos" ] || [ "$est" = "sin-permiso" ]; then
    local titulo texto accion
    if [ "$est" = "cortafuegos" ]; then
      titulo="🟠  $nom — cortafuegos cerrado"
      texto="Ese equipo responde, pero tiene el puerto SSH cerrado.
cursalialinux activa el cortafuegos de fábrica."
      accion="Abrir el puerto en ese equipo!security-medium:fbtn"
      cmd="bash -c '$SELF cortafuegos $ip'"
    else
      titulo="🔴  $nom — falta darle permiso"
      texto="Todavía no tiene tu llave. Se pide la contraseña
<b>una sola vez</b> y después nunca más.

<i>Si ya lo hiciste, comprueba que el usuario sea el correcto:
ahora dice <b>$u</b>.</i>"
      accion="Dar permiso a este equipo!dialog-password:fbtn"
      cmd="bash -c '$SELF permiso $ip'"
    fi
    yad --class=cursaliaeq $GTKRC --borders=14 --title="$nom — Equipos en Red" \
      --center --width=580 --height=360 --window-icon="$LOGO" \
      --image="$LOGO_CAB" --image-on-top \
      --text="<span size=\"x-large\"><b>$titulo</b></span>
<tt>$u@$ip</tt>

$texto" \
      --form --columns=1 \
      --field="$accion" "$cmd" \
      --field="Corregir el usuario o el nombre!document-edit:fbtn" "bash -c '$SELF editar $ip'" \
      --button="⬅ Volver:bash -c '$SELF'" --button="Cerrar:1" 2>/dev/null
    return
  fi

  ver=$(version_de "$ip"); ver="${ver:-desconocida}"
  local mia; mia=$(dpkg-query -W -f='${Version}' cursalialinux-escritorio 2>/dev/null)
  local aviso_ver=""
  [ -n "$mia" ] && [ "$ver" != "$mia" ] && [ "$ver" != "desconocida" ] \
    && aviso_ver="  ⬆ <b>tú tienes la $mia</b>"

  yad --class=cursaliaeq $GTKRC --borders=14 --title="$nom — Equipos en Red" \
    --center --width=620 --height=470 --window-icon="$LOGO" \
    --image="$LOGO_CAB" --image-on-top \
    --text="<span size=\"x-large\"><b>🟢  $nom</b></span>
<tt>$u@$ip</tt>  ·  cursalialinux <b>$ver</b>$aviso_ver" \
    --form --columns=1 \
    --field="Ver el informe de este equipo!dialog-information:fbtn"        "bash -c '$SELF informe $ip'" \
    --field="Abrir sus máquinas de Windows!computer:fbtn"                  "bash -c '$SELF windows $ip'" \
    --field="Actualizar cursalialinux!system-software-update:fbtn"         "bash -c '$SELF actualizar $ip'" \
    --field="Enviarle archivos!document-send:fbtn"                         "bash -c '$SELF enviar $ip'" \
    --field="Abrir una terminal!utilities-terminal:fbtn"                   "bash -c '$SELF terminal $ip'" \
    --field="Cambiar el nombre o quitarlo de la lista!document-edit:fbtn"  "bash -c '$SELF editar $ip'" \
    --button="⬅ Volver:bash -c '$SELF'" --button="Cerrar:1" 2>/dev/null
}

informe(){
  local ip="$1" u; u=$(usuario_de "$ip")
  local salida
  salida=$(timeout 60 ssh -o BatchMode=yes "$u@$ip" 'cursalia-informe.sh' 2>&1 \
           || ssh -o BatchMode=yes "$u@$ip" 'bash -s' < /usr/bin/cursalia-informe.sh 2>&1)
  echo "$salida" | yad --class=cursaliaeq $GTKRC --text-info --center \
    --width=760 --height=640 --window-icon="$LOGO" \
    --title="Informe de $(nombre_de "$ip")" --fontname="Monospace 10" \
    --button="Cerrar:0" 2>/dev/null
  acciones "$ip"
}

windows(){
  local ip="$1" u; u=$(usuario_de "$ip")
  command -v virt-manager >/dev/null 2>&1 || {
    aviso "Falta <b>virt-manager</b> en este equipo.

Instálalo con:  <tt>sudo apt install virt-manager</tt>" dialog-error
    acciones "$ip"; return; }
  virt-manager --connect "qemu+ssh://$u@$ip/system" >/dev/null 2>&1 &
  aviso "<b>Abriendo las máquinas de $(nombre_de "$ip")…</b>

Aparecerá el Gestor con las máquinas de ese equipo.
Doble clic en una para ver su pantalla aquí." computer
  acciones "$ip"
}

actualizar(){
  local ip="$1" u; u=$(usuario_de "$ip")
  pregunta "<b>Actualizar cursalialinux en $(nombre_de "$ip")?</b>

Se le instalará la última versión publicada.
Te pedirá la contraseña de <b>$u</b> en ese equipo." || { acciones "$ip"; return; }
  x-terminal-emulator -e bash -c \
    "ssh -t $u@$ip 'sudo apt update && sudo apt install -y cursalialinux-escritorio && dpkg -l cursalialinux-escritorio | tail -1'; echo; read -p 'Pulsa Enter para cerrar'" 2>/dev/null
  acciones "$ip"
}

enviar(){
  local ip="$1" u; u=$(usuario_de "$ip")
  local archivos
  archivos=$(yad --class=cursaliaeq $GTKRC --file --multiple --center --width=740 --height=500 \
    --window-icon="$LOGO" --title="¿Qué le envío a $(nombre_de "$ip")?" \
    --separator='\n' --button="Cancelar:1" --button="Enviar:0" 2>/dev/null)
  [ -z "$archivos" ] && { acciones "$ip"; return; }

  # Al escritorio, que es donde la gente espera encontrarlo. La carpeta
  # se llama "Escritorio" o "Desktop" según el idioma del sistema, así
  # que se le pregunta a él mismo cuál usa.
  local destino
  destino=$(timeout 8 ssh -o BatchMode=yes "$u@$ip" \
    'xdg-user-dir DESKTOP 2>/dev/null || echo "$HOME"' 2>/dev/null)
  [ -z "$destino" ] && destino="."

  ( echo "20"; echo "# Enviando…"
    echo "$archivos" | while read -r f; do
      [ -n "$f" ] && scp -q "$f" "$u@$ip:$destino/" 2>/dev/null
    done
    echo "100"
  ) | yad --class=cursaliaeq $GTKRC --progress --auto-close --center --width=440 \
        --window-icon="$LOGO" --title="Enviando archivos" --no-buttons 2>/dev/null

  aviso "<b>Archivos enviados.</b>

Los verás en el <b>escritorio</b> de $(nombre_de "$ip")." document-send
  acciones "$ip"
}

terminal(){
  local ip="$1" u; u=$(usuario_de "$ip")
  x-terminal-emulator -e bash -c "ssh $u@$ip" 2>/dev/null &
  acciones "$ip"
}

editar(){
  sola
  local ip="$1" u nom datos
  u=$(usuario_de "$ip"); nom=$(nombre_de "$ip")
  datos=$(yad --class=cursaliaeq $GTKRC --borders=14 --form --center --width=460 \
    --window-icon="$LOGO" --title="Editar equipo" \
    --text="<b>$nom</b>\n<tt>$ip</tt>" \
    --field="Nombre" "$nom" --field="Usuario" "$u" \
    --separator='|' --button="Quitar de la lista:2" \
    --button="Cancelar:1" --button="Guardar:0" 2>/dev/null)
  local r=$?
  if [ "$r" = "2" ]; then
    pregunta "¿Quitar <b>$nom</b> de la lista?

No se borra nada de ese equipo: solo deja de
aparecer aquí." && olvidar "$ip"
    menu; return
  fi
  [ -n "$datos" ] && guardar "$ip" "$(echo "$datos" | cut -d'|' -f2)" "$(echo "$datos" | cut -d'|' -f1)"
  menu
}

# ═══ PANTALLA PRINCIPAL ════════════════════════════════════════════
menu(){
  sola
  local mi_red; mi_red=$(ip -4 addr show 2>/dev/null | grep -oE 'inet 192\.168\.[0-9]+\.[0-9]+' \
    | grep -v '122\.' | head -1 | cut -d' ' -f2)

  if [ ! -s "$EQUIPOS" ]; then
    yad --class=cursaliaeq $GTKRC --borders=14 --title="Equipos en Red — cursalialinux" \
      --center --width=600 --height=380 --window-icon="$LOGO" \
      --image="$LOGO_CAB" --image-on-top \
      --text="<span size=\"x-large\"><b>🖥️  Equipos en Red</b></span>

Administra otras computadoras con cursalialinux desde aquí:
ver cómo están, abrir sus máquinas de Windows, actualizarlas
o enviarles archivos. Sin moverte de tu silla.

<i>Todavía no tienes ningún equipo guardado.</i>" \
      --form --columns=1 \
      --field="Buscar equipos en mi red!system-search:fbtn"   "bash -c '$SELF buscar'" \
      --field="Añadir uno a mano!list-add:fbtn"               "bash -c '$SELF anadir'" \
      --button="Cerrar:1" 2>/dev/null
    return
  fi

  local args=() ip u nom est
  while IFS='|' read -r ip u nom; do
    [ -z "$ip" ] && continue
    est=$(estado_de "$ip")
    args+=(--field="$(icono_de "$est")   $nom   —   $(texto_de "$est")   ·   $ip!network-workgroup:fbtn" "bash -c '$SELF acciones $ip'")
  done < "$EQUIPOS"

  local n; n=$(grep -c . "$EQUIPOS")
  local alto=$(( 250 + n * 46 ))
  [ "$alto" -gt 660 ] && alto=660

  yad --class=cursaliaeq $GTKRC --borders=14 --title="Equipos en Red — cursalialinux" \
    --center --width=640 --height=$alto --window-icon="$LOGO" \
    --image="$LOGO_CAB" --image-on-top \
    --text="<span size=\"x-large\"><b>🖥️  Equipos en Red</b></span>
Tu equipo: <tt>${mi_red:-sin red}</tt>   ·   $n equipo(s) guardado(s)

<span size=\"small\">🟢 listo   🔴 falta permiso   🟠 cortafuegos   ⚪ apagado</span>" \
    --form --columns=1 "${args[@]}" \
    --button="🔍 Buscar más:bash -c '$SELF buscar'" \
    --button="➕ Añadir:bash -c '$SELF anadir'" \
    --button="Cerrar:1" 2>/dev/null
}

case "${1:-menu}" in
  buscar)     buscar ;;
  anadir)     anadir ;;
  acciones)   acciones "$2" ;;
  informe)    informe "$2" ;;
  windows)    windows "$2" ;;
  actualizar) actualizar "$2" ;;
  enviar)     enviar "$2" ;;
  terminal)   terminal "$2" ;;
  editar)      editar "$2" ;;
  permiso)     dar_permiso "$2" ;;
  cortafuegos) abrir_cortafuegos "$2" ;;
  menu|*)     menu ;;
esac
