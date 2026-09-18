import QtQuick
import org.qfield.gui

/*
 * TopoBtn - bouton carré de palette : icône et/ou texte, appui court / appui long,
 * état coché, couleur de fond (vert / orange / rouge pour les mesures).
 */
Rectangle {
  id: btn

  property string text: ""
  property string icon: ""            // URL d'image (PNG du thème) ou ""
  property string emoji: ""           // pictogramme texte si pas d'image
  property bool checked: false
  property bool marker: false         // "main" en bas à droite (appui long = objet)
  property color baseColor: QfTheme.darkTheme ? "#3a3a3a" : "#e6e6e6"
  property color checkedColor: QfTheme.mainColor
  property color textColor: checked ? "white" : (QfTheme.darkTheme ? "#f0f0f0" : "#202020")
  property int fontSize: 11
  property bool small: false
  property alias mouse: area

  signal clicked()
  signal pressAndHold()

  implicitWidth: 56
  implicitHeight: 56
  width: implicitWidth
  height: implicitHeight
  radius: 6
  border.width: 1
  border.color: checked ? Qt.darker(checkedColor, 1.3) : (QfTheme.darkTheme ? "#555" : "#b8b8b8")
  color: !enabled ? (QfTheme.darkTheme ? "#2a2a2a" : "#f3f3f3") : area.pressed ? Qt.darker(baseColor, 1.25) : (checked ? checkedColor : baseColor)
  opacity: enabled ? 1 : 0.5

  Column {
    anchors.centerIn: parent
    spacing: 1
    width: parent.width - 4

    Image {
      visible: btn.icon !== ""
      source: btn.icon
      width: btn.text !== "" ? Math.min(btn.width, btn.height) * 0.5 : Math.min(btn.width, btn.height) * 0.7
      height: width
      fillMode: Image.PreserveAspectFit
      anchors.horizontalCenter: parent.horizontalCenter
      smooth: true
      asynchronous: true
    }
    Text {
      visible: btn.icon === "" && btn.emoji !== ""
      text: btn.emoji
      font.pixelSize: btn.text !== "" ? 18 : 24
      color: btn.textColor
      anchors.horizontalCenter: parent.horizontalCenter
    }
    Text {
      visible: btn.text !== ""
      text: btn.text
      font.pixelSize: btn.fontSize
      font.bold: btn.checked
      color: btn.textColor
      width: parent.width
      horizontalAlignment: Text.AlignHCenter
      wrapMode: Text.WordWrap
      maximumLineCount: 3
      elide: Text.ElideRight
    }
  }

  Text {
    visible: btn.marker
    text: "✋"
    font.pixelSize: 11
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    anchors.margins: 2
  }

  MouseArea {
    id: area
    anchors.fill: parent
    enabled: btn.enabled
    onClicked: btn.clicked()
    onPressAndHold: btn.pressAndHold()
  }
}
