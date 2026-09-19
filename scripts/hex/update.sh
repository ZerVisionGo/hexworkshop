#!/usr/bin/env bash
# update.sh — 一条命令：同步上游 → 合进 zer/main → 类型检查 → 重新打包 → 装到 /Applications。
#
# 用法：
#   bash scripts/hex/update.sh              # 同步上游 + 打包安装（免确认）
#   bash scripts/hex/update.sh --no-sync    # 不碰 git，只用当前工作区重新打包安装（改了源码后用这个）
#   bash scripts/hex/update.sh --stage      # 透传给 package-mac.sh（上游换了 SDK / bun 版本时）
#
# 遇到合并冲突会停下来并保留冲突状态，让人来解决；不会自动 push。
# 安装时会退出正在运行的 Hex Workshop，并把旧版本备份到 ~/Applications/。
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

SYNC=1; PKG_ARGS=()
for a in "$@"; do
  case "$a" in
    --no-sync) SYNC=0 ;;
    --stage) PKG_ARGS+=("--stage") ;;
    *) echo "未知参数：$a" >&2; exit 2 ;;
  esac
done

if [ "$SYNC" -eq 1 ]; then
  if [ -n "$(git status --porcelain --untracked-files=no)" ]; then
    echo "工作区有未提交的改动，先提交或 stash 再同步：" >&2
    git status --short --untracked-files=no >&2
    exit 1
  fi
  [ "$(git branch --show-current)" = "zer/main" ] || { echo "请在 zer/main 上运行（当前：$(git branch --show-current)）" >&2; exit 1; }

  echo "== 同步上游 =="
  git fetch -q upstream
  git checkout -q main
  git merge -q --ff-only upstream/main
  git checkout -q zer/main
  if ! git merge --no-edit main; then
    echo
    echo "合并上游时有冲突。解决后：git add -A && git commit，再运行 bash scripts/hex/update.sh --no-sync" >&2
    exit 1
  fi
  echo "zer/main 已合并 upstream/main @ $(git rev-parse --short main)"

  if [ -f bun.lock ] && ! git diff --quiet HEAD@{1} HEAD -- bun.lock package.json 2>/dev/null; then
    echo "== 依赖有变化，bun install =="
    bun install
    PKG_ARGS+=("--stage")
  fi

  echo "== 类型检查 =="
  bun run typecheck:all
fi

echo "== 打包并安装 =="
bash scripts/hex/package-mac.sh --install --yes ${PKG_ARGS[@]+"${PKG_ARGS[@]}"}

if [ "$SYNC" -eq 1 ]; then
  echo
  echo "本地分支已更新但未推送。确认 app 正常后：git push origin main zer/main"
fi
