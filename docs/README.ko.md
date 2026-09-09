<p align="center">
  <img src="../assets/readme-banner.png" alt="BannerHither — 지금 보고 있는 화면에 알림을" width="720">
</p>

# BannerHither

[English](../README.md) | 한국어 | [日本語](README.ja.md) | [简体中文](README.zh-Hans.md) | [Deutsch](README.de.md) | [Français](README.fr.md) | [Español](README.es.md)

[![CI](https://github.com/KJeon10/BannerHither/actions/workflows/ci.yml/badge.svg)](https://github.com/KJeon10/BannerHither/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](../LICENSE)

BannerHither는 macOS 알림 배너가 **어느 디스플레이에 뜰지** 정하는 작은 메뉴 막대 앱입니다.
macOS는 배너를 항상 주 디스플레이에 띄우는데, 모니터가 여러 대면 그 화면이 지금 보고 있는
화면이 아닐 때가 많습니다. BannerHither는 배너가 나타나는 순간 마우스 포인터가 있는 화면,
작업 중인 창이 있는 화면, 또는 직접 고른 디스플레이로 배너를 옮깁니다.

https://github.com/user-attachments/assets/b1078871-2b50-4f3b-bef2-7592d8338b50

## 설치

### 다운로드

1. [Releases](https://github.com/KJeon10/BannerHither/releases)에서 `BannerHither-<버전>.dmg`를 받습니다.
2. 이미지를 열고 `BannerHither.app`을 Applications 바로가기로 끌어다 놓습니다.
3. 응용 프로그램에서 실행합니다. 앱과 이미지 모두 Developer ID로 서명하고 공증했으므로 macOS는 첫 실행 시 일반적인 확인만 묻습니다.

### Homebrew

```sh
brew install --cask KJeon10/tap/bannerhither
```

### 직접 빌드

직접 빌드하려면 [소스에서 빌드](#소스에서-빌드)를 참고하세요.

### 첫 실행

BannerHither는 **손쉬운 사용** 권한(시스템 설정 › 개인정보 보호 및 보안 › 손쉬운 사용)을 요청합니다.
이 권한으로 NotificationCenter의 창을 옮깁니다. 허용하면 엔진이 자동으로 시작되고, 실행 중에는
메뉴 막대 아이콘이 배지가 달린 종 모양으로 바뀝니다.

메뉴의 *테스트 알림 보내기*를 누르면 3초 뒤 알림이 도착합니다. 그 사이에 마우스를 다른 화면으로
옮겨 배너가 어디에 뜨는지 확인해 보세요.

## 기능

- **마우스 포인터가 있는 화면** — 지금 쓰고 있는 디스플레이로 배너가 따라옵니다.
- **활성 창이 있는 화면** — 포커스된 창 옆에 배너가 뜹니다. 창이 없으면 마우스 화면으로 폴백합니다.
- **특정 디스플레이** — 항상 지정한 모니터에 띄웁니다. 그 모니터가 분리되어 있으면 다시 연결될 때까지
  macOS 기본 동작을 그대로 둡니다.
- **기본 동작** — 아무것도 하지 않고 메뉴 막대에만 상주합니다.
- Dock 아이콘 없는 메뉴 막대 앱, 시작/중지 토글, 로그인 시 실행, 마우스를 옮길 시간을 주는 3초 지연
  테스트 알림, 버그 리포트용 *진단 정보 복사*.
- 유니버설 바이너리(Apple Silicon·Intel), 한국어·영어·일본어·중국어(간체)·독일어·프랑스어·스페인어 UI.
- 필요한 권한은 손쉬운 사용 하나뿐. 네트워크 접근과 데이터 수집이 없습니다.

## 동작 원리

`NotificationCenter.app`은 모든 배너를 디스플레이 크기의 투명한 창 하나에 그리며, 배너를 표시할
때마다 그 창을 주 디스플레이에 배치합니다. BannerHither는 공개 Accessibility API로
NotificationCenter를 관찰하다가, 배너 창이 기본 위치에 나타나면 창의 `AXPosition`을 바꿔 창의
우상단 모서리를 목표 디스플레이의 우상단 모서리에 맞춥니다. 그러면 macOS가 그 디스플레이에
직접 그렸을 때와 같은 자리에 배너가 옵니다. 창 전체가 움직이므로 클릭, 스와이프, 닫기 버튼이
그대로 동작합니다.

앱은 *전이 시점*(배너가 막 나타났거나 NotificationCenter가 막 재배치했을 때)에만 개입하므로,
이미 떠 있는 배너가 마우스를 따라다니지 않습니다. 시계를 클릭한 디스플레이에 NotificationCenter가
직접 배치하는 알림 센터 패널은 건드리지 않습니다.

이 방식은 NotificationCenter의 비공개 동작에 의존하며 macOS 업데이트로 바뀔 수 있습니다. 창을
찾거나 옮길 수 없게 되면 BannerHither는 실패를 로그에 남기고 macOS는 평소처럼 동작합니다. 그 외에는
아무 영향이 없습니다. *진단 정보 복사*는 현재 NotificationCenter 창의 속성을 덤프하므로 버그
리포트로 변화를 파악할 수 있습니다.

### 검증된 macOS 버전

| macOS | 상태 |
| --- | --- |
| 26.6 (Tahoe) | 검증됨: 배너 창 탐색·이동, NotificationCenter 재시작 후 복구 확인 |
| 14.0 – 15.x | 빌드되며 동작할 것으로 예상(Big Sur 이후 단일 창 구조가 같음)되나 아직 검증하지 않음 |

### 알려진 제한

- 목표 디스플레이가 배너 창의 원래 크기보다 좁으면 창이 디스플레이 왼쪽 가장자리 밖으로 삐져나갑니다.
  배너 자체는 온전히 보이며, 문제가 되면 아래 `resizeToTargetScreen` 옵션으로 창을 먼저 줄일 수 있습니다.
- 다른 디스플레이를 미러링하는 디스플레이는 별도 목표가 아닙니다.
- *각각의 Spaces가 있는 디스플레이*를 끈 상태, Stage Manager, 잠금 화면에서는 테스트하지 않았습니다.

## 자주 묻는 질문

**알림이 왜 엉뚱한 모니터에 뜨나요?**
macOS는 알림 배너를 항상 주 디스플레이(시스템 설정 › 디스플레이에서 메뉴 막대가 있는 화면)에만
띄웁니다. 마우스 포인터나 활성 창이 어디 있든 상관없습니다. 다른 화면에서 작업 중이면 알림이 매번
엉뚱한 화면에 뜨는 이유입니다. BannerHither는 배너를 지금 실제로 보고 있는 화면으로 옮깁니다.

**두 번째 모니터나 외장 디스플레이에 알림을 받을 수 있나요?**
네. *마우스 포인터가 있는 화면*이나 *활성 창이 있는 화면*을 고르거나, *특정 디스플레이*로 외장
디스플레이를 지정하세요. 다른 설정은 아무것도 바꾸지 않고 두 번째 모니터에 배너가 뜹니다.

**시스템 설정 › 디스플레이에서 메뉴 막대를 다른 화면으로 끌어다 놓으면 되지 않나요?**
그러면 그 화면이 주 디스플레이가 되어 Dock, 새 창의 기본 위치, 주 Space까지 함께 옮겨지고, 한 번
정하면 화면을 옮겨 다녀도 따라오지 않습니다. BannerHither는 디스플레이 배치는 그대로 두고 배너만
옮깁니다.

**알림 자체가 바뀌나요?**
아니요. NotificationCenter 창 전체를 옮기므로 클릭, 스와이프, 알림 동작이 그대로 작동하고 알림
내용은 읽지 않습니다. 시계를 클릭해 여는 알림 센터 패널도 건드리지 않습니다.

**지원하는 macOS 버전은?**
macOS 14 Sonoma 이상이며, macOS 26 Tahoe에서 검증했습니다(위의 검증된 버전 표 참고).

## 고급 설정

메뉴의 모든 항목은 `io.github.kjeon10.BannerHither` 아래 `UserDefaults`에 저장됩니다. 메뉴에 없는
옵션이 둘 있습니다.

| 키 | 기본값 | 의미 |
| --- | --- | --- |
| `pollIntervalMilliseconds` | `1000` | 안전망 폴링 간격. 앱은 Accessibility 이벤트로 동작하며, 폴링은 놓친 이벤트와 NotificationCenter 재시작을 보완합니다. `0`이면 폴링을 끕니다(50–5000 허용). |
| `resizeToTargetScreen` | `false` | 옮기기 전에 배너 창을 목표 디스플레이 크기로 조정합니다. |

```sh
defaults write io.github.kjeon10.BannerHither pollIntervalMilliseconds -int 500
defaults write io.github.kjeon10.BannerHither resizeToTargetScreen -bool true
```

변경은 다음 배너부터 적용됩니다. 앱 동작을 따라가려면:

```sh
log stream --predicate 'subsystem == "io.github.kjeon10.BannerHither"' --level debug
```

## 소스에서 빌드

요구 사항: macOS 14 이상, Xcode 16 이상(또는 같은 버전의 Command Line Tools).

```sh
git clone https://github.com/KJeon10/BannerHither.git
cd BannerHither
make build          # → build/BannerHither.app
open build/BannerHither.app
```

앱이 요청하는 손쉬운 사용 권한을 허용하면 끝입니다.

## 개인정보

BannerHither는 알림 내용을 읽지 않으며 외부와 통신하지 않습니다. 원한다면 [소스에서 직접 빌드](#소스에서-빌드)할
수도 있습니다.

## 크레딧

[PingPlace](https://github.com/NotWadeGrimridge/PingPlace), [ShoveIt](https://github.com/JaysonRawlins/ShoveIt), [NotificationNanny](https://github.com/chessper53/NotificationNanny)를 참고했습니다.

## 라이선스

[MIT](../LICENSE) © 2026 [KJeon10](https://github.com/KJeon10)
