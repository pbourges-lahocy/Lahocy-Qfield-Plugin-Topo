# Lahocy Topo

Plugin d'application **QField** qui reproduit le principe d'interface du logiciel de levé utilisé
jusqu'ici : palette d'objets à deux niveaux, boîte « mesure et dessin », objets actifs,
excentrements, carnet de terrain, implantation, menu station totale. Le plan est mis en
forme au bureau dans QGIS ; un seul catalogue d'objets générique est utilisé sur le terrain.

- Spécification fonctionnelle : [docs/SPEC_LahocyTopo.md](docs/SPEC_LahocyTopo.md)
- Structure du code : [ARCHITECTURE.md](ARCHITECTURE.md)
- Historique : [CHANGELOG.md](CHANGELOG.md)

**État : 0.5.0, testé sur QField Windows ; à tester sur tablette Android et avec de vrais appareils.** Voir [Cycle de test](#cycle-de-test).

## Installation sur la tablette

### 1. Le plugin

Dans QField : **Réglages → Plugins → Install plugin from URL**, coller :

```
https://github.com/pbourges-lahocy/Lahocy-Qfield-Plugin-Topo/releases/latest/download/lahocy-topo.zip
```

Le plugin « Lahocy Topo » apparaît avec un interrupteur d'activation. Pour mettre à jour,
recoller la **même URL** : l'asset garde toujours le même nom, QField remplace la version en
place.

### 2. Le projet

Le plugin travaille dans un projet QField contenant les couches du modèle
(`pt_topo`, `station`, `visee`, `lineaire`, `surface`, `symbole`, `texte`, `entree`, `talus`,
`implantation`, `topo_param`). Télécharger `LahocyTopo-projet.zip` depuis la
[dernière release](https://github.com/pbourges-lahocy/Lahocy-Qfield-Plugin-Topo/releases/latest),
le décompresser dans le dossier des projets de la tablette (ou le publier via QFieldSync /
QFieldCloud) et ouvrir `LahocyTopo.qgs`. Le bouton **Topo** de la barre d'outils affiche le
panneau à droite (mode droitier). Un projet client se construit au bureau en gardant ces
couches (le script `tools/build_project.py` les crée dans le système de projection voulu).

### 3. GNSS

Le récepteur est configuré dans QField (interne, Bluetooth NMEA, NTRIP, hauteur d'antenne).
Le plugin lit la position et applique ses propres seuils de précision (bouton **Param.**),
avec le voyant vert / orange / rouge du logiciel de référence.

### 4. Station totale, disto, détecteur (pont local)

Un plugin QField ne peut pas ouvrir de port série ou Bluetooth : le pilotage passe par le
**pont local** `lahocy-bridge.zip` (Python), à lancer sur la tablette Windows.

Première étape, **valider la liaison avec la station** sans QField (port COM du couplage
Bluetooth ou de la poignée radio, station en mode GeoCOM) :

```bash
pip install -r bridge/requirements.txt
python bridge/geocom_test.py --list
python bridge/geocom_test.py COM5 --measure
```

Puis lancer le pont :

```bash
python bridge/topo_bridge.py
```

Dans le plugin : **Menu station → Paramètres** → appareil `geocom`, port COM de la station
(Bluetooth interne ou poignée RH17), **Connecter**. Le pilote `simulateur` (entrée clavier)
permet de dérouler tout le cycle sans appareil, comme l'« Entrée clavier » du logiciel de référence.
Sur Android, le pont devra être porté dans une application compagnon (même API HTTP).

## Cycle de test

```
modification du code → commit + push → tag vX.Y.Z → GitHub Actions publie la release
→ "Install plugin from URL" sur la tablette → test → erreur QML ? corriger avec le message réel
```

Les erreurs QML apparaissent dans le journal des messages QField (menu ⋮ → Journal des
messages) : les recopier telles quelles pour correction.

## Publier une nouvelle version

1. Mettre à jour `version=` dans [`plugin/metadata.txt`](plugin/metadata.txt) et
   [`CHANGELOG.md`](CHANGELOG.md) (et `RELEASE_NOTES.md`).
2. Commit, push sur `main`, puis :

   ```bash
   git tag v0.4.1
   git push origin v0.4.1
   ```

3. Le workflow [`.github/workflows/release.yml`](.github/workflows/release.yml) vérifie la
   version, zippe `plugin/` en `lahocy-topo.zip` (+ copie versionnée), `project/LahocyTopo`
   en `LahocyTopo-projet.zip` et `bridge/` en `lahocy-bridge.zip`, puis publie la release.

## Outils bureau

```bash
# régénérer le projet générique dans un autre système de projection
C:\OSGeo4W\bin\python-qgis-ltr.bat tools\build_project.py 3948 project\LahocyTopo

# convertir un thème du logiciel de référence (MDB) en catalogue theme.json + icônes
python tools\theme_to_json.py "<dossier du thème>" plugin\theme
```

## Tests unitaires des calculs

`tests/run_tests.cmd` exécute `tests/test_calculs.qml` avec le runtime Qt d'OSGeo4W (sans
QField) : excentrements, arcs, parallèles, réduction polaire, double retournement, station
libre, relèvement, GSI. Toute modification de `TopoCore.js` ou `TopoCalc.js` doit le laisser vert.

## Sécurité

Aucun secret (NTRIP, QFieldCloud, tokens) ne doit être commité : voir `.gitignore`.
