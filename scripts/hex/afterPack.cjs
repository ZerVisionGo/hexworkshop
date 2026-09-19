// hex afterPack：在签名之前整理 bundle。
//
// 1. 删掉 app-update.yml
//    electron-builder 在 afterPack 阶段（PublishManager 的系统监听器）写入它，用户 hook 总是
//    最后执行，且都发生在签名之前——所以在这里删，签名会覆盖最终的 bundle；打包后再删会破坏
//    code signature 的 seal。不删的话自建的 app 会在上游发新版时被 electron-updater 换回官方版本。
//
// 2. 图标
//    - 未改名（productName 仍是 Craft Agents）：调上游 afterPack，拷 Liquid Glass 的 Assets.car。
//    - 改名（Hex Workshop）：不拷 Craft 的 Assets.car，并从 Info.plist 删掉 CFBundleIconName，
//      让 macOS 回退到 electron-builder 写入的 icon.icns（我们自己的图标）。
//
// 通过 `electron-builder -c.afterPack=scripts/hex/afterPack.cjs` 传入（见 package-mac.sh），
// 不改上游的 electron-builder.yml。
const path = require('node:path')
const fs = require('node:fs')
const { execFileSync } = require('node:child_process')

const UPSTREAM_PRODUCT_NAME = 'Craft Agents'
const upstreamAfterPack = require(path.join(__dirname, '..', '..', 'apps', 'electron', 'scripts', 'afterPack.cjs'))

module.exports = async function afterPack(context) {
  const productName = context.packager.appInfo.productFilename
  const appBundle = path.join(context.appOutDir, `${productName}.app`)
  const resources = path.join(appBundle, 'Contents', 'Resources')

  if (productName === UPSTREAM_PRODUCT_NAME) {
    await upstreamAfterPack(context)
  } else if (context.electronPlatformName === 'darwin') {
    const plist = path.join(appBundle, 'Contents', 'Info.plist')
    try {
      execFileSync('/usr/libexec/PlistBuddy', ['-c', 'Delete :CFBundleIconName', plist], { stdio: 'ignore' })
      console.log('hex afterPack: removed CFBundleIconName (using icon.icns)')
    } catch {
      console.log('hex afterPack: CFBundleIconName not present')
    }
    // 主进程启动时会 app.dock.setIcon(dist/resources/icon.png)（apps/electron/src/main/index.ts），
    // Finder 用 icon.icns、Dock 却用这张 PNG——所以把 bundle 里的 PNG 也换成我们的。
    const dockPng = path.join(resources, 'app', 'dist', 'resources', 'icon.png')
    const ourPng = path.join(__dirname, '..', '..', 'resources', 'hex', 'icon-1024.png')
    if (fs.existsSync(dockPng) && fs.existsSync(ourPng)) {
      fs.copyFileSync(ourPng, dockPng)
      console.log('hex afterPack: replaced dist/resources/icon.png (Dock icon)')
    } else {
      console.log(`hex afterPack: dock icon not replaced (dockPng=${fs.existsSync(dockPng)} ourPng=${fs.existsSync(ourPng)})`)
    }
  }

  const updateYml = path.join(resources, 'app-update.yml')
  if (fs.existsSync(updateYml)) {
    fs.rmSync(updateYml)
    console.log(`hex afterPack: removed ${updateYml}`)
  } else {
    console.log('hex afterPack: app-update.yml not present (nothing to remove)')
  }
}
