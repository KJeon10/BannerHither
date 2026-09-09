<p align="center">
  <img src="../assets/readme-banner.png" alt="BannerHither — 让通知出现在你正在看的屏幕上" width="720">
</p>

# BannerHither

[English](../README.md) | [한국어](README.ko.md) | [日本語](README.ja.md) | 简体中文 | [Deutsch](README.de.md) | [Français](README.fr.md) | [Español](README.es.md)

[![CI](https://github.com/KJeon10/BannerHither/actions/workflows/ci.yml/badge.svg)](https://github.com/KJeon10/BannerHither/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](../LICENSE)

BannerHither 是一个小巧的 macOS 菜单栏 App，用来决定**通知横幅出现在哪个显示器上**。macOS 总是把横幅显示在主显示器上；使用多台显示器时，那往往不是你正在看的那一台。BannerHither 会在横幅出现的瞬间，把它移到鼠标指针所在的屏幕、你正在使用的窗口所在的屏幕，或你指定的某一台显示器上。

<!-- Demo video: paste the GitHub-hosted mp4 URL here on its own line -->

## 安装

### 下载

1. 从 [Releases](https://github.com/KJeon10/BannerHither/releases) 页面获取 `BannerHither-<版本>.dmg`。
2. 打开镜像，把 `BannerHither.app` 拖到 Applications 快捷方式上。
3. 从“应用程序”文件夹启动。App 和镜像都已用 Developer ID 签名并经过公证，macOS 会直接打开而不给出警告。

### Homebrew

```sh
brew install --cask KJeon10/tap/bannerhither
```

### 自行构建

如需自行构建，请参阅[从源码构建](#从源码构建)。

### 首次启动

BannerHither 会请求**辅助功能**权限（系统设置 › 隐私与安全性 › 辅助功能）。正是这项权限让它能够移动 NotificationCenter 的窗口。授权后引擎会自动启动；运行期间，菜单栏图标会显示为带角标的铃铛。

试试菜单里的*发送测试通知*：通知会在 3 秒后到达，这段时间足够你把鼠标移到另一台显示器上，看看横幅落在哪里。

## 功能

- **鼠标指针所在的屏幕** — 横幅跟着你出现在正在使用的显示器上。
- **活跃窗口所在的屏幕** — 横幅出现在拥有焦点的窗口旁边；无法确定活跃窗口时则回退到鼠标所在的屏幕。
- **指定显示器** — 横幅始终显示在某一台显示器上。若该显示器被拔掉，则保持 macOS 的原有行为，直到它重新接入。
- **系统默认** — 什么都不做，只在菜单栏待命。
- 仅菜单栏、无程序坞图标；开始/停止开关；登录时打开；带 3 秒延迟的测试通知，方便你移动鼠标；用于提交错误报告的*拷贝诊断信息*。
- 通用二进制（Apple 芯片和 Intel）；界面支持英语、韩语、日语、简体中文、德语、法语和西班牙语。
- 只需要一项权限：辅助功能。不访问网络，不收集数据。

## 工作原理

`NotificationCenter.app` 把所有横幅都绘制在一个透明的、与显示器同样大小的窗口里，并在每次展示横幅时把这个窗口放到主显示器上。BannerHither 通过公开的辅助功能 API 监视 NotificationCenter：当横幅窗口出现在默认位置时，App 会设置该窗口的 `AXPosition`，使其右上角与所选显示器的右上角重合，这样横幅就恰好位于 macOS 在那台显示器上原生绘制时的位置。由于移动的是整个窗口，点按、轻扫和关闭按钮都照常工作。

App 只在*状态变化*时介入（横幅刚出现，或 NotificationCenter 刚重新定位它），因此已经显示在屏幕上的横幅不会追着鼠标跑；通知中心面板（NotificationCenter 会把它放在你点按时钟的那台显示器上）也绝不会被触碰。

这依赖于 NotificationCenter 未公开的行为，Apple 可能在任何一次 macOS 更新中改变它。如果窗口无法再被找到或移动，BannerHither 会记录失败，macOS 则按原样运作；其他一切不受影响。*拷贝诊断信息*会导出当前 NotificationCenter 窗口的属性，以便从错误报告中诊断此类变化。

### 已测试的 macOS 版本

| macOS | 状态 |
| --- | --- |
| 26.6 (Tahoe) | 已验证：能找到并移动横幅窗口，NotificationCenter 重启后可恢复 |
| 14.0 – 15.x | 可编译且应能正常工作（窗口结构自 Big Sur 以来保持稳定），但尚未验证 |

### 已知限制

- 如果目标显示器比横幅窗口原本适配的显示器更窄，窗口会超出该显示器的左边缘。横幅本身仍完整可见；如果在意，可用下文的 `resizeToTargetScreen` 选项先调整窗口大小。
- 镜像其他显示器的显示器不是独立的目标。
- 尚未在关闭*显示器具有单独空间*、使用台前调度或锁定屏幕的情况下测试。

## 高级设置

菜单里的所有设置都保存在 `io.github.kjeon10.BannerHither` 下的 `UserDefaults` 中。有两个选项没有菜单项：

| 键 | 默认值 | 含义 |
| --- | --- | --- |
| `pollIntervalMilliseconds` | `1000` | 兜底轮询间隔。App 由辅助功能事件驱动；轮询只用于弥补漏掉的事件和 NotificationCenter 重启。`0` 表示关闭轮询（接受 50–5000）。 |
| `resizeToTargetScreen` | `false` | 移动之前，先把横幅窗口调整为目标显示器的大小。 |

```sh
defaults write io.github.kjeon10.BannerHither pollIntervalMilliseconds -int 500
defaults write io.github.kjeon10.BannerHither resizeToTargetScreen -bool true
```

更改从下一条横幅开始生效。要跟踪 App 的动作：

```sh
log stream --predicate 'subsystem == "io.github.kjeon10.BannerHither"' --level debug
```

## 从源码构建

要求：macOS 14 或更高版本，Xcode 16 或更高版本（或对应的 Command Line Tools）。

```sh
git clone https://github.com/KJeon10/BannerHither.git
cd BannerHither
make build          # → build/BannerHither.app
open build/BannerHither.app
```

按提示允许辅助功能权限即可。

## 隐私

BannerHither 不读取通知内容，也不与外部通信。如果你愿意，也可以[从源码自行构建](#从源码构建)。

## 致谢

参考了 [PingPlace](https://github.com/NotWadeGrimridge/PingPlace)、[ShoveIt](https://github.com/JaysonRawlins/ShoveIt) 和 [NotificationNanny](https://github.com/chessper53/NotificationNanny)。

## 许可证

[MIT](../LICENSE) © 2026 [KJeon10](https://github.com/KJeon10)
