#!/bin/bash
# publicar-repositorio.sh — Arma el repositorio de paquetes y lo sube a GitHub.
#
# Convierte la carpeta paquetes/ en un repositorio APT firmado, listo para que
# cualquier cursalialinux lo lea con "apt update". Se publica en GitHub Pages,
# que es gratuito y no necesita servidor propio.
#
# Uso:  bash publicar-repositorio.sh            → arma y sube
#       bash publicar-repositorio.sh --local    → solo arma, no sube
#
# Antes del primer uso hay que rellenar scripts/repositorio.conf
set -u

BASE="$(cd "$(dirname "$0")/.." && pwd)"
CONF="$BASE/scripts/repositorio.conf"
REPO="$BASE/repositorio"
SUITE=trixie
COMPONENTE=main
ARQ=all
SOLO_LOCAL=0
[ "${1:-}" = "--local" ] && SOLO_LOCAL=1

# ── Configuración ────────────────────────────────────────────────────
if [ ! -f "$CONF" ]; then
  cat > "$CONF" <<'EJEMPLO'
# Datos para publicar el repositorio de paquetes.
# Rellena las dos líneas y vuelve a ejecutar publicar-repositorio.sh

# Tu usuario de GitHub (el que sale en la dirección del repositorio)
GITHUB_USUARIO=

# Nombre del repositorio que creaste en GitHub
GITHUB_REPO=cursalialinux

# Identificador de tu clave GPG. Déjalo vacío para usar la primera que haya.
# Se ve con:  gpg --list-secret-keys --keyid-format=long
CLAVE_GPG=
EJEMPLO
  echo "══════════════════════════════════════════════"
  echo " FALTA CONFIGURAR"
  echo "══════════════════════════════════════════════"
  echo
  echo " Acabo de crear este archivo:"
  echo "   $CONF"
  echo
  echo " Ábrelo, pon tu usuario de GitHub y vuelve a ejecutar:"
  echo "   nano $CONF"
  echo
  exit 1
fi

# shellcheck disable=SC1090
. "$CONF"

[ -n "${GITHUB_USUARIO:-}" ] || { echo "ERROR: falta GITHUB_USUARIO en $CONF"; exit 1; }
GITHUB_REPO="${GITHUB_REPO:-cursalialinux}"

# ── Clave de firma ───────────────────────────────────────────────────
if [ -z "${CLAVE_GPG:-}" ]; then
  CLAVE_GPG=$(gpg --list-secret-keys --keyid-format=long 2>/dev/null | awk '/^sec/{print $2; exit}' | cut -d/ -f2)
fi
if [ -z "$CLAVE_GPG" ]; then
  echo "ERROR: no tienes ninguna clave GPG."
  echo
  echo "  Créala con:"
  echo "    gpg --batch --gen-key <<EOF"
  echo "    %no-protection"
  echo "    Key-Type: RSA"
  echo "    Key-Length: 4096"
  echo "    Name-Real: cursalialinux"
  echo "    Name-Email: tu-correo@ejemplo.com"
  echo "    Expire-Date: 5y"
  echo "    %commit"
  echo "    EOF"
  exit 1
fi

URL="https://${GITHUB_USUARIO}.github.io/${GITHUB_REPO}"

echo "══════════════════════════════════════════════"
echo " REPOSITORIO DE PAQUETES cursalialinux"
echo "══════════════════════════════════════════════"
echo "  Dirección: $URL"
echo "  Firma con: $CLAVE_GPG"

# ── Estructura ───────────────────────────────────────────────────────
echo
echo "── 1/5 · Ordenando los paquetes ──"
POOL="$REPO/pool/$COMPONENTE"
DIST="$REPO/dists/$SUITE/$COMPONENTE/binary-$ARQ"
mkdir -p "$POOL" "$DIST"

