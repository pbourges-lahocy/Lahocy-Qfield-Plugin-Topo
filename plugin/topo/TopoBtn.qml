import QtQuick
import org.qfield.gui

/*
 * TopoBtn - bouton de l'interface : icône monochrome (theme/ui/<nom>.svg),
 * image du catalogue (PNG) ou glyphe texte, libellé optionnel, appui court /
 * appui long, état coché, couleur de fond (vert / orange / rouge pour la mesure).
 */
Rectangle {
  id: btn

  property string text: ""
  property string icon: ""            // URL d'image (PNG du catalogue) ou ""
  property string ui: ""              // nom d'icône de l'interface (sans extension)
  property string emoji: ""           // glyphe texte si pas d'image
  property bool checked: false
  property bool marker: false         // point vert : appui long = objet direct
  property color baseColor: QfTheme.darkTheme ? "#3a3a3a" : "#f2f2f2"
  property color checkedColor: QfTheme.mainColor
  property color textColor: checked ? "white" : (QfTheme.darkTheme ? "#f0f0f0" : "#202020")
  property int fontSize: 10
  property bool small: false
  property real iconSize: text !== "" ? Math.min(width, height) * 0.46 : Math.min(width, height) * 0.6
  property bool lightIcon: checked || QfTheme.darkTheme
  property alias mouse: area
  readonly property string uiBase: Qt.resolvedUrl("../theme/ui/")

  signal clicked()
  signal pressAndHold()

  implicitWidth: 52
  implicitHeight: 52
  width: implicitWidth
  height: implicitHeight
  radius: 8
  border.width: 1
  border.color: checked ? Qt.darker(checkedColor, 1.2) : (QfTheme.darkTheme ? "#505050" : "#d4d4d4")
  color: !enabled ? (QfTheme.darkTheme ? "#2a2a2a" : "#f7f7f7") : area.pressed ? Qt.darker(baseColor, 1.2) : (checked ? checkedColor : baseColor)
  opacity: enabled ? 1 : 0.45

  Column {
    anchors.centerIn: parent
    spacing: 2
    width: parent.width - 4

    Image {
      visible: btn.ui !== "" || btn.icon !== ""
      source: btn.ui !== "" ? (btn.uiBase + btn.ui + (btn.lightIcon ? "_w" : "") + ".svg") : btn.icon
      width: btn.iconSize
      height: width
      sourceSize.width: width * 2
      sourceSize.height: width * 2
      fillMode: Image.PreserveAspectFit
      anchors.horizontalCenter: parent.horizontalCenter
      smooth: true
      asynchronous: btn.ui === ""
    }
    Text {
      visible: btn.ui === "" && btn.icon === "" && btn.emoji !== ""
      text: btn.emoji
      font.pixelSize: btn.text !== "" ? 17 : 22
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
      maximumLineCount: 2
      elide: Text.ElideRight
      lineHeight: 0.9
    }
  }

  Rectangle {
    visible: btn.marker
    width: 7; height: 7; radius: 3.5
    color: btn.checked ? "white" : QfTheme.mainColor
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    anchors.margins: 3
  }

  MouseArea {
    id: area
    anchors.fill: parent
    enabled: btn.enabled
    onClicked: btn.clicked()
    onPressAndHold: btn.pressAndHold()
  }
}
