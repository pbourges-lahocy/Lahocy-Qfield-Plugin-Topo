import QtQuick
import QtQuick.Controls
import org.qfield.core
import org.qfield.gui
import org.qgis
import "topo"
import "theme/theme.js" as ThemeData

/*
 * Lahocy Topo - plugin d'application QField.
 * Levé topographique : palette / sous-palettes, mesure et dessin,
 * objets actifs, excentrements, carnet, implantation, station totale (pont local).
 *
 * Le plugin a besoin d'un projet contenant les couches du modèle
 * (pt_topo, lineaire, topo_param, ...) : voir project/LahocyTopo et le README.
 */
Item {
  id: plugin

  property var mainWindow: iface.mainWindow()
  property var mapCanvas: iface.mapCanvas()
  property var positionSource: iface.findItemByObjectName("positionSource")
  property var pointHandler: iface.findItemByObjectName("pointHandler")
  property bool loaded: false
  property bool panelVisible: true
  readonly property string themeBase: Qt.resolvedUrl("theme/")

  TopoData { id: topoData }
  TopoDevices { id: devices }

  TopoEngine {
    id: engine
    db: topoData
    mainWindow: plugin.mainWindow
    mapCanvas: plugin.mapCanvas
    positionSource: plugin.positionSource
    station: station
    themeBase: plugin.themeBase
    onToast: msg => plugin.mainWindow.displayToast(msg)
    onRequestDialog: (kind, payload) => dialogs.open(kind, payload)
  }

  TopoStation {
    id: station
    engine: engine
    db: topoData
    devices: devices
    onToast: msg => plugin.mainWindow.displayToast(msg)
    onRequestDialog: (kind, payload) => dialogs.open(kind, payload)
  }

  TopoPanel {
    id: panel
    engine: engine
    station: station
    devices: devices
    mainWindow: plugin.mainWindow
    visible: plugin.loaded && plugin.panelVisible
    onOpenCarnet: carnet.open()
    onOpenImplantation: implantation.open()
    onOpenStationMenu: stationMenu.open()
    onOpenSettings: dialogs.open("settings", {})
    onOpenDetection: dialogs.open("detection", {})
  }

  TopoDialogs {
    id: dialogs
    engine: engine
    station: station
    devices: devices
    mainWindow: plugin.mainWindow
    onStationMenuRequested: stationMenu.open()
  }

  TopoCarnet { id: carnet; engine: engine; station: station; mainWindow: plugin.mainWindow }
  TopoImplantation { id: implantation; engine: engine; mainWindow: plugin.mainWindow }
  TopoStationMenu { id: stationMenu; engine: engine; station: station; devices: devices; mainWindow: plugin.mainWindow }

  /* ---------------- bouton de la barre d'outils QField ---------------- */
  QfToolButton {
    id: toggleButton
    iconSource: Qt.resolvedUrl("icon.svg")
    iconColor: plugin.loaded && plugin.panelVisible ? "white" : QfTheme.mainColor
    bgcolor: plugin.loaded && plugin.panelVisible ? QfTheme.mainColor : QfTheme.darkGray
    round: true
    onClicked: {
      if (!plugin.loaded) plugin.load();
      else plugin.panelVisible = !plugin.panelVisible;
    }
  }

  /* ---------------- événements des appareils ---------------- */
  Connections {
    target: devices
    function onDistoKey(key) {
      // télécommande : une mesure au disto = "Mesure point avec liaison"
      if (engine.excentMode || station.excentTps || engine.pending || engine.courant) engine.measure(true, false);
    }
    function onDetectorMeasure(m) {
      engine.setDetection(m);
      devices.detectorAck();
    }
    function onTpsLock(locked) {
      if (!locked) { plugin.mainWindow.displayToast("Prisme perdu"); lostTimer.restart(); }
      else { lostTimer.stop(); plugin.mainWindow.displayToast("Prisme verrouillé"); }
    }
    function onSearchDone(found) { plugin.mainWindow.displayToast(found ? "Prisme trouvé" : "Prisme non trouvé"); }
  }
  Timer {
    id: lostTimer
    interval: 3000
    onTriggered: { if (engine.mesureSource === "tps" && !devices.tpsLocked && station.driver !== "simulateur") stationMenu.open(); }
  }

  /* ---------------- chargement ---------------- */
  function load() {
    plugin.loaded = false;
    if (!topoData.hasLayers()) {
      if (qgisProject && qgisProject.fileName) plugin.mainWindow.displayToast("Lahocy Topo : ce projet ne contient pas les couches du modèle (pt_topo, lineaire, topo_param) – ouvrir le projet LahocyTopo");
      return;
    }
    topoData.mapSettings = plugin.mapCanvas.mapSettings;
    topoData.operateur = topoData.getParam("operateur", "");
    // catalogue embarqué dans le plugin (theme/theme.js, généré à partir de theme.json)
    let theme = ThemeData.THEME;
    if (!theme || !theme.objets) { plugin.mainWindow.displayToast("Lahocy Topo : catalogue theme.js absent ou invalide"); theme = { "palette": [], "objets": {}, "listes_textes": {} }; }
    engine.init(theme);
    station.init();
    engine.mesureSource = topoData.getParam("mesure_source", "gnss");
    plugin.registerHandler();
    plugin.loaded = true;
    plugin.panelVisible = true;
    plugin.mainWindow.displayToast("Lahocy Topo chargé – thème " + (theme.nom || "") + " (" + Object.keys(theme.objets || {}).length + " objets)");
  }

  property bool handlerRegistered: false
  function registerHandler() {
    if (!plugin.pointHandler || plugin.handlerRegistered) return;
    plugin.handlerRegistered = plugin.pointHandler.registerHandler("Topo", function (point, type, interactionType) {
      return engine.mapClicked(point, interactionType);
    }, 100);
  }

  Connections {
    target: iface
    function onLoadProjectEnded() { Qt.callLater(plugin.load); }
  }

  Component.onCompleted: {
    iface.addItemToPluginsToolbar(toggleButton);
    Qt.callLater(plugin.load);
  }

  Component.onDestruction: {
    if (plugin.pointHandler && plugin.handlerRegistered) plugin.pointHandler.deregisterHandler("Topo");
  }
}
