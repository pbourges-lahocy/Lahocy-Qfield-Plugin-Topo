## Lahocy Topo 0.7.0 — catalogue GéoBretagne

Le catalogue d'objets est désormais le **standard topographique régional GéoBretagne 2.0.6** :
26 familles, 575 objets avec leur identifiant, leur calque, leur classe PCRS et la règle de
levé du carnet (planimétrie, altimétrie) affichée dans la consigne. Sous-palettes filtrées
Surface / Sous-sol / Info, recherche par nom ou identifiant. Licence GPL-3.0 pour le catalogue
(voir `plugin/theme/LICENCE_CATALOGUE.md`).

Interface en trois zones (0.6) : barre du haut (source GNSS / station, hauteur, modules), barre
du bas (consigne, contexte, dernier point), panneau de levé. Station totale : liaison Bluetooth
GeoCOM validée avec une TS15 via l'application compagnon Android.

### Fichiers de la release

| Fichier | Rôle |
|---|---|
| `lahocy-topo.zip` | plugin QField (« Install plugin from URL ») |
| `LahocyTopo-projet.zip` | projet QField générique (GeoPackage + .qgs) à ouvrir dans QField |
| `lahocy-topolink.apk` | application compagnon Android (station totale / disto / détecteur) |
| `lahocy-bridge.zip` | pont local Python pour tablette Windows |

### État

Testé sur QField Windows 4.3.3 : palette GéoBretagne, mise en station et visée de référence au
simulateur (point mesuré à la position attendue), levé linéaire. Les méthodes déduites du carnet
sont à valider objet par objet sur le terrain (`tools/geobretagne_rules.json` pour corriger).
