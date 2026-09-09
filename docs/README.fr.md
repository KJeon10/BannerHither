<p align="center">
  <img src="../assets/readme-banner.png" alt="BannerHither — les notifications sur l’écran que vous regardez" width="720">
</p>

# BannerHither

[English](../README.md) | [한국어](README.ko.md) | [日本語](README.ja.md) | [简体中文](README.zh-Hans.md) | [Deutsch](README.de.md) | Français | [Español](README.es.md)

[![CI](https://github.com/KJeon10/BannerHither/actions/workflows/ci.yml/badge.svg)](https://github.com/KJeon10/BannerHither/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](../LICENSE)

BannerHither est une petite app de barre des menus pour macOS qui décide **sur quel écran apparaissent les
bannières de notification**. macOS affiche toujours les bannières sur l’écran principal ; avec plusieurs
moniteurs, ce n’est souvent pas celui que vous regardez. BannerHither déplace chaque bannière, dès qu’elle
apparaît, vers l’écran situé sous le pointeur de la souris, vers l’écran de la fenêtre dans laquelle vous
travaillez, ou vers un écran de votre choix.

https://github.com/user-attachments/assets/6a6004a7-ac3a-4d62-ad7c-ff5f3f2d2485

## Installation

### Téléchargement

1. Récupérez `BannerHither-<version>.dmg` sur la page [Releases](https://github.com/KJeon10/BannerHither/releases).
2. Ouvrez l’image et faites glisser `BannerHither.app` sur le raccourci Applications.
3. Lancez l’app depuis le dossier Applications. L’app et l’image sont signées avec un Developer ID et notarisées : macOS ne demande que la confirmation habituelle au premier lancement.

### Homebrew

```sh
brew install --cask KJeon10/tap/bannerhither
```

### Compiler soi-même

Pour compiler l’app vous-même, voir [Compilation depuis les sources](#compilation-depuis-les-sources).

### Premier lancement

BannerHither demande l’autorisation **Accessibilité** (Réglages Système › Confidentialité et sécurité ›
Accessibilité). C’est cette autorisation qui lui permet de déplacer la fenêtre de NotificationCenter. Une
fois accordée, le moteur démarre automatiquement ; l’icône de la barre des menus affiche une cloche avec un
badge tant qu’il tourne.

Utilisez *Envoyer une notification de test* dans le menu : une notification arrive trois secondes plus tard,
ce qui laisse le temps de déplacer la souris vers un autre écran et de voir où la bannière atterrit.

## Fonctionnalités

- **Écran sous le pointeur de la souris** — les bannières vous suivent, quel que soit l’écran que vous utilisez.
- **Écran de la fenêtre active** — les bannières apparaissent à côté de la fenêtre au premier plan,
  l’écran de la souris servant de solution de repli.
- **Écran fixe** — les bannières vont toujours sur un moniteur précis. S’il est débranché, le comportement de
  macOS reste inchangé jusqu’à son retour.
- **Par défaut du système** — ne rien faire, l’app reste simplement dans la barre des menus.
- Barre des menus uniquement, sans icône dans le Dock ; un bouton Démarrer/Arrêter ; Ouvrir avec la session ;
  une notification de test avec 3 secondes de délai pour vous laisser déplacer la souris ; un élément
  *Copier les diagnostics* pour les rapports de bug.
- Binaire universel (puce Apple et Intel) ; interface en anglais, coréen, japonais, chinois simplifié,
  allemand, français et espagnol.
- Une seule autorisation nécessaire : Accessibilité. Aucun accès réseau, aucune collecte de données.

## Fonctionnement

`NotificationCenter.app` dessine toutes les bannières dans une seule fenêtre transparente de la taille de
l’écran et place cette fenêtre sur l’écran principal chaque fois qu’une bannière est présentée. BannerHither
observe NotificationCenter via l’API Accessibility publique : lorsque la fenêtre de bannière apparaît à sa
position par défaut, l’app règle son `AXPosition` de sorte que son coin supérieur droit coïncide avec le coin
supérieur droit de l’écran choisi, ce qui place la bannière exactement là où macOS la dessinerait nativement
sur cet écran. Comme c’est toute la fenêtre qui se déplace, les clics, les balayages et le bouton de fermeture
continuent de fonctionner.

L’app n’agit qu’aux *transitions* (une bannière vient d’apparaître, ou NotificationCenter vient de la
repositionner) : une bannière ne court donc jamais après la souris une fois affichée, et le panneau du Centre
de notifications, que NotificationCenter place sur l’écran où vous avez cliqué sur l’horloge, n’est jamais
touché.

Tout cela repose sur un comportement non documenté de NotificationCenter, qu’Apple peut modifier à n’importe
quelle mise à jour de macOS. Si la fenêtre ne peut plus être trouvée ou déplacée, BannerHither consigne
l’échec dans le journal et macOS se comporte comme d’habitude ; rien d’autre n’est affecté. *Copier les
diagnostics* copie dans le presse-papiers les attributs actuels de la fenêtre de NotificationCenter afin que ces changements
puissent être diagnostiqués à partir d’un rapport de bug.

### Versions de macOS testées

| macOS | État |
| --- | --- |
| 26.6 (Tahoe) | Vérifié : fenêtre de bannière trouvée, déplacée et rétablie après les redémarrages de NotificationCenter |
| 14.0 – 15.x | Compile et devrait fonctionner (la structure de la fenêtre est stable depuis Big Sur), mais pas encore vérifié |

### Limitations connues

- Si l’écran cible est plus étroit que l’écran pour lequel la fenêtre de bannière a été dimensionnée, la
  fenêtre dépasse du bord gauche de l’écran. La bannière elle-même reste entièrement visible ; l’option
  `resizeToTargetScreen` ci-dessous redimensionne d’abord la fenêtre si cela pose problème.
- Les écrans qui recopient un autre écran ne sont pas des cibles distinctes.
- Non testé avec *Les écrans disposent de Spaces distincts* désactivé, avec Stage Manager, ni sur l’écran
  verrouillé.

## FAQ

**Pourquoi mes notifications apparaissent-elles sur le mauvais écran ?**
macOS n’affiche les bannières de notification que sur l’écran principal, celui qui porte la barre des
menus dans Réglages Système › Moniteurs, quel que soit l’écran où se trouvent le pointeur ou la fenêtre
active. Dès que vous travaillez sur un autre écran, chaque notification arrive au mauvais endroit.
BannerHither déplace chaque bannière vers l’écran que vous regardez réellement.

**Puis-je recevoir les notifications sur mon deuxième écran ou sur un écran externe ?**
Oui. Choisissez *Écran sous le pointeur de la souris* ou *Écran de la fenêtre active*, ou désignez
l’écran externe comme *Écran fixe*. Les bannières apparaissent alors sur le deuxième écran sans rien
changer d’autre à votre configuration.

**Pourquoi ne pas simplement déplacer la barre des menus sur l’autre écran dans Réglages Système › Moniteurs ?**
Cela fait de l’autre écran l’écran principal, ce qui déplace aussi le Dock, la position par défaut des
nouvelles fenêtres et l’espace principal ; et c’est un choix fixe qui ne vous suit pas quand vous
changez d’écran. BannerHither ne touche pas à la disposition des écrans et ne déplace que la bannière.

**La notification elle-même est-elle modifiée ?**
Non. C’est toute la fenêtre de NotificationCenter qui est déplacée : clic, balayage et actions de
notification continuent de fonctionner, et le contenu des notifications n’est jamais lu. Le panneau du
centre de notifications ouvert depuis l’horloge n’est pas touché.

**Quelles versions de macOS sont prises en charge ?**
macOS 14 Sonoma ou plus récent, vérifié sous macOS 26 Tahoe (voir le tableau des versions testées ci-dessus).

## Réglages avancés

Tout ce qui figure dans le menu est stocké dans les `UserDefaults` sous `io.github.kjeon10.BannerHither`.
Deux options n’ont pas d’élément de menu :

| Clé | Par défaut | Signification |
| --- | --- | --- |
| `pollIntervalMilliseconds` | `1000` | Intervalle d’interrogation de secours. Les événements Accessibility pilotent l’app ; l’interrogation ne couvre que les événements manqués et les redémarrages de NotificationCenter. `0` la désactive (valeurs acceptées : 50–5000). |
| `resizeToTargetScreen` | `false` | Redimensionner la fenêtre de bannière à la taille de l’écran cible avant de la déplacer. |

```sh
defaults write io.github.kjeon10.BannerHither pollIntervalMilliseconds -int 500
defaults write io.github.kjeon10.BannerHither resizeToTargetScreen -bool true
```

Les changements prennent effet à la bannière suivante. Pour suivre ce que fait l’app :

```sh
log stream --predicate 'subsystem == "io.github.kjeon10.BannerHither"' --level debug
```

## Compilation depuis les sources

Prérequis : macOS 14 ou ultérieur et Xcode 16 ou ultérieur (ou les Command Line Tools correspondants).

```sh
git clone https://github.com/KJeon10/BannerHither.git
cd BannerHither
make build          # → build/BannerHither.app
open build/BannerHither.app
```

Accordez l’autorisation Accessibilité lorsque l’app la demande, et c’est tout.

## Confidentialité

BannerHither ne lit jamais le contenu des notifications et ne communique pas avec l’extérieur. Si vous préférez,
vous pouvez aussi [compiler l’app vous-même depuis les sources](#compilation-depuis-les-sources).

## Remerciements

[PingPlace](https://github.com/NotWadeGrimridge/PingPlace), [ShoveIt](https://github.com/JaysonRawlins/ShoveIt) et [NotificationNanny](https://github.com/chessper53/NotificationNanny) ont servi de références.

## Licence

[MIT](../LICENSE) © 2026 [KJeon10](https://github.com/KJeon10)
