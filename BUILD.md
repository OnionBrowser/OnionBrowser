# Build Onion Browser 2.X
## Build Dependencies
Onion Browser uses both CocoaPods *and* Carthage due to its usage in dependencies.

- [CocoaPods](https://cocoapods.org/)
- [Carthage](https://github.com/Carthage/Carthage)

There's also a precompiled [iObfs](https://github.com/mtigas/iObfs) that is required, and included in the build steps below. (At last check, the cross-compiler for obfs4proxy did not play well when packaging iObfs as a Carthage framework. Also note that the Go cross-compiler does not allow us to use bitcode; therefore bitcode is disabled in Onion Browser.)

### Carthage from MacPorts
Although it is not officially documented on their site, you *can* install Carthage through [MacPorts](https://www.macports.org/).

Be aware, though, that this will lead to a bug with a library `libz.[dylib|a]` used during building the carthage dependencies: The MacPorts version of `libz` is not compiled for ARM architecture which ultimately will break the build of our carthage dependencies.

Therefor it is highly recommended to install carthage via the officially documented ways!

## Steps to build Onion Browser 2.X

```bash
git clone git@github.com:OnionBrowser/OnionBrowser.git
cd OnionBrowser
git checkout 2.X
pod repo update
pod install
carthage update
open OnionBrowser2.xcworkspace
```

If the Carthage dependencies don't build, this could eventually help:

```bash
rm -rf Carthage/
brew install automake libtool
```

Of course, you need Homebrew for that. Check out https://brew.sh/ for this.
