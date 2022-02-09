# Build Onion Browser 2.X
## Build Dependencies
Onion Browser uses [CocoaPods](https://cocoapods.org/) as its dependency manager.

There is a dependency, which contains a precompiled framework. If you run into 
trouble, you might want to investigate there:

- [IPtProxy](https://cocoapods.org/pods/IPtProxy)

## Steps to build Onion Browser 2.X

```bash
git clone git@github.com:OnionBrowser/OnionBrowser.git
cd OnionBrowser
git checkout 2.X
pod repo update
pod install
open OnionBrowser2.xcworkspace
```

The latest [Tor.framework](https://github.com/iCepa/Tor.framework/blob/pure_pod/) 
will compile Tor, OpenSSL, libevent and liblzma during the build process of the 
depending app. So please also have a look at the 
[build instructions over there](https://github.com/iCepa/Tor.framework/blob/pure_pod/README.md#Installation),
for any required tooling which needs to be in place.  


## Edit Config.xcconfig

Instead of changing signing/release-related configuration in the main project configuration 
(which mainly edits the `project.pbxproj` file), do it in `Config.xcconfig` instead, which avoids
accidental checkins of sensitive information.

You will at least need to edit the `OB_APP_BUNDLE_ID[config=Debug]` line to be able to run
the app in a simulator. 

Make sure, you didn't accidentally remove the references to that in `project.pbxproj`!
