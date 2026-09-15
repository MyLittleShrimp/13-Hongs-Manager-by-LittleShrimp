# Git 与 GitHub 上传准备

## 已整理的版本内容

- 分支：`main`。
- 纳入：Godot工程与脚本、16张游戏美术、导入配置、测试、文档、素材提示词、启动器和可重复下载工具。
- 文档插图集中在 `docs/images/`，在 GitHub 上可以直接查看。
- 排除：Godot/FFmpeg可执行程序、安装包、Godot缓存、本地运行数据、全部测试产物、旧版目录快照、宣传视频及录制母版。
- `.gitattributes` 统一文本换行；Windows启动脚本在检出时使用CRLF。
- 宣传视频仍保留在本地 `output/宣传片/`，后续可以单独作为发布附件上传。

## 连接测试（2026-09-16）

公共GitHub仓库的HTTPS读取已通过：

```powershell
git -c http.sslBackend=openssl -c credential.interactive=never ls-remote https://github.com/godotengine/godot.git HEAD
```

默认Windows Schannel在当前环境报 `SEC_E_NO_CREDENTIALS`；使用Git自带OpenSSL成功，未关闭证书校验。当前项目采用仓库级OpenSSL配置，不影响其他项目。

这个结果只验证网络与公共读取能力。目标仓库、账号登录和写入权限还需确认，不能据此声称已上传成功。

## 首次提交和上传

目标仓库：[MyLittleShrimp/13-Hongs-Manager-by-LittleShrimp](https://github.com/MyLittleShrimp/13-Hongs-Manager-by-LittleShrimp)。提交作者已在本仓库配置为用户提供的信息。目标仓库首次读取成功，当前没有远程分支。

首次提交和推送使用：

```powershell
git commit -m "feat: add playable Thirteen Hongs tea trading game v0.5"
git remote add origin https://github.com/MyLittleShrimp/13-Hongs-Manager-by-LittleShrimp.git
git push -u origin main
```

如果目标仓库已经有提交，应先获取并检查远程历史，再决定如何合并，避免覆盖现有内容。登录时使用GitHub的浏览器授权或本机凭据管理器，不把令牌写入代码或远程URL。

## 克隆后运行

仓库不包含Godot程序。Windows上安装Python后，在仓库根目录执行：

```powershell
python tools/bootstrap_godot.py
python tools/run_godot.py --headless --editor --import
```

随后双击「启动游戏.cmd」。也可以用自己安装的Godot 4.7.2打开 `prototype/project.godot`，完成资源导入后运行。

项目代码和美术的开源许可证尚未指定；`LICENSES/` 记录的是Godot自身的第三方许可，不能当作本游戏全部内容的许可。
