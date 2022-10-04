mpchain APIのcreate_sendを叩く【Electron】

　[前回][]とおなじことをElectronでやってみた。

<!-- more -->

# ブツ

* [リポジトリ][]

![eye-catch.png][リポジトリ]

[リポジトリ]:https://github.com/ytyaru/Electron.mpchain.CreateSned.20221004113052
[eye-catch.png]:eye-catch.png

# 実行

```sh
NAME='Electron.mpchain.CreateSned.20221004113052'
git clone https://github.com/ytyaru/$NAME
cd $NAME
./run.sh
```

環境|version
----|-------
Node.js|18.10.0
Electron|21.0.1

# コード抜粋

　基本的には[前回][]と同じ。ただ、Electron固有のIPC通信では関数を渡したり受け取ったりできない。`json()`関数などを含む`res`を返すことができない。そのせいで受け取る側も以下のように変更せねばならなかった。

## mpchain.js

```javascript
class Mpchain {
    ...
    static async #request(data, isPost=true) {
        ...
        //const res = await fetch(URL, options)
        //return await res.json()
        return await window.ipc.fetch(URL, options)
    }
}
```

　厄介なのはここから。以降はElectron固有の実装になる。

## main.js

　やることは２つだけ。窓を作る。IPC通信で実行するメソッドを実装する。

　ファイル分割したかったが、どうやればいいかわからなかった。結局これまで通りすべて1ファイルに書いた。

```javascript
const { app, BrowserWindow, session, ipcMain, dialog, net } = require('electron')
const path = require('path')
const fetch = require('electron-fetch').default; // Node.js v18 ならGlobalにfetchがあるらしいが使えなかったので継続利用する

function createWindow () {
    const mainWindow = new BrowserWindow({
        width: 800,
        height: 600,
        webPreferences: {
            nodeIntegration: false, // https://www.electronjs.org/ja/docs/latest/breaking-changes
            enableRemoteModule: true,
            contextIsolation: true,
            preload: path.join(__dirname, 'preload.js')
        }
    })
    mainWindow.loadFile('src/index.html')
    //mainWindow.setMenuBarVisibility(false);
    mainWindow.webContents.openDevTools()
}
app.whenReady().then(async()=>{
    createWindow()
    app.on('activate', async()=>{
        if (BrowserWindow.getAllWindows().length === 0) { createWindow() }
    })
})
app.on('window-all-closed', async()=>{
    if (process.platform !== 'darwin') { app.quit() }
})

// fetch の Response は関数を含んでいるためIPCでは返せない。そこで関数実行結果を返す
async function returnMimeTypeData(url, options, res) {
    // res.text(), blob(), arrayBuffer(), formData(), redirect(), clone(), error()
    if (!options) { return await res.text() }
    else if ('application/json' === options.headers['Content-Type']) { return await res.json() }
    else if (options.headers['Content-Type'].match(/text\//)) { return await res.text() }
    else if (options.headers['Content-Type'].match(/(image|audio|video|)\//)) { return await res.blob() }
    else { return await res.text() }
}
ipcMain.handle('fetch', async(event, url, options)=>{
    console.log(url, options)
    const res = await fetch(url, options).catch(e=>console.error(e));
    return await returnMimeTypeData(url, options, res)
})
```

　Node.js v18 からはfetch APIがグローバルAPIとして使えるらしい。でも、Electronでそれを使う方法がわからなかった。ふつうに`fetch`を呼び出そうとしても未定義エラーになってしまう。`nodeIntegration`を`true`にしても変わらなかった。仕方なくelectron-fetchパッケージを継続利用することにした。

　Electronも v21 になったが特に変わりなく。この面倒くさいIPC通信の構造もおなじ。IPC通信のシリアライズ問題があるせいで`fetch`の戻り値に`json()`など関数を含めることができない。よって結果を返すときに面倒なルーティングが必要になってしまう。今回は`application/json`な場合しか使わないので楽だったが、ほかが動作するのかは未確認。

## preload.js

```javascript
const {remote,contextBridge,ipcRenderer} =  require('electron');
contextBridge.exposeInMainWorld('ipc', {
    fetch:async(url, options)=>await ipcRenderer.invoke('fetch', url, options),
})
```

## rendere.js

　これは[前回][]の丸パクリ。

```javascript
window.addEventListener('DOMContentLoaded', async(event) => {
    const throttle = new Throttle()
    const ids = ['from', 'to', 'quantity', 'fee-per-kb']
    for (const id of ids) { 
        document.getElementById(id).addEventListener('input', async(event) => {
            createSend({ id: event.target.id, value: event.target.value })
        })
    }
    function createSend(d=null) {
        const values = ids.map(id=>document.getElementById(id).value)
        if (d) { values[ids.find(id=>id === d.id)] = d.value }
        throttle.run(async()=>{
            document.querySelector(`#result`).value = JSON.stringify(
                await Mpchain.createSend(...values))
        })
    }
    createSend()
})
```

## index.html

　これも[前回][]のほぼ丸パクリ。Electronのセキュリティ設定`<meta http-equiv`や`renderer.js`呼出を追加したくらいか。

```html
<!-- HTML内JS呼出禁止など。不都合ならコメントアウトすること。 -->
<meta http-equiv="Content-Security-Policy" content="default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'">

<input id="from" value="MEHCqJbgiNERCH3bRAtNSSD9uxPViEX1nu">
<input id="to" value="MEHCqJbgiNERCH3bRAtNSSD9uxPViEX1nu">
<input id="quantity" type="number" min="0" value="11411400">
<input id="fee-per-kb" type="number" min="0" max="200" value="10">

<script src="js/electron/renderer.js"></script>
```

