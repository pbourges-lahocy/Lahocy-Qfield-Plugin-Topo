import QtQuick
import QtQuick.Controls
import org.qfield.gui

/*
 * TopoPalette - zone 3 du logiciel de référence : palette principale (2 colonnes) et
 * sous-palettes flottantes. Appui court = sous-palette, appui long = objet.
 */
Item {
  id: pal

  required property var engine
  property int columns: (engine.theme && engine.theme.colonnes) ? engine.theme.colonnes : 2
  property real cell: 54
  property real spacing: 3
  property bool onLeft: false          // la sous-palette s'ouvre du côté de la carte

  width: columns * (cell + spacing) + spacing + 4
  implicitWidth: width

  // grille avec emplacements vides conservés (comme Topo)
  property var slots: {
    let list = engine.theme.palette || [];
    let maxPos = -1;
    for (const b of list) maxPos = Math.max(maxPos, b.pos);
    let out = [];
    for (let i = 0; i <= Math.max(maxPos, columns * 5 - 1); i++) out.push(null);
    for (const b of list) out[b.pos] = b;
    return out;
  }

  Rectangle {
    anchors.fill: parent
    color: QfTheme.darkTheme ? "#262626" : "#f7f7f7"
    border.color: QfTheme.darkTheme ? "#444" : "#c8c8c8"
  }

  Flickable {
    id: flick
    anchors.fill: parent
    anchors.margins: 2
    contentHeight: grid.height + 4
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    Grid {
      id: grid
      columns: pal.columns
      spacing: pal.spacing
      x: pal.spacing

      Repeater {
        model: pal.slots
        delegate: TopoBtn {
          required property var modelData
          required property int index
          width: pal.cell
          height: pal.cell
          enabled: modelData !== null
          icon: modelData ? engine.iconUrl(modelData.icone) : ""
          text: (modelData && !modelData.icone) ? modelData.nom : ""
          fontSize: 9
          marker: !!(modelData && modelData.objet && modelData.sous_palette && modelData.sous_palette.length > 0)
          checked: modelData !== null && subPopup.visible && subPopup.bouton === modelData
          onClicked: {
            if (!modelData) return;
            if (modelData.sous_palette && modelData.sous_palette.length > 0) pal.openSub(modelData, this);
            else if (modelData.objet) engine.activate(modelData.objet);
          }
          onPressAndHold: {
            if (!modelData) return;
            if (modelData.objet) { engine.activate(modelData.objet); subPopup.close(); }
            else if (modelData.sous_palette && modelData.sous_palette.length > 0) pal.openSub(modelData, this);
          }
        }
      }
    }
  }

  function openSub(bouton, item) {
    subPopup.bouton = bouton;
    subPopup.page = 0;
    const pos = item.mapToItem(pal, 0, 0);
    subPopup.y = Math.max(0, Math.min(pos.y, pal.height - subPopup.height));
    subPopup.open();
  }

  /* ---------------- sous-palette flottante ---------------- */
  Popup {
    id: subPopup
    property var bouton: null
    property int page: 0
    property int perPage: 20
    property int subColumns: 4
    property var items: {
      if (!bouton) return [];
      let list = bouton.sous_palette || [];
      let maxPos = -1;
      for (const b of list) maxPos = Math.max(maxPos, b.pos);
      let out = [];
      for (let i = 0; i <= maxPos; i++) out.push(null);
      for (const b of list) out[b.pos] = b;
      // supprime les trous en fin de page pour la pagination
      return out;
    }
    property int pages: Math.max(1, Math.ceil(items.length / perPage))

    parent: pal
    x: pal.onLeft ? pal.width + 4 : -width - 4
    width: subColumns * (pal.cell + 4) + 16
    height: Math.min(pal.height, Math.ceil(Math.min(perPage, items.length - page * perPage) / subColumns) * (pal.cell + 4) + 52)
    modal: false
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent
    padding: 6
    background: Rectangle { color: QfTheme.darkTheme ? "#303030" : "#ffffff"; border.color: QfTheme.mainColor; border.width: 2; radius: 6 }

    contentItem: Column {
      spacing: 4
      Row {
        width: parent.width
        spacing: 4
        Text { text: subPopup.bouton ? String(subPopup.bouton.nom).replace(/^Cat/, "") : ""; font.bold: true; color: QfTheme.mainTextColor; width: parent.width - 100; elide: Text.ElideRight; anchors.verticalCenter: parent.verticalCenter }
        TopoBtn { width: 30; height: 28; emoji: "◀"; small: true; enabled: subPopup.page > 0; onClicked: subPopup.page-- }
        Text { text: (subPopup.page + 1) + "/" + subPopup.pages; color: QfTheme.mainTextColor; anchors.verticalCenter: parent.verticalCenter }
        TopoBtn { width: 30; height: 28; emoji: "▶"; small: true; enabled: subPopup.page < subPopup.pages - 1; onClicked: subPopup.page++ }
      }
      Grid {
        columns: subPopup.subColumns
        spacing: 4
        Repeater {
          model: subPopup.items.slice(subPopup.page * subPopup.perPage, (subPopup.page + 1) * subPopup.perPage)
          delegate: TopoBtn {
            required property var modelData
            width: pal.cell
            height: pal.cell
            enabled: modelData !== null
            icon: modelData ? engine.iconUrl(modelData.icone) : ""
            text: (modelData && !modelData.icone) ? modelData.objet : ""
            fontSize: 9
            onClicked: { if (modelData) { engine.activate(modelData.objet); subPopup.close(); } }
            ToolTip.visible: modelData !== null && mouse.containsMouse
            ToolTip.text: modelData ? (engine.objet(modelData.objet) ? engine.objet(modelData.objet).nom : modelData.objet) : ""
          }
        }
      }
    }
  }
}
