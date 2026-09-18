## Lahocy Topo 0.5.0 — renommage complet et outil de test de liaison station

Reprise complète du plugin sur le principe d'interface du logiciel de référence :
palette 2 colonnes et sous‑palettes, boîte mesure et dessin (GNSS / station totale),
objets actifs multiples, excentrements, carnet de terrain et carnet polaire,
implantation, menu station (mise en station, visées de référence, station libre,
pilotage), détection. Catalogue générique converti du thème du logiciel de référence « Sbaa ».

### Fichiers de la release

| Fichier | Rôle |
|---|---|
| `lahocy-topo.zip` | plugin QField (« Install plugin from URL ») |
| `LahocyTopo-projet.zip` | projet QField générique (GeoPackage + .qgs) à ouvrir dans QField |
| `lahocy-bridge.zip` | pont local Python pour station totale / disto / détecteur (tablette Windows) |

### État

Testé sur QField Windows 4.3.3 : palette, levé GNSS (simulateur NMEA), symbole, texte,
carnet, mise en station, levé et excentrement au simulateur de station totale via le pont,
continuer / supprimer, paramètres. 30 tests unitaires des calculs (`tests/`). Reste à tester sur tablette
Android et avec de vrais appareils. Voir `CHANGELOG.md`, `README.md` et `docs/SPEC_LahocyTopo.md`.
