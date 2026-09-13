# Lahocy Topo

Plugin d'application QField apportant la couche metier topographique
(Lahocy) au-dessus du moteur SIG terrain QField : calculs topo, carnet
d'observations, pilotage d'instruments (GNSS, stations totales), et a
terme integration a notre PostGIS central.

**Etat actuel : POC.** Les fonctionnalites sont ajoutees progressivement.
Voir [ARCHITECTURE.md](ARCHITECTURE.md) pour la structure du code et la
vision a long terme, [CHANGELOG.md](CHANGELOG.md) pour l'historique des
versions.

## Installation sur la tablette (QField Android)

1. Dans QField, ouvrir **Reglages -> Plugins**.
2. Appuyer sur **"Install plugin from URL"**.
3. Coller l'URL suivante :

   ```
   https://github.com/pbourges-lahocy/Lahocy-Qfield-Plugin-Topo/releases/latest/download/lahocy-topo.zip
   ```

4. Le plugin "Lahocy Topo" apparait dans la liste, avec un interrupteur
   d'activation.

Cette URL pointe toujours vers la derniere version publiee (voir
[Distribution](#distribution) ci-dessous).

## Mise a jour sur la tablette

Quand une nouvelle version est publiee (voir [Publier une nouvelle
version](#publier-une-nouvelle-version)) :

1. Retourner dans **Reglages -> Plugins**.
2. Appuyer a nouveau sur **"Install plugin from URL"**.
3. Coller la **meme URL** que ci-dessus.

QField remplace la version installee par la nouvelle, plutot que d'en
installer un doublon - a condition de toujours reinstaller depuis la meme
URL avec le meme nom de fichier. C'est pour cela que le nom de l'asset de
release (`lahocy-topo.zip`) ne change jamais entre les versions.

## Cycle de developpement

```
modification du code
        |
        v
   commit + push
        |
        v
  tag vX.Y.Z (declenche la release)
        |
        v
  GitHub Actions publie lahocy-topo.zip
        |
        v
  "Install plugin from URL" sur la tablette
        |
        v
       test
        |
        v
  erreur QML ? -> corriger avec le message d'erreur reel, recommencer
```

### Publier une nouvelle version

1. Mettre a jour la ligne `version=` dans [`plugin/metadata.txt`](plugin/metadata.txt).
2. Ajouter une entree dans [`CHANGELOG.md`](CHANGELOG.md).
3. Commit, push sur `main`.
4. Creer et pousser un tag correspondant :

   ```bash
   git tag v0.1.1
   git push origin v0.1.1
   ```

5. Le workflow [`.github/workflows/release.yml`](.github/workflows/release.yml)
   verifie que le tag correspond bien a la version dans `metadata.txt`,
   zippe le contenu de `plugin/`, et publie une release GitHub avec deux
   fichiers :
   - `lahocy-topo.zip` (nom fixe, c'est celui que la tablette utilise) ;
   - `lahocy-topo-X.Y.Z.zip` (copie horodatee, pour l'historique).

Si le tag et `metadata.txt` ne correspondent pas, la release echoue avec un
message clair plutot que de publier une version incoherente.

## Distribution : pourquoi cette methode

QField installe les plugins d'application via un bouton **"Install plugin
from URL"** qui telecharge un fichier `.zip` (le fichier `main.qml` doit
etre a la racine du zip). Le nom de ce fichier zip determine le dossier
d'installation sur l'appareil : reinstaller depuis une URL servant
toujours le meme nom de fichier met a jour le plugin existant ; changer de
nom de fichier cree un second plugin en double.

GitHub propose une URL stable pour "le dernier fichier nomme X publie
parmi les releases" :

```
https://github.com/<compte>/<repot>/releases/latest/download/<nom-fixe>
```

En attachant toujours un asset `lahocy-topo.zip` (meme nom) a chaque
release, cette URL pointe automatiquement vers la derniere version sans
jamais changer - c'est l'URL a coller une seule fois dans QField.

## Securite

Aucun secret (mots de passe NTRIP, identifiants QFieldCloud, tokens, etc.)
ne doit se trouver dans ce depot. Voir `.gitignore` pour les patterns
exclus. La gestion de secrets locaux (NTRIP, cloud) sera mise en place
localement sur chaque poste/appareil quand ces fonctionnalites seront
developpees - jamais commitee.
