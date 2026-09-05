# 🧠 MindSieve

**基于端侧 AI 的注意力流失阻断工具**

MindSieve 是一个开源的注意力管理工具，通过在用户打开手机时提供极简搜索入口、实时检测黑洞 App 使用时长，并用悬浮窗拦截提醒，帮助用户找回数字生活中的专注力。

## ✨ 功能特性

- 🔍 **极简搜索**：输入关键词，直达抖音/小红书/B站搜索结果，跳过推荐流
- 🛡️ **注意力哨兵**：检测到黑洞 App 被打开时，计算使用时长，弹窗提醒
- 🤖 **端侧 AI Agent**：本地决策引擎，不上传任何用户数据
- 📊 **数据看板**：饼状图 + 柱状图 + AI 智能分析建议
- ⚙️ **自定义管理**：用户可自由添加/删除/开关被监控的 App

## 🛠️ 技术栈

| 技术 | 用途 |
|------|------|
| Flutter | 跨平台 UI 框架 |
| Dart | 编程语言 |
| SQLite | 本地数据库 |
| fl_chart | 数据可视化图表 |
| ModelScope API | AI 智能分析 |
| MIT License | 开源协议 |

## 📱 安装体验

### Android 用户
1. 下载 app-release.apk（见 Releases）
2. 点击安装，允许「未知来源应用」权限
3. 打开 App，开始体验

### iOS 用户
TestFlight 版本正在准备中，敬请期待。

## 🏗️ 快速开始（开发）

```bash
git clone https://github.com/Harriet-Haoshan/mindsieve.git
cd mindsieve
flutter pub get
flutter run
