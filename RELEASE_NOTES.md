## Lahocy Topo 0.6.0 — nouvelle interface

Interface repensée en trois zones : **barre du haut** (source GNSS / station avec sa
qualité, hauteur de canne ou de prisme, modules), **barre du bas** (consigne, confirmation
des clics, actions de contexte, dernier point mesuré) et **panneau latéral** réduit au levé
(palette 4 colonnes avec recherche par nom, dessin, Mesurer / STOP, objets actifs), repliable.
Icônes monochromes propres au plugin.

Station totale : liaison Bluetooth GeoCOM validée avec une TS15 depuis l'application
compagnon Android (0.5.x : avertissements GeoCOM acceptés, verrouillage prisme stable).

### Fichiers de la release

| Fichier | Rôle |
|---|---|
| `lahocy-topo.zip` | plugin QField (« Install plugin from URL ») |
| `LahocyTopo-projet.zip` | projet QField générique (GeoPackage + .qgs) à ouvrir dans QField |
| `lahocy-topolink.apk` | application compagnon Android (station totale / disto / détecteur) |
| `lahocy-bridge.zip` | pont local Python pour tablette Windows |

### État

Plugin testé sur QField Windows 4.3.3 (GNSS simulé, simulateur de station via le pont) :
sous-palette, recherche, linéaire à plusieurs sommets, barres haut et bas. Mesure de distance
et pilotage sur station réelle restent à valider sur le terrain. Voir `README.md`,
`CHANGELOG.md` et `docs/SPEC_LahocyTopo.md`.
