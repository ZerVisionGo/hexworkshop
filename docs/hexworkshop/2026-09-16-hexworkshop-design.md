> **状态更新（2026-09-19）**：本文是 fork Craft Agents 之前的自研设计（v2）。已决定不自研，改为 fork [craft-agents-oss](https://github.com/craft-ai-agents/craft-agents-oss) 二开（即本仓库）。八个模块与 Craft Agents 功能的对应关系见 [README.md](README.md)。保留本文作为需求清单和取舍依据。

# Hex Workshop 设计文档（v2 · 完整产品）

日期：2026-09-16
状态：v2 待确认。v1 只覆盖"内容派生"一条线，用户要求设计成完整的个人 AI 工坊，本版重写。

## 1. 定位

**给雨果一个人用的本地 AI 工坊。** 用自然语言下任务，或者点一个预设任务，交给 Claude / Codex 去干：读写这台电脑上的文件、跑命令、用 skill、操作各个子仓库；执行过程可见、可审批、可停止；产物有记录、有 diff、能回滚、能一键提交；重复的活能定时跑。搭建过程录成教程。

对标腾讯 WorkBuddy 的"本地执行型 AI 工作台"定位，但只服务一个人、一台机器、一个 meta-repo。

**不是什么**：不是对外产品，不做多用户、不做云端、不做 IM 机器人、不做直播录屏。

### 1.1 八个模块

| 模块 | 一句话 | 阶段 |
|---|---|---|
| A 对话台 | 自然语言直接下任务，可续聊、可插话、可保存成任务 | 1 |
| B 任务库 | 预设任务 = md 文件（表单 + prompt），按分类组织 | 1 |
| C 执行引擎 | pi 会话、工具流、审批策略、并发队列、停止 / 重试 | 1（审批与队列在 2） |
| D 工作区 | 选在哪个子仓库里干活，看 git 状态、变更 diff、回滚、一键 commit | 2 |
| E 产物与记录 | 每次执行的日志、产物、回放、搜索 | 1 |
| F 模型与用量 | 多 provider、任务级默认模型、计费提示、用量统计 | 1（统计在 2） |
| G 自动化 | 定时任务、完成 / 失败通知 | 3 |
| H 能力管理 | skill / extension 的列表与启停、工坊自己的上下文文件 | 3 |

阶段只是交付顺序，不是范围裁剪：本文档把八个模块全部设计到可实现。

### 1.2 内容原则（内容类任务适用）

- **博客是源头，社媒是派生**：`apps/rainnut-blog/content/blog/*.mdx` 是所有内容的单一真相源；X、小红书、小绿书（公众号图片消息）、公众号文章都从博客派生；小绿书从小红书产物二级派生；派生物过时了从源头重生成，不手改
- **配图跟着平台走**：不是独立任务，和文案一起交付；小红书 3:4、公众号封面 2.35:1 + 1:1 缩略图、X 复用博客 16:9
- **素材层**：`docs/content-ops/`（`library/topics.md` 选题库、`library/benchmarks.md` 对标库、`library/cases/` 拆解记录、`drafts/YYYY-MM/`）；规则在 `playbook.md`，流程在 `content-system.md`。内容任务从这里取选题、往这里写拆解
- **小红书方向产物发布前必须过 `xhs-precheck`**，结果写进产物目录 `precheck.md`，有 ERROR 不算完成

| 目标 | 文案 | 图 | 派生自 |
|---|---|---|---|
| 博客 | 人写 | 16:9 正文配图（`zerspace-illustrations`） | — |
| X | thread | 复用博客配图 | 博客 |
| 小红书 | 标题 + 正文 + 标签 | 3:4 封面 + 正文图 | 博客 |
| 小绿书 | 短文案，去标签语法 | 复用小红书的图 | 小红书产物 |
| 公众号文章 | 长文 HTML | 封面 2.35:1 + 1:1；正文图复用博客 | 博客 |

## 2. 技术选型

- **执行层 pi**（`@earendil-works/pi-coding-agent` 0.85.x + `@earendil-works/pi-ai`），SDK 进程内 `createAgentSession()`。理由：多 provider，OAuth 同时支持 Claude Pro/Max 与 ChatGPT Plus/Pro（Codex）；实现 Agent Skills 标准，`.pi/settings.json` 的 `skills` 指向 `../../.claude/skills` 即复用现有 skill；extension 的 `tool_call` 钩子可以拦截 / 放行 / 终止工具调用，这是审批策略的实现基础；`SessionManager` 支持文件持久化会话，这是对话台续聊的基础
- **前端 / 服务端 Next.js 16 App Router**，与 rainnut-blog 同栈（pnpm、Biome、Tailwind、Radix）
- **持久化：文件**。`runs/`、`sessions/`、`schedules.json`、`usage.jsonl`。单人单机，不上数据库
- **定时：`croner`**（纯 JS cron，跑在 Next 的 Node 进程里，`instrumentation.ts` 里启动）
- **通知：`osascript`** 发 macOS 通知
- **测试 Vitest**
- 前提：本机已装 pi，已 `/login` 至少一个 provider（2026-09-16 本机 `auth.json` 为空）

### 2.1 计费差异（写进 UI）

- anthropic：通过 pi 调用按 token 计入 Claude extra usage，不占订阅额度
- openai-codex：走 ChatGPT 订阅额度，OpenAI 官方认可

## 3. 目录结构

```
apps/hexworkshop/
  README.md
  AGENTS.md                    工坊自己的上下文：我是谁、平台规则在哪、各子仓库是什么（模块 H）
  .pi/settings.json            { "skills": ["../../.claude/skills"] }
  tasks/<category>/<id>.md     任务库（模块 B）
  runs/<runId>/                执行记录（模块 E，gitignore）
  sessions/<sessionId>.jsonl   对话台会话（pi SessionManager 文件模式，gitignore）
  data/
    schedules.json             定时任务（模块 G）
    usage.jsonl                用量记录（模块 F）
    workspaces.json            工作区清单（模块 D，可由 .bootstrap-repos.tsv 生成）
  src/app/
    (shell)/layout.tsx         左侧导航：对话 / 任务 / 记录 / 自动化 / 设置
    chat/page.tsx              模块 A
    tasks/page.tsx             模块 B
    runs/page.tsx  runs/[id]   模块 E
    automation/page.tsx        模块 G
    settings/page.tsx          模块 F + H
    api/chat/...               会话 CRUD + prompt/steer/followUp/abort（SSE）
    api/run/...                任务执行（SSE）+ 审批应答
    api/runs/...               记录列表 / 单次 / 产物文件
    api/workspaces/...         git 状态 / diff / 回滚 / commit
    api/schedules/...          定时 CRUD
    api/models  api/usage  api/capabilities
  src/lib/
    engine/session.ts          pi 会话封装（创建、事件映射、abort）
    engine/approval.ts         审批策略 extension + 前后端应答通道
    engine/queue.ts            并发队列
    engine/prompt.ts           prompt 组装（任务正文 + 固定尾部 + skill 提示）
    tasks.ts                   任务加载 / 校验 / 占位符
    runs.ts                    记录写入 / 快照 / 读取
    workspaces.ts              子仓库发现 + git 操作
    schedules.ts  usage.ts  notify.ts  models.ts  capabilities.ts
  docs/superpowers/specs/
```

独立 git 仓库，有远端后登记 `.bootstrap-repos.tsv`。

## 4. 数据模型

全部是文件，这里定义的是形状。

```ts
// 任务（来自 tasks/<category>/<id>.md 的 frontmatter）
Task {
  id, name, description, category: "content" | "research" | "repo" | "files" | "daily"
  inputs: Input[]                 // 见 §5
  workspace?: string              // 默认工作区 id，如 "rainnut-blog"；缺省 = hexworkshop 自身
  output?: string                 // 产物目录模板
  skills: string[]
  model?: "provider/id"           // 任务级默认模型
  approval?: "auto" | "writes" | "all"   // 任务级审批策略，缺省读全局设置
  schedule?: string               // cron 表达式；有就出现在自动化页
  disabled?: { reason: string }   // 校验失败时由 tasks.ts 填
}

// 执行记录（runs/<runId>/）
Run {
  id: "<ISO时间戳>-<taskId|chat>", taskId?, sessionId?, workspace, model
  inputs: Record<string, string>
  status: "queued" | "running" | "waiting_approval" | "done" | "failed" | "stopped"
  startedAt, endedAt, usage: { input, output, cacheRead, cost? }
  outputDir?, changedFiles: string[]     // 结束时对工作区 git status 取的差集
  trigger: "manual" | "schedule" | "chat"
}
// runs/<runId>/ 内：run.json（上面这个）、log.jsonl（所有事件）、output/（快照）、diff.patch（changedFiles 的 git diff）

// 对话会话（sessions/，由 pi SessionManager 管理，工坊只存索引）
Session { id, title, workspace, model, createdAt, updatedAt, runIds: string[] }

// 定时（data/schedules.json）
Schedule { id, taskId, cron, inputs, model?, enabled, lastRunId?, nextAt }

// 用量（data/usage.jsonl，每行一次 agent_end）
Usage { at, runId, provider, model, input, output, cacheRead, durationMs }

// 工作区（data/workspaces.json，可从 .bootstrap-repos.tsv 生成）
Workspace { id, path, kind: "apps" | "services" | "packages" | "tools" | "docs" | "root" }
```

## 5. 模块 B · 任务库

Markdown + frontmatter，**frontmatter 描述表单和策略，正文是 prompt 模板**。

```md
---
id: blog-to-x
name: 博客 → X
description: 把一篇博客改编成 X thread，配图复用博客已有的
category: content
workspace: rainnut-blog
inputs:
  - { key: post, label: 选一篇文章, type: file, glob: content/blog/*.mdx }
  - { key: length, label: 长度, type: select, options: [单条, thread], default: thread }
output: content/social/{{post.basename}}/x/
skills: []
approval: writes
---
读取 {{post}}，以 @Zerspace 的口吻改编成 {{length}}……
```

- `inputs[].type`：`file`（glob 相对工作区）、`select`、`text`、`textarea`、`url`、`files`（多选）
- `required` 默认 true；内容任务的 `post` 设 false 即允许无源派生
- 占位符 `{{key}}`、`{{key.basename}}`、`{{workspace}}`；未知占位符 → 任务标灰
- 校验：`id` 与文件名一致；`output` 解析后必须落在 meta-repo 内的 `apps/` `docs/` `tools/` 下；`file` glob 匹配 0 个时表单内提示
- **从对话保存为任务**（模块 A → B）：对话台上点「存为任务」，把这次会话的首条 prompt 抽成模板，自动识别其中的文件路径变成 `file` 输入，生成草稿 md 让用户改一下再保存

### 5.1 首批任务

| 分类 | 任务 | 阶段 | 备注 |
|---|---|---|---|
| daily | `hello` | 1 | smoke |
| files | `tidy-downloads` | 1 | 整理 ~/Downloads，按类型归档、列出可删项——通用工坊的演示任务 |
| content | `blog-to-x` | 1 | 不出图 |
| content | `blog-to-xiaohongshu` | 1 | `skills: [zerspace-illustrations, xhs-precheck]`；前置：skill 加 3:4 版式 |
| content | `xiaohongshu-to-wechat-pic` | 1 | 小绿书；`skills: [xhs-precheck]` |
| content | `blog-to-wechat-article` | 2 | 调 `dbs-wechat-html`；前置：skill 加 2.35:1 封面版式 |
| content | `illustrate-post` | 2 | 给已有博客文章批量补 16:9 正文配图 |
| research | `hot-topics` | 2 | 热帖 → 选题，追加到 `docs/content-ops/library/topics.md` |
| research | `deconstruct-hot-posts` | 2 | 调 `content-deconstruct`，产物写 `library/cases/`，无源任务 |
| research | `market-research` | 2 | 跑 `market-research` skill 一轮，产物落 `docs/market-research/ideas/` |
| repo | `sync-repos` | 2 | 跑 `install.sh sync`，汇报落后的子仓库 |
| daily | `weekly-review` | 3 | 读 `runs/`、各仓库一周提交、`usage.jsonl`，生成周复盘；`schedule: "0 20 * * 0"` |

产物目录（内容类）：`apps/rainnut-blog/content/social/<post-slug>/{x,xiaohongshu,wechat-pic,wechat-article}/`。

## 6. 模块 A · 对话台

WorkBuddy 的主入口是对话，这里也是。

- 一个会话 = 一个 pi 文件会话（`SessionManager` 文件模式，存 `sessions/`），可关掉页面回来续聊
- 新建会话时选**工作区**和**模型**；会话内可切模型（pi 支持）
- 运行中可**插话**（`session.steer()`，当前工具调用做完就插进去）和**追加**（`session.followUp()`，等 agent 停下再发）；UI 上是同一个输入框，运行中出现「插话 / 排队」两个按钮
- 停止 = `session.abort()`
- 每次 prompt 的执行也记成一条 Run（`trigger: "chat"`），进模块 E，这样对话里产生的文件改动一样有 diff 和回滚
- 「存为任务」见 §5
- 会话列表在左侧，按更新时间排；可改标题、删除

## 7. 模块 C · 执行引擎

### 7.1 会话生命周期

```
createAgentSession({ cwd: <workspace.path>, model, sessionManager, modelRuntime, resourceLoader })
   resourceLoader = DefaultResourceLoader({ extensionFactories: [approvalExtension(policy, channel)] })
prompt = engine/prompt.ts 组装
   = 任务正文（占位符替换）
   + 「把所有产物写到 <output>，不要写到别处」（有 output 时）
   + 「这个任务请使用 skill：<skills>」（有 skills 时）
subscribe → 事件映射 → SSE + log.jsonl
agent_end → usage.jsonl、git 差集 → changedFiles、diff.patch、output 快照、通知
```

事件映射：

| pi 事件 | SSE |
|---|---|
| `message_update` / `text_delta` | `{type:"text", delta}` |
| `message_update` / `thinking_delta` | `{type:"thinking", delta}`（UI 折叠显示） |
| `tool_execution_start` / `end` | `{type:"tool", phase, name, args, isError}` |
| 审批扩展发出 | `{type:"approval", id, toolName, input, reason}` |
| `auto_retry_start` / `end` | `{type:"status", message:"重试中 (n/max)"}` |
| `compaction_start` / `end` | `{type:"status", message:"压缩上下文"}` |
| `agent_end` | `{type:"done", runId, usage, changedFiles}` |
| 异常 | `{type:"error", message}` |

### 7.2 审批策略

pi 没有内置权限确认，用 extension 的 `tool_call` 钩子实现三档：

| 档 | 行为 |
|---|---|
| `auto` | 全放行；只拦截黑名单命令（`rm -rf /`、`git push --force`、`git reset --hard`、写工作区外的路径）→ 直接 `block` 并终止 |
| `writes`（默认） | `read` / `ls` / `grep` 类放行；`write` / `edit` / `bash` 需要确认 |
| `all` | 每个工具调用都确认 |

确认流程：钩子 → 通过 channel 发 SSE `approval` → 前端弹一条内联卡片（不是模态）显示工具名和参数 → 用户点「允许 / 拒绝 / 本次全部允许」→ `POST /api/run/<runId>/approve` → resolve 钩子的 Promise。**超时 5 分钟默认拒绝**，Run 状态在等待期间为 `waiting_approval`。定时触发的 Run 没人看，强制用 `auto` 档。

优先级：任务 frontmatter 的 `approval` > 全局设置。

### 7.3 并发队列

- 全局并发上限默认 2（设置页可改 1~4）
- 同一工作区同时只允许一个 Run（避免两个 agent 改同一仓库）
- 超出的进队列，状态 `queued`，UI 显示位置；队列里的可以取消
- 定时触发的 Run 一样进队列，不插队

### 7.4 停止与失败

- 停止：`abort()`，状态 `stopped`，快照与 diff 照做
- 失败：pi 自动重试后仍失败 → `failed`；`runs/` 保留，已产出的文件不删；通知一条

## 8. 模块 D · 工作区

- 工作区 = meta-repo 里的子仓库 + 根仓库自身，从 `.bootstrap-repos.tsv` 生成 `data/workspaces.json`，也可手加
- 每个 Run 绑定一个工作区，`cwd` 就是它的路径；agent 写工作区外的路径被审批扩展拦下
- Run 开始前记 `git status --porcelain` 快照，结束后再取一次，差集 = `changedFiles`；对这些文件跑 `git diff` 存成 `diff.patch`
- 记录页可以：看 diff、**回滚**（对未提交的改动 `git checkout -- <files>` + 删除新增文件，回滚前二次确认）、**一键 commit**（用 `commitmsg` skill 的规范生成信息，只 add 这次 Run 的 `changedFiles`，不 push）
- 工作区若不是干净状态，Run 开始前在 UI 上提示（不阻止）——回滚只能精确到"这次 Run 改的文件"，脏工作区会让边界模糊

## 9. 模块 E · 产物与记录

- 列表：按时间倒序，可按任务 / 工作区 / 状态 / 触发方式筛选，可全文搜 prompt
- 详情：左边日志回放（读 `log.jsonl`，不重跑），右边产物文件树 + 预览（Markdown 渲染、图片、HTML 沙箱 iframe、JSON / CSV 表格、其他原文）+ diff 视图
- 「重跑」：带同样输入再跑一次；「以此为模板」：跳到对话台并预填 prompt
- 保留策略：默认保留 90 天，设置页可改；超期只删 `output/` 快照和 `diff.patch`，`run.json` 与 `log.jsonl` 永久保留

## 10. 模块 F · 模型与用量

- 模型列表来自 `modelRuntime.getAvailable()`（只列已登录 provider）；每个模型附计费文案（§2.1）
- 默认模型三级：全局设置 < 任务 frontmatter < 本次表单选择
- 每次 `agent_end` 追加一行 `usage.jsonl`；设置页有用量面板：按天 / 按模型 / 按任务的 token 与次数，anthropic 按公开单价估算费用，openai-codex 只计次数
- 没有 provider 登录：所有页面顶部横幅「在终端跑 `pi` 然后 `/login`」，执行按钮禁用

## 11. 模块 G · 自动化

- 定时任务 = 任务 + cron + 固定输入 + 模型；存 `data/schedules.json`；任务 frontmatter 的 `schedule` 字段是默认值，可在自动化页覆盖或关掉
- `croner` 在 `instrumentation.ts` 里加载全部 enabled 的 schedule；触发即入队列（§7.3），审批强制 `auto`
- 自动化页：列表（下次运行、上次结果）、启停、立即运行、编辑 cron（提供"每天 / 每周 / 每月"三个快捷）
- 通知：Run 完成 / 失败 / 等待审批时 `osascript -e 'display notification'`；设置页可关
- 工坊只在 `pnpm dev` / `pnpm start` 跑着的时候有定时——这是接受的限制，README 里写明；要常驻就用 `launchd` 拉起 `pnpm start`，提供一个 `scripts/install-launchd.sh`

## 12. 模块 H · 能力管理

- 设置页列出 pi 发现的 skill（名字、来源路径、描述）和 extension；可按名字启停（写入 `.pi/settings.json`）
- `AGENTS.md`（工坊根目录）是工坊自己的上下文：我是雨果、各工作区是什么、内容规则在 `docs/content-ops/`、产物约定。pi 会自动读它；设置页提供直接编辑
- 不做 MCP 管理面板：pi 对 MCP 的支持方式待查，v2 不承诺

## 13. UI

左侧固定导航，五个页面；主色延续雨果 IP：奶油纸底、灰蓝单色系、点缀黄只用于"运行中 / 等待审批"。

```
┌────────┬───────────────────────────────────────────────────────────┐
│ ⬡ Hex  │  对话台                                          [模型 ▾] │
│        │  ┌─ 会话 ─────┐ ┌─────────────────────────┐ ┌─ 本次改动 ─┐│
│ 对话   │  │ ● 整理下载  │ │ 你：把 Downloads 里的…   │ │ 12 个文件  ││
│ 任务   │  │   周复盘    │ │ ▸ ls ~/Downloads        │ │ + 归档/    ││
│ 记录   │  │   博客→X   │ │ ▸ bash mkdir 归档/…      │ │ 查看 diff  ││
│ 自动化 │  │            │ │ ┌ 需要确认 ────────────┐ │ │ 回滚       ││
│ 设置   │  │            │ │ │ bash: mv *.dmg 归档/  │ │ │ 提交       ││
│        │  │            │ │ │ [允许] [拒绝] [全部允许]│ │ └───────────┘│
│        │  │            │ │ └──────────────────────┘ │              │
│ 运行中 2│  │ + 新会话   │ │ [输入…        ][插话][排队]│              │
│ 队列 1 │  └────────────┘ └─────────────────────────┘              │
└────────┴───────────────────────────────────────────────────────────┘
```

- **对话**：三栏——会话列表 / 消息流（工具调用折叠、审批内联卡片、thinking 折叠）/ 本次改动（changedFiles + diff + 回滚 + 提交）
- **任务**：左栏分类 + 任务列表，中间表单 + 日志流，右栏产物；即 v1 demo 的布局
- **记录**：表格 + 筛选；点进去是日志回放 + 产物 + diff
- **自动化**：schedule 列表；下次运行时间用相对时间显示
- **设置**：模型与计费、用量面板、审批默认档、并发上限、通知开关、skill / extension 启停、`AGENTS.md` 编辑、记录保留天数
- 导航底部常驻"运行中 n / 队列 m"，点开是当前所有 Run 的迷你列表，可从任何页面停止
- 状态语义：`queued` 灰 / `running` 黄 / `waiting_approval` 黄闪 / `done` 深灰蓝 / `failed` 锈色 / `stopped` 浅灰蓝

## 14. 错误处理

| 情况 | 处理 |
|---|---|
| 没有 provider 登录 | 全局横幅 + 执行禁用 |
| OAuth 过期 | pi 自动刷新；失败原样进日志，Run `failed` |
| agent 中途出错 / 网络断 | 显示重试；最终 `failed`，产物保留，通知 |
| 审批超时 | 5 分钟默认拒绝，Run 继续（agent 会收到拒绝原因）；如果拒绝导致 agent 无法继续则自然结束 |
| 黑名单命令 | `block` + `terminate`，Run `failed`，日志里标红 |
| 工作区不干净 | 开始前提示，不阻止；回滚时只处理本次 `changedFiles` |
| 回滚 / 提交失败（git 报错） | 原样显示 git 输出，不做自动修复 |
| 同工作区已有 Run | 入队列并提示"等 <runId> 结束" |
| 定时任务触发时工坊没在跑 | 无法触发，README 说明 + launchd 脚本 |
| `output` 越界 / 占位符错 | 任务标灰，显示原因 |

## 15. 验证

1. **Vitest**：`tasks.ts`（解析、占位符、越界）、`engine/prompt.ts`、`engine/queue.ts`（并发与同工作区互斥）、`engine/approval.ts`（三档策略对各工具的判定、超时默认拒绝）、`workspaces.ts` 的差集与回滚文件列表计算（用临时 git 仓库）
2. **smoke**：`hello` 走任务页，`tidy-downloads` 走审批流（`writes` 档必然触发确认），一次对话走 steer → 三条链路都通
3. **人工验收**：`blog-to-x` 跑霞鹜文楷那篇，产物能直接发；`weekly-review` 设成一分钟后触发看定时链路
4. 不做 E2E 浏览器测试

## 16. 交付阶段

| 阶段 | 内容 | 完成标志 |
|---|---|---|
| 1 | 对话台（不含存为任务）、任务库、执行引擎（无审批、并发 1）、记录与产物、模型选择与计费提示、`hello` `tidy-downloads` `blog-to-x` `blog-to-xiaohongshu` `xiaohongshu-to-wechat-pic` | 三条 smoke 通 + 第一批社媒内容从工坊产出 |
| 2 | 审批策略、并发队列、工作区（diff / 回滚 / 提交）、用量面板、存为任务、阶段 2 的任务 | `tidy-downloads` 走完审批 → 回滚 → 重跑 → 提交 |
| 3 | 定时、通知、launchd、能力管理、`AGENTS.md` 编辑、`weekly-review` | 周日晚上自动出复盘 |

## 17. 教程拆集

1. 工坊是什么 + pi 登录 + `hello` 跑通
2. 对话台：一句话整理下载文件夹
3. 任务文件：加一个任务不改代码
4. 博客 → X：第一条真实产物
5. Claude / Codex 一键切换 + 计费差异
6. 审批策略：让 agent 改文件前先问我
7. diff、回滚、一键提交
8. 定时：每周日自动出周复盘
9. 小红书：3:4 配图版式 + 小绿书复用

## 18. 明确不做

- 多用户、云端部署、IM 机器人、手机端
- 打包成桌面应用
- 抖音 / 视频类内容（用 Recordly 手工录）
- MCP 管理面板（待查 pi 支持方式）
- 自动 push
