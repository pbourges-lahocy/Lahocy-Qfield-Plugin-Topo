import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.qfield.gui
import "TopoCore.js" as Core
import "TopoCalc.js" as Topo

/*
 * TopoStationMenu - "Menu Station" du logiciel de référence : mise en station, visées de
 * référence, station libre, pilotage, paramétrage de la connexion.
 */
Dialog {
  id: menu

  required property var engine
  required property var station
  required property var devices
  required property var mainWindow

  title: "Menu Station"
  modal: false
  width: Math.min(560, mainWindow.width - 20)
  height: Math.min(640, mainWindow.height - 20)
  x: 10
  y: 10
  standardButtons: Dialog.Close
  parent: mainWindow.contentItem

  property var stations: []
  function refresh() { stations = station.stationList(); }
  onOpened: refresh()

  Connections {
    target: station
    function onChanged() { if (menu.visible) menu.refresh(); }
  }

  contentItem: ColumnLayout {
    spacing: 6

    // état
    Rectangle {
      Layout.fillWidth: true
      implicitHeight: etat.implicitHeight + 10
      color: devices.tpsConnected ? "#e2f6e2" : "#fde8e8"
      radius: 4
      Text {
        id: etat
        anchors.fill: parent; anchors.margins: 5
        wrapMode: Text.WordWrap
        color: "#202020"
        text: (devices.reachable ? (devices.tpsConnected ? ("Connecté : " + devices.tpsModel + (devices.tpsLocked ? " – prisme verrouillé" : " – PRISME PERDU")) : "Pont joignable – station non connectée") : "Pont injoignable (lancer topo_bridge.py sur la tablette)")
              + "\n" + (station.active ? ("Station active : " + station.current.matricule + "  X " + Core.fmt(station.current.x, 3) + "  Y " + Core.fmt(station.current.y, 3) + "  Z " + Core.fmt(station.current.z, 3) + "  hi " + Core.fmt(station.current.hi, 3) + (station.oriente ? ("  V0 " + Topo.fmtGr(station.current.v0)) : "  NON ORIENTÉE")) : "Aucune station active")
      }
    }

    TabBar {
      id: tabs
      Layout.fillWidth: true
      TabButton { text: "Mise en station" }
      TabButton { text: "Références" }
      TabButton { text: "Station libre" }
      TabButton { text: "Pilotage" }
      TabButton { text: "Paramètres" }
    }

    StackLayout {
      Layout.fillWidth: true
      Layout.fillHeight: true
      currentIndex: tabs.currentIndex

      /* ---------------- Mise en station ---------------- */
      Flickable {
        contentHeight: mesCol.implicitHeight
        clip: true
        ColumnLayout {
          id: mesCol
          width: parent.width
          spacing: 6
          RowLayout {
            Text { text: "Matricule :"; color: QfTheme.mainTextColor }
            TextField { id: matField; Layout.preferredWidth: 110; placeholderText: "auto" }
            Text { text: "Hauteur tourillons (m) :"; color: QfTheme.mainTextColor }
            TextField { id: hiField; Layout.preferredWidth: 80; text: station.hiDefaut.toFixed(3); inputMethodHints: Qt.ImhFormattedNumbersOnly }
          }
          Text { text: "Création d'une nouvelle station"; font.bold: true; color: QfTheme.mainTextColor }
          Flow {
            Layout.fillWidth: true
            spacing: 4
            TopoBtn { width: 96; height: 56; emoji: "⌨"; text: "Saisie de\ncoordonnées"; fontSize: 9; onClicked: coordDialog.open() }
            TopoBtn { width: 96; height: 56; emoji: "◎"; text: "Clic sur\npoint connu"; fontSize: 9; onClicked: { menu.close(); engine.pickPoint(function (pt) { station.stationSurPoint(pt, parseFloat(hiField.text) || station.hiDefaut); menu.open(); }, "Cliquer sur le point topo ou la station où est l'appareil"); } }
            TopoBtn { width: 96; height: 56; emoji: "✥"; text: "Clic libre\ndans le plan"; fontSize: 9; onClicked: { menu.close(); engine.setClickMode("station_libre_clic"); engine.clickCallback = function (p) { station.stationClicLibre(p, parseFloat(hiField.text) || station.hiDefaut, matField.text); menu.open(); }; } }
            TopoBtn { width: 96; height: 56; emoji: "➶"; text: "Mesure\n(visée avant)"; fontSize: 9; enabled: station.active && station.oriente; onClicked: station.viseeAvant(matField.text) }
            TopoBtn { width: 96; height: 56; emoji: "△"; text: "Station\nlibre"; fontSize: 9; onClicked: { station.libreStart(matField.text, parseFloat(hiField.text) || station.hiDefaut); tabs.currentIndex = 2; } }
          }
          Text { text: "Changer de station / reprise"; font.bold: true; color: QfTheme.mainTextColor }
          ListView {
            id: stationList
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(200, contentHeight + 4)
            clip: true
            model: menu.stations
            delegate: Rectangle {
              required property var modelData
              required property int index
              width: stationList.width; height: 34
              color: stationList.currentIndex === index ? QfTheme.mainColor : (index % 2 ? "#00000010" : "transparent")
              Text { anchors.fill: parent; anchors.margins: 4; verticalAlignment: Text.AlignVCenter; color: stationList.currentIndex === index ? "white" : QfTheme.mainTextColor
                text: modelData.matricule + "   " + modelData.type + "   " + modelData.statut + "   X " + Core.fmt(modelData.x, 2) + "  Y " + Core.fmt(modelData.y, 2) + "  Z " + Core.fmt(modelData.z, 2) + (Core.isNum(modelData.v0) ? "  V0 " + Topo.fmtGr(modelData.v0, 3) : "") }
              MouseArea { anchors.fill: parent; onClicked: stationList.currentIndex = index }
            }
          }
          Flow {
            Layout.fillWidth: true
            spacing: 4
            TopoBtn { width: 130; height: 46; emoji: "⇄"; text: "Changer (appareil\ndéplacé ici)"; fontSize: 9; enabled: stationList.currentIndex >= 0; onClicked: station.changerStation(menu.stations[stationList.currentIndex].fid, parseFloat(hiField.text) || station.hiDefaut) }
            TopoBtn { width: 130; height: 46; emoji: "🔍"; text: "Zoomer"; fontSize: 9; enabled: stationList.currentIndex >= 0; onClicked: engine.zoomToPoints([menu.stations[stationList.currentIndex]]) }
            TopoBtn { width: 130; height: 46; emoji: "🗑"; text: "Supprimer"; fontSize: 9; enabled: stationList.currentIndex >= 0 && menu.stations[stationList.currentIndex].statut !== "active"; onClicked: { engine.db.deleteFeature("station", menu.stations[stationList.currentIndex].fid); menu.refresh(); } }
          }
        }
      }

      /* ---------------- Références ---------------- */
      ColumnLayout {
        spacing: 6
        Text { text: station.active ? ("Visées de référence de " + station.current.matricule) : "Aucune station active"; font.bold: true; color: QfTheme.mainTextColor }
        ListView {
          id: refList
          Layout.fillWidth: true
          Layout.fillHeight: true
          clip: true
          model: station.active ? station.current.refs : []
          delegate: Rectangle {
            required property var modelData
            required property int index
            width: refList.width; height: 40
            color: index % 2 ? "#00000010" : "transparent"
            RowLayout {
              anchors.fill: parent; anchors.margins: 3
              CheckBox { checked: !modelData.exclue; onToggled: station.excludeReference(index, !checked) }
              Text { Layout.fillWidth: true; color: QfTheme.mainTextColor; font.pixelSize: 11; wrapMode: Text.WordWrap
                text: (modelData.type === "REF_APPROCHEE" ? "≈ " : "") + modelData.cible + "  Hz " + Topo.fmtGr(modelData.hz) + (Core.isNum(modelData.sd) ? "  Di " + Core.fmt(modelData.sd, 3) : "") + "  V0 " + Topo.fmtGr(modelData.v0) + (Core.isNum(modelData.ecart_plani) ? "  écart " + Core.fmt(modelData.ecart_plani, 3) + " / " + Core.fmt(modelData.ecart_alti, 3) : "") }
            }
          }
        }
        CheckBox { id: bicapteurRef; text: "Mesure bicapteur (point GNSS puis visée)"; visible: station.bicapteur }
        Flow {
          Layout.fillWidth: true
          spacing: 4
          TopoBtn { width: 120; height: 56; emoji: "∠↔"; text: "Angles et distance\nsur point connu"; fontSize: 9; enabled: station.active; onClicked: menu.viser("REF_ANGLE_DIST") }
          TopoBtn { width: 120; height: 56; emoji: "∠"; text: "Angle Hz seul\nsur point connu"; fontSize: 9; enabled: station.active; onClicked: menu.viser("REF_ANGLE") }
          TopoBtn { width: 120; height: 56; emoji: "≈∠"; text: "Visée APPROCHÉE\n(V0 provisoire)"; fontSize: 9; enabled: station.active; onClicked: menu.viser("REF_APPROCHEE") }
        }
      }

      /* ---------------- Station libre ---------------- */
      ColumnLayout {
        spacing: 6
        Text { text: station.libre ? ("Station libre " + station.libre.matricule + " – hi " + Core.fmt(station.libre.hi, 3)) : "Démarrer une station libre depuis l'onglet Mise en station"; font.bold: true; color: QfTheme.mainTextColor }
        RowLayout {
          visible: station.libre !== null
          CheckBox { checked: station.doubleRetournement; text: "Double retournement"; onToggled: { station.doubleRetournement = checked; station.saveSettings(); } }
          CheckBox { checked: station.bicapteur; text: "Bicapteur (référence = point GNSS)"; onToggled: { station.bicapteur = checked; } }
        }
        ListView {
          id: libreList
          Layout.fillWidth: true
          Layout.fillHeight: true
          clip: true
          model: station.libre ? station.libre.refs : []
          delegate: Rectangle {
            required property var modelData
            required property int index
            width: libreList.width; height: 44
            color: index % 2 ? "#00000010" : "transparent"
            RowLayout {
              anchors.fill: parent; anchors.margins: 2
              CheckBox { text: "XY"; checked: modelData.useXY !== false; onToggled: station.libreSetOption(index, "useXY", checked) }
              CheckBox { text: "Z"; checked: modelData.useZ !== false; onToggled: station.libreSetOption(index, "useZ", checked) }
              CheckBox { text: "Di"; checked: modelData.useDist !== false; onToggled: station.libreSetOption(index, "useDist", checked) }
              Text { Layout.fillWidth: true; color: QfTheme.mainTextColor; font.pixelSize: 11; wrapMode: Text.WordWrap
                text: modelData.cible.matricule + "  Hz " + Topo.fmtGr(modelData.hz) + "  Di " + Core.fmt(modelData.sd, 3) + (station.libre.result && station.libre.result.ok && station.libre.result.residus[index] ? ("  résidu " + Core.fmt(station.libre.result.residus[index].dPlani, 3) + " / " + Core.fmt(station.libre.result.residus[index].dZ, 3)) : "") }
              TopoBtn { width: 34; height: 34; emoji: "🗑"; onClicked: { station.libre.refs.splice(index, 1); station.libreCompute(); } }
            }
          }
        }
        Text {
          visible: station.libre !== null && station.libre.result !== null
          Layout.fillWidth: true; wrapMode: Text.WordWrap; color: QfTheme.mainTextColor; font.pixelSize: 11
          text: !station.libre || !station.libre.result ? "" : (station.libre.result.ok ? ("Résultat : X " + Core.fmt(station.libre.result.x, 3) + "  Y " + Core.fmt(station.libre.result.y, 3) + "  Z " + Core.fmt(station.libre.result.z, 3) + "  V0 " + Topo.fmtGr(station.libre.result.v0) + "\nEMQ plani " + Core.fmt(station.libre.result.emq_plani, 3) + " m – EMQ alti " + Core.fmt(station.libre.result.emq_alti, 3) + " m (" + station.libre.result.iterations + " it.)") : ("Calcul impossible : " + station.libre.result.message))
        }
        Flow {
          Layout.fillWidth: true
          spacing: 4
          TopoBtn { width: 120; height: 52; emoji: "➶"; text: "Viser une\nréférence"; fontSize: 9; enabled: station.libre !== null; onClicked: { if (station.bicapteur) station.libreVisee(null); else menu.chooseCible(function (c) { station.libreVisee(c); }); } }
          TopoBtn { width: 120; height: 52; emoji: "✔"; text: "Valider la\nstation libre"; fontSize: 9; baseColor: "#8fe08f"; enabled: station.libre !== null && station.libre.result !== null && station.libre.result.ok; onClicked: station.libreValidate() }
          TopoBtn { width: 100; height: 52; emoji: "✘"; text: "Abandonner"; fontSize: 9; baseColor: "#ffd6d6"; enabled: station.libre !== null; onClicked: station.libreCancel() }
        }
      }

      /* ---------------- Pilotage ---------------- */
      ColumnLayout {
        spacing: 6
        Text { text: devices.tpsConnected ? (devices.tpsLocked ? "Prisme verrouillé" : "Prisme perdu – relancer une recherche") : "Station non connectée"; font.bold: true; color: QfTheme.mainTextColor }
        Flow {
          Layout.fillWidth: true
          spacing: 4
          TopoBtn { width: 100; height: 52; emoji: "🔦"; text: "PowerSearch"; fontSize: 9; onClicked: station.powerSearch(false) }
          TopoBtn { width: 100; height: 52; emoji: "🔦+"; text: "PowerSearch\nétendu"; fontSize: 9; onClicked: station.powerSearch(true) }
          TopoBtn { width: 100; height: 52; emoji: "🌀"; text: "Recherche\nspirale"; fontSize: 9; onClicked: station.spirale() }
          TopoBtn { width: 100; height: 52; emoji: "⛔"; text: "Stop"; fontSize: 9; baseColor: "#ffd6d6"; onClicked: station.stopMoteurs() }
          TopoBtn { width: 100; height: 52; emoji: "🗺"; text: "Relockage\ndans le plan"; fontSize: 9; onClicked: { menu.close(); engine.setClickMode("relock"); } }
          TopoBtn { width: 100; height: 52; emoji: "🔒"; text: devices.tpsLocked ? "Déverrouiller" : "Verrouiller"; fontSize: 9; onClicked: station.lock(!devices.tpsLocked) }
          TopoBtn { width: 100; height: 52; emoji: "🔴"; text: "Plomb /\nlaser"; fontSize: 9; onClicked: station.laser(true) }
          TopoBtn { width: 100; height: 52; emoji: "📍"; text: devices.tpsTracking ? "Suivi ON" : "Suivi OFF"; fontSize: 9; checked: devices.tpsTracking; onClicked: station.tracking(!devices.tpsTracking) }
        }
        Text { text: "Joystick"; font.bold: true; color: QfTheme.mainTextColor }
        RowLayout {
          spacing: 8
          Grid {
            columns: 3
            spacing: 4
            Item { width: 48; height: 48 }
            TopoBtn { width: 48; height: 48; emoji: "▲"; onClicked: station.joystick("haut", joySpeed.checked ? "rapide" : "lent") }
            Item { width: 48; height: 48 }
            TopoBtn { width: 48; height: 48; emoji: "◀"; onClicked: station.joystick("gauche", joySpeed.checked ? "rapide" : "lent") }
            TopoBtn { width: 48; height: 48; emoji: "■"; baseColor: "#ffd6d6"; onClicked: station.stopMoteurs() }
            TopoBtn { width: 48; height: 48; emoji: "▶"; onClicked: station.joystick("droite", joySpeed.checked ? "rapide" : "lent") }
            Item { width: 48; height: 48 }
            TopoBtn { width: 48; height: 48; emoji: "▼"; onClicked: station.joystick("bas", joySpeed.checked ? "rapide" : "lent") }
            Item { width: 48; height: 48 }
          }
          ColumnLayout {
            Switch { id: joySpeed; text: checked ? "Rapide" : "Lent" }
            Text { text: "Hz " + (isNaN(devices.tpsHz) ? "—" : devices.tpsHz.toFixed(4)) + "\nV " + (isNaN(devices.tpsV) ? "—" : devices.tpsV.toFixed(4)); color: QfTheme.mainTextColor }
            Text { text: "Axe de visée (gisement) : " + Topo.fmtGr(station.axeVisee(), 3); color: QfTheme.mainTextColor; font.pixelSize: 11 }
          }
        }
      }

      /* ---------------- Paramètres ---------------- */
      Flickable {
        contentHeight: paramCol.implicitHeight
        clip: true
        ColumnLayout {
          id: paramCol
          width: parent.width
          spacing: 6
          Text { text: "Connexion (via le pont local)"; font.bold: true; color: QfTheme.mainTextColor }
          GridLayout {
            columns: 4
            Text { text: "Pont :"; color: QfTheme.mainTextColor }
            TextField { id: urlField; Layout.columnSpan: 3; Layout.fillWidth: true; text: devices.url }
            Text { text: "Appareil :"; color: QfTheme.mainTextColor }
            ComboBox { id: driverBox; model: ["simulateur", "geocom"]; currentIndex: Math.max(0, model.indexOf(station.driver)) }
            Text { text: "Port COM :"; color: QfTheme.mainTextColor }
            TextField { id: portField; text: station.port; Layout.preferredWidth: 90; placeholderText: "COM5 / nom BT" }
            Text { text: "Vitesse :"; color: QfTheme.mainTextColor }
            TextField { id: baudField; text: String(station.baud); Layout.preferredWidth: 90; inputMethodHints: Qt.ImhDigitsOnly }
            Text { text: "Mesure :"; color: QfTheme.mainTextColor }
            ComboBox { id: modeBox; model: ["prisme", "sans_prisme"]; currentIndex: station.modeMesure === "sans_prisme" ? 1 : 0; onActivated: station.modeMesure = currentText }
          }
          Flow {
            Layout.fillWidth: true
            spacing: 4
            TopoBtn { width: 120; height: 46; emoji: "🔌"; text: devices.tpsConnected ? "Reconnecter" : "Connecter"; fontSize: 9; baseColor: "#8fe08f"; onClicked: { devices.url = urlField.text; station.driver = driverBox.currentText; station.port = portField.text; station.baud = parseInt(baudField.text) || 115200; station.connecter(); } }
            TopoBtn { width: 120; height: 46; emoji: "⏏"; text: "Déconnecter"; fontSize: 9; enabled: devices.tpsConnected; onClicked: station.deconnecter() }
            TopoBtn { width: 120; height: 46; emoji: "📏"; text: devices.distoConnected ? "Disto connecté" : "Connecter\nle disto"; fontSize: 9; onClicked: devices.distoConnect(driverBox.currentText === "simulateur" ? "simulateur" : "disto_ble", "", function (r) { engine.toast(r.ok ? "Disto connecté" : ("Disto : " + r.error)); }) }
            TopoBtn { width: 120; height: 46; emoji: "📡"; text: devices.detectorConnected ? "Détecteur connecté" : "Connecter\nle détecteur"; fontSize: 9; onClicked: devices.detectorConnect(driverBox.currentText === "simulateur" ? "simulateur" : "detector", detPortField.text, 9600, "generic", function (r) { engine.toast(r.ok ? "Détecteur connecté" : ("Détecteur : " + r.error)); }) }
            TextField { id: detPortField; width: 90; placeholderText: "COM détecteur"; text: "COM5" }
          }
          Text { text: "Options de mesure"; font.bold: true; color: QfTheme.mainTextColor }
          CheckBox { text: "Double retournement (2 faces)"; checked: station.doubleRetournement; onToggled: { station.doubleRetournement = checked; station.saveSettings(); } }
          CheckBox { text: "Correction courbure / réfraction"; checked: station.courbure; onToggled: { station.courbure = checked; station.saveSettings(); } }
          RowLayout {
            CheckBox { text: "Bicapteur (GNSS sur le prisme)"; checked: station.bicapteur; onToggled: station.bicapteur = checked }
            Text { text: "décalage antenne / prisme (m) :"; color: QfTheme.mainTextColor }
            TextField { Layout.preferredWidth: 70; text: station.decalageBicapteur.toFixed(3); onEditingFinished: { station.decalageBicapteur = parseFloat(text) || 0; station.saveSettings(); } }
          }
          RowLayout {
            Text { text: "Hauteur du disto sur la canne (m) :"; color: QfTheme.mainTextColor }
            TextField { Layout.preferredWidth: 70; text: station.hauteurDisto.toFixed(2); onEditingFinished: { station.hauteurDisto = parseFloat(text) || 1.2; station.saveSettings(); } }
          }
          RowLayout {
            Text { text: "Recherche spirale (grades) Hz :"; color: QfTheme.mainTextColor }
            TextField { Layout.preferredWidth: 60; text: String(station.spiraleHz); onEditingFinished: { station.spiraleHz = parseFloat(text) || 10; station.saveSettings(); } }
            Text { text: "V :"; color: QfTheme.mainTextColor }
            TextField { Layout.preferredWidth: 60; text: String(station.spiraleV); onEditingFinished: { station.spiraleV = parseFloat(text) || 10; station.saveSettings(); } }
          }
          Flow {
            Layout.fillWidth: true
            spacing: 4
            TopoBtn { width: 130; height: 46; emoji: "📤"; text: "Export carnet\nGSI"; fontSize: 9; onClicked: station.exportGsi() }
            TopoBtn { width: 130; height: 46; emoji: "📤"; text: "Export carnet\npolaire CSV"; fontSize: 9; onClicked: station.exportCsvPolaire() }
          }
        }
      }
    }
  }

  /* ---------------- visée de référence : choix de la cible ---------------- */
  function viser(type) {
    chooseCible(function (c) { station.viseeReference(type, c); });
  }

  property var cibleCallback: null
  function chooseCible(cb) { cibleCallback = cb; cibleDialog.refresh(); cibleDialog.open(); }

  Dialog {
    id: cibleDialog
    title: "Point de référence (cible)"
    parent: mainWindow.contentItem
    modal: true
    width: Math.min(460, mainWindow.width - 20)
    height: Math.min(520, mainWindow.height - 20)
    x: (mainWindow.width - width) / 2
    y: (mainWindow.height - height) / 2
    standardButtons: Dialog.Ok | Dialog.Cancel
    property var candidates: []
    function refresh() {
      let out = [];
      for (const s of station.stationList()) if (!station.active || s.matricule !== station.current.matricule) out.push({ "matricule": s.matricule, "x": s.x, "y": s.y, "z": s.z, "label": "Station " + s.matricule + " (" + s.type + ")" });
      for (const p of engine.carnetList(["IMPORTE", "GPS", "TPS", "STATION", "CONSTRUIT", "IMPLANTE"], cibleSearch.text)) out.push({ "matricule": p.matricule, "x": p.x, "y": p.y, "z": p.z, "label": "Point " + p.matricule + " (" + p.type + ")" });
      candidates = out;
    }
    contentItem: ColumnLayout {
      RowLayout {
        TextField { id: cibleSearch; Layout.fillWidth: true; placeholderText: "Matricule…"; onTextChanged: cibleDialog.refresh() }
        TopoBtn { width: 110; height: 40; emoji: "🗺"; text: "Sur le plan"; fontSize: 9; onClicked: { cibleDialog.reject(); menu.close(); engine.pickPoint(function (pt) { menu.open(); if (menu.cibleCallback) menu.cibleCallback({ "matricule": pt.matricule, "x": pt.x, "y": pt.y, "z": pt.z }); }, "Cliquer sur la référence dans le plan"); } }
      }
      ListView {
        id: cibleList
        Layout.fillWidth: true; Layout.fillHeight: true
        clip: true
        model: cibleDialog.candidates
        delegate: Rectangle {
          required property var modelData
          required property int index
          width: cibleList.width; height: 32
          color: cibleList.currentIndex === index ? QfTheme.mainColor : (index % 2 ? "#00000010" : "transparent")
          Text { anchors.fill: parent; anchors.margins: 4; verticalAlignment: Text.AlignVCenter; text: modelData.label + "   Z " + Core.fmt(modelData.z, 2); color: cibleList.currentIndex === index ? "white" : QfTheme.mainTextColor }
          MouseArea { anchors.fill: parent; onClicked: cibleList.currentIndex = index; onDoubleClicked: { cibleList.currentIndex = index; cibleDialog.accept(); } }
        }
      }
    }
    onAccepted: { if (cibleList.currentIndex >= 0 && menu.cibleCallback) menu.cibleCallback(candidates[cibleList.currentIndex]); }
  }

  /* ---------------- saisie de coordonnées ---------------- */
  Dialog {
    id: coordDialog
    title: "Station par saisie de coordonnées"
    parent: mainWindow.contentItem
    modal: true
    width: 340
    x: (mainWindow.width - width) / 2
    y: (mainWindow.height - height) / 2
    standardButtons: Dialog.Ok | Dialog.Cancel
    contentItem: GridLayout {
      columns: 2
      Text { text: "X :"; color: QfTheme.mainTextColor } TextField { id: cx; Layout.fillWidth: true; inputMethodHints: Qt.ImhFormattedNumbersOnly }
      Text { text: "Y :"; color: QfTheme.mainTextColor } TextField { id: cy; Layout.fillWidth: true; inputMethodHints: Qt.ImhFormattedNumbersOnly }
      Text { text: "Z :"; color: QfTheme.mainTextColor } TextField { id: cz; Layout.fillWidth: true; inputMethodHints: Qt.ImhFormattedNumbersOnly }
    }
    onAccepted: station.stationCoordonnees(matField.text, parseFloat(cx.text), parseFloat(cy.text), parseFloat(cz.text), parseFloat(hiField.text) || station.hiDefaut)
  }
}
