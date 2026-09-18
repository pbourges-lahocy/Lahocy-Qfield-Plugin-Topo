import QtQuick
import QtQuick.Layouts
import org.qfield.gui

/*
 * TopoActiveObjects - liste des objets actifs (linéaires en cours) :
 * ligne courante en surbrillance, appui = basculer, appui long = mettre en
 * attente ; relance du dernier objet.
 */
ColumnLayout {
  id: zone

  required property var engine
  spacing: 3
  visible: engine.activeList.length > 0 || engine.lastObjectCode !== ""

  RowLayout {
    Layout.fillWidth: true
    Text { Layout.fillWidth: true; text: "Objets actifs"; font.pixelSize: 11; font.bold: true; color: QfTheme.darkTheme ? "#f0f0f0" : "#202020" }
    TopoBtn { width: 30; height: 28; ui: "reprendre"; small: true; enabled: engine.lastObjectCode !== ""; onClicked: engine.relaunchLast() }
  }

  Flickable {
    Layout.fillWidth: true
    Layout.preferredHeight: Math.min(list.height, 4 * 32)
    contentHeight: list.height
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    Column {
      id: list
      width: parent.width
      spacing: 2
      Repeater {
        model: engine.activeList
        delegate: Rectangle {
          required property var modelData
          width: list.width
          height: 30
          radius: 6
          color: modelData.current ? QfTheme.mainColor : (modelData.orange ? "#ffe2b8" : (QfTheme.darkTheme ? "#3a3a3a" : "#ececec"))
          Row {
            anchors.fill: parent
            anchors.margins: 3
            spacing: 6
            Image { source: modelData.icone || ""; width: 22; height: 22; fillMode: Image.PreserveAspectFit; asynchronous: true; anchors.verticalCenter: parent.verticalCenter; visible: source !== "" }
            Text { text: modelData.label; font.pixelSize: 11; font.bold: modelData.current; color: modelData.current ? "white" : (QfTheme.darkTheme ? "#f0f0f0" : "#202020"); width: parent.width - 32; elide: Text.ElideRight; anchors.verticalCenter: parent.verticalCenter }
          }
          MouseArea {
            anchors.fill: parent
            onClicked: engine.switchTo(modelData.key)
            onPressAndHold: engine.wait(modelData.key)
          }
        }
      }
    }
  }
}
