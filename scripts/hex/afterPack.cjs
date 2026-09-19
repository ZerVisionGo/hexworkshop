// hex afterPack：先跑上游的 afterPack（Liquid Glass 图标等），再删掉 app-update.yml。
//
// 为什么在这里删：electron-builder 在 afterPack 阶段（PublishManager 的系统监听器）
// 写入 app-update.yml，用户 hook 总是最后执行，且都发生在签名之前——所以在这里删
// 文件，签名会覆盖最终的 bundle；打包后再删会破坏 code signature 的 seal。
//
// 为什么要删：electron-builder.yml 的 publish 指向官方更新源，不删的话自建的 app
// 会在上游发新版时被 electron-updater 换回官方版本。
//
// 通过 `electron-builder -c.afterPack=scripts/hex/afterPack.cjs` 传入（见 package-mac.sh），
// 不改上游的 electron-builder.yml。
const path = require('node:path')
const fs = require('node:fs')

const upstreamAfterPack = require(path.join(__dirname, '..', '..', 'apps', 'electron', 'scripts', 'afterPack.cjs'))

module.exports = async function afterPack(context) {
  await upstreamAfterPack(context)

  const appName = context.packager.appInfo.productFilename
  const updateYml = path.join(context.appOutDir, `${appName}.app`, 'Contents', 'Resources', 'app-update.yml')
  if (fs.existsSync(updateYml)) {
    fs.rmSync(updateYml)
    console.log(`hex afterPack: removed ${updateYml}`)
  } else {
    console.log('hex afterPack: app-update.yml not present (nothing to remove)')
  }
}
