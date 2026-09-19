#!/usr/bin/env bash
# package-mac.sh — 把 fork 打成本机可用的 .app（不公证、不自动更新）。
#
# 用法：
#   bash scripts/hex/package-mac.sh --stage      # 首次 / bun install 后 / 同步上游后：先跑上游 build-dmg.sh 暂存
#                                                #   bun 二进制、Claude SDK 原生二进制、ripgrep（只需一次）
#   bash scripts/hex/package-mac.sh              # 日常：只重新构建 + 打包（快）
#   bash scripts/hex/package-mac.sh --install    # 打包后替换 /Applications 里的 app（会先确认）
#   可组合：--stage --install
#
# 关键点：
#   - app-update.yml 在 scripts/hex/afterPack.cjs 里、签名之前删掉，签名覆盖最终 bundle。
#     （打包后再删会破坏 seal；ad-hoc --deep 重签又会丢 Electron 的 entitlements）
#   - 签名：electron-builder 自动发现钥匙串里的 Apple Development 证书；没有证书时
#     回退为带 entitlements 的 ad-hoc 签名，本机可开、不能分发。
#   - 配置（~/.craft-agent/）不在 app 里，换 app 不影响 workspace / 凭据。
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ARCH="${ARCH:-arm64}"
APP_NAME="Craft Agents"                       # 与 electron-builder.yml 的 productName 一致
ELECTRON_DIR="$ROOT_DIR/apps/electron"
BUILT_APP="$ELECTRON_DIR/release/mac-$ARCH/$APP_NAME.app"
TARGET_APP="/Applications/$APP_NAME.app"
BACKUP_DIR="$HOME/Applications"

DO_STAGE=0; DO_INSTALL=0
for a in "$@"; do
  case "$a" in
    --stage) DO_STAGE=1 ;;
    --install) DO_INSTALL=1 ;;
    *) echo "未知参数：$a" >&2; exit 2 ;;
  esac
done

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

echo "== 打包（自定义 afterPack 去掉 app-update.yml）=="
rm -rf "$ELECTRON_DIR/release/mac-$ARCH"
( cd "$ELECTRON_DIR" && npx electron-builder --mac "--$ARCH" \
    --config electron-builder.yml \
    -c.afterPack="$ROOT_DIR/scripts/hex/afterPack.cjs" )

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

echo
echo "产物：$BUILT_APP"
echo "版本：$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$BUILT_APP/Contents/Info.plist")  commit：$(git rev-parse --short HEAD)"

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
read -r -p "继续？[y/N] " ans
[[ "$ans" == [yY] ]] || { echo "已取消"; exit 0; }

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
fi

cp -R "$BUILT_APP" "$TARGET_APP"
xattr -dr com.apple.quarantine "$TARGET_APP" 2>/dev/null || true
echo "已安装：$TARGET_APP"
echo "打开：open \"$TARGET_APP\""
