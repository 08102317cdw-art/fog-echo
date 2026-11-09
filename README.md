# 雾中回响

《寂静岭》非官方同人恐怖游戏，使用 Godot 和 GDScript 制作。源码公开，仅供非商业学习交流，与 KONAMI 无关。

**版本说明：本仓库没有 v1.2 Windows 成品对应的完整最终源码。**

| 内容 | 来源与状态 |
| --- | --- |
| `game/` | 交付的 v1.1 完整源码，加上本仓库的网页导出适配；网页版使用此版本 |
| `snapshots/v1.2-dev/` | v1.2 开发过程快照，主控等部分文件仍是较早版本；不保证能运行或还原 v1.2 |
| `tools/` | 开发快照附带的素材生成和下载工具，部分保留原开发环境绝对路径 |
| `docs/` | 原始开发文件说明、v1.2 成品说明和素材署名清单 |
| Releases 中的 v1.2 Windows 包 | 原先交付的游戏成品，与本仓库网页版本不同 |

## 网页游玩

网页部署使用 GitHub Pages，入口见仓库主页的「About」网址。**网页标注为 v1.1 网页适配版，不包含 v1.2 成品的完整枪械、商人和学校后续章节。**

推荐使用电脑上的 Chrome、Edge 或 Firefox。需要支持 WebGL 2.0；首次下载游戏资源后，请点击画面或按键启用声音。浏览器兼容模式不支持体积雾，画质与 Windows 版有区别。

WASD 移动，Shift 奔跑，鼠标环顾，E 调查，F 手电筒，鼠标左键攻击或踩踏，Tab 物品栏，M 地图，R 收音机，Esc 或 P 暂停。Esc 可能先解除浏览器鼠标锁定，此时点击画面可重新捕获鼠标，也可用 P 暂停。

## 本地开发与导出

1. 安装 Godot 4.3 标准版及同版本导出模板。
2. 导入 `game/project.godot`，等待资源导入完成，然后按 F5 运行。
3. 导出选择 `Web`；输出文件为 `dist/index.html`，使用兼容渲染和单线程模式。
4. 使用 HTTP 服务预览导出的目录，不能直接双击 HTML 文件：

```powershell
python -m http.server 8080 --directory dist
```

命令行导出方式：

```powershell
New-Item -ItemType Directory -Force dist
godot --headless --path game --editor --import
godot --headless --path game --export-release Web ../dist/index.html
```

推送到 `main` 后，`.github/workflows/pages.yml` 会从源码构建并部署网页。仓库 Settings → Pages 的来源需选择 GitHub Actions。

## 原始文件与素材

开发文件整理包和原始交付包保留在本地。仓库包含游戏运行所需资源；下载网页、素材缩略图、重复压缩包、导入缓存和编辑器程序不纳入源码仓库。开发快照原样保留，其内容不能作为已验证的 v1.2 最终版。

具体来源、版本差异及校验值见 [发布记录](docs/发布记录.md)。第三方素材见 [署名与授权说明](THIRD_PARTY_NOTICES.md)。

## 使用许可

原创部分保留禁止商用限制，详见 [公开源码使用说明](LICENSE.md)。这是公开源码项目，不宣称采用符合开源定义的许可证。第三方素材继续遵循 CC0、SIL OFL 等各自授权。
