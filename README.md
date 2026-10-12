# Kaiwa du Jour — version locale

Application d'apprentissage du japonais (manuel Genki I) qui tourne **entièrement sur votre ordinateur** :
séances de rappel, parcours d'unités, leçon du jour, cartes, missions de conversation, bilans.
La progression et les leçons importées sont enregistrées dans un dossier, l'IA passe par [Ollama](https://ollama.com).

## Ce qu'il faut

| | |
|---|---|
| Système | Windows 10 ou 11 (PowerShell 5.1, déjà installé) |
| Navigateur | Chrome, Edge ou Firefox récent |
| IA (optionnelle) | [Ollama](https://ollama.com/download) installé et lancé |

Aucune autre installation : pas de Node, pas de Python.

## Installation

1. Récupérez le dossier du projet (clone git ou copie) à l'endroit de votre choix.
2. Double-cliquez sur **`Lancer Kaiwa.bat`**.
3. Le navigateur s'ouvre sur <http://localhost:8765/>.

Laissez la petite fenêtre noire ouverte pendant que vous étudiez. La fermer arrête l'application.
Relancer le `.bat` alors que l'app tourne déjà ouvre simplement le navigateur.

> Si Windows affiche un avertissement au premier lancement, choisissez « Exécuter quand même » :
> le script ne fait qu'ouvrir un petit serveur local (`localhost` uniquement, jamais accessible depuis le réseau).

## Importer des leçons

L'app fonctionne avec des fichiers de contenu `.json` :

- **`kaiwa_socle.json`** : la structure du parcours, à importer une seule fois.
- **`kaiwa_L1.json`, `kaiwa_L2.json`…** : une leçon par fichier (fiches, exercices, banque de questions, lexique).

Au premier lancement, l'app propose l'import (« Plus tard » permet de continuer sans).
Ensuite : **Réglages (engrenage) → Contenu et sauvegarde → Ajouter des leçons**. Vous pouvez choisir plusieurs fichiers d'un coup ;
l'import n'écrase jamais votre progression.

Pour voir ce qui est importé : **Parcours → Unités**. Chaque unité est marquée *importée* ou *pas importée*, avec un filtre
« Toutes / Importées / À importer ».

Pour créer des fichiers à partager : **Parcours → Outils** (export du socle ou d'une leçon).

## Sauvegarde de la progression

Tout est écrit au fur et à mesure dans le dossier **`data/`** (un petit fichier par document) : progression, leçons importées,
cartes, missions, réglages (thème, voix, modèle d'IA…).

- Une copie zippée de `data/` est faite chaque jour dans **`backups/`** (les 14 dernières sont gardées).
- Avant tout effacement de la progression (Réglages → *Remettre ma progression à zéro*), l'app demande confirmation et crée
  une copie `backups/avant-effacement-AAAA-MM-JJ_HH-mm-ss.zip`.
- Changer d'ordinateur : copiez le dossier du projet avec `data/`.
- Restaurer : arrêtez l'app, remplacez `data/` par le contenu d'une sauvegarde `backups/kaiwa-AAAA-MM-JJ.zip`, relancez.
- Sauvegarde portable : **Réglages → Sauvegarder ma progression** télécharge un fichier `.json` (la progression seule, sans le contenu).

Si vous ouvrez `index.html` directement sans le `.bat`, l'app marche mais les données restent dans le navigateur :
utilisez toujours le lanceur.

## Activer l'IA (Ollama)

L'IA sert à l'aide, aux conversations de mission, aux corrections libres, aux bilans et à la leçon du jour.

1. Installez Ollama, puis téléchargez un modèle. Pour le japonais, un modèle de 7 à 8 milliards de paramètres est un bon minimum :
   ```bash
   ollama pull qwen2.5:7b
   ```
2. Dans l'app : **Réglages → IA locale (Ollama)** → *Détecter les modèles installés* → choisissez le modèle → *Tester*.

Sans modèle choisi, tout fonctionne sauf les fonctions d'IA. Le premier appel peut prendre quelques secondes (chargement du modèle).
Adresse par défaut : `http://localhost:11434` (modifiable dans les réglages).

## Organisation du dossier

```
Lancer Kaiwa.bat   lanceur (double-clic)
server.ps1         mini serveur local : sert l'app et écrit dans data\
index.html         l'application complète (un seul fichier)
data\              VOS DONNÉES (non versionnées)
backups\           copies quotidiennes de data\ (non versionnées)
variantes\         version publique « Genki » et sorties d'export
```

## Dépannage

- **Page blanche / « connexion refusée »** : la fenêtre noire est fermée, relancez `Lancer Kaiwa.bat`.
- **Port 8765 déjà utilisé par un autre programme** : lancez `powershell -ExecutionPolicy Bypass -File server.ps1 -Port 8800`.
- **« Ollama ne répond pas »** : vérifiez qu'Ollama est lancé (icône dans la barre des tâches) et l'adresse dans les réglages.
- **Réglages → texte rouge « enregistrement non garanti »** : l'app n'a pas été ouverte via le lanceur.
