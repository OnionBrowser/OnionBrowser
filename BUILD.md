# Build OnionBrowser 2.X
## Build Dependencies
OnionBrowser uses both CocoaPods *and* Carthage due to its usage in dependencies.

- [CocoaPods](https://cocoapods.org/)
- [Carthage](https://github.com/Carthage/Carthage)

### Carthage from MacPorts 
Although it is not officially documented on their site, you *can* install Carthage through [MacPorts](https://www.macports.org/).

Be aware, though, that this will lead to a bug with a library `libz.[dylib|a]` used during building the carthage dependencies: The MacPorts version of `libz` is not compiled for ARM architecture which ultimately will break the build of our carthage dependencies.

Therefor it is highly recommended to install carthage via the officially documented ways!

## Steps to build OnionBrowser 2.X
```bash
$ git clone git@github.com:mtigas/OnionBrowser.git
$ cd OnionBrowser
$ git checkout 2.X
$ pod repo update
$ pod install
$ carthage update --platform iOS --use-submodules
$ open OnionBrowser2.xcworkspace
```
