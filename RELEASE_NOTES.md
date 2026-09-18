## Lahocy Topo 0.5.3 — application compagnon Android, liaison TS15 validée

Correctif 0.5.3 : verrouillage prisme (mode lock ATR activé, état stable) ; mesure ATR
possible sans verrouillage. 0.5.2 : avertissements GeoCOM 1280 à 1284 acceptés, libellés des codes.

Le plugin QField reproduit le principe d'interface du logiciel de référence : palette
2 colonnes et sous‑palettes, boîte mesure et dessin (GNSS / station totale), objets actifs
multiples, excentrements, carnet de terrain et carnet polaire, implantation, menu station
(mise en station, visées de référence, station libre, pilotage), détection.

Nouveau : **Lahocy Topo Link**, application Android qui ouvre la liaison Bluetooth avec la
station totale (GeoCOM), le DISTO et le détecteur, et répond au plugin sur `127.0.0.1:8765`.
Elle permet de **tester la liaison avec la station** (nom d'instrument, angles, batterie)
avant tout levé.

### Fichiers de la release

| Fichier | Rôle |
|---|---|
| `lahocy-topo.zip` | plugin QField (« Install plugin from URL ») |
| `LahocyTopo-projet.zip` | projet QField générique (GeoPackage + .qgs) à ouvrir dans QField |
| `lahocy-topolink.apk` | application compagnon Android (station totale / disto / détecteur) |
| `lahocy-bridge.zip` | pont local Python pour tablette Windows |

### État

Plugin testé sur QField Windows 4.3.3 (GNSS simulé, simulateur de station via le pont),
30 tests unitaires des calculs. Liaison Bluetooth GeoCOM validée avec une TS15 depuis
l'application compagnon (nom d'instrument, angles) ; mesure de distance et pilotage restent
à essayer sur le terrain : commencer par **Tester la liaison** dans Lahocy Topo Link.
Voir `README.md` (installation), `CHANGELOG.md` et `docs/SPEC_LahocyTopo.md`.
