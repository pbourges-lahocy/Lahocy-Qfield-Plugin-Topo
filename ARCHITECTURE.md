# Architecture

## Principe

QField fournit le moteur cartographique, les couches, le snapping, la symbologie, le
mode hors‑ligne et QFieldCloud. Le plugin **Lahocy Topo** apporte la couche métier
**topographique** : palette d'objets, cycle de placement (linéaires, symboles, textes…),
excentrements, carnet de terrain, implantation, station totale.

La spécification fonctionnelle complète (avec la correspondance chapitre par chapitre vers le manuel du logiciel de levé utilisé jusqu'ici) est dans [docs/SPEC_LahocyTopo.md](docs/SPEC_LahocyTopo.md).

## Structure du dépôt

```
plugin/                    plugin d'application QField (zippé par la release : lahocy-topo.zip)
  main.qml                 point d'entrée : bouton de barre d'outils, chargement, événements appareils
  metadata.txt             nom / version (doit correspondre au tag de release)
  icon.svg
  theme/theme.json         catalogue d'objets et palettes (équivalent du MDB de thème)
  theme/icons/             icônes des objets du catalogue (PNG)
  theme/ui/                icônes monochromes de l'interface (SVG, générées par tools/make_ui_icons.py)
  topo/
    TopoCore.js             géométrie : arcs, courbes, parallèles, excentrements, WKT
    TopoCalc.js             topographie : réduction polaire, V0, station libre (moindres carrés), GSI
    TopoData.qml            accès aux couches du GeoPackage (création / mise à jour / suppression, paramètres)
    TopoEngine.qml          logique métier du levé (objets actifs, mesures, excentrements, carnet, implantation)
    TopoStation.qml         contexte station totale (mise en station, références, station libre, pilotage)
    TopoDevices.qml         client HTTP du pont local (statut, événements)
    TopoTopBar.qml          barre du haut (Popup non modal) : source et qualité, hauteur, modules
    TopoBottomBar.qml       barre du bas : consigne, confirmation de clic, actions de contexte, dernier point
    TopoPanel.qml           panneau latéral repliable : palette, dessin, mesure, objets actifs
    TopoPalette.qml         palette 4 colonnes : familles, sous-palette en place, recherche par nom
    TopoMeasureBox.qml      excentrements favoris, Mesurer / STOP, point unique, dernier point
    TopoDrawOptions.qml     primitives de dessin selon la famille, détection, guidage
    TopoGuidage.qml         guidage d'implantation
    TopoActiveObjects.qml   liste des objets actifs, relance du dernier objet
    TopoStationMenu.qml     menu Station
    TopoCarnet.qml          carnet de terrain et carnet polaire
    TopoImplantation.qml    gestionnaire d'implantation
    TopoDialogs.qml         dialogues (texte, excentrements, seuils GNSS, réglages, simulateur…)
    TopoBtn.qml             bouton carré de palette
project/LahocyTopo/        projet QField générique (GeoPackage + .qgs), zippé dans la release
bridge/                    pont local Python (Windows) : serveur HTTP + pilotes (simulateur, GeoCOM, disto BLE, détecteur)
companion/                 application compagnon Android « Lahocy Topo Link » (Kotlin) : même contrat HTTP,
                           Bluetooth SPP (GeoCOM, détecteur) et BLE (DISTO), service de premier plan, test de liaison
tools/                     scripts bureau : conversion d'un thème, génération du projet
docs/                      spécification
```

## Flux de données

- Toute mesure crée un **point topo** (`pt_topo`) avec ses métadonnées (qualité GNSS ou
  observations brutes station : Hz, V, Di, hi, hr, face). Les primitives (`lineaire`,
  `surface`, `symbole`, `texte`, `entree`, `talus`) référencent les matricules utilisés et
  conservent leur définition exacte dans `params_json` : un recalcul de points (V0,
  station libre, compensation) **régénère** les primitives.
- Les objets en cours et en attente sont persistés (`statut`) : reprise après fermeture.
- Les réglages sont dans la table `topo_param` (synchronisés avec le projet).

## Appareils

Un plugin QML ne peut pas ouvrir de port série / Bluetooth : une station totale se pilote en
**dialogue** (requête GeoCOM → réponse), alors que QField n'offre aux plugins que des
récepteurs GNSS en lecture seule et que le QML de Qt 6 n'expose ni Bluetooth ni port série.
Le plugin parle donc à un **pont** en HTTP sur `127.0.0.1:8765` qui expose des primitives
« mesurer / tourner / chercher / lire une distance » ; le plugin fait tous les calculs.

Deux implémentations du même contrat (routes et JSON identiques, voir `docs/SPEC_LahocyTopo.md` §14.2) :

- **Android : `companion/` (Lahocy Topo Link, Kotlin)**. Service de premier plan avec
  serveur HTTP (NanoHTTPD) lié à `127.0.0.1`, pilotes portés ligne à ligne du pont Python :
  `GeoComDriver` (Bluetooth SPP, RFCOMM), `DistoBle` (GATT, service Leica), `SerialDetector`
  (SPP), simulateurs. Le « port » envoyé par le plugin est une adresse MAC, un nom Bluetooth
  ou vide (station choisie dans l'application). L'écran unique sert à choisir la station,
  tester la liaison (mêmes étapes que `geocom_test.py`) et démarrer / arrêter le pont.
- **Windows : `bridge/` (Python, pyserial / bleak)**, avec `bridge/geocom_test.py` pour
  valider la liaison sans QField.

Voie « directement dans QField » : elle passerait par une contribution au cœur C++ de QField
(un type QML de socket Bluetooth/série pour les plugins, à faire accepter par OPENGIS.ch) ou
par un build QField maison. Le plugin garderait la même couche `TopoDevices.qml` : seul le
transport changerait.

## Leçons du POC (Android)

- Un `Item` reparenté sur `mainWindow.contentItem` ne se repeint pas de façon fiable sur
  certaines tablettes ; les `Dialog` / `Popup` (Overlay de QtQuick Controls) fonctionnent.
  Le panneau est donc un `Popup { modal: false; closePolicy: Popup.NoAutoClose }`.
- Utiliser `mainWindow.sceneTopMargin / sceneBottomMargin / sceneRightMargin` pour rester
  dans la zone sûre (barre d'état, boutons de navigation).
- Ne pas redéfinir une propriété FINAL de QML (`data`, `result`…) dans un composant.
