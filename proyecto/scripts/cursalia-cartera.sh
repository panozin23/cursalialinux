#!/bin/bash
# cursalia-cartera.sh — Arregla la ventana «Servicio de cartera de KDE»
#
# EL PROBLEMA
#   Al abrir VS Code, el correo o el navegador, KDE pregunta:
#     «La aplicación X ha solicitado abrir la cartera kdewallet.
#      Introduzca la contraseña de esta cartera.»
#
# POR QUÉ PASA
#   La cartera guarda las contraseñas cifradas. Al iniciar sesión, el
#   módulo pam_kwallet5 intenta abrirla con la MISMA contraseña con la
#   que entras al sistema. Si la cartera se creó a mano con otra clave
#   —o si cambiaste tu contraseña de usuario después— ya no coinciden,
#   PAM no puede abrirla y KDE la pide a mano cada vez.
#
#   En el registro se ve así:
#     kwalletd: Failed to open wallet "kdewallet" "Error de lectura -
#               posiblemente contraseña incorrecta."
#
# QUÉ HACE ESTE GUION
#   Paso 1 (por defecto): solo MIRA y explica el estado. No toca nada.
#   Paso 2 (--reparar):   respalda la cartera, la retira y deja que PAM
#                         cree una nueva sincronizada con tu contraseña
#                         de inicio de sesión.
#
# NO NECESITA SUDO: todo ocurre dentro de tu carpeta personal.
set -u

CARTERAS="$HOME/.local/share/kwalletd"
RESPALDOS="$HOME/.local/share/kwalletd-respaldos"
FECHA=$(date +%Y%m%d-%H%M%S)

azul(){ printf '\033[1;34m%s\033[0m\n' "$*"; }
ok(){   printf '   ✅ %s\n' "$*"; }
mal(){  printf '   ❌ %s\n' "$*"; }
avi(){  printf '   ⚠️  %s\n' "$*"; }

echo
azul "══════════════════════════════════════════════"
azul " CARTERA DE CONTRASEÑAS DE KDE"
azul "══════════════════════════════════════════════"
echo

# ── 1. ¿Está el módulo de PAM instalado? ─────────────────────────────
echo "── El desbloqueo automático ──"
if [ -f /usr/lib/x86_64-linux-gnu/security/pam_kwallet5.so ]; then
  ok "módulo pam_kwallet5 instalado"
else
  mal "falta el paquete libpam-kwallet5"
  echo "      Instálalo con:  sudo apt install libpam-kwallet5"
fi

if grep -q "pam_kwallet5.so" /etc/pam.d/sddm 2>/dev/null; then
  ok "SDDM tiene activado el desbloqueo al iniciar sesión"
else
  mal "SDDM no llama a pam_kwallet5 (faltan líneas en /etc/pam.d/sddm)"
fi

if systemctl --user is-active plasma-kwallet-pam.service >/dev/null 2>&1 ||
   journalctl --user -b 2>/dev/null | grep -q "plasma-kwallet-pam"; then
  ok "el servicio de desbloqueo arrancó en esta sesión"
else
  avi "el servicio de desbloqueo no aparece en esta sesión"
fi
echo

# ── 2. ¿Qué carteras hay? ────────────────────────────────────────────
echo "── Tus carteras ──"
if [ -d "$CARTERAS" ] && ls "$CARTERAS"/*.kwl >/dev/null 2>&1; then
  for c in "$CARTERAS"/*.kwl; do
    printf '   📁 %s  (%s, creada el %s)\n' \
      "$(basename "$c" .kwl)" "$(du -h "$c" | cut -f1)" \
      "$(date -r "$c" +%d/%m/%Y)"
  done
else
  ok "no hay ninguna cartera todavía: PAM creará una correcta al entrar"
  echo
  exit 0
fi
echo

# ── 3. ¿Falló la apertura en esta sesión? ────────────────────────────
echo "── Qué dice el registro de hoy ──"
FALLO=$(journalctl --user -b 2>/dev/null | grep -c "Failed to open wallet" || true)
if [ "${FALLO:-0}" -gt 0 ]; then
  mal "la cartera NO se pudo abrir con la contraseña de inicio ($FALLO intentos)"
  echo "      Por eso te sale la ventana pidiendo la contraseña."
  DESAJUSTE=si
else
  ok "no hay errores de apertura en esta sesión"
  DESAJUSTE=no
fi
echo

# ── 4. Solo mirar, o reparar ─────────────────────────────────────────
if [ "${1:-}" != "--reparar" ]; then
  azul "── Qué puedes hacer ──"
  echo
  echo " a) Si RECUERDAS la contraseña de la cartera:"
  echo "    abre  kwalletmanager5  →  clic derecho en «kdewallet»  →"
  echo "    «Cambiar contraseña»  →  escribe la MISMA con la que entras"
  echo "    al sistema. Es lo mejor: no se pierde nada."
  echo
  echo " b) Si NO la recuerdas (o te da igual lo que haya dentro):"
  echo "    este guion la respalda y la retira. Al volver a entrar,"
  echo "    KDE crea una nueva ya sincronizada y no vuelve a preguntar."
  echo
  echo "    Ejecuta:   bash $0 --reparar"
  echo
  avi "Se pierden las contraseñas guardadas DENTRO de la cartera"
  echo "      (no las del wifi ni la del usuario: esas viven en otro sitio)."
  echo
  exit 0
fi

# ── 5. Reparación, con confirmación escrita ──────────────────────────
azul "── REPARAR ──"
echo
echo " Se hará esto, por este orden:"
echo "   1. Copia de seguridad en $RESPALDOS"
echo "   2. Cerrar el servicio de carteras (kwalletd6)"
echo "   3. Retirar kdewallet.kwl y kdewallet.salt"
echo "   4. Cerrar sesión y volver a entrar → cartera nueva, sincronizada"
echo
if [ "$DESAJUSTE" = "no" ]; then
  avi "Hoy la cartera NO ha dado errores. ¿Seguro que quieres rehacerla?"
  echo
fi
printf ' Escribe REPARAR para continuar (cualquier otra cosa cancela): '
read -r RESP
if [ "$RESP" != "REPARAR" ]; then
  echo
  echo " Cancelado. No se ha tocado nada."
  exit 0
fi

echo
mkdir -p "$RESPALDOS"
cp -a "$CARTERAS"/. "$RESPALDOS/$FECHA-copia/" 2>/dev/null || {
  mkdir -p "$RESPALDOS/$FECHA-copia"; cp -a "$CARTERAS"/* "$RESPALDOS/$FECHA-copia/"; }
ok "copia guardada en $RESPALDOS/$FECHA-copia"

kquitapp6 kwalletd6 >/dev/null 2>&1 || pkill -u "$USER" kwalletd6 >/dev/null 2>&1 || true
sleep 1
ok "servicio de carteras detenido"

rm -f "$CARTERAS/kdewallet.kwl" "$CARTERAS/kdewallet.salt"
ok "cartera retirada"

echo
azul "══════════════════════════════════════════════"
echo " Falta un paso, y lo tienes que dar tú:"
echo
echo "   CIERRA LA SESIÓN Y VUELVE A ENTRAR"
echo
echo " Al entrar, PAM creará la cartera con tu contraseña de inicio."
echo " A partir de ahí, VS Code y los demás abrirán sin preguntar."
azul "══════════════════════════════════════════════"
echo
