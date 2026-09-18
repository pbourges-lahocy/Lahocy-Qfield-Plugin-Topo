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
  theme/icons/             icônes des boutons
  topo/
    TopoCore.js             géométrie : arcs, courbes, parallèles, excentrements, WKT
    TopoCalc.js             topographie : réduction polaire, V0, station libre (moindres carrés), GSI
    TopoData.qml            accès aux couches du GeoPackage (création / mise à jour / suppression, paramètres)
    TopoEngine.qml          logique métier du levé (objets actifs, mesures, excentrements, carnet, implantation)
    TopoStation.qml         contexte station totale (mise en station, références, station libre, pilotage)
    TopoDevices.qml         client HTTP du pont local (statut, événements)
    TopoPanel.qml           panneau latéral (Popup non modal) : ruban + zones 3 / 4 / 5
    TopoPalette.qml         zone 3 : palette principale et sous-palettes
    TopoMeasureBox.qml      zone 4 haut : excentrements, hauteur, STOP, acquisition, qualité
    TopoDrawOptions.qml     zone 4 milieu : primitives de dessin selon la famille, confirmation de clic
    TopoGuidage.qml         guidage d'implantation
    TopoActiveObjects.qml   zone 5 : objets actifs, relance, attente
    TopoStationMenu.qml     menu Station
    TopoCarnet.qml          carnet de terrain et carnet polaire
    TopoImplantation.qml    gestionnaire d'implantation
    TopoDialogs.qml         dialogues (texte, excentrements, seuils GNSS, réglages, simulateur…)
    TopoBtn.qml             bouton carré de palette
project/LahocyTopo/        projet QField générique (GeoPackage + .qgs), zippé dans la release
bridge/                    pont local Python : serveur HTTP + pilotes (simulateur, GeoCOM, disto BLE, détecteur)
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

Un plugin QML ne peut pas ouvrir de port série / Bluetooth. Le pont local
(`bridge/topo_bridge.py`) expose des primitives « mesurer / tourner / chercher / lire une
distance » en HTTP sur `127.0.0.1:8765` ; le plugin fait tous les calculs. Aujourd'hui le
pont tourne sur tablette Windows (Python).

**Avant tout : valider la liaison avec la station** avec `bridge/geocom_test.py` (port COM,
nom d'instrument, batterie, angles, verrouillage, mesure), sans QField.

### Connexion directe des appareils dans QField (Android) : options

Pourquoi ce n'est pas immédiat : une station totale se pilote en **dialogue** (requête
GeoCOM → réponse), alors que QField n'offre aux plugins que des récepteurs GNSS en lecture
seule (Bluetooth NMEA, TCP, UDP, fichier, capteurs QGIS) et que le QML de Qt 6 n'expose plus
ni Bluetooth ni port série. Trois voies, de la plus rapide à la plus intégrée :

1. **Application compagnon Android** (Kotlin) : service en arrière‑plan qui ouvre la
   liaison Bluetooth SPP avec la station et sert **le même contrat HTTP** que le pont Python
   sur `127.0.0.1`. Le plugin ne change pas ; les pilotes GeoCOM se portent ligne à ligne.
   Quelques centaines de lignes, pas de build QField. C'est la voie recommandée à court terme.
2. **Contribution à QField** : ajouter au cœur C++ un type QML générique de socket
   Bluetooth/série accessible aux plugins (`org.qfield.core`). Une fois accepté en amont
   (OPENGIS.ch), le plugin parlerait GeoCOM directement depuis le QML. Délai incertain,
   mais c'est la seule vraie solution « directement dans QField ».
3. **Build QField maison** avec ce type : contrôle total, mais maintenance d'une version
   forkée sur Android (NDK, vcpkg) — à réserver si la voie 2 échoue.

Dans les trois cas, le plugin garde la même couche `TopoDevices.qml` : seul le transport
change (HTTP local aujourd'hui, socket QML demain).

## Leçons du POC (Android)

- Un `Item` reparenté sur `mainWindow.contentItem` ne se repeint pas de façon fiable sur
  certaines tablettes ; les `Dialog` / `Popup` (Overlay de QtQuick Controls) fonctionnent.
  Le panneau est donc un `Popup { modal: false; closePolicy: Popup.NoAutoClose }`.
- Utiliser `mainWindow.sceneTopMargin / sceneBottomMargin / sceneRightMargin` pour rester
  dans la zone sûre (barre d'état, boutons de navigation).
- Ne pas redéfinir une propriété FINAL de QML (`data`, `result`…) dans un composant.
