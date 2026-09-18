import QtQuick
import org.qfield.gui

/*
 * TopoActiveObjects - zone 5 du logiciel de référence : pile des linéaires actifs,
 * bouton "relance dernier objet" et bouton "objets en attente".
 */
Item {
  id: zone

  required property var engine
  property real cell: 48

  width: cell + 8
  implicitWidth: width

  Rectangle {
    anchors.fill: parent
    color: QfTheme.darkTheme ? "#262626" : "#f0f0f0"
    border.color: QfTheme.darkTheme ? "#444" : "#c8c8c8"
  }

  Column {
    anchors.top: parent.top
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.topMargin: 4
    spacing: 4

    TopoBtn {
      width: zone.cell; height: zone.cell
      emoji: "↺"
      text: "Relance"
      fontSize: 8
      enabled: engine.lastObjectCode !== ""
      onClicked: engine.relaunchLast()
    }
    TopoBtn {
      width: zone.cell; height: zone.cell
      emoji: "⏸"
      text: "Attente"
      fontSize: 8
      baseColor: engine.hasWaiting ? "#ffb347" : (QfTheme.darkTheme ? "#3a3a3a" : "#e6e6e6")
      onClicked: engine.wait()
      onPressAndHold: engine.requestDialog("attente", { "items": engine.waitingList() })
    }
    Rectangle { width: zone.cell; height: 2; color: QfTheme.darkTheme ? "#555" : "#bbb" }

    Repeater {
      model: engine.activeList
      delegate: TopoBtn {
        required property var modelData
        width: zone.cell; height: zone.cell
        icon: modelData.icone
        text: modelData.label
        fontSize: 8
        checked: modelData.current
        baseColor: modelData.orange ? "#ffb347" : (QfTheme.darkTheme ? "#3a3a3a" : "#e6e6e6")
        onClicked: engine.switchTo(modelData.key)
        onPressAndHold: engine.wait(modelData.key)
      }
    }
  }
}
