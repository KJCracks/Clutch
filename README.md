        ___ _       _       _
       / __\ |_   _| |_ ___| |__
      / /  | | | | | __/ __| '_ \
     / /___| | |_| | || (__| | | |
     \____/|_|\__,_|\__\___|_| |_|
 
     --------------------------------
     High-Speed iOS Decryption System
     --------------------------------
 
     Authors:
 
     ttwj - post 1.2.6
     NinjaLikesCheez - post 1.2.6
     Zorro - fixes, features, code (1.4)
 
     dissident - The original creator of Clutch (pre 1.2.6)
     Nighthawk - Code contributor (pre 1.2.6)
     Rastignac - Inspiration and genius
     TheSexyPenguin - Inspiration (not really)
     dildog - Refactoring and code cleanup (2.0)
 
     Thanks to: Nighthawk, puy0, rwxr-xr-x, Flox, Flawless, FloydianSlip, Crash-X, MadHouse, Rastignac, aulter, icefire


Usage
------------
Current development version: *Clutch 1.4-git8*

*Clutch* [flags] [application name] [...]

* `-a`                          Crack all applications<br />
* `-u`                          Cracks updated applications<br />
* `-f`                          Flushes cache<br />
* `-v`                          Shows version<br />
* `-c`                          Runs configuration utility<br />
* `-i <IPA> <BINARY <OUTPATH>`  Installs IPA & cracks it<br />
* `-e <InBinary> <OutBinary>`   Cracks specific already-installed executable or one that has been scp'd to the device.
* `--yopa`                      Creates a YOPA package<br />
* `--info`                      Gets info about target<br />


You can also set environment variables to change the behaviour of *Clutch*
* `CLUTCH_CONF` Sets path to configuration file<br />
* `CLUTCH_IGNORE_DEV` Ignores the dev updates<br />

Compiling
------------
Ensure that entitlements are properly signed

`codesign -f -s <Signing Identity> --entitlements Clutch.entitlements Clutch`

Licenses
------------
*Clutch* uses the following libraries under their respective licenses.

[ZipArchive](https://github.com/mattconnolly/ZipArchive/) by Matt Connolly, Edward Patel, et al.<br />
[MiniZip](http://www.winimage.com/zLibDll/minizip.html) by Gilles Vollant adn Mathias Svensson.

Clutch is released under the GNU Affero General Public License (http://www.gnu.org/licenses/agpl-3.0.html)

TODO
-------------
* Implement libarchive (built and included)
* Fix a tonne of stuff



(c) Kim Jong-Cracks 1819-2014


