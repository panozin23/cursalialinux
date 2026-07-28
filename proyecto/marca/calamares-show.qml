/* ============================================================
   Diapositivas del instalador — cursalialinux 1.1
   ============================================================
   Criterio de los textos:
     · Hablarle a la persona, en segunda persona y de lo que ella gana.
     · No comparar con nadie ni hablar mal de ninguna plataforma.
     · Frases cortas, cálidas y fáciles de leer de un vistazo.

   Cada diapositiva lleva su color de la paleta Azul Hielo, para que
   se note el cambio sin necesidad de leer.
   ============================================================ */

import QtQuick 2.0;
import calamares.slideshow 1.0;

Presentation
{
    id: presentation

    Timer {
        interval: 10000
        running: true
        repeat: true
        onTriggered: presentation.goToNextSlide()
    }

    /* ---------- 1 · Bienvenida ---------- */
    Slide {
        Image {
            id: logo1
            source: "cursalia-logo.png"
            width: 150; height: 150
            fillMode: Image.PreserveAspectFit
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -110
        }
        Text {
            anchors.horizontalCenter: logo1.horizontalCenter
            anchors.top: logo1.bottom
            anchors.topMargin: 24
            text: qsTr("<b><font size='+3' color='#1D4FD8'>Bienvenido a cursalialinux</font></b><br/><br/>"+
                  "Un sistema rápido, en español y hecho en Bolivia.<br/><br/>"+
                  "Está pensado para que empieces a trabajar<br/>"+
                  "desde el primer día, sin configurar nada.")
            wrapMode: Text.WordWrap
            width: 700
            horizontalAlignment: Text.AlignHCenter
            color: "#0A1730"
            font.pixelSize: 19
            lineHeight: 1.4
        }
    }

    /* ---------- 2 · Windows Studio ---------- */
    Slide {
        Image {
            id: logo2
            source: "cursalia-logo.png"
            width: 135; height: 135
            fillMode: Image.PreserveAspectFit
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -120
        }
        Text {
            anchors.horizontalCenter: logo2.horizontalCenter
            anchors.top: logo2.bottom
            anchors.topMargin: 22
            text: qsTr("<b><font size='+3' color='#1D4FD8'>Tus programas siguen contigo</font></b><br/><br/>"+
                  "Si en tu trabajo usas programas de Windows,<br/>"+
                  "aquí los puedes seguir usando: se abren en<br/>"+
                  "una ventana más de tu escritorio.<br/><br/>"+
                  "Sin reiniciar y sin complicaciones.<br/><br/>"+
                  "<font color='#0B7C93'>Lo encuentras como <b>Windows Studio</b><br/>"+
                  "en el Centro cursalialinux.</font>")
            wrapMode: Text.WordWrap
            width: 720
            horizontalAlignment: Text.AlignHCenter
            color: "#0A1730"
            font.pixelSize: 18
            lineHeight: 1.36
        }
    }

    /* ---------- 3 · Desarrollo web ---------- */
    Slide {
        Image {
            id: logo3
            source: "cursalia-logo.png"
            width: 135; height: 135
            fillMode: Image.PreserveAspectFit
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -118
        }
        Text {
            anchors.horizontalCenter: logo3.horizontalCenter
            anchors.top: logo3.bottom
            anchors.topMargin: 22
            text: qsTr("<b><font size='+3' color='#1D4FD8'>Listo para crear tu próxima web</font></b><br/><br/>"+
                  "Tu editor de código, PHP, Node.js, Python,<br/>"+
                  "Git y Docker ya vienen preparados.<br/><br/>"+
                  "Con un clic creas un proyecto <b>Laravel</b> o<br/>"+
                  "levantas un <b>WordPress</b> en tu propia máquina.<br/><br/>"+
                  "<font color='#0B7C93'>Empiezas a programar, no a configurar.</font>")
            wrapMode: Text.WordWrap
            width: 720
            horizontalAlignment: Text.AlignHCenter
            color: "#0A1730"
            font.pixelSize: 18
            lineHeight: 1.36
        }
    }

    /* ---------- 4 · Creación de contenido ---------- */
    Slide {
        Image {
            id: logo4
            source: "cursalia-logo.png"
            width: 135; height: 135
            fillMode: Image.PreserveAspectFit
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -118
        }
        Text {
            anchors.horizontalCenter: logo4.horizontalCenter
            anchors.top: logo4.bottom
            anchors.topMargin: 22
            text: qsTr("<b><font size='+3' color='#1D4FD8'>Todo para que crees lo tuyo</font></b><br/><br/>"+
                  "<b>Video</b> — edita, graba tu pantalla y ponle subtítulos.<br/>"+
                  "<b>Imágenes</b> — diseña, retoca fotos y crea tus logos.<br/>"+
                  "<b>Audio</b> — graba, mezcla y produce tu música.<br/><br/>"+
                  "<font color='#0B7C93'>Herramientas profesionales, ya incluidas.</font>")
            wrapMode: Text.WordWrap
            width: 730
            horizontalAlignment: Text.AlignHCenter
            color: "#0A1730"
            font.pixelSize: 18
            lineHeight: 1.36
        }
    }

    /* ---------- 5 · Cierre ---------- */
    Slide {
        Image {
            id: logo5
            source: "cursalia-logo.png"
            width: 150; height: 150
            fillMode: Image.PreserveAspectFit
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -112
        }
        Text {
            anchors.horizontalCenter: logo5.horizontalCenter
            anchors.top: logo5.bottom
            anchors.topMargin: 24
            text: qsTr("<b><font size='+3' color='#1D4FD8'>Este sistema es tuyo</font></b><br/><br/>"+
                  "Úsalo con libertad: instálalo en los equipos que<br/>"+
                  "quieras, compártelo con tu familia, con tu oficina<br/>"+
                  "o con quien lo necesite.<br/><br/>"+
                  "Y cuando tengas dudas, el <b>Centro cursalialinux</b><br/>"+
                  "te acompaña paso a paso.<br/><br/>"+
                  "<font color='#0B7C93'><b>Ya casi está. Bienvenido.</b></font>")
            wrapMode: Text.WordWrap
            width: 720
            horizontalAlignment: Text.AlignHCenter
            color: "#0A1730"
            font.pixelSize: 19
            lineHeight: 1.4
        }
    }
}
