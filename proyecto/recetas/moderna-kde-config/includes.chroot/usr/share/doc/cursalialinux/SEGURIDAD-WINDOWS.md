# Proteger un Windows sin soporte dentro de cursalialinux

Qué protege de verdad a un Windows 7, 8.1 o 10 que ya no recibe parches, y qué
solo lo parece. Escrito el 2026-07-26.

---

## Lo primero: el antivirus no arregla el problema

Hay que decirlo claro porque es la confusión más extendida.

Un antivirus **revisa archivos** buscando programas maliciosos conocidos. Lo hace
bien y es útil. Pero un sistema sin parches no tiene un problema de archivos:
tiene **agujeros en el propio sistema** —en cómo maneja la red, el protocolo de
compartir carpetas, el navegador— que Microsoft ya no va a tapar.

Un atacante que aprovecha uno de esos agujeros **no necesita que abras ningún
archivo**. El antivirus no ve nada raro porque no hay nada raro que ver: solo hay
una puerta que quedó abierta para siempre.

> El antivirus es la cerradura de la puerta. El parche que falta es la ventana
> rota del baño. Poner mejor cerradura no cierra la ventana.

Eso no significa que no sirva de nada — sí ayuda contra lo que descargas tú. Pero
si es tu única protección, estás mal cubierto.

---

## La buena noticia: ya tienes una protección fuerte

La red virtual por defecto de libvirt (`default`) funciona en modo **NAT**:

```bash
virsh -c qemu:///system net-dumpxml default | grep forward
#   <forward mode='nat'>
```

Eso significa que la máquina virtual está **detrás de una barrera**, igual que tu
computadora detrás del router de casa. Puede salir a internet, pero **nadie desde
internet puede iniciar una conexión hacia ella**.

Esto elimina de golpe toda una familia de ataques: los que buscan máquinas
vulnerables por internet y se conectan solos. Esos, sencillamente, no llegan.

**Lo que sí queda como riesgo:**

- Lo que descargues o abras tú dentro de Windows
- Páginas web maliciosas si navegas con un navegador viejo
- Otros equipos de tu red local, si alguno está infectado

---

## Las protecciones que de verdad funcionan, por orden

### 1. Cortarle internet cuando no lo necesita ⭐ la más eficaz

Un sistema sin red no es atacable por red. Punto.

La mayoría de programas antiguos —facturación, laboratorio, sistemas
institucionales de escritorio— **nunca necesitaron internet** para funcionar.

Usa el **Panel de Windows** (`cursalia-windows-control.sh`): un botón corta y otro
devuelve la red, en caliente, sin apagar nada.

Y para pasarle archivos sin red, el mismo panel crea un **CD virtual** desde
cualquier carpeta tuya.

### 2. Instantáneas ⭐ la red de seguridad

Esta es la protección que ningún Windows normal te puede dar.

Tomas una foto del estado completo antes de cualquier cambio. Si algo se infecta o
se rompe, vuelves atrás en segundos y **es como si nunca hubiera pasado**. No hay
que desinfectar nada: el estado malo simplemente deja de existir.

```bash
virsh -c qemu:///system snapshot-create-as NOMBRE estado-limpio "Antes de tocar"
virsh -c qemu:///system snapshot-revert     NOMBRE estado-limpio
```

También está en el Panel, con botones.

**Consejo:** toma una instantánea llamada `recien-instalado` en cuanto termines de
configurar todo. Es tu punto de retorno permanente.

### 3. No usar Windows como administrador

Crea una cuenta normal para el trabajo diario y deja la de administrador solo para
instalar cosas. Muchos programas maliciosos no pueden hacer daño real sin permisos
de administrador.

Es gratis, tarda dos minutos y sigue siendo de lo más efectivo que existe.

### 4. No navegar ni leer correo ahí dentro

El navegador de un Windows sin soporte es el punto más débil de todo el conjunto.

**Navega en cursalialinux**, que sí recibe parches, y usa la máquina virtual
únicamente para el programa que la justifica. Si necesitas descargar algo para
Windows, bájalo en Linux y pásaselo por el CD virtual.

### 5. El cortafuegos del anfitrión

cursalialinux ya trae **ufw** activado. Como todo el tráfico de la máquina virtual
pasa por Linux, puedes filtrarlo desde fuera — algo que ningún programa dentro de
Windows podría desactivar aunque estuviera infectado.

Es una capa avanzada; para la mayoría, cortar la red cuando no se usa da mejor
resultado con mucho menos trabajo.

---

## Y entonces, ¿pongo antivirus o no?

Sí, como **complemento**, nunca como única defensa. Pero antes revisa esto:

### Microsoft Defender (ya viene incluido)

En Windows 8, 8.1, 10 y 11 viene de fábrica. Es razonable y no cuesta nada.

**Pero comprueba si sigue recibiendo definiciones.** Microsoft las fue retirando
para los sistemas sin soporte, y un antivirus sin definiciones actualizadas es
prácticamente decorativo. En Windows: *Seguridad de Windows → Protección
antivirus → ver la fecha de la última actualización*.

Si esa fecha es de hace meses, ya no te está protegiendo de nada nuevo.

### En Windows 7

Microsoft Security Essentials fue descontinuado. Habría que recurrir a alguno de
los antivirus gratuitos de terceros que **todavía** soporten Windows 7 — cada vez
son menos, y conviene verificarlo en su web antes de instalar nada.

### Antivirus gratuitos de terceros

Existen varias opciones sin costo para uso personal. Antes de elegir:

- Comprueba **en su sitio oficial** que aún soporten tu versión de Windows
- Ojo con las versiones «gratuitas» que instalan barras de navegador o pantallas
  de publicidad constante
- Uno solo. **Dos antivirus a la vez se estorban** y dejan el sistema más lento y
  menos protegido, no más

### ClamAV / ClamWin

Libre y gratuito. Su protección en tiempo real es floja comparada con las
alternativas comerciales, pero para revisar archivos concretos antes de abrirlos
cumple, y no tiene publicidad ni sorpresas.

---

## La receta práctica

Para un Windows 7 u 8.1 que solo usas para un programa de trabajo:

1. Instala Windows y el programa que necesitas
2. Crea una **cuenta de usuario normal** para el día a día
3. Toma una instantánea: `recien-instalado`
4. **Corta la red** desde el Panel
5. Pásale archivos con el **CD virtual** cuando haga falta
6. Cuando necesites internet un rato: instantánea → conectar → hacer solo eso →
   desconectar
7. Deja Defender activo si aún recibe definiciones; si no, un antivirus gratuito
   que sí soporte esa versión

Con eso tienes un sistema antiguo **aislado, reversible y usable**, corriendo
dentro de un Linux moderno que sí recibe parches.

---

## Lo que la virtualización te da y ninguna otra cosa te da

| Riesgo | En un equipo con Windows viejo | En cursalialinux con máquina virtual |
|---|---|---|
| Se infecta | Reinstalar todo, horas | Volver a la instantánea, segundos |
| Ataques desde internet | Expuesto directo | Detrás de NAT, o sin red |
| Contagia al resto | Sí, es el mismo equipo | No: tu Linux está fuera de esa caja |
| Probar algo dudoso | Te la juegas | Instantánea antes, y listo |
| Navegar seguro | Con el navegador viejo | Navegas en Linux, actualizado |

El punto no es que la máquina virtual sea invulnerable. Es que **cuando falla, no
te cuesta nada**. Y esa diferencia lo cambia todo.
