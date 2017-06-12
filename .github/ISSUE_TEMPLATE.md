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
