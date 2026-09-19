# AGENTS.md — Hex Workshop（fork of Craft Agents）

## 语言要求

与用户交流、写文档、写 commit message 用中文。代码、标识符、上游文件保持英文。

## 编码行为准则（fork 专属，最重要）

本仓库是 [craft-ai-agents/craft-agents-oss](https://github.com/craft-ai-agents/craft-agents-oss) 的 fork，目标是**既二开、又长期跟上游更新**。一切取舍服从一个原则：**把自己的 delta 压到最小。**

### 分支

| 分支 | 用途 | 规则 |
|---|---|---|
| `main` | 上游镜像 | 只 `git merge --ff-only upstream/main`，永远不直接提交 |
| `zer/main` | 二开长期分支，GitHub 默认分支 | 所有二开在这里；同步上游用 **merge**，不 rebase，不 force push |
| `fix/*` `feature/*` | 给上游的 PR | **从 `upstream/main` 切**，不从 `zer/main` 切；PR 合并后随下一次同步自然回到 `zer/main` |

bug 修复走 `fix/*` → 上游 PR。**不要把修复直接合进 `zer/main`**——留在自己这边就是永久冲突源。上游迟迟不合、又急用时，才 cherry-pick 到 `zer/main` 并在 commit message 注明 `cherry-pick of upstream PR #n`，合并后删掉。

### 改动优先级

1. **不碰源码就能做到的**：Skills / Sources / Automations / 主题 / workspace 配置。零冲突，优先。
2. **加新文件**：新 package、新组件、新 route，只在入口处加一行引用。
3. **改已有文件**：最小 diff。不顺手格式化、不重命名、不挪代码、不改注释措辞。
4. 每次做到第 3 项前先问：能不能作为 feature PR 给上游？上游一周一个 release，自己维护的每一行都是每周要付的利息。

### 不要动的文件

`README.md`、`CONTRIBUTING.md`、`CODE_OF_CONDUCT.md`、`SECURITY.md`、`TRADEMARK.md`、`NOTICE`、`LICENSE`、`apps/electron/CLAUDE.md` 及其它上游已有的 CLAUDE.md。fork 自己的说明只写在根目录 `AGENTS.md`、`CLAUDE.md` 和 `docs/hexworkshop/`（上游没有这些文件，不会冲突）。

### 品牌

不使用 "Craft" / "Craft Agents" 名称、logo 命名自己的东西（上游 `TRADEMARK.md`）。自己用不需要改 `productName` / `appId`；**只有要对外分发安装包时**才改 `apps/electron/electron-builder.yml` 的 `appId` / `productName` 和图标。

### 提交

- 一个 commit 只做一件事，方便将来挑出来给上游
- commit message 中文，前缀沿用 conventional commits（`feat:` `fix:` `docs:` `chore:`）
- 不提交 `.env`、`runs/`、任何凭据

## 任务执行方式

- 改上游源码前先 `git log --oneline main..zer/main` 看现有 delta，不要让它无节制增长
- 同步上游后必须 `bun run typecheck:all` 通过再推
- 涉及 electron 主进程 / 渲染进程 / IPC 的改动，读 `apps/electron/CLAUDE.md`（上游维护，权威）
- 需要给上游提 PR 时，遵守 `CONTRIBUTING.md`：从 `main` 切分支、`bun run typecheck:all`、分支名 `fix/xxx` / `feature/xxx`

## 项目概述

Craft Agents 是 craft.do 开源的桌面 agent 工作台（Electron + React，Apache-2.0）：多会话收件箱、Workspace / Project、Sources（本地目录 / MCP / REST）、Skills（兼容 Claude Code skills）、Automations（cron / webhook / 状态触发）、三档权限、headless server 模式。

本 fork 的用途：给雨果一个人用的本地 AI 工坊，跑 meta-repo（`../../`）里的自媒体流水线——选题、拆解、写作检查、排版、发布、数据回流。它取代了原计划自研的 Next.js + pi 工坊，原设计与对应关系见 `docs/hexworkshop/README.md`。

## 技术栈

- 运行时 / 包管理：**Bun**（monorepo workspaces：`packages/*`、`apps/*`）
- 桌面：Electron + React 18 + Vite + Tailwind v4 + shadcn/ui（Radix）+ Jotai + i18next
- Agent 引擎：`@anthropic-ai/claude-agent-sdk`（Claude）+ `@earendil-works/pi-ai`（其它 provider：openai-codex / openrouter / google / ollama…）
- 打包：electron-builder（`apps/electron/electron-builder.yml`），`asar: false`
- 测试：`bun test`；类型检查 `tsc --noEmit` 按 package

## 常用命令

```bash
# 首次
bun install
cp .env.example .env            # 按需填

# 开发运行（不触发自动更新——auto-update 只在 app.isPackaged 时启用）
bun run electron:dev            # 热更新
bun run electron:start          # 完整构建后启动

# 检查
bun run typecheck:all
bun run test
bun run lint

# 本机打包（不签名、不公证）
bun run electron:dist:dev:mac
# 打包后必须删掉更新清单，否则 electron-updater 会把 app 拉回官方版本：
rm "apps/electron/release/mac-arm64/Craft Agents.app/Contents/Resources/app-update.yml"
codesign --force --deep -s - "apps/electron/release/mac-arm64/Craft Agents.app"   # ad-hoc 签名

# 同步上游（在 zer/main 上）
git fetch upstream
git checkout main && git merge --ff-only upstream/main && git push origin main
git checkout zer/main && git merge main          # 解决冲突 → typecheck → push
git push origin zer/main

# 查看自己的 delta
git log --oneline main..zer/main
git diff --stat main..zer/main
```

远端：`origin` = `ZerVisionGo/hex-workshop`（本地路径 `apps/hexworkshop`，在 meta-repo 的 `.bootstrap-repos.tsv` 登记）；`upstream` = `craft-ai-agents/craft-agents-oss`。

## 目录结构

```
apps/
  electron/        桌面应用（主进程 src/main、预加载 src/preload、渲染 src/renderer）
  cli/             命令行入口
  webui/  viewer/  Web 端与只读查看器
packages/
  shared/          agent 后端、配置、模型列表、skills / sources 逻辑（改动最集中的地方）
  core/  server-core/  server/   headless server 与核心类型
  ui/              共享 React 组件
  pi-agent-server/ pi 引擎的会话服务
  session-tools-core/  session-mcp-server/  会话工具
  messaging-gateway/  messaging-whatsapp-worker/  消息网关
docs/
  cli.md           上游文档
  hexworkshop/     ← fork 自己的文档（设计、取舍、对应关系）
scripts/           构建脚本（electron-build-*.ts、build-server.ts）
```

## 核心模式与约定（上游的，改代码前要知道）

- Claude Agent SDK 会 spawn 一个原生 `claude` 二进制，路径解析在 `packages/shared/src/agent/backend/internal/runtime-resolver.ts`；打包环境靠 `claude-agent-sdk-binary` 别名。改这块先读 `apps/electron/CLAUDE.md` §1
- 认证环境变量（`CLAUDE_CODE_OAUTH_TOKEN` / `ANTHROPIC_API_KEY`）必须在创建 agent 之前设置
- 主进程 ↔ 渲染进程只走 preload 暴露的 `electronAPI`；有 `lint:ipc-sends` 检查裸 send
- i18n 字符串有 parity / sorted / coverage 三道 lint，新增 UI 文案要同步所有 locale（或跑 `bun run sort-locales`）
- 加载指示器统一用 `Spinner` / `LoadingIndicator`，不用 `Loader2` / `animate-spin`
- 图标用 lucide-react；新 shadcn 组件用 `npx shadcn@latest add`

## 主要功能模块（与 meta-repo 的接法）

- **Workspace** 指向 meta-repo 根目录 `../../`，让 agent 读到根 `AGENTS.md` / `CLAUDE.md`
- **Skills** 从 `../../.claude/skills/` 导入；`~/.claude/plugins/` 里的 marketplace skill（dbs-* 等）需手动拷贝或软链
- **Sources** 至少挂 `../../docs/content-ops/`（选题库、草稿）和 `../../apps/rainnut-blog/content/`
- **Automations** 承接原设计里的定时任务（选题提醒、数据回流）
- 公众号发文流水线的 skill + CLI 是壳无关的，设计在 meta-repo 侧，工坊只负责调用
