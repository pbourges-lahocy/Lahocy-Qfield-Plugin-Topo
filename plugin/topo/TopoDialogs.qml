import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.qfield.gui
import "TopoCore.js" as Core
import "TopoCalc.js" as Topo

/*
 * TopoDialogs - boîtes de dialogue du plugin (texte, excentrements, hauteurs,
 * seuils GNSS, réglages, détection, saisie simulateur, ambiguïtés...).
 * open(kind, payload) est appelé par les signaux requestDialog de l'engine
 * et du module station.
 */
Item {
  id: dialogs

  required property var engine
  required property var station
  required property var devices
  required property var mainWindow

  property var payload: ({})

  function open(kind, p) {
    payload = p || {};
    switch (kind) {
      case "texte": texteField.text = payload.defaut || ""; texteListe.model = payload.liste || []; texteDialog.open(); break;
      case "excent": excentDialog.mode = payload.mode; excentDist.text = payload.defaut !== undefined ? Number(payload.defaut).toFixed(3) : ""; excentD2.text = ""; excentDz.text = ""; excentDialog.side = payload.side || "gauche"; excentDialog.direction = "gauche"; excentDialog.open(); break;
      case "confirm_warn": warnDialog.open(); break;
      case "hauteur": hauteurDialog.tps = !!payload.tps; hauteurField.text = (payload.tps ? station.hr : engine.hauteurCanne).toFixed(3); hauteurDialog.open(); break;
      case "rayon": rayonField.text = engine.rayonCercle.toFixed(3); rayonLock.checked = engine.rayonVerrouille; rayonDialog.open(); break;
      case "decalage": decalageField.text = "0.10"; decalageDialog.open(); break;
      case "attente": attenteList.model = payload.items || []; attenteDialog.open(); break;
      case "ambiguite": ambList.model = payload.items || []; ambDialog.open(); break;
      case "suppr_appui": supprDialog.open(); break;
      case "excent_config": excentConfigDialog.open(); break;
      case "saisie_mesure": simDialog.anglesSeuls = !!payload.anglesSeuls; simDialog.open(); break;
      case "reference_resultat": refDialog.open(); break;
      case "visee_avant_resultat": engine.toast("Station " + payload.matricule + " : X " + Core.fmt(payload.point.x, 3) + " Y " + Core.fmt(payload.point.y, 3) + " Z " + Core.fmt(payload.point.z, 3)); break;
      case "detection": detDialog.open(); break;
      case "seuils": seuilsDialog.load(); seuilsDialog.open(); break;
      case "settings": settingsDialog.load(); settingsDialog.open(); break;
      case "import": importDialog.open(); break;
      case "station_menu": stationMenuRequested(); break;
      default: engine.toast("Dialogue inconnu : " + kind);
    }
  }

  signal stationMenuRequested()

  function center(d) { d.x = (mainWindow.width - d.width) / 2; d.y = (mainWindow.height - d.height) / 2; }

  /* ---------------- texte ---------------- */
  Dialog {
    id: texteDialog
    parent: mainWindow.contentItem; modal: true; title: "Texte"; width: 360
    standardButtons: Dialog.Ok | Dialog.Cancel
    onAboutToShow: dialogs.center(texteDialog)
    contentItem: ColumnLayout {
      TextField { id: texteField; Layout.fillWidth: true; placeholderText: "Saisir le texte…" }
      ListView {
        id: texteListe
        Layout.fillWidth: true; Layout.preferredHeight: Math.min(200, count * 32); clip: true
        delegate: ItemDelegate { required property var modelData; width: texteListe.width; text: modelData; onClicked: texteField.text = modelData }
      }
    }
    onAccepted: engine.setPendingText(texteField.text)
  }

  /* ---------------- excentrement ---------------- */
  Dialog {
    id: excentDialog
    property string mode: "point"
    property string side: "gauche"
    property string direction: "gauche"
    parent: mainWindow.contentItem; modal: true; width: 380
    title: ({ "point": "Excentrement par rapport à un point", "station": "Excentrement par rapport à la station", "perp_prec": "Perpendiculaire point précédent", "perp_suiv": "Perpendiculaire point suivant (1er point)", "perp_suiv_2": "Perpendiculaire point suivant (2e point)", "vertical": "Excentrement vertical", "deux_dist": "Excentrement par deux distances" })[mode] || "Excentrement"
    standardButtons: Dialog.Ok | Dialog.Cancel
    onAboutToShow: dialogs.center(excentDialog)
    contentItem: ColumnLayout {
      spacing: 6
      Text { Layout.fillWidth: true; wrapMode: Text.WordWrap; color: QfTheme.mainTextColor; font.pixelSize: 11
        text: (dialogs.payload.appui ? ("Point d'appui : " + dialogs.payload.appui.matricule) : "") + (dialogs.payload.ref ? ("   Référence : " + (dialogs.payload.ref.matricule || dialogs.payload.ref.m || "station")) : "") }
      // direction (par rapport à point / station)
      Flow {
        visible: excentDialog.mode === "point" || excentDialog.mode === "station"
        spacing: 4
        Repeater {
          model: [["avant", "▲ Avant"], ["arriere", "▼ Arrière"], ["gauche", "◀ Gauche"], ["droite", "▶ Droite"]]
          TopoBtn { required property var modelData; width: 80; height: 44; text: modelData[1]; fontSize: 10; checked: excentDialog.direction === modelData[0]; onClicked: excentDialog.direction = modelData[0] }
        }
      }
      RowLayout {
        visible: excentDialog.mode === "point"
        TopoBtn { width: 150; height: 40; text: "Inverser appui / référence"; fontSize: 9; checked: swapCheck.checked; onClicked: swapCheck.checked = !swapCheck.checked }
        CheckBox { id: swapCheck; visible: false }
        TopoBtn { width: 150; height: 40; text: "Référence sur le plan"; fontSize: 9; onClicked: { excentDialog.reject(); engine.setClickMode("ref_point"); } }
      }
      // côté (perpendiculaires, deux distances)
      Flow {
        visible: ["perp_prec", "perp_suiv", "perp_suiv_2", "deux_dist"].indexOf(excentDialog.mode) >= 0
        spacing: 4
        TopoBtn { width: 110; height: 44; text: "◀ Gauche"; fontSize: 10; checked: excentDialog.side === "gauche"; onClicked: excentDialog.side = "gauche" }
        TopoBtn { width: 110; height: 44; text: "Droite ▶"; fontSize: 10; checked: excentDialog.side === "droite"; onClicked: excentDialog.side = "droite" }
      }
      RowLayout {
        visible: excentDialog.mode !== "vertical"
        Text { text: excentDialog.mode === "deux_dist" ? "Distance 1 (m) :" : "Distance (m) :"; color: QfTheme.mainTextColor }
        TextField { id: excentDist; Layout.fillWidth: true; inputMethodHints: Qt.ImhFormattedNumbersOnly }
        TopoBtn { width: 70; height: 36; emoji: "📏"; text: "Disto"; fontSize: 8; enabled: devices.distoConnected; onClicked: station.distoDistance(distoSol.checked, function (d) { excentDist.text = d.toFixed(3); }) }
      }
      RowLayout {
        visible: excentDialog.mode === "deux_dist"
        Text { text: "Distance 2 (m) :"; color: QfTheme.mainTextColor }
        TextField { id: excentD2; Layout.fillWidth: true; inputMethodHints: Qt.ImhFormattedNumbersOnly }
        TopoBtn { width: 70; height: 36; emoji: "📏"; text: "Disto"; fontSize: 8; enabled: devices.distoConnected; onClicked: station.distoDistance(distoSol.checked, function (d) { excentD2.text = d.toFixed(3); }) }
      }
      CheckBox { id: distoSol; visible: devices.distoConnected && excentDialog.mode !== "vertical"; text: "Visée au sol (corrigée de la hauteur du disto)" }
      RowLayout {
        visible: excentDialog.mode === "vertical"
        Text { text: "Décalage Z (m, négatif vers le bas) :"; color: QfTheme.mainTextColor }
        TextField { id: excentDz; Layout.fillWidth: true; inputMethodHints: Qt.ImhFormattedNumbersOnly; text: "-0.000" }
      }
    }
    onAccepted: {
      const values = { "direction": direction, "side": side, "distance": parseFloat(excentDist.text) || 0, "d1": parseFloat(excentDist.text) || 0, "d2": parseFloat(excentD2.text) || 0, "dz": parseFloat(excentDz.text) || 0, "swap": swapCheck.checked };
      swapCheck.checked = false;
      if (mode === "station") station.excentStationValidate(values);
      else if (mode === "perp_suiv_2") engine.perpSuivantValidate(values);
      else engine.excentValidate(values);
    }
    onRejected: { if (mode !== "perp_suiv_2" && mode !== "station") engine.cancelExcent(); }
  }

  /* ---------------- confirmation qualité orange ---------------- */
  Dialog {
    id: warnDialog
    parent: mainWindow.contentItem; modal: true; title: "Qualité GNSS hors tolérance"; width: 340
    standardButtons: Dialog.Yes | Dialog.No
    onAboutToShow: dialogs.center(warnDialog)
    contentItem: Text { text: engine.qualityDetail + "\n\nMesurer quand même ?"; wrapMode: Text.WordWrap; color: QfTheme.mainTextColor }
    onAccepted: engine.measure(!!dialogs.payload.withLink, true)
  }

  /* ---------------- hauteur canne / prisme ---------------- */
  Dialog {
    id: hauteurDialog
    property bool tps: false
    parent: mainWindow.contentItem; modal: true; width: 340
    title: tps ? "Hauteur du prisme" : "Hauteur d'antenne (canne)"
    standardButtons: Dialog.Ok | Dialog.Cancel
    onAboutToShow: dialogs.center(hauteurDialog)
    contentItem: ColumnLayout {
      Flow {
        Layout.fillWidth: true
        spacing: 4
        Repeater {
          model: [1.3, 1.45, 1.5, 1.6, 1.7, 1.8, 2.0, 2.05, 2.2]
          TopoBtn { required property var modelData; width: 60; height: 40; text: modelData.toFixed(2); fontSize: 10; onClicked: hauteurField.text = modelData.toFixed(3) }
        }
      }
      TextField { id: hauteurField; Layout.fillWidth: true; inputMethodHints: Qt.ImhFormattedNumbersOnly }
      Text { visible: station.bicapteur; text: "Bicapteur : hauteur d'antenne = prisme + " + station.decalageBicapteur.toFixed(3) + " m"; color: QfTheme.secondaryTextColor; font.pixelSize: 10 }
    }
    onAccepted: { const h = parseFloat(hauteurField.text); if (!isNaN(h)) { if (tps) station.setHr(h); else engine.setHauteurCanne(h); } }
  }

  /* ---------------- rayon de cercle ---------------- */
  Dialog {
    id: rayonDialog
    parent: mainWindow.contentItem; modal: true; title: "Rayon du cercle"; width: 300
    standardButtons: Dialog.Ok | Dialog.Cancel
    onAboutToShow: dialogs.center(rayonDialog)
    contentItem: ColumnLayout {
      TextField { id: rayonField; Layout.fillWidth: true; inputMethodHints: Qt.ImhFormattedNumbersOnly }
      CheckBox { id: rayonLock; text: "Forcer le rayon (cercle par 1 point = centre)" }
    }
    onAccepted: engine.setRayon(parseFloat(rayonField.text) || 0, rayonLock.checked)
  }

  /* ---------------- décalage de symbole ---------------- */
  Dialog {
    id: decalageDialog
    parent: mainWindow.contentItem; modal: true; title: "Décalage du symbole (m, perpendiculaire à l'axe 1-2)"; width: 320
    standardButtons: Dialog.Ok | Dialog.Cancel
    onAboutToShow: dialogs.center(decalageDialog)
    contentItem: TextField { id: decalageField; inputMethodHints: Qt.ImhFormattedNumbersOnly }
    onAccepted: engine.adjustDecalage(parseFloat(decalageField.text) || 0)
  }

  /* ---------------- objets en attente ---------------- */
  Dialog {
    id: attenteDialog
    parent: mainWindow.contentItem; modal: true; title: "Objets en attente"; width: 380; height: 400
    standardButtons: Dialog.Close
    onAboutToShow: dialogs.center(attenteDialog)
    contentItem: ListView {
      id: attenteList
      clip: true
      delegate: ItemDelegate {
        required property var modelData
        width: attenteList.width
        text: modelData.label + "  (" + modelData.role + ")"
        onClicked: { attenteDialog.close(); engine.resumeWaiting(modelData); }
        onPressAndHold: engine.zoomToFeature(modelData.role, modelData.fid)
      }
    }
  }

  /* ---------------- levée d'ambiguïté (suppression) ---------------- */
  Dialog {
    id: ambDialog
    parent: mainWindow.contentItem; modal: true; title: "Plusieurs éléments : choisir celui à supprimer"; width: 400; height: 400
    standardButtons: Dialog.Close
    onAboutToShow: dialogs.center(ambDialog)
    contentItem: ListView {
      id: ambList
      clip: true
      delegate: ItemDelegate {
        required property var modelData
        width: ambList.width
        text: modelData.label + "   (" + modelData.dist.toFixed(2) + " m)"
        onClicked: { ambDialog.close(); engine.deleteElement(modelData.role, modelData.fid); }
        onPressAndHold: engine.zoomToFeature(modelData.role, modelData.fid)
      }
    }
  }

  /* ---------------- suppression d'un point d'appui ---------------- */
  Dialog {
    id: supprDialog
    parent: mainWindow.contentItem; modal: true; title: "Point d'appui d'un excentrement"; width: 380
    standardButtons: Dialog.Cancel
    onAboutToShow: dialogs.center(supprDialog)
    contentItem: ColumnLayout {
      Text { Layout.fillWidth: true; wrapMode: Text.WordWrap; color: QfTheme.mainTextColor; text: "Le point " + (dialogs.payload.matricule || "") + " sert d'appui à " + (dialogs.payload.nb || 0) + " point(s) excentré(s)." }
      TopoBtn { Layout.fillWidth: true; height: 44; text: "OUI : supprimer aussi les points excentrés"; fontSize: 10; baseColor: "#ffd6d6"; onClicked: { supprDialog.close(); engine.deleteElement("pt_topo", dialogs.payload.fid, false); } }
      TopoBtn { Layout.fillWidth: true; height: 44; text: "NON : les conserver (points construits)"; fontSize: 10; onClicked: { supprDialog.close(); engine.deleteElement("pt_topo", dialogs.payload.fid, true); } }
    }
  }

  /* ---------------- excentrements favoris ---------------- */
  Dialog {
    id: excentConfigDialog
    parent: mainWindow.contentItem; modal: true; title: "Excentrements affichés"; width: 340
    standardButtons: Dialog.Ok | Dialog.Cancel
    onAboutToShow: dialogs.center(excentConfigDialog)
    property var all: ["point", "perp_prec", "perp_suiv", "vertical", "milieu", "deux_dist"]
    contentItem: ColumnLayout {
      Repeater {
        id: excentChecks
        model: excentConfigDialog.all
        CheckBox { required property var modelData; text: engine.excentLabels[modelData]; checked: engine.excentFavoris.indexOf(modelData) >= 0 }
      }
    }
    onAccepted: {
      let fav = [];
      for (let i = 0; i < excentChecks.count; i++) if (excentChecks.itemAt(i).checked) fav.push(excentConfigDialog.all[i]);
      engine.excentFavoris = fav; engine.saveSettings();
    }
  }

  /* ---------------- simulateur : saisie hz / v / di ---------------- */
  Dialog {
    id: simDialog
    property bool anglesSeuls: false
    parent: mainWindow.contentItem; modal: true; title: "Entrée clavier (simulateur de station)"; width: 340
    standardButtons: Dialog.Ok | Dialog.Cancel
    onAboutToShow: dialogs.center(simDialog)
    contentItem: GridLayout {
      columns: 2
      Text { text: "Hz (grades) :"; color: QfTheme.mainTextColor } TextField { id: simHz; Layout.fillWidth: true; text: "0.0000"; inputMethodHints: Qt.ImhFormattedNumbersOnly }
      Text { text: "V (grades, 100 = horizon) :"; color: QfTheme.mainTextColor } TextField { id: simV; Layout.fillWidth: true; text: "100.0000"; inputMethodHints: Qt.ImhFormattedNumbersOnly }
      Text { visible: !simDialog.anglesSeuls; text: "Distance inclinée (m) :"; color: QfTheme.mainTextColor } TextField { id: simSd; visible: !simDialog.anglesSeuls; Layout.fillWidth: true; text: "10.000"; inputMethodHints: Qt.ImhFormattedNumbersOnly }
    }
    onAccepted: { if (dialogs.payload.cb) dialogs.payload.cb({ "hz": parseFloat(simHz.text) || 0, "v": parseFloat(simV.text) || 100, "sd": parseFloat(simSd.text) || 0 }); }
  }

  /* ---------------- résultat d'une visée de référence ---------------- */
  Dialog {
    id: refDialog
    parent: mainWindow.contentItem; modal: true; title: "Visée de référence"; width: 380
    standardButtons: Dialog.Ok | Dialog.Cancel
    onAboutToShow: dialogs.center(refDialog)
    contentItem: Text {
      wrapMode: Text.WordWrap; color: QfTheme.mainTextColor
      text: {
        const r = dialogs.payload.ref;
        if (!r) return "";
        let s = "Cible : " + r.cible + "\nHz " + Topo.fmtGr(r.hz) + "   V " + Topo.fmtGr(r.v) + (Core.isNum(r.sd) ? "   Di " + Core.fmt(r.sd, 3) + " m" : "") + "\nV0 = " + Topo.fmtGr(r.v0) + " gr";
        if (Core.isNum(r.ecart_plani)) s += "\n\nÉcart planimétrique : " + Core.fmt(r.ecart_plani, 3) + " m" + (r.ecart_plani > station.toleranceEcart ? "  ⚠ hors tolérance" : "") + "\nÉcart altimétrique : " + Core.fmt(r.ecart_alti, 3) + " m";
        if (r.type === "REF_APPROCHEE") s += "\n\nVisée approchée : à remplacer par une visée précise sur la même cible.";
        return s + "\n\nAccepter cette visée ?";
      }
    }
    onAccepted: { if (dialogs.payload.cb) dialogs.payload.cb(true); }
    onRejected: { if (dialogs.payload.cb) dialogs.payload.cb(false); }
  }

  /* ---------------- détection (saisie manuelle) ---------------- */
  Dialog {
    id: detDialog
    parent: mainWindow.contentItem; modal: true; title: "Détection – saisie manuelle"; width: 340
    standardButtons: Dialog.Ok | Dialog.Cancel
    onAboutToShow: dialogs.center(detDialog)
    contentItem: GridLayout {
      columns: 2
      Text { text: "Profondeur (m) :"; color: QfTheme.mainTextColor } TextField { id: detProf; Layout.fillWidth: true; inputMethodHints: Qt.ImhFormattedNumbersOnly }
      Text { text: "Index :"; color: QfTheme.mainTextColor } TextField { id: detIndex; Layout.fillWidth: true }
      Text { text: "Intensité :"; color: QfTheme.mainTextColor } TextField { id: detInt; Layout.fillWidth: true; inputMethodHints: Qt.ImhFormattedNumbersOnly }
      Text { text: "Fréquence :"; color: QfTheme.mainTextColor } TextField { id: detFreq; Layout.fillWidth: true; inputMethodHints: Qt.ImhFormattedNumbersOnly }
      CheckBox { Layout.columnSpan: 2; text: "Dès réception : déclencher la mesure aussitôt"; checked: engine.detectionAuto; onToggled: engine.detectionAuto = checked }
    }
    onAccepted: engine.setDetection({ "profondeur": parseFloat(detProf.text) || 0, "index": detIndex.text, "intensite": parseFloat(detInt.text), "frequence": parseFloat(detFreq.text), "mode": "manuel" })
  }

  /* ---------------- seuils de précision GNSS ---------------- */
  Dialog {
    id: seuilsDialog
    parent: mainWindow.contentItem; modal: true; title: "Paramétrage des seuils de précision GNSS"; width: 380
    standardButtons: Dialog.Ok | Dialog.Cancel
    onAboutToShow: dialogs.center(seuilsDialog)
    property var criteres: [["hrms", "HRMS (m)"], ["vrms", "VRMS (m)"], ["hdop", "HDOP"], ["pdop", "PDOP"], ["vdop", "VDOP"]]
    function load() {
      for (let i = 0; i < seuilRows.count; i++) {
        const key = criteres[i][0], s = engine.seuils[key] || { "actif": false, "limite": 0 };
        seuilRows.itemAt(i).actif = s.actif; seuilRows.itemAt(i).limite = String(s.limite);
      }
      nbSat.text = String(engine.seuils.nb_sat_min || 0);
      fixBox.currentIndex = engine.seuils.fix_requis === 4 ? 0 : engine.seuils.fix_requis === 5 ? 1 : engine.seuils.fix_requis === 2 ? 2 : 3;
      tolOrange.text = String(engine.seuils.tolerance_orange || 2);
    }
    contentItem: ColumnLayout {
      RowLayout { Text { text: "Critère"; font.bold: true; Layout.preferredWidth: 160; color: QfTheme.mainTextColor } Text { text: "Limite"; font.bold: true; color: QfTheme.mainTextColor } }
      Repeater {
        id: seuilRows
        model: seuilsDialog.criteres
        RowLayout {
          required property var modelData
          property alias actif: chk.checked
          property alias limite: lim.text
          CheckBox { id: chk; text: modelData[1]; Layout.preferredWidth: 160 }
          TextField { id: lim; Layout.preferredWidth: 90; inputMethodHints: Qt.ImhFormattedNumbersOnly }
        }
      }
      RowLayout { Text { text: "Satellites minimum :"; Layout.preferredWidth: 160; color: QfTheme.mainTextColor } TextField { id: nbSat; Layout.preferredWidth: 90; inputMethodHints: Qt.ImhDigitsOnly } }
      RowLayout { Text { text: "Fix requis :"; Layout.preferredWidth: 160; color: QfTheme.mainTextColor } ComboBox { id: fixBox; Layout.fillWidth: true; model: ["RTK fixe", "RTK fixe ou flottant", "DGPS ou mieux", "Aucun"] } }
      RowLayout { Text { text: "Marge orange (x limite) :"; Layout.preferredWidth: 160; color: QfTheme.mainTextColor } TextField { id: tolOrange; Layout.preferredWidth: 90; inputMethodHints: Qt.ImhFormattedNumbersOnly } }
    }
    onAccepted: {
      let s = {};
      for (let i = 0; i < seuilRows.count; i++) s[criteres[i][0]] = { "actif": seuilRows.itemAt(i).actif, "limite": parseFloat(seuilRows.itemAt(i).limite) || 0 };
      s.nb_sat_min = parseInt(nbSat.text) || 0;
      s.fix_requis = [4, 5, 2, 0][fixBox.currentIndex];
      s.tolerance_orange = parseFloat(tolOrange.text) || 2;
      engine.seuils = s; engine.saveSettings(); engine.evalQuality();
    }
  }

  /* ---------------- réglages généraux ---------------- */
  Dialog {
    id: settingsDialog
    parent: mainWindow.contentItem; modal: true; title: "Paramètres"; width: 400
    standardButtons: Dialog.Ok | Dialog.Cancel
    onAboutToShow: dialogs.center(settingsDialog)
    function load() {
      droitierSw.checked = engine.droitier; bureauSw.checked = engine.modeBureau; zoomSw.checked = engine.zoomAuto; appuiSw.checked = engine.pointsAppuiVisibles;
      matField.text = engine.db.getParam("matricule_prochain", "1000"); tolField.text = (engine.tolImplantation * 100).toFixed(1); opField.text = engine.db.operateur;
    }
    contentItem: ColumnLayout {
      Switch { id: droitierSw; text: checked ? "Mode droitier (panneau à droite)" : "Mode gaucher (panneau à gauche)" }
      Switch { id: bureauSw; text: checked ? "Mode bureau (clics directs)" : "Mode terrain (clics confirmés)" }
      Switch { id: zoomSw; text: "Recentrage automatique à la mesure" }
      Switch { id: appuiSw; text: "Points d'appui aux excentrements visibles" }
      RowLayout { Text { text: "Prochain matricule :"; color: QfTheme.mainTextColor } TextField { id: matField; Layout.fillWidth: true } }
      RowLayout { Text { text: "Tolérance d'implantation (cm) :"; color: QfTheme.mainTextColor } TextField { id: tolField; Layout.preferredWidth: 80; inputMethodHints: Qt.ImhFormattedNumbersOnly } }
      RowLayout { Text { text: "Opérateur :"; color: QfTheme.mainTextColor } TextField { id: opField; Layout.fillWidth: true } }
      TopoBtn { Layout.fillWidth: true; height: 40; text: "Seuils de précision GNSS…"; fontSize: 10; onClicked: dialogs.open("seuils", {}) }
    }
    onAccepted: {
      engine.droitier = droitierSw.checked; engine.modeBureau = bureauSw.checked; engine.zoomAuto = zoomSw.checked;
      engine.setPointsAppuiVisibles(appuiSw.checked);
      engine.tolImplantation = (parseFloat(tolField.text) || 5) / 100;
      engine.db.setParam("matricule_prochain", matField.text || "1000");
      engine.db.operateur = opField.text; engine.db.setParam("operateur", opField.text);
      engine.saveSettings(); engine.refreshUi();
    }
  }

  /* ---------------- import de points ---------------- */
  Dialog {
    id: importDialog
    parent: mainWindow.contentItem; modal: true; title: "Import d'un fichier de points"; width: 400
    standardButtons: Dialog.Ok | Dialog.Cancel
    onAboutToShow: dialogs.center(importDialog)
    contentItem: ColumnLayout {
      Text { Layout.fillWidth: true; wrapMode: Text.WordWrap; color: QfTheme.mainTextColor; text: "Fichier attendu : " + qgisProject.homePath + "/import/points.txt\nFormat : matricule X Y [Z] (séparateur espace, ; ou tabulation)." }
      RadioButton { id: impTopo; text: "Points importés (carnet de terrain)"; checked: true }
      RadioButton { id: impImpl; text: "Liste d'implantation" }
    }
    onAccepted: {
      const path = qgisProject.homePath + "/import/points.txt";
      if (!QfFileUtils.fileExists(path)) { engine.toast("Fichier absent : " + path); return; }
      const raw = QfFileUtils.readFileContent(path);
      let text = "";
      if (typeof raw === "string") text = raw;
      else if (raw && raw.byteLength !== undefined) { const bytes = new Uint8Array(raw); for (let i = 0; i < bytes.length; i++) text += String.fromCharCode(bytes[i]); }
      else text = String(raw);
      if (!text) { engine.toast("Fichier vide : " + path); return; }
      engine.importPointsFromText(text, impImpl.checked ? "implantation" : "pt_topo");
    }
  }
}
