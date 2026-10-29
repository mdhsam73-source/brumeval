# Brumeval (Godot 4)

RPG pixel vu de dessus : masques, transfert d'âme, village à bâtir, options sociales. Version Godot du prototype web.

## Lancer le jeu

1. Installer [Godot 4.3](https://godotengine.org/download) (version standard, pas .NET).
2. Ouvrir Godot, cliquer sur **Importer**, choisir le fichier `project.godot` de ce dossier.
3. Appuyer sur **F5** pour jouer.

Commandes : ZQSD ou WASD pour bouger (clavier AZERTY et QWERTY), Espace pour attaquer, E pour interagir, R pour le transfert d'âme, B pour construire, I pour le sac, M pour la carte, H pour une potion, Échap pour la pause. La manette marche aussi (A attaque, X interagir, Y âme).

## Organisation

| Fichier | Rôle |
| --- | --- |
| `scenes/main.tscn` | Scène principale : le monde, la caméra, la lumière de nuit et l'interface |
| `scripts/defs.gd` | Équilibrage : créatures, bâtiments, recettes, zones, quêtes |
| `scripts/world.gd` | Carte, joueur, IA, combat, bâtiments, temps, sauvegarde |
| `scripts/ui.gd` | Écran titre, HUD, sac, construction, dialogues, paramètres |
| `scripts/art.gd` | Pixel art généré par le code (à remplacer par de vrais sprites) |
| `autoload/lang.gd` | Textes français et anglais |
| `autoload/settings.gd` | Paramètres et touches |

Les sauvegardes vont dans le dossier utilisateur de Godot (`user://save_*.json`).

## Paliers Patreon

Le palier se simule dans **Paramètres → Palier Patreon (simulation)**. Lanterne débloque la tenue dorée et la statue, Gardien ouvre la Crypte des Échos, Archimage ajoute le familier Luciole. En version finale, `Settings.tier` doit venir du serveur de liaison Patreon (OAuth), jamais d'un code tapé dans le jeu.

## Prochaines étapes

- Remplacer `art.gd` par des sprites dessinés (Aseprite) et la carte par un `TileMapLayer`.
- Ajouter musique et sons (le prototype web avait des bips, pas encore portés).
- Exporter : Projet → Exporter, puis Windows, Linux, macOS ou Web (télécharger les modèles d'export la première fois).

## Prototype web

Le premier prototype (HTML/JavaScript) est gardé dans `web-prototype/index.html` pour référence.
