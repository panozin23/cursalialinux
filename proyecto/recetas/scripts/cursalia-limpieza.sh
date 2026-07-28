#!/bin/bash
# ================================================================
#  Limpieza cursalialinux — menú de opciones (usuario y root)
# ================================================================
LOGO="/usr/share/pixmaps/cursalialinux.png"
SELF="/usr/local/bin/cursalia-limpieza"
ROOTCLEAN="/usr/local/sbin/cursalia-limpieza-root"

libre_txt() { df -h / | awk 'NR==2{print $4" libres de "$2}'; }
avail_b()   { df --output=avail -B1 / | tail -1; }

resultado() { # $1 título, $2 antes(bytes), $3 después(bytes)
  MB=$(( ($3 - $2) / 1024 / 1024 ))
  [ "$MB" -lt 0 ] && MB=0
  yad --info --center --width=440 --window-icon="$LOGO" --image="$LOGO" \
      --title="Limpieza cursalialinux" \
      --text="<b>$1</b>\n\n🧹 Espacio liberado: <b>~${MB} MB</b>\n💾 Ahora tienes: <b>$(libre_txt)</b>" \
      --button="OK:0"
}

limpiar_usuario() {
  A=$(avail_b)
  rm -rf "$HOME/.local/share/Trash/"* 2>/dev/null
  rm -rf "$HOME/.cache/thumbnails/"* "$HOME/.thumbnails/"* 2>/dev/null
  find "$HOME/.cache" -maxdepth 2 -type d -name "Cache" -exec rm -rf {} + 2>/dev/null
  B=$(avail_b)
  resultado "✅ Limpieza rápida (usuario) terminada" "$A" "$B"
}

limpiar_profunda() {
  A=$(avail_b)
  xfce4-terminal --title="Limpieza profunda (administrador)" --hold -e \
    "bash -c 'echo Se te pedira tu contrasena de administrador...; echo; pkexec $ROOTCLEAN; echo; echo Listo. Cierra esta ventana.'"
  yad --info --center --width=440 --window-icon="$LOGO" --image="$LOGO" \
      --title="Limpieza cursalialinux" \
      --text="<b>🔥 Limpieza profunda</b>\n\nCuando termine en la ventana negra, pulsa OK para ver el espacio libre." --button="OK:0"
  B=$(avail_b)
  resultado "✅ Limpieza profunda (administrador) terminada" "$A" "$B"
}

instalar_bleach() {
  yad --question --center --width=420 --window-icon="$LOGO" --image="$LOGO" \
      --title="BleachBit" --text="<b>BleachBit</b> no está instalado.\n¿Instalarlo ahora? (necesita internet)" || return 1
  xfce4-terminal --title="Instalar BleachBit" --hold -e "bash -c 'pkexec apt-get install -y bleachbit; echo; echo Listo. Cierra esta ventana.'"
  return 1
}

bleach_usuario() {
  if command -v bleachbit >/dev/null 2>&1; then setsid bleachbit >/dev/null 2>&1 &
  else instalar_bleach; fi
}
bleach_root() {
  if command -v bleachbit >/dev/null 2>&1; then setsid pkexec bleachbit >/dev/null 2>&1 &
  else instalar_bleach; fi
}

ver_espacio() {
  yad --info --center --width=480 --window-icon="$LOGO" --image="$LOGO" \
      --title="Espacio en disco" \
      --text="<big><b>💾 $(libre_txt)</b></big>\n\n<tt>$(df -h / | sed -n '1p;2p')</tt>" --button="OK:0"
}

menu() {
  yad --title="Limpieza cursalialinux" --center --width=560 --height=460 \
    --window-icon="$LOGO" --image="$LOGO" --image-on-top \
    --text="<big><b>🧹  Limpieza cursalialinux</b></big>
Mantén tu sistema limpio y con espacio libre.
💾 Ahora: <b>$(libre_txt)</b>

Elige una opción:" \
    --form --columns=1 \
    --field="🧹  Limpieza rápida (mi usuario)!edit-clear:fbtn"            "bash -c '$SELF usuario &'" \
    --field="🔥  Limpieza profunda (administrador)!security-high:fbtn"     "bash -c '$SELF profunda &'" \
    --field="🧴  BleachBit — limpiador avanzado!edit-clear-all:fbtn"       "bash -c '$SELF bleach &'" \
    --field="🛡️  BleachBit como administrador (root)!security-high:fbtn"   "bash -c '$SELF bleachroot &'" \
    --field="📊  Ver espacio en disco!drive-harddisk:fbtn"                 "bash -c '$SELF espacio &'" \
    --button="Cerrar:1"
}

case "$1" in
  usuario)    limpiar_usuario ;;
  profunda)   limpiar_profunda ;;
  bleach)     bleach_usuario ;;
  bleachroot) bleach_root ;;
  espacio)    ver_espacio ;;
  *)          menu ;;
esac
