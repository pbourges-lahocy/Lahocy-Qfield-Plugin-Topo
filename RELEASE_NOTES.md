## Lahocy Topo 0.8.1 — symbologie du standard GéoBretagne

0.8.1 : choix du nombre de points de pose d'un symbole (1, 2 ou 3), plus d'étiquettes de nom sur les objets dessinés.

Le projet dessine désormais les objets **comme le standard** : couleur et épaisseur des calques,
types de ligne avec leurs tirets et leurs textes intégrés (« aep », « ep », « » »…), hachures du
standard, blocs SVG à taille réelle dans la couleur de l'objet. Les icônes de la palette sont
dessinées à partir du catalogue (blocs colorés avec le nombre de points, tirets des linéaires,
motifs des hachures) et les familles portent la couleur du nuancier.

Il faut **réinstaller le projet** (`LahocyTopo-projet.zip`) : nouvelle symbologie et nouveau
champ `couleur` sur les couches.

Rappel des versions précédentes : catalogue GéoBretagne 2.0.6 (26 familles, 575 objets, règles de
levé du carnet), blocs SVG orientés et mis à l'échelle par les points levés, colonne d'objets et
panneau de mesure, application compagnon Android pour la station totale (liaison TS15 validée).

### Fichiers de la release

| Fichier | Rôle |
|---|---|
| `lahocy-topo.zip` | plugin QField (« Install plugin from URL ») |
| `LahocyTopo-projet.zip` | projet QField générique (GeoPackage + .qgs + blocs SVG) à ouvrir dans QField |
| `lahocy-topolink.apk` | application compagnon Android (station totale / disto / détecteur) |
| `lahocy-bridge.zip` | pont local Python pour tablette Windows |
