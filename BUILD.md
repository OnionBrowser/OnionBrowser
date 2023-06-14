# Build Onion Browser 3.X
## Build Dependencies

Onion Browser uses [CocoaPods](https://cocoapods.org/) as its dependency manager.


## Steps to build Onion Browser 3.X

```bash
git clone git@github.com:OnionBrowser/OnionBrowser.git
cd OnionBrowser
git checkout 3.X
pod repo update
pod install
open OnionBrowser.xcworkspace
```

## Edit Config.xcconfig

Instead of changing signing/release-related configuration in the main project configuration 
(which mainly edits the `project.pbxproj` file), do it in `Config.xcconfig` instead, which avoids
accidental checkins of sensitive information.

You will at least need to edit the `OB_APP_BUNDLE_ID[config=Debug]` line to be able to run
the app in a simulator. 

Make sure, you didn't accidentally remove the references to that in `project.pbxproj`!

To disable the dependency on Orbot iOS for debugging in the simulator, you can set
`OrbotManager-simulatorIgnoreOrbot` to `true`.
