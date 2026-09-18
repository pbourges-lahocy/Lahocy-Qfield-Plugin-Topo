# Lahocy Topo

Plugin d'application **QField** qui reproduit le principe d'interface du logiciel de levé utilisé
jusqu'ici : palette d'objets à deux niveaux, boîte « mesure et dessin », objets actifs,
excentrements, carnet de terrain, implantation, menu station totale. Le plan est mis en
forme au bureau dans QGIS ; un seul catalogue d'objets générique est utilisé sur le terrain.

- Spécification fonctionnelle : [docs/SPEC_LahocyTopo.md](docs/SPEC_LahocyTopo.md)
- Structure du code : [ARCHITECTURE.md](ARCHITECTURE.md)
- Historique : [CHANGELOG.md](CHANGELOG.md)

**État : 0.6.0, testé sur QField Windows ; liaison station totale validée avec une TS15 sur Android.** Voir [Cycle de test](#cycle-de-test).

L'interface se compose d'une **barre du haut** (source de mesure GNSS ou station avec sa
qualité, hauteur de canne ou de prisme, accès aux modules), d'une **barre du bas** (consigne,
confirmation des clics, actions de contexte, dernier point) et d'un **panneau latéral**
repliable (palette d'objets avec recherche par nom, dessin, Mesurer, objets actifs).

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
QFieldCloud) et ouvrir `LahocyTopo.qgs`. Le bouton **Topo** de la barre d'outils affiche ou
masque l'interface (panneau à droite en mode droitier, à gauche en mode gaucher). Un projet client se construit au bureau en gardant ces
couches (le script `tools/build_project.py` les crée dans le système de projection voulu).

### 3. GNSS

Le récepteur est configuré dans QField (interne, Bluetooth NMEA, NTRIP, hauteur d'antenne).
Le plugin lit la position et applique ses propres seuils de précision (bouton **Param.**),
avec le voyant vert / orange / rouge du logiciel de référence.

### 4. Station totale, disto, détecteur

Un plugin QField ne peut pas ouvrir de port série ou Bluetooth : le pilotage passe par un
petit programme « pont » sur la tablette, qui parle aux appareils et répond au plugin sur
`127.0.0.1:8765`. Sur le terrain il n'y a donc que deux applications : QField (avec le GNSS,
interne, Bluetooth NMEA ou application constructeur) et le pont, qui ne sert que lorsqu'on
sort la station.

#### Tablette Android : application compagnon « Lahocy Topo Link »

`lahocy-topolink.apk` est dans la release.

1. Installer l'APK (autoriser l'installation depuis ce fichier), accorder les permissions
   Bluetooth et notifications au premier lancement.
2. Appairer la station dans les réglages Bluetooth d'Android (station allumée, Bluetooth
   actif, mode GeoCOM ; licence GeoCOM robotique nécessaire pour ATR, recherche et moteurs).
3. Ouvrir Lahocy Topo Link, choisir la station dans la liste, **Tester la liaison** : le
   journal affiche le nom de l'instrument, les angles et la batterie.
4. **Démarrer le pont** (une notification permanente reste affichée), revenir dans QField :
   **Menu station → Paramètres** → appareil `geocom`, port vide → **Connecter**.

Le DISTO (Bluetooth Smart) et le détecteur de réseaux (Bluetooth série) passent par la même
application. Le pilote `simulateur` fonctionne sans appareil, comme l'« Entrée clavier » du
logiciel de référence.

#### Tablette Windows : pont Python

Le **pont local** `lahocy-bridge.zip` (Python) rend le même service sur Windows.

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
(Bluetooth interne ou poignée RH17), **Connecter**.

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
   en `LahocyTopo-projet.zip` et `bridge/` en `lahocy-bridge.zip`, publie la release, puis
   compile l'application compagnon Android et l'ajoute en `lahocy-topolink.apk` (signée avec
   la clé des secrets `TOPOLINK_*` du dépôt ; sauvegarde locale de la clé hors dépôt).
   Chaque modification de `companion/` sur `main` est aussi compilée par
   [`companion-ci.yml`](.github/workflows/companion-ci.yml) (APK de debug en artefact).

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
