# Git 与 GitHub 上传准备

## 更新发布包

推送源码不会自动更新 Release 的 ZIP。每次发布新版本都需要重新构建完整包、上传附件并发布对应版本。

当前发布目标为 **v0.7.0**，包含两首背景音乐、v0.6茶市剧情和v0.7验茶／复焙演出。游戏版本号统一读取 `prototype/project.godot` 的 `config/version`。发布说明位于 `docs/releases/v0.7.0.md`。

在已准备便携引擎且工作区提交干净后执行：

```powershell
python tools/build_release.py
```

该脚本从当前Git提交构建干净副本，加入便携引擎，检查两首音乐并导入资源；打包后重新解压，对成品包运行音乐循环、角色交易、工序演出和GPU启动检查。成功产物位于 `output/releases/v<版本号>/`，包括Windows完整ZIP、SHA256校验、构建记录和发布说明。脚本不会自动上传或覆盖已有ZIP。

上传ZIP与校验文件至同版本Release草稿，确认附件摘要后发布，并将当前推荐下载版本设为Latest。GitHub的预发布版本不能设为Latest；使用普通Release发布单机试玩包时，标题和说明仍明确标注「试玩版」。旧版保留为历史记录。

## 上传结果

2026-09-16，v0.5首次提交 `7f97418` 已推送至目标仓库 `main` 分支，已建立本地 `main` 到 `origin/main` 的跟踪关系。首次提交包含113个文件，原始内容约50 MB。

已用暂存内容导出一份不含Godot缓存的干净副本，完成16张美术的重新导入，并通过51项角色与完整交易流程检查。Git格式检查通过；已检查的常见令牌和私钥格式未发现匹配，最大的单文件约3 MB。

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

上述命令验证网络与公共读取；随后对目标仓库的实际推送也已成功，确认本次上传所需写入权限可用。

## 首次提交和上传

目标仓库：[MyLittleShrimp/13-Hongs-Manager-by-LittleShrimp](https://github.com/MyLittleShrimp/13-Hongs-Manager-by-LittleShrimp)。提交作者已在本仓库配置为用户提供的信息。首次检查时目标为空仓库；推送后已有 `main` 分支。

首次提交和推送使用以下命令（已完成，无需重复添加origin）：

```powershell
git commit -m "feat: add playable Thirteen Hongs tea trading game v0.5"
git remote add origin https://github.com/MyLittleShrimp/13-Hongs-Manager-by-LittleShrimp.git
git push -u origin main
```

之后继续更新：

```powershell
git status
git add --all
git diff --cached --check
git commit -m "说明这次具体改动"
git push
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
