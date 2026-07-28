/* Slideshow del instalador — cursalialinux (logo en TODAS las diapositivas) */

import QtQuick 2.0;
import calamares.slideshow 1.0;

Presentation
{
    id: presentation

    Timer {
        interval: 11000
        running: true
        repeat: true
        onTriggered: presentation.goToNextSlide()
    }

    Slide {
        Image {
            id: logo1
            source: "cursalia-logo.png"
            width: 170; height: 170
            fillMode: Image.PreserveAspectFit
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -95
        }
        Text {
            anchors.horizontalCenter: logo1.horizontalCenter
            anchors.top: logo1.bottom
            anchors.topMargin: 26
            text: qsTr("<b>Bienvenido a cursalialinux Ligera</b><br/><br/>"+
                  "Un sistema rápido y en español, pensado para<br/>"+
                  "desarrolladores web y creadores de contenido.")
            wrapMode: Text.WordWrap
            width: 660
            horizontalAlignment: Text.AlignHCenter
            color: "#0A1730"
            font.pixelSize: 20
        }
    }

    Slide {
        Image {
            id: logo2
            source: "cursalia-logo.png"
            width: 150; height: 150
            fillMode: Image.PreserveAspectFit
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -100
        }
        Text {
            anchors.horizontalCenter: logo2.horizontalCenter
            anchors.top: logo2.bottom
            anchors.topMargin: 26
            text: qsTr("<b>Todo listo para trabajar</b><br/><br/>"+
                  "Navegador, oficina (Word · Excel · PowerPoint),<br/>"+
                  "editores de código, y estudios de video, imagen y audio —<br/>"+
                  "ya vienen instalados.")
            wrapMode: Text.WordWrap
            width: 700
            horizontalAlignment: Text.AlignHCenter
            color: "#0A1730"
            font.pixelSize: 20
        }
    }

    Slide {
        Image {
            id: logo3
            source: "cursalia-logo.png"
            width: 150; height: 150
            fillMode: Image.PreserveAspectFit
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -95
        }
        Text {
            anchors.horizontalCenter: logo3.horizontalCenter
            anchors.top: logo3.bottom
            anchors.topMargin: 26
            text: qsTr("<b>Gracias por elegir cursalialinux</b><br/><br/>"+
                  "La instalación es automática y terminará<br/>"+
                  "en unos minutos.")
            wrapMode: Text.WordWrap
            width: 660
            horizontalAlignment: Text.AlignHCenter
            color: "#2563EB"
            font.pixelSize: 20
        }
    }

}
