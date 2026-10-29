# Brumeval (Godot 4)

RPG pixel vu de dessus : masques, transfert d'âme, village à bâtir, options sociales. Version Godot du prototype web.

## Lancer le jeu

1. Installer [Godot 4.3](https://godotengine.org/download) (version standard, pas .NET).
2. Ouvrir Godot, cliquer sur **Importer**, choisir le fichier `project.godot` de ce dossier.
3. Appuyer sur **F5** pour jouer.

Sur écran tactile, le pouce gauche fait bouger (joystick qui apparaît où on pose le doigt) et les boutons à droite attaquent, parlent, utilisent l'âme ou une potion.

Commandes : ZQSD ou WASD pour bouger (clavier AZERTY et QWERTY), Espace pour attaquer, E pour interagir, R pour le transfert d'âme, B pour construire, I pour le sac, M pour la carte, H pour une potion, Échap pour la pause. La manette marche aussi (A attaque, X interagir, Y âme).

## Organisation

| Fichier | Rôle |
| --- | --- |
| `scenes/main.tscn` | Scène principale : le monde, la caméra, la lumière de nuit et l'interface |
| `scripts/defs.gd` | Équilibrage : créatures, bâtiments, recettes, zones, quêtes |
| `scripts/world.gd` | Carte, joueur, IA, combat, bâtiments, temps, sauvegarde |
| `scripts/ui.gd` | Écran titre, HUD, sac, construction, dialogues, paramètres |
| `scripts/art.gd` | Chargement des sprites, TileSet de la carte, minicarte |
| `scripts/touch_controls.gd` | Joystick et boutons tactiles (Android, tablettes) |
| `art/tiles.png`, `art/sprites.png` | Les sprites (sol, arbres, personnages, bâtiments, boutons) |
| `tools/make_art.py` | Le script qui dessine ces sprites (relancer `python3 tools/make_art.py` après une retouche) |
| `export_presets.cfg` | Exports Android, Windows, Linux et Web |
| `.github/workflows/builds.yml` | Compile le jeu sur GitHub à chaque envoi |
| `autoload/lang.gd` | Textes français et anglais |
| `autoload/settings.gd` | Paramètres et touches |

Les sauvegardes vont dans le dossier utilisateur de Godot (`user://save_*.json`).

## Paliers Patreon

Le palier se simule dans **Paramètres → Palier Patreon (simulation)**. Lanterne débloque la tenue dorée et la statue, Gardien ouvre la Crypte des Échos, Archimage ajoute le familier Luciole. En version finale, `Settings.tier` doit venir du serveur de liaison Patreon (OAuth), jamais d'un code tapé dans le jeu.

## Android et autres versions

GitHub compile le jeu tout seul à chaque envoi (onglet **Actions** du dépôt) : APK Android, Windows, Linux et Web.
Après chaque mise à jour de `main`, la release **derniere-version** contient les fichiers prêts à télécharger.
Sur un téléphone : ouvrir la release, télécharger `Brumeval-android.apk`, puis autoriser l'installation depuis le navigateur.
Cet APK est signé avec une clé de test ; pour le Play Store il faudra une clé de publication (à garder secrète).

Depuis Godot sur PC : **Projet → Exporter**, choisir un préréglage, puis **Exporter le projet**
(Godot propose de télécharger les modèles d'export la première fois ; pour Android il faut aussi le SDK Android et Java 17).

## Performances

- La carte est rendue par `TileMapLayer` et les personnages par `Sprite2D` : environ 26 appels de dessin par image au lieu de 750.
- Les créatures loin du joueur ne calculent plus leur IA.
- **Paramètres** : « Lumières dynamiques » (désactivées par défaut sur téléphone) et « Économie d'énergie » (30 images par seconde).
- Rendu « Compatibilité » (OpenGL ES 3 / WebGL 2), qui marche sur la plupart des téléphones et vieux PC.

## Prochaines étapes

- Ajouter musique et sons (le prototype web avait des bips, pas encore portés).
- Police pixel et icônes d'objets dans le sac.

## Prototype web

Le premier prototype (HTML/JavaScript) est gardé dans `web-prototype/index.html` pour référence.
