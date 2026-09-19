#!/usr/bin/env bash
# package-mac.sh — 把 fork 打成本机可用的「Hex Workshop.app」（不公证、不自动更新）。
#
# 用法：
#   bash scripts/hex/package-mac.sh --stage      # 首次 / bun install 后 / 同步上游后：先跑上游 build-dmg.sh
#                                                #   暂存 bun 二进制、Claude SDK 原生二进制、ripgrep（只需一次）
#   bash scripts/hex/package-mac.sh              # 日常：只重新构建 + 打包（快）
#   bash scripts/hex/package-mac.sh --install    # 打包后安装到 /Applications（会先确认；加 --yes 免确认）
#   bash scripts/hex/package-mac.sh --vanilla    # 不改名，打成与官方同名的 Craft Agents.app（不能与官方共存）
#   可组合：--stage --install
#
# 默认是「改名版」，与官方 app 完全隔离、可同时运行：
#   productName / appId    Hex Workshop / com.zervisiongo.hexworkshop
#                          → 独立的 ~/Library/Application Support/Hex Workshop（Chromium profile、内置浏览器 cookie、单实例锁）
#   CRAFT_CONFIG_DIR       $HOME/.hexworkshop（通过 Info.plist 的 LSEnvironment 烤入，Finder 启动也生效）
#                          → 独立的 workspaces / sessions / credentials / logs（依赖 fix/config-dir 补丁）
#   CRAFT_DEEPLINK_SCHEME  hexworkshop://
#   图标                   resources/hex/icon.icns（HEX 像素字样，由 scripts/hex/make-icon.swift 生成）
#   首次使用需把官方的 workspace 拷过来：cp -R ~/.craft-agent/workspaces/<slug> ~/.hexworkshop/workspaces/
#
# 关键点：
#   - app-update.yml 在 scripts/hex/afterPack.cjs 里、签名之前删掉，签名覆盖最终 bundle。
#   - 签名：electron-builder 自动发现钥匙串里的 Apple Development 证书；没有证书时
#     回退为带 entitlements 的 ad-hoc 签名，本机可开、不能分发。
#   - 上游文件一个不改：所有覆盖都走 electron-builder 的 -c.xxx 命令行参数。
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ARCH="${ARCH:-arm64}"
ELECTRON_DIR="$ROOT_DIR/apps/electron"
BACKUP_DIR="$HOME/Applications"

DO_STAGE=0; DO_INSTALL=0; VANILLA=0; ASSUME_YES=0
for a in "$@"; do
  case "$a" in
    --stage) DO_STAGE=1 ;;
    --install) DO_INSTALL=1 ;;
    --vanilla) VANILLA=1 ;;
    --yes|-y) ASSUME_YES=1 ;;
    *) echo "未知参数：$a" >&2; exit 2 ;;
  esac
done

if [ "$VANILLA" -eq 1 ]; then
  APP_NAME="Craft Agents"
  BRAND_ARGS=()
else
  APP_NAME="Hex Workshop"
  HEX_CONFIG_DIR="$HOME/.hexworkshop"
  BRAND_ARGS=(
    "-c.productName=$APP_NAME"
    "-c.appId=com.zervisiongo.hexworkshop"
    "-c.mac.icon=$ROOT_DIR/resources/hex/icon.icns"
    "-c.mac.extendInfo.LSEnvironment.CRAFT_CONFIG_DIR=$HEX_CONFIG_DIR"
    "-c.mac.extendInfo.LSEnvironment.CRAFT_APP_NAME=$APP_NAME"
    "-c.mac.extendInfo.LSEnvironment.CRAFT_DEEPLINK_SCHEME=hexworkshop"
  )
fi
BUILT_APP="$ELECTRON_DIR/release/mac-$ARCH/$APP_NAME.app"
TARGET_APP="/Applications/$APP_NAME.app"

cd "$ROOT_DIR"

if [ "$DO_STAGE" -eq 1 ]; then
  echo "== 暂存（上游 build-dmg.sh ${ARCH}）=="
  bash "$ELECTRON_DIR/scripts/build-dmg.sh" "$ARCH"
fi

