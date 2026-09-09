<p align="center">
  <img src="../assets/readme-banner.png" alt="BannerHither — las notificaciones en la pantalla que estás mirando" width="720">
</p>

# BannerHither

[English](../README.md) | [한국어](README.ko.md) | [日本語](README.ja.md) | [简体中文](README.zh-Hans.md) | [Deutsch](README.de.md) | [Français](README.fr.md) | Español

[![CI](https://github.com/KJeon10/BannerHither/actions/workflows/ci.yml/badge.svg)](https://github.com/KJeon10/BannerHither/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](../LICENSE)

BannerHither es una pequeña app de barra de menús para macOS que decide **en qué pantalla aparecen las tiras de
notificación**. macOS siempre muestra las tiras en la pantalla principal; con varios monitores, a menudo no es la
que estás mirando. BannerHither mueve cada tira, en el momento en que aparece, a la pantalla bajo el puntero
del ratón, a la pantalla de la ventana en la que estás trabajando o a la pantalla que elijas.

<!-- Demo video: paste the GitHub-hosted mp4 URL here on its own line -->

## Instalación

### Descarga

1. Descarga `BannerHither-<versión>.dmg` desde la página de [Releases](https://github.com/KJeon10/BannerHither/releases).
2. Abre la imagen y arrastra `BannerHither.app` al acceso directo Applications.
3. Ábrela desde la carpeta Aplicaciones. Tanto la app como la imagen están firmadas con un Developer ID y notarizadas, así que macOS solo pide la confirmación habitual del primer inicio.

### Homebrew

```sh
brew install --cask KJeon10/tap/bannerhither
```

### Compilar por tu cuenta

Si prefieres compilarla por tu cuenta, consulta [Compilar desde el código fuente](#compilar-desde-el-código-fuente).

### Primer inicio

BannerHither pide el permiso de **Accesibilidad** (Ajustes del Sistema › Privacidad y seguridad › Accesibilidad).
Ese permiso es lo que le permite mover la ventana de NotificationCenter. Una vez concedido, el motor se
inicia automáticamente; mientras está en marcha, el icono de la barra de menús muestra una campana con un
globo.

Usa *Enviar notificación de prueba* en el menú: la notificación llega tres segundos después, tiempo suficiente
para mover el ratón a otra pantalla y ver dónde aparece la tira.

## Funciones

- **Pantalla bajo el puntero del ratón** — las tiras te siguen a la pantalla que estés usando.
- **Pantalla de la ventana activa** — las tiras aparecen junto a la ventana que tiene el foco; si no se
  puede determinar, se usa la pantalla del ratón.
- **Pantalla fija** — las tiras van siempre a un monitor concreto. Si ese monitor está desconectado, el
  comportamiento de macOS se deja intacto hasta que vuelva.
- **Por omisión del sistema** — no hacer nada; la app se queda aparcada en la barra de menús.
- Solo barra de menús, sin icono en el Dock; Iniciar/Detener; Abrir al iniciar sesión; una notificación de
  prueba con 3 segundos de retardo para que te dé tiempo a mover el ratón; *Copiar diagnóstico* para los
  informes de errores.
- Binario universal (chip de Apple e Intel); interfaz en inglés, coreano, japonés, chino simplificado, alemán,
  francés y español.
- Necesita exactamente un permiso: Accesibilidad. Sin acceso a la red ni recopilación de datos.

## Cómo funciona

`NotificationCenter.app` dibuja todas las tiras dentro de una única ventana transparente del tamaño de la
pantalla y coloca esa ventana en la pantalla principal cada vez que presenta una tira. BannerHither observa
NotificationCenter a través de la API pública de Accesibilidad: cuando la ventana de la tira aparece en su
posición por omisión, la app ajusta el `AXPosition` de la ventana para que su esquina superior derecha coincida con la esquina
superior derecha de la pantalla elegida, lo que deja la tira exactamente donde macOS la dibujaría de forma
nativa en esa pantalla. Como se mueve la ventana entera, los clics, los deslizamientos y el botón de cerrar
siguen funcionando.

La app solo actúa en las *transiciones* (acaba de aparecer una tira, o NotificationCenter acaba de
recolocarla), así que una tira nunca persigue al ratón una vez que está en pantalla, y el panel del Centro de
notificaciones, que NotificationCenter coloca en la pantalla cuyo reloj hayas pulsado, nunca se toca.

Esto depende de un comportamiento no documentado de NotificationCenter que Apple puede cambiar en cualquier
actualización de macOS. Si la ventana ya no se puede encontrar o mover, BannerHither registra el fallo y macOS
se comporta como siempre; nada más se ve afectado. *Copiar diagnóstico* vuelca los atributos actuales de la
ventana de NotificationCenter para que esos cambios puedan diagnosticarse a partir de un informe de error.

### Versiones de macOS probadas

| macOS | Estado |
| --- | --- |
| 26.6 (Tahoe) | Verificado: ventana de la tira encontrada, movida y restablecida tras reinicios de NotificationCenter |
| 14.0 – 15.x | Compila y debería funcionar (la estructura de la ventana es estable desde Big Sur), pero aún no se ha verificado |

### Limitaciones conocidas

- Si la pantalla de destino es más estrecha que la pantalla para la que se dimensionó la ventana de la tira, la
  ventana sobresale por el borde izquierdo. La tira en sí sigue siendo totalmente visible; la opción
  `resizeToTargetScreen` de más abajo redimensiona primero la ventana si eso llegara a importar.
- Las pantallas que duplican otra pantalla no son destinos independientes.
- No se ha probado con la opción *Pantallas con Spaces separados* desactivada, con el Organizador visual ni en la
  pantalla de bloqueo.

## Ajustes avanzados

Todo lo que hay en el menú se guarda en `UserDefaults` bajo `io.github.kjeon10.BannerHither`. Dos opciones no
tienen elemento de menú:

| Clave | Por omisión | Significado |
| --- | --- | --- |
| `pollIntervalMilliseconds` | `1000` | Intervalo de sondeo de seguridad. Los eventos de Accesibilidad dirigen la app; el sondeo solo cubre los eventos perdidos y los reinicios de NotificationCenter. `0` desactiva el sondeo (se aceptan 50–5000). |
| `resizeToTargetScreen` | `false` | Redimensionar la ventana de la tira a la pantalla de destino antes de moverla. |

```sh
defaults write io.github.kjeon10.BannerHither pollIntervalMilliseconds -int 500
defaults write io.github.kjeon10.BannerHither resizeToTargetScreen -bool true
```

Los cambios se aplican a partir de la siguiente tira. Para seguir lo que hace la app:

```sh
log stream --predicate 'subsystem == "io.github.kjeon10.BannerHither"' --level debug
```

## Compilar desde el código fuente

Requisitos: macOS 14 o posterior y Xcode 16 o posterior (o las Command Line Tools correspondientes).

```sh
git clone https://github.com/KJeon10/BannerHither.git
cd BannerHither
make build          # → build/BannerHither.app
open build/BannerHither.app
```

Concede el permiso de Accesibilidad cuando la app lo pida y listo.

## Privacidad

BannerHither no lee el contenido de las notificaciones ni se comunica con el exterior. Si lo prefieres, también
puedes [compilarla desde el código fuente](#compilar-desde-el-código-fuente).

## Créditos

[PingPlace](https://github.com/NotWadeGrimridge/PingPlace), [ShoveIt](https://github.com/JaysonRawlins/ShoveIt) y [NotificationNanny](https://github.com/chessper53/NotificationNanny) sirvieron de referencia.

## Licencia

[MIT](../LICENSE) © 2026 [KJeon10](https://github.com/KJeon10)
