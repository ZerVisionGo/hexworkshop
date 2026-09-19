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
