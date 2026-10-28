# AntCam — 《地下蚁国》第一人称蚂蚁视角 Mod

**Empires of the Undergrowth — first-person ant view & puppet mode (UE4SS Lua mod)**

在 RTS 视角之外，按一个键就能"钻进"你自己的一只蚂蚁里，用它的眼睛看世界，还可以用 WASD + 鼠标亲自操控它，或者按 Q 让它自己去打周围的敌人。再按一次，立刻回到原来的第三人称 RTS 视角。

> ⚠️ 这是**非官方**的玩家作品，与游戏开发商、发行商没有任何关系。实验性质，**请只在单人 / 离线模式使用，使用前备份存档**，风险自负。

## 功能

- **F8**：进入 / 退出蚂蚁视角。它是另外生成的一个相机，**不会修改游戏原本的相机**，所以不会和第三人称冲突。
- **只能选你自己阵营的蚂蚁**，不会操控敌人。**PageUp / PageDown** 切换下一只 / 上一只。
- **操控模式（小键盘 1）**：暂停这只蚂蚁的 AI，由你控制。
  - **W A S D** 按你看的方向移动，**鼠标**转头（光标会被固定在屏幕中央，这是故意的），方向键可作备用转头。
  - **Q**：开 / 关**自动攻击**。开启时恢复蚂蚁自己的 AI，由游戏自己的战斗逻辑去打附近的敌人，此时 WASD 失效。
  - **Home / End**：鼠标灵敏度加 / 减；**Insert**：上下反转。
- **小键盘 + − \* /**：相机前后 / 上下微调。
- **小键盘 3**：在控制台输出周围生物的诊断信息（调试用）。

## 测试环境

- 游戏：Steam 版，构建号 **1.2.1.1**（虚幻引擎 **4.27.2**），Windows
- UE4SS：**zDEV 版本** `<3.0.0>`

## 安装

### 方式 A：完整包（推荐，已含 UE4SS 和配置）
1. 下载 `AntCam-vX.X-Full.zip`。
2. 把里面所有内容解压到游戏目录的 `EotU\Binaries\Win64\`（就是 `EotU-Win64-Shipping.exe` 所在的文件夹）。
3. 启动游戏，进入对局，按 **F8**。

### 方式 B：只装 Mod（你已经装过 UE4SS）
1. 下载 `AntCam-vX.X-ModOnly.zip`，把里面的 `Mods` 和 `UE4SS_Signatures` 两个文件夹合并进同一个 `Win64` 文件夹。
2. 用记事本打开 `UE4SS-settings.ini`，找到 `[EngineVersionOverride]`，设置 `MajorVersion = 4`、`MinorVersion = 27`。
3. 启动游戏。

> 为什么需要 `UE4SS_Signatures\FText_Constructor.lua`？UE4SS 的自动扫描在这个游戏里找不到一个函数，这个文件手动指定了它的位置。它只对应游戏构建号 1.2.1.1。

## 卸载

把 `dwmapi.dll` 改名为 `dwmapi.dll.disabled`（临时关闭 UE4SS），或者删除 `Mods\AntCam` 文件夹。

## 常见问题

| 现象 | 可能原因 |
| --- | --- |
| 控制台出现 `PS scan failed / Failed to find FText` | 游戏更新了，`FText_Constructor.lua` 不再匹配。请开 Issue，并附上游戏构建号 |
| 控制台出现 `Failed to find EngineVersion` | 没有设置 `[EngineVersionOverride]`（见安装第 2 步） |
| 按 F8 没反应 | 看控制台有没有 `[AntCam] loaded`；必须在对局里，主菜单不行 |
| 控制台有红字提示找不到 `main.lua` | **文件夹名必须是纯英文**。Windows 解压时可能生成 `AntCam - 副本` 之类的文件夹，请删除 |
| 鼠标转头没反应 | 看控制台的 `mouse:` 开头几行并带到 Issue 里；方向键转头仍可用 |
| F9 变成拍照 | F9 是游戏自带的拍照键，本 Mod 没有使用它 |

## 已知限制

- 实验性质，只在单人 / 离线下测试过。
- 操控模式下蚂蚁的 AI 会被暂停并屏蔽 RTS 的点击；退出时会恢复，但极端情况下可能留下不一致的状态。
- 游戏更新后可能失效。
- 自动攻击依赖游戏自己的 AI，没有敌人时蚂蚁会按平常的行为活动。

## 致谢与许可

- 基于 [UE4SS](https://github.com/UE4SS-RE/RE-UE4SS)（MIT 许可）。
- 本项目代码使用 MIT 许可，见 `LICENSE`。
- 本仓库**不包含**任何游戏文件、游戏资源或从游戏中导出的代码。


---

## English summary

AntCam lets you press **F8** to look through the eyes of one of **your own** ants (separate camera, the game's own camera is never touched), switch ants with **PageUp/PageDown**, steer the ant yourself with **WASD + mouse** (Numpad 1), and toggle **auto-attack** with **Q**. Unofficial, experimental, **single-player/offline only — back up your saves**.

Tested on game build **1.2.1.1** (UE 4.27.2). Requires UE4SS (zDEV) with `[EngineVersionOverride] MajorVersion=4, MinorVersion=27` and the bundled `UE4SS_Signatures/FText_Constructor.lua`. See the install section above. Not affiliated with the game's developer or publisher.
