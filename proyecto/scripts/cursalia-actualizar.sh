#!/bin/bash
# ================================================================
#  Actualizar cursalialinux — un botón, sin comandos
# ================================================================
LOGO="/usr/share/pixmaps/cursalialinux.png"

yad --question --center --class=cursaliacentro --width=480 \
  --window-icon="$LOGO" --image="$LOGO" --image-on-top \
  --title="Actualizar cursalialinux" \
  --text="<big><b>🔄  Actualizar cursalialinux</b></big>

Busca e instala las últimas mejoras y correcciones de seguridad de tu sistema.

• Necesita <b>internet</b>
• Se te pedirá tu <b>contraseña</b>

¿Actualizar ahora?" \
  --button="Cancelar:1" --button="Actualizar:0" || exit 0

xfce4-terminal --title="Actualizar cursalialinux" --hold -e "bash -c '
  echo \"════════════════════════════════════════\"
  echo \"   Actualizando cursalialinux...\"
  echo \"════════════════════════════════════════\"; echo
  echo \"Se te pedirá tu contraseña de administrador.\"; echo
  if pkexec sh -c \"apt-get update && apt-get -y upgrade\"; then
    echo; echo \"✅  Listo. Tu sistema está al día.\"
  else
    echo; echo \"⚠️  No se pudo completar. Revisa tu conexión a internet.\"
  fi
  echo; echo \"Puedes cerrar esta ventana.\"
'"
