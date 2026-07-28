#!/bin/bash
# cursalia-icono-menu.sh — Pone el logo de cursalialinux en el botón del menú.
#
# El lanzador de aplicaciones de Plasma (kickoff) pide el icono
# «start-here-kde». El tema Papirus lo tiene, pero es el genérico de KDE
# —los tres puntitos y el signo de mayor—, así que sale ese en vez del logo.
#
# Este script busca el kickoff dentro de la configuración del panel y le
# cambia solo esa clave. No toca nada más: ni widgets, ni fondos, ni el
# orden de la barra.
#
# Se ejecuta UNA VEZ en el primer inicio de sesión. Después se marca como
# hecho y no vuelve a molestar, para que quien prefiera otro icono lo pueda
# cambiar sin que se lo reviertan.
#
# Uso:  cursalia-icono-menu.sh           → solo si no se hizo antes
#       cursalia-icono-menu.sh --forzar  → aplicarlo de nuevo
set -u

ICONO="cursalialinux"
CONFIG="$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"
TESTIGO="$HOME/.config/cursalialinux-icono-menu.hecho"

[ "${1:-}" = "--forzar" ] && rm -f "$TESTIGO"

[ -f "$TESTIGO" ] && { echo "» ya se aplicó antes (usa --forzar para repetir)"; exit 0; }
[ -f "$CONFIG" ]  || { echo "» todavía no hay configuración de panel; se intentará en el próximo inicio"; exit 0; }

# ── Localizar el kickoff ─────────────────────────────────────────────
# Los números de contenedor y applet cambian en cada instalación, así que
# hay que buscarlos en vez de darlos por sabidos.
GRUPO=$(grep -B3 '^plugin=org\.kde\.plasma\.kickoff$' "$CONFIG" \
        | grep -oE '^\[Containments\]\[[0-9]+\]\[Applets\]\[[0-9]+\]$' | head -1)

if [ -z "$GRUPO" ]; then
  echo "» no encuentro el lanzador de aplicaciones en el panel; no hago nada"
  exit 0
fi

CONT=$(echo "$GRUPO" | sed -E 's/.*Containments\]\[([0-9]+)\].*/\1/')
APP=$(echo  "$GRUPO" | sed -E 's/.*Applets\]\[([0-9]+)\].*/\1/')

echo "» lanzador encontrado: contenedor $CONT, applet $APP"

# ── Aplicar el icono ─────────────────────────────────────────────────
ESCRIBIR=$(command -v kwriteconfig6 || command -v kwriteconfig5 || true)

if [ -n "$ESCRIBIR" ]; then
  "$ESCRIBIR" --file "$CONFIG" \
    --group Containments --group "$CONT" \
    --group Applets --group "$APP" \
    --group Configuration --group General \
    --key icon "$ICONO"
  echo "» icono cambiado a «$ICONO»"
else
  echo "» falta kwriteconfig; no se pudo aplicar"
  exit 1
fi

touch "$TESTIGO"

# ── Refrescar el panel si la sesión ya está en marcha ─────────────────
if [ -n "${KDE_FULL_SESSION:-}" ] && command -v qdbus6 >/dev/null 2>&1; then
  qdbus6 org.kde.plasmashell /PlasmaShell refreshCurrentShell 2>/dev/null \
    || echo "» cierra sesión y vuelve a entrar para verlo"
else
  echo "» se verá en el próximo inicio de sesión"
fi
