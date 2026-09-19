# Hex Workshop · 海克斯工坊

给雨果自己用的本地 AI 工坊：把自媒体日常里重复的活定义成任务，交给 Claude / Codex 去干，产物直接落到 meta-repo 该去的位置。搭建过程录成教程。

本仓库是 [craft-ai-agents/craft-agents-oss](https://github.com/craft-ai-agents/craft-agents-oss)（Craft Agents，Apache-2.0）的 fork。二开规则见根目录 `AGENTS.md`。

## 为什么叫工坊

**工坊（workshop）是一个有工具、有半成品、在里面造东西的空间。** 工作台（bench）只是工坊里那张桌子。这个项目要的是前者：任务定义是工具，执行记录是半成品，博客文章进来、各平台的内容出去。

名字来自英雄联盟里皮尔特沃夫的**海克斯科技（Hextech）**——把魔法装进机器、让普通人也能用。杰斯和维克托造东西的地方就叫 Hextech workshop。这个项目做的是同一件事：把 AI agent 装进一个普通人按一下就能用的界面。

只取 `hex` 一个词，不碰任何 Riot 商标；也不使用 "Craft" / "Craft Agents" 品牌（见上游 `TRADEMARK.md`）。

## 为什么 fork 而不是自研

2026-09-18 调研结论：自研设计（v2，八模块）里 80% Craft Agents 已经有了，且多出 cron 自动化、headless 远程、多会话收件箱。剩下的表单式任务 UI 和雨果皮肤不值得从零写一个 Next.js + pi runner。

| 自研设计模块 | Craft Agents 对应 | 缺口 |
|---|---|---|
| A 对话台 | Sessions（多会话收件箱、状态流） | — |
| B 任务库（md 表单 + prompt） | Skills（可从 `.claude/skills` 导入）+ Automations | 没有表单 UI，参数在聊天里给 |
| C 执行引擎（pi、审批、停止） | Claude Agent SDK + pi-ai 双引擎；三档权限 | — |
| D 工作区（git 状态、diff、回滚） | Projects 绑定工作目录；Multi-File Diff | 一键 commit / 回滚待验证 |
| E 产物与记录 | Session 持久化 | — |
| F 模型与用量 | 多 provider，Claude / Codex 订阅 OAuth | 用量统计待验证 |
| G 自动化 | Automations（cron / webhook / 状态触发） | — |
| H 能力管理 | Skills / Sources 按 workspace 管理 | — |

原设计文档：[2026-09-16-hexworkshop-design.md](2026-09-16-hexworkshop-design.md)（保留作需求清单）。

## 安装、迁移与更新（自建 Hex Workshop.app）

自建包与官方 Craft Agents **完全隔离、可同时运行**：不同的 bundle id、`~/Library/Application Support/Hex Workshop/`、配置目录 `~/.hexworkshop/`（通过 Info.plist 的 `LSEnvironment` 烤入，双击启动也生效）。脚本都在 `scripts/hex/`，上游文件一个不改。

### 首次

```bash
cd apps/hexworkshop
bun install
bash scripts/hex/package-mac.sh --stage --install    # --stage 暂存 bun / Claude SDK 二进制（只需一次）；--install 装到 /Applications，会确认
```

第一次打开是全新状态。把官方版里已配好的东西搬过来（一次性）：

```bash
cp ~/.craft-agent/credentials.enc ~/.hexworkshop/                 # 凭据按机器 UUID 加密，同机可直接复用，不用重新登录
cp -R ~/.craft-agent/workspaces/<slug> ~/.hexworkshop/workspaces/  # workspace（skills / sources / automations / sessions）
```

然后在 Hex Workshop 里 设置 → 工作区 → 添加已有目录，选 `~/.hexworkshop/workspaces/<slug>`；LLM 连接重新登一次或从 `~/.craft-agent/config.json` 的 `llmConnections` 手动合并。之后两边数据各自演化，这是"互不影响"的代价。

### 日常更新

```bash
bash scripts/hex/update.sh            # 同步上游 → 合进 zer/main → typecheck → 打包 → 替换 /Applications（免确认）
bash scripts/hex/update.sh --no-sync  # 只改了本地源码：不碰 git，直接重新打包安装
```

- 合并上游有冲突时脚本会停下并保留冲突现场，解决后 `git add -A && git commit`，再 `update.sh --no-sync`
- `bun.lock` / `package.json` 变了会自动 `bun install` 并加 `--stage`
- 安装时会退出正在运行的 Hex Workshop，旧版本备份到 `~/Applications/`（只留最近 2 个）
- 脚本**不会 push**；确认新包正常后手动 `git push origin main zer/main`

### 单独打包（不安装）

```bash
bash scripts/hex/package-mac.sh              # 产物在 apps/electron/release/mac-arm64/Hex Workshop.app
bash scripts/hex/package-mac.sh --vanilla    # 与官方同名的 Craft Agents.app（不能与官方共存，仅调试用）
```

### 图标

`resources/hex/icon-1024.png` 由 `scripts/hex/make-icon.swift` 生成（Craft 同款白→浅灰圆角底板 + 灰蓝像素 "HEX" 字样），`icon.icns` 由它导出。改颜色：`swift scripts/hex/make-icon.swift resources/hex/icon-1024.png 5C7C9B`，再重跑 `iconutil`（见 `package-mac.sh` 注释）。Dock 图标在运行时由主进程从 `dist/resources/icon.png` 设置，`scripts/hex/afterPack.cjs` 会把 bundle 里这张也替换掉。

### 排错

- 上游改了签名或 SDK 版本导致包起不来：`bash scripts/hex/package-mac.sh --stage --install`
- 自动更新日志里的 `ENOENT app-update.yml` 是预期的（我们故意删了更新清单）
- Dock 图标还是旧的：`killall Dock`
