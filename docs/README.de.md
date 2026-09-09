<p align="center">
  <img src="../assets/readme-banner.png" alt="BannerHither – Mitteilungen auf dem Bildschirm, den du gerade ansiehst" width="720">
</p>

# BannerHither

[English](../README.md) | [한국어](README.ko.md) | [日本語](README.ja.md) | [简体中文](README.zh-Hans.md) | Deutsch | [Français](README.fr.md) | [Español](README.es.md)

[![CI](https://github.com/KJeon10/BannerHither/actions/workflows/ci.yml/badge.svg)](https://github.com/KJeon10/BannerHither/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](../LICENSE)

BannerHither ist eine kleine Menüleisten-App für macOS, die entscheidet, **auf welchem Bildschirm
Mitteilungsbanner erscheinen**. macOS zeigt Banner immer auf dem Hauptbildschirm; mit mehreren Monitoren ist
das oft nicht der, auf den du gerade schaust. BannerHither verschiebt jedes Banner in dem Moment, in dem es
erscheint, auf den Bildschirm unter dem Mauszeiger, auf den Bildschirm des Fensters, in dem du gerade
arbeitest, oder auf einen Bildschirm deiner Wahl.

<!-- Demo video: paste the GitHub-hosted mp4 URL here on its own line -->

## Installation

### Download

1. Lade `BannerHither-<Version>.dmg` von der [Releases](https://github.com/KJeon10/BannerHither/releases)-Seite herunter.
2. Öffne das Image und ziehe `BannerHither.app` auf die Verknüpfung „Applications“.
3. Starte die App aus dem Ordner „Programme“. App und Image sind mit einer Developer ID signiert und beglaubigt, macOS fragt also nur die übliche Bestätigung beim ersten Start ab.

### Homebrew

```sh
brew install --cask KJeon10/tap/bannerhither
```

### Selbst bauen

Wer die App lieber selbst baut, findet die Anleitung unter [Aus dem Quellcode bauen](#aus-dem-quellcode-bauen).

### Erster Start

BannerHither bittet um die Berechtigung **Bedienungshilfen** (Systemeinstellungen › Datenschutz & Sicherheit ›
Bedienungshilfen). Diese Berechtigung erlaubt es, das Fenster von NotificationCenter zu verschieben. Sobald
sie erteilt ist, startet die Engine automatisch; das Symbol in der Menüleiste zeigt eine Glocke mit Kennzeichen,
solange sie läuft.

Verwende *Testmitteilung senden* im Menü: Drei Sekunden später trifft eine Mitteilung ein – genug Zeit, um die
Maus auf einen anderen Bildschirm zu bewegen und zu sehen, wo das Banner landet.

## Funktionen

- **Bildschirm unter dem Mauszeiger** – Banner folgen dir auf den Bildschirm, den du gerade benutzt.
- **Bildschirm des aktiven Fensters** – Banner erscheinen neben dem Fenster mit dem Fokus; andernfalls
  wird der Bildschirm unter dem Mauszeiger verwendet.
- **Bestimmter Bildschirm** – Banner landen immer auf einem festgelegten Monitor. Ist dieser nicht
  angeschlossen, bleibt das macOS-Verhalten unverändert, bis er zurückkehrt.
- **Systemstandard** – nichts tun, die App bleibt nur in der Menüleiste geparkt.
- Nur Menüleiste, kein Dock-Symbol; Starten/Stoppen; Bei der Anmeldung öffnen; eine Testmitteilung mit
  3 Sekunden Verzögerung, damit du die Maus bewegen kannst; *Diagnosedaten kopieren* für Fehlerberichte.
- Universal Binary (Apple Silicon und Intel); Oberfläche auf Englisch, Koreanisch, Japanisch, vereinfachtem
  Chinesisch, Deutsch, Französisch und Spanisch.
- Benötigt genau eine Berechtigung: Bedienungshilfen. Kein Netzwerkzugriff, keine Datenerfassung.

## Funktionsweise

`NotificationCenter.app` zeichnet jedes Banner in ein einziges transparentes Fenster in Bildschirmgröße und
platziert dieses Fenster auf dem Hauptbildschirm, sobald ein Banner angezeigt wird. BannerHither beobachtet
NotificationCenter über die öffentliche Accessibility-API: Erscheint das Bannerfenster an seiner
Standardposition, setzt die App dessen `AXPosition` so, dass die rechte obere Ecke mit der rechten oberen Ecke
des gewählten Bildschirms zusammenfällt – genau dort, wo macOS das Banner auf diesem Bildschirm nativ zeichnen
würde. Weil das ganze Fenster verschoben wird, funktionieren Klicks, Streichgesten und die Schließen-Taste
weiterhin.

Die App greift nur bei *Übergängen* ein (ein Banner ist gerade erschienen oder NotificationCenter hat es gerade
neu positioniert). Ein Banner jagt also nie der Maus hinterher, sobald es auf dem Bildschirm ist, und das
Panel der Mitteilungszentrale, das NotificationCenter auf dem Bildschirm öffnet, dessen Uhr du angeklickt hast,
wird nie angefasst.

Das beruht auf undokumentiertem Verhalten von NotificationCenter, das Apple mit jedem macOS-Update ändern kann.
Lässt sich das Fenster nicht mehr finden oder verschieben, protokolliert BannerHither den Fehler, und macOS
verhält sich wie gewohnt; sonst ist nichts betroffen. *Diagnosedaten kopieren* gibt die aktuellen Attribute des
NotificationCenter-Fensters aus, sodass solche Änderungen anhand eines Fehlerberichts diagnostiziert werden
können.

### Getestete macOS-Versionen

| macOS | Status |
| --- | --- |
| 26.6 (Tahoe) | Verifiziert: Bannerfenster gefunden, verschoben und nach Neustarts von NotificationCenter wiederhergestellt |
| 14.0 – 15.x | Lässt sich bauen und sollte funktionieren (die Fensterstruktur ist seit Big Sur stabil), aber noch nicht verifiziert |

### Bekannte Einschränkungen

- Ist der Zielbildschirm schmaler als der Bildschirm, für den das Bannerfenster dimensioniert wurde, ragt das
  Fenster über den linken Rand des Bildschirms hinaus. Das Banner selbst bleibt vollständig sichtbar; die Option
  `resizeToTargetScreen` unten passt das Fenster vorher an, falls das je stört.
- Bildschirme, die einen anderen Bildschirm spiegeln, sind keine eigenen Ziele.
- Nicht getestet bei deaktivierter Option *Monitore verwenden verschiedene Spaces*, mit Stage Manager oder auf dem
  Sperrbildschirm.

## Erweiterte Einstellungen

Alles im Menü wird in den `UserDefaults` unter `io.github.kjeon10.BannerHither` gespeichert. Zwei Optionen
haben keinen Menüeintrag:

| Schlüssel | Standard | Bedeutung |
| --- | --- | --- |
| `pollIntervalMilliseconds` | `1000` | Abfrageintervall als Sicherheitsnetz. Accessibility-Ereignisse steuern die App; die Abfrage fängt nur verpasste Ereignisse und Neustarts von NotificationCenter ab. `0` deaktiviert die Abfrage (50–5000 zulässig). |
| `resizeToTargetScreen` | `false` | Das Bannerfenster vor dem Verschieben auf die Größe des Zielbildschirms anpassen. |

```sh
defaults write io.github.kjeon10.BannerHither pollIntervalMilliseconds -int 500
defaults write io.github.kjeon10.BannerHither resizeToTargetScreen -bool true
```

Änderungen gelten ab dem nächsten Banner. Um mitzuverfolgen, was die App tut:

```sh
log stream --predicate 'subsystem == "io.github.kjeon10.BannerHither"' --level debug
```

## Aus dem Quellcode bauen

Voraussetzungen: macOS 14 oder neuer und Xcode 16 oder neuer (oder die passenden Command Line Tools).

```sh
git clone https://github.com/KJeon10/BannerHither.git
cd BannerHither
make build          # → build/BannerHither.app
open build/BannerHither.app
```

Erteile der App die Berechtigung für Bedienungshilfen, wenn sie danach fragt – das war’s.

## Datenschutz

BannerHither liest keine Mitteilungsinhalte und kommuniziert nicht mit der Außenwelt. Wer möchte, kann die App
auch [selbst aus dem Quellcode bauen](#aus-dem-quellcode-bauen).

## Danksagung

[PingPlace](https://github.com/NotWadeGrimridge/PingPlace), [ShoveIt](https://github.com/JaysonRawlins/ShoveIt) und [NotificationNanny](https://github.com/chessper53/NotificationNanny) dienten als Referenz.

## Lizenz

[MIT](../LICENSE) © 2026 [KJeon10](https://github.com/KJeon10)
