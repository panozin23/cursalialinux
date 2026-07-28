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
