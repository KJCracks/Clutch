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
     Zorro, Tash  - fixes, features, code
 
     dissident - The original creator of Clutch (pre 1.2.6)
     Nighthawk - Code contributor (pre 1.2.6)
     Rastignac - Inspiration and genius
     TheSexyPenguin - Inspiration (not really)
     dildog - Refactoring and code cleanup (Clean up, refactoring, new features)
 

     Translators:
  
     hotsjf - Chinese
     DoubleDoughnut - Serbian
     OdNairy - Russian 
     iD70my - Arabic

     Thanks to: Nighthawk, puy0, rwxr-xr-x, Flox, Flawless, FloydianSlip, Crash-X, MadHouse, Rastignac, aulter, icefire


Usage
------------
Current stable version: *Clutch 1.4.6*

*Clutch* [flags] [application name] [...]

* `-a`                          Crack all applications<br />
* `-u`                          Cracks updated applications<br />
* `-f`                          Flushes cache<br />
* `-v`                          Shows version<br />
* `-c`                          Runs configuration utility<br />
* `-i <IPA> <BINARY <OUTPATH>`  Installs IPA & cracks it<br />
* `-e <InBinary> <OutBinary>`   Cracks specific already-installed executable or one that has been scp'd to the device.
* `--info`                      Gets info about target<br />


You can also set environment variables to change the behaviour of *Clutch*
* `CLUTCH_CONF` Sets path to configuration file<br />
* `CLUTCH_IGNORE_DEV` Ignores the dev updates<br />
* `CLUTCH_COMPRESSION_LEVEL` Sets compression level (1-9)<br />
* `CLUTCH_CRACKER_NAME` Sets cracker name<br />
* `CLUTCH_NATIVE_ZIP` Sets if native zip will be used<br />
* `CLUTCH_METADATA_EMAIL` Sets metadata email<br />

Support
-----------
If you encounter any issues, please visit our IRC at *irc.cracksbykim #Clutch* or open an issue here.

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