# 暂存产物自检：没有就提示加 --stage
for need in \
  "$ELECTRON_DIR/node_modules/@anthropic-ai/claude-agent-sdk-binary" \
  "$ELECTRON_DIR/vendor/bun/bun"; do
  [ -e "$need" ] || { echo "缺少暂存产物 $need，请加 --stage 重跑" >&2; exit 1; }
done

echo "== 构建 =="
bun run electron:build

echo "== 打包：${APP_NAME}（自定义 afterPack 去掉 app-update.yml）=="
rm -rf "$ELECTRON_DIR/release/mac-$ARCH"
# -c.mac.target=dir：只产出 .app 目录，不做 dmg / zip（省一半时间，也不会生成 app-update.yml）
( cd "$ELECTRON_DIR" && npx electron-builder --mac "--$ARCH" \
    --config electron-builder.yml \
    -c.mac.target=dir \
    -c.afterPack="$ROOT_DIR/scripts/hex/afterPack.cjs" \
    ${BRAND_ARGS[@]+"${BRAND_ARGS[@]}"} )

[ -d "$BUILT_APP" ] || { echo "未找到构建产物：$BUILT_APP" >&2; exit 1; }
[ ! -e "$BUILT_APP/Contents/Resources/app-update.yml" ] || { echo "app-update.yml 仍然存在，afterPack 未生效" >&2; exit 1; }

echo "== 签名校验 =="
if ! codesign --verify --deep --strict "$BUILT_APP" 2>/dev/null; then
  echo "electron-builder 未签名或签名无效，改用带 entitlements 的 ad-hoc 签名"
  codesign --force --deep --options runtime \
    --entitlements "$ELECTRON_DIR/build/entitlements.mac.plist" -s - "$BUILT_APP"
  codesign --verify --deep --strict "$BUILT_APP"
fi
codesign -dv "$BUILT_APP" 2>&1 | grep -E "^(Authority|Signature)" | head -2 || true

PLIST="$BUILT_APP/Contents/Info.plist"
echo
echo "产物：$BUILT_APP"
echo "版本：$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PLIST")  commit：$(git rev-parse --short HEAD)"
echo "bundle id：$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$PLIST")"
if [ "$VANILLA" -eq 0 ]; then
  echo "配置目录：$(/usr/libexec/PlistBuddy -c 'Print :LSEnvironment:CRAFT_CONFIG_DIR' "$PLIST" 2>/dev/null || echo '未写入 LSEnvironment！')"
fi

if [ "$DO_INSTALL" -ne 1 ]; then
  echo
  echo "只构建未安装。要装到 /Applications：bash scripts/hex/package-mac.sh --install"
  exit 0
fi

echo
if [ -d "$TARGET_APP" ]; then
  echo "将替换 ${TARGET_APP}（旧版本备份到 ${BACKUP_DIR}/）"
else
  echo "将安装到 $TARGET_APP"
fi
if [ "$ASSUME_YES" -eq 1 ]; then
  echo "（--yes）继续"
else
  read -r -p "继续？[y/N] " ans
  [[ "$ans" == [yY] ]] || { echo "已取消"; exit 0; }
fi

if pgrep -f "$TARGET_APP/Contents/MacOS/" >/dev/null; then
  echo "退出正在运行的 ${APP_NAME}…"
  osascript -e "tell application \"$APP_NAME\" to quit" || true
  for _ in $(seq 1 20); do pgrep -f "$TARGET_APP/Contents/MacOS/" >/dev/null || break; sleep 0.5; done
fi

if [ -d "$TARGET_APP" ]; then
  mkdir -p "$BACKUP_DIR"
  BACKUP="$BACKUP_DIR/$APP_NAME (backup $(date +%Y%m%d-%H%M)).app"
  mv "$TARGET_APP" "$BACKUP"
  echo "旧版本已移至：$BACKUP"
  # 只保留最近 2 个备份
  ls -1dt "$BACKUP_DIR/$APP_NAME (backup "*.app 2>/dev/null | tail -n +3 | while IFS= read -r old; do rm -rf "$old"; echo "清理旧备份：$old"; done
fi

cp -R "$BUILT_APP" "$TARGET_APP"
xattr -dr com.apple.quarantine "$TARGET_APP" 2>/dev/null || true
echo "已安装：$TARGET_APP"
echo "打开：open \"$TARGET_APP\""
