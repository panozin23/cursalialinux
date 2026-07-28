#!/bin/bash
# ================================================================
#  Fecha y hora cursalialinux — ventana amigable (sin comandos)
# ================================================================
LOGO="/usr/share/pixmaps/cursalialinux.png"
SELF="/usr/local/bin/cursalia-fechahora"

ahora_txt() { date "+%A %d de %B de %Y  —  %H:%M"; }

ntp_estado() {
  if timedatectl show -p NTP --value 2>/dev/null | grep -qi yes; then echo "ACTIVA (internet)"; else echo "manual"; fi
}

ajustar_manual() {
  # Elegir fecha con calendario + hora con campos
  HOY=$(date +%d); MES=$(date +%m); ANIO=$(date +%Y)
  HORA=$(date +%H); MIN=$(date +%M)
  SEL=$(yad --form --center --width=420 --class=cursaliacentro \
        --window-icon="$LOGO" --image="$LOGO" --image-on-top \
        --title="Ajustar fecha y hora" \
        --text="<b>Elige la fecha y la hora correctas:</b>" \
        --field="Fecha:CAL" "$(date +%m/%d/%Y)" \
        --field="Hora (0-23)::NUM" "$HORA!0..23!1" \
        --field="Minutos::NUM" "$MIN!0..59!1" \
        --date-format="%m/%d/%Y" --separator="|") || return
  FECHA=$(echo "$SEL" | cut -d'|' -f1)   # mm/dd/aaaa
  H=$(echo "$SEL" | cut -d'|' -f2); M=$(echo "$SEL" | cut -d'|' -f3)
  MM=$(echo "$FECHA" | cut -d/ -f1); DD=$(echo "$FECHA" | cut -d/ -f2); YYYY=$(echo "$FECHA" | cut -d/ -f3)
  H=$(printf "%02d" "$H"); M=$(printf "%02d" "$M")
  # formato date: MMDDhhmmYYYY  (sin comillas ni espacios -> a prueba de teclado)
  STAMP="${MM}${DD}${H}${M}${YYYY}"
  pkexec sh -c "timedatectl set-ntp false 2>/dev/null; date ${STAMP} && hwclock --systohc 2>/dev/null" 2>/dev/null
  yad --info --center --width=420 --class=cursaliacentro --window-icon="$LOGO" --image="$LOGO" \
      --title="Fecha y hora" --text="<b>✅ Hora ajustada</b>\n\nAhora: <b>$(ahora_txt)</b>" --button="OK:0"
}

hora_automatica() {
  pkexec sh -c "timedatectl set-ntp true 2>/dev/null; systemctl enable --now systemd-timesyncd 2>/dev/null" 2>/dev/null
  sleep 2
  yad --info --center --width=440 --class=cursaliacentro --window-icon="$LOGO" --image="$LOGO" \
      --title="Fecha y hora" \
      --text="<b>🌐 Hora automática activada</b>\n\nCon internet, la hora se corrige sola.\n\nAhora: <b>$(ahora_txt)</b>" --button="OK:0"
}

zona_horaria() {
  Z=$(yad --list --center --width=420 --height=460 --class=cursaliacentro \
        --window-icon="$LOGO" --title="Zona horaria" \
        --text="<b>Elige tu zona horaria:</b>" \
        --column="Zona" --no-headers \
        America/La_Paz America/Lima America/Bogota America/Caracas \
        America/Santiago America/Argentina/Buenos_Aires America/Asuncion \
        America/Montevideo America/Guayaquil America/Mexico_City \
        America/Managua America/Costa_Rica America/Panama America/El_Salvador \
        America/Guatemala America/Tegucigalpa America/Santo_Domingo \
        America/Havana Europe/Madrid) || return
  pkexec timedatectl set-timezone "$Z" 2>/dev/null
  yad --info --center --width=420 --class=cursaliacentro --window-icon="$LOGO" --image="$LOGO" \
      --title="Zona horaria" --text="<b>✅ Zona: $Z</b>\n\nAhora: <b>$(ahora_txt)</b>" --button="OK:0"
}

menu() {
  pkill -f "class=cursaliacentro" 2>/dev/null; sleep 0.15
  yad --class=cursaliacentro --title="Fecha y hora cursalialinux" --center --width=560 --height=420 \
    --window-icon="$LOGO" --image="$LOGO" --image-on-top \
    --text="<big><b>🕐  Fecha y hora</b></big>
Ahora: <b>$(ahora_txt)</b>
Modo: <b>$(ntp_estado)</b>

Elige una opción:" \
    --form --columns=1 \
    --field="🌐  Hora automática por internet (recomendado)!appointment-new:fbtn"  "bash -c '$SELF auto &'" \
    --field="🕐  Ajustar fecha y hora a mano!document-edit:fbtn"                   "bash -c '$SELF manual &'" \
    --field="🌎  Cambiar zona horaria!preferences-system-time:fbtn"                "bash -c '$SELF zona &'" \
    --button="Cerrar:1"
}

case "$1" in
  manual) ajustar_manual ;;
  auto)   hora_automatica ;;
  zona)   zona_horaria ;;
  *)      menu ;;
esac