n=0
for d in "$BASE"/paquetes/*.deb; do
  [ -f "$d" ] || continue
  cp -f "$d" "$POOL/"; n=$((n+1))
  printf '   ✅ %s\n' "$(basename "$d")"
done
[ "$n" -gt 0 ] || { echo "   ❌ no hay paquetes en $BASE/paquetes"; echo "      Genera uno con: bash scripts/crear-paquete.sh"; exit 1; }

# ── Índice de paquetes ───────────────────────────────────────────────
echo
echo "── 2/5 · Generando el índice ──"
( cd "$REPO" && dpkg-scanpackages --multiversion pool /dev/null > "dists/$SUITE/$COMPONENTE/binary-$ARQ/Packages" 2>/dev/null )
gzip -9kf "$DIST/Packages"
printf '   ✅ %s paquete(s) indexados\n' "$(grep -c '^Package:' "$DIST/Packages")"

# ── Archivo Release ──────────────────────────────────────────────────
echo
echo "── 3/5 · Describiendo el repositorio ──"
cat > "$REPO/dists/$SUITE/Release" <<REL
Origin: cursalialinux
Label: cursalialinux
Suite: $SUITE
Codename: $SUITE
Architectures: $ARQ amd64
Components: $COMPONENTE
Description: Paquetes propios de cursalialinux
Date: $(date -Ru)
REL

( cd "$REPO/dists/$SUITE" && apt-ftparchive release . >> Release.tmp 2>/dev/null \
  && grep -vE '^(Origin|Label|Suite|Codename|Architectures|Components|Description|Date):' Release.tmp >> Release \
  && rm -f Release.tmp )
echo "   ✅ Release con las sumas de verificación"

# ── Firma ────────────────────────────────────────────────────────────
echo
echo "── 4/5 · Firmando ──"
( cd "$REPO/dists/$SUITE"
  rm -f Release.gpg InRelease
  gpg --default-key "$CLAVE_GPG" --batch --yes -abs -o Release.gpg Release 2>/dev/null
  gpg --default-key "$CLAVE_GPG" --batch --yes --clearsign -o InRelease Release 2>/dev/null )
[ -f "$REPO/dists/$SUITE/InRelease" ] && echo "   ✅ firmado" || { echo "   ❌ no se pudo firmar"; exit 1; }

# La clave pública, para que apt confíe
gpg --export "$CLAVE_GPG" > "$REPO/cursalialinux-archive-keyring.gpg"
echo "   ✅ clave pública exportada"

# ── Página con instrucciones ─────────────────────────────────────────
echo
echo "── 5/5 · Página de instrucciones ──"
cat > "$REPO/index.html" <<HTML
<!doctype html><html lang="es"><meta charset="utf-8">
<title>Repositorio de cursalialinux</title>
<meta name="viewport" content="width=device-width,initial-scale=1">
<style>
 body{font-family:system-ui,sans-serif;max-width:44rem;margin:3rem auto;padding:0 1.2rem;
      line-height:1.7;color:#0A1730;background:#F2F6FA}
 h1{color:#1D4FD8} h2{margin-top:2.2rem;border-top:1px solid #D2DFEE;padding-top:1.4rem}
 pre{background:#0B1524;color:#D6E4F0;padding:1rem;border-radius:7px;overflow-x:auto;font-size:.86rem}
 code{background:#E7EFF8;padding:.1em .35em;border-radius:3px}
 .nota{background:#fff;border:1px solid #D2DFEE;border-radius:7px;padding:1rem 1.2rem}
</style>
<h1>Repositorio de cursalialinux</h1>
<p>Aquí se publican las mejoras de <b>cursalialinux</b>. Una vez añadido,
tu sistema recibe las novedades con <code>apt upgrade</code>, sin reinstalar nada.</p>

<h2>Añadirlo a tu sistema</h2>
<p>Copia y pega esto en una terminal. Solo hace falta una vez:</p>
<pre>sudo mkdir -p /usr/share/keyrings
wget -qO- $URL/cursalialinux-archive-keyring.gpg \\
  | sudo tee /usr/share/keyrings/cursalialinux.gpg > /dev/null

echo "deb [signed-by=/usr/share/keyrings/cursalialinux.gpg] $URL $SUITE $COMPONENTE" \\
  | sudo tee /etc/apt/sources.list.d/cursalialinux.list

sudo apt update
sudo apt install cursalialinux-escritorio</pre>

<h2>Recibir mejoras</h2>
<pre>sudo apt update && sudo apt upgrade</pre>

<div class="nota">
<p><b>¿Qué contiene?</b> El Centro cursalialinux, el Windows Studio, la marca,
la limpieza automática y la documentación en español.</p>
<p>Todo es software libre, construido sobre Debian, KDE, GNU y decenas de
proyectos más.</p>
</div>
</html>
HTML
echo "   ✅ index.html"

# ── Subir ────────────────────────────────────────────────────────────
if [ "$SOLO_LOCAL" -eq 1 ]; then
  echo
  echo "══════════════════════════════════════════════"
  echo " Repositorio armado en: $REPO"
  echo " (no se subió: usaste --local)"
  echo "══════════════════════════════════════════════"
  exit 0
fi

echo
echo "── Subiendo a GitHub ──"
cd "$REPO"
if [ ! -d .git ]; then
  git init -q -b main
  git remote add origin "https://github.com/${GITHUB_USUARIO}/${GITHUB_REPO}.git"
  echo "   repositorio git iniciado"
fi
git add -A
git -c user.name="cursalialinux" -c user.email="dpto.salud10@gmail.com" \
    commit -q -m "Paquetes cursalialinux — $(date '+%Y-%m-%d %H:%M')" 2>/dev/null \
    && echo "   cambios registrados" || echo "   (sin cambios que registrar)"

if git push -u origin main 2>&1 | tail -3; then
  echo
  echo "══════════════════════════════════════════════"
  echo " ✅ PUBLICADO"
  echo "══════════════════════════════════════════════"
  echo
  echo " Instrucciones para tus usuarios:"
  echo "   $URL"
  echo
  echo " GitHub Pages tarda 1-2 minutos en actualizar."
else
  echo
  echo " ⚠️  No se pudo subir. Comprueba que:"
  echo "    · creaste el repositorio en github.com/${GITHUB_USUARIO}/${GITHUB_REPO}"
  echo "    · tienes acceso configurado (token o llave SSH)"
fi
