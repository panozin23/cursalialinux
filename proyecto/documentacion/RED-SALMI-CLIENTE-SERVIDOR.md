# Varios consultorios trabajando a la vez

Cómo montar SALMI, SOAPS o SNIS para que varias personas metan información
al mismo tiempo, cada una desde su computadora, sin estorbarse.

---

## La idea

Un puesto guarda la información de todos. Los demás se conectan a él.

```
        🖥️ SERVIDOR — el que no se mueve
           Windows con la base de datos
                     ▲
        ┌────────────┼────────────┐
        │            │            │
    💻 puesto 2  💻 puesto 3  💻 puesto 4
```

Quién puede editar y quién solo meter consultas **lo decide el programa**, con
sus usuarios y perfiles. No es cosa del sistema. Un mismo usuario administrador
puede entrar desde cualquier puesto.

---

## Quién debe ser el servidor

**La máquina que nunca se mueve de sitio.**

Si el servidor fuera un portátil que alguien se lleva, los demás puestos se
quedan sin base de datos en cuanto salga por la puerta.

Y tiene que ir **por cable**. La red en puente no funciona por wifi: los puntos
de acceso rechazan el tráfico de la máquina virtual. Los clientes sí pueden ir
por wifi sin ningún problema.

---

## El problema que hay que resolver

De fábrica, cada Windows virtual vive escondido dentro de su cursalialinux, en
una red privada propia:

```
🖥️ escritorio 192.168.1.100        💻 portátil 192.168.1.101
   └ Windows 192.168.122.x            └ Windows 192.168.122.x
       ↑ invisible desde fuera            ↑ invisible desde fuera
```

Las direcciones se parecen pero no son la misma red. Es como dos casas con el
mismo número en calles distintas.

La solución es la **red en puente**: que el Windows del servidor salga a la red
del centro con su propia dirección, como una computadora más enchufada al
router.

```
🖥️ escritorio                      💻 portátil
   └ Windows 192.168.1.50 ←────────── Windows (en red privada)
       SALMI servidor                    SALMI cliente
```

**Solo el servidor necesita el puente.** Los clientes salen hacia afuera y con
eso les basta.

---

## Cómo se hace

En la máquina que será servidor:

```bash
# Primero mira e informa, sin tocar nada
sudo bash cursalia-modo-servidor.sh

# Cuando estés conforme
sudo bash cursalia-modo-servidor.sh --aplicar
```

Desde otro equipo, siguiendo la regla de oro:

```bash
scp cursalia-modo-servidor.sh usuario@IP:~/
ssh -t usuario@IP 'sudo bash ~/cursalia-modo-servidor.sh'
```

### Qué deja hecho

| | Por qué |
|---|---|
| Red en puente | para que los demás consultorios lo vean |
| Windows arranca solo | sin depender de que alguien lo encienda |
| El equipo no se duerme | un servidor dormido deja a todos sin base |
| SSH abierto en la red local | para administrarlo a distancia |

Guarda una copia de la máquina virtual en `/var/backups/cursalialinux/` antes de
tocar nada, y al terminar imprime cómo deshacerlo.

> **La máquina virtual tiene que estar apagada.** Si está encendida, el script
> se salta el paso de la red y te avisa. Apágala desde dentro de Windows
> (Inicio → Apagar) y vuelve a ejecutarlo.

---

## Después, dentro de Windows

Un servidor no puede cambiar de número.

```
Configuración → Red e Internet → Ethernet
Asignación de IP → Editar → Manual → IPv4 activado

Dirección IP        192.168.1.50
Máscara             255.255.255.0
Puerta de enlace    192.168.1.1
DNS                 192.168.1.1
```

Elige un número **fuera del rango que reparte el router**. Si las máquinas del
centro reciben `.100`, `.101`, `.102`…, entonces el `.50` está libre y nadie te
lo va a quitar.

### La prueba

Desde otra computadora de la red:

```bash
ping -c3 192.168.1.50
```

Si responde, ya está. Los clientes pueden conectarse.

---

## Dos cosas que confunden

### El servidor no puede hacerse ping a sí mismo

Después del cambio, la propia máquina anfitriona **no puede** hacer ping a su
Windows. Es normal y no estorba.

| Desde | ¿Ve al Windows del servidor? |
|---|---|
| Otras computadoras de la red | ✅ sí |
| La propia máquina anfitriona | ❌ no — pero no le hace falta |

Esa máquina usa su Windows por la ventana de siempre, no por la red. Y **Equipos
en Red sigue funcionando**, porque se conecta al cursalialinux, no al Windows.

### Windows tarda la primera vez

Al estrenar tarjeta de red, el primer arranque es más lento: está buscando
dirección. Solo la primera vez.

Y si Windows tenía actualizaciones pendientes, las instalará al apagarse y al
encenderse. Puede tardar media hora. **No lo interrumpas** — interrumpir ahí sí
puede dañar el sistema.

---

## Deshacerlo

El script imprime las tres órdenes exactas al terminar. En resumen:

```bash
sudo virsh define /var/backups/cursalialinux/MAQUINA-FECHA.xml
sudo virsh autostart --disable MAQUINA
sudo systemctl unmask sleep.target suspend.target \
                      hibernate.target hybrid-sleep.target
```

---

## Sobre quitarle programas al servidor

**No hace falta, y sale caro.**

Los estudios de cursalialinux son sobre todo accesos en el menú; lo que pesa son
los programas, y se comparten entre estudios. Desinstalar libera poco y arrastra
dependencias compartidas que un día te tumban algo que sí usabas — en la máquina
que guarda la información de todo el centro.

Un servidor no se define por tener poco software, sino por **estar siempre
disponible**. Eso es lo que arregla el modo servidor.

Si el menú estorba, en KDE se ocultan entradas con un clic. Reversible y sin
desinstalar nada.
