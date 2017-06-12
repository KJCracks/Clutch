（下面有中文版）

Before filing an issue, please ensure you are using the master branch at the latest version and [building correctly](../README.md#building).

Please search issues to make sure your issue has not been reported before.

We only support iOS 8 and later. We only support publicly known jailbreak methods. Please use the latest version of your jailbreak before filing an issue.

If you are receiving an immediate crash with the message *Killed: 9*, ensure the build is being signed correctly. Try these steps before filing an issue:

* Rename the binary to something else like `clutch2`
* Re-sign the binary on the device by copying `Clutch.entitlements` onto the device and using LDID: `ldid -SClutch.entitlements`

If you are seeing the message *Error: Could not obtain mach port, either the process is dead (codesign error?) or entitlements were not properly signed!*, try re-signing or [building](../README.md#building) again.

If a framework will not dump and you are not seeing the *Error: Could not obtain mach port, either the process is dead (codesign error?) or entitlements were not properly signed!* message, please file an issue.

# General information

Please delete the example text and fill this in:

* iOS version: e.g 10.2, 9.3.3
* Commit hash: <use `git log` to see this>
* App bundle ID: `example.app.name`
* App name: *Example app name*
* Command used: example: `clutch -d ...`

# Log

Please post the complete log from the terminal here surrounded with backticks as [described here](https://help.github.com/articles/creating-and-highlighting-code-blocks/).

-------

提交 issue 之前，请确认您在使用的是 master 分支的最新版并且[编译过程正确](../README.md#building)。.

请先搜索 issue 列表以确认之前您的问题并没有被报告过。

我们只支持 iOS 8 及以后版本，以及公开的越狱方法。提交问题之前请确认你使用的越狱软件是最新版。

如果程序显示出 *Killed: 9* 然后瞬间崩溃，请确认可执行文件有被正确地签名。试试以下步骤：

* 把可执行文件改个名字，比如改成 `clutch2`
* 把 `Clutch.entitlements` 复制到设备上，然后运行 `ldid -SClutch.entitlements` 

如果你看到这条提示信息 *Error: Could not obtain mach port, either the process is dead (codesign error?) or entitlements were not properly signed!* ，试试重新签名或者重新[编译](../README.md#building)。

如果有 framework 无法 dump 出来，也没有显示出 *Error: Could not obtain mach port, either the process is dead (codesign error?) or entitlements were not properly signed!* 的错误信息，请提交 issue 。

# 一般信息

请删掉示例文字并填写相关信息。

* iOS 版本：例如 10.2, 9.3.3
* Commit hash：<可使用 `git log` 看到>
* App bundle ID：`example.app.name`
* App 名称：*Example app name*
* 使用的命令：例如 `clutch -d ...`

# Log

请在此贴出来自终端的完整 log ，并且用反引号括住，就像[这里](https://help.github.com/articles/creating-and-highlighting-code-blocks/)所描述的一样。
