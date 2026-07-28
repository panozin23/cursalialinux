#!/bin/bash
# subir-proyecto.sh — Sube el código fuente de cursalialinux a GitHub.
#
# En el repositorio ya viajaban los paquetes .deb. Esto añade lo que los
# genera: scripts, documentación, recetas y marca. Va en una carpeta
# aparte, «proyecto/», para no mezclarse con el repositorio APT.
#
# Uso:  bash subir-proyecto.sh
#
# Qué NO sube (y por qué):
#   cocina/      15 GB de chroots — no cabe ni tiene sentido
#   isos/        las imágenes de 3,5 GB
#   repositorio/ es el destino, no el origen
#   *.iso        binarios grandes; el de VirtIO se regenera con su script
#
# No necesita sudo.
set -u

BASE="$(cd "$(dirname "$0")/.." && pwd)"
REPO="$BASE/repositorio"
DESTINO="$REPO/proyecto"

[ -d "$REPO/.git" ] || { echo "ERROR: falta el repositorio git en $REPO"; \
  echo "  Ejecuta antes:  bash scripts/publicar-repositorio.sh"; exit 1; }

echo "══════════════════════════════════════════════"
echo " SUBIR EL CÓDIGO FUENTE A GITHUB"
echo "══════════════════════════════════════════════"

mkdir -p "$DESTINO"

echo
echo "── Copiando ──"
for c in scripts documentacion recetas plasmoides; do
  [ -d "$BASE/$c" ] || continue
  rsync -a --delete \
    --exclude '*.iso' --exclude '*.deb' --exclude '*.tar*' \
    --exclude '*.antes-de-*' --exclude '*.qcow2' \
    "$BASE/$c" "$DESTINO/"
  printf '   ✅ %-16s %s\n' "$c" "$(du -sh "$DESTINO/$c" | cut -f1)"
done

# La marca sin el CD de VirtIO, que son 52 MB y se regenera solo
rsync -a --delete --exclude '*.iso' "$BASE/marca" "$DESTINO/"
printf '   ✅ %-16s %s\n' "marca" "$(du -sh "$DESTINO/marca" | cut -f1)"

cp -f "$BASE/VERSION" "$DESTINO/" 2>/dev/null
cp -f "$BASE/../LEEME.md" "$DESTINO/" 2>/dev/null
echo "   ✅ VERSION y LEEME.md"

# ── Explicación para quien llegue al repositorio ─────────────────────
cat > "$DESTINO/LEEME.md" <<'DOC'
# cursalialinux — código fuente

Aquí vive lo que construye la distribución. Los paquetes ya compilados están
en la raíz de este mismo repositorio, servidos como repositorio APT.

## Qué hay en cada carpeta

| Carpeta | Contenido |
|---|---|
| `scripts/` | Constructores de la ISO, el Centro, el Windows Studio y las herramientas `cursalia-*` |
| `documentacion/` | Guías en español: virtualización, licencias, seguridad, créditos |
| `recetas/` | Configuración de las ediciones Moderna (KDE) y Ligera (XFCE) |
| `marca/` | Logos, hoja de estilo, esquema de color, diapositivas del instalador |
| `plasmoides/` | Widgets propios para el escritorio |

## Qué NO está aquí

- `cocina/` — los chroots, 15 GB
- `isos/` — las imágenes construidas, 3,5 GB cada una
- `marca/virtio-cursalia.iso` — 52 MB de controladores; se regenera con
  `scripts/crear-virtio-reducido.sh`

## Instalar la distribución

No hace falta clonar nada. Las instrucciones están en
<https://panozin23.github.io/cursalialinux/>

## Licencia

Software libre, principalmente GPL y LGPL. Construido sobre Debian, KDE, GNU
y decenas de proyectos más — ver `documentacion/CREDITOS.md`.
DOC

# Que git ignore lo pesado aunque alguien lo copie por error
cat > "$REPO/.gitignore" <<'IGN'
# Binarios grandes: no van a GitHub
*.qcow2
proyecto/**/*.iso
proyecto/**/*.tar.*
# Respaldos de trabajo
*.antes-de-*
IGN

echo
echo "── Subiendo ──"
cd "$REPO"
git add -A
if git -c user.name="cursalialinux" -c user.email="dpto.salud10@gmail.com" \
      commit -q -m "Código fuente — $(date '+%Y-%m-%d %H:%M')" 2>/dev/null; then
  echo "   cambios registrados"
else
  echo "   (sin cambios que registrar)"
fi

if git push origin main 2>&1 | tail -2; then
  echo
  echo "══════════════════════════════════════════════"
  echo " ✅ SUBIDO"
  echo "══════════════════════════════════════════════"
  echo
  echo " Código fuente:"
  echo "   https://github.com/panozin23/cursalialinux/tree/main/proyecto"
  echo
  echo " Peso total: $(du -sh "$DESTINO" | cut -f1)"
else
  echo "   ⚠️  no se pudo subir. ¿Sigue funcionando la llave SSH?"
fi
