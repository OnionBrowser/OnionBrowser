## Onion Browser

[![Build Status](https://travis-ci.org/OnionBrowser/iOS-OnionBrowser.png)](https://travis-ci.org/OnionBrowser/iOS-OnionBrowser)  
[Official Site][official] | [Support][help] | [Changelog][changelog]  
&copy; 2012-2014 [Mike Tigas][miketigas] ([@mtigas](https://twitter.com/mtigas))  
[MIT License][license]

A minimal, open-source web browser for iOS that tunnels web traffic through
the [Tor network][tor]. See the [official site][official] for more details
and App Store links.

---

* **OnionBrowser**: 1.5.9 (20141109.1) — [See changelog][changelog]
* **[Tor][tor]**: 0.2.5.10 (Oct 24 2014)
* **[libevent][libevent]**: 2.0.21-stable (Nov 18 2012)
* **[OpenSSL][openssl]**: 1.0.1j (Oct 15 2014)

[official]: https://mike.tig.as/onionbrowser/
[help]: https://mike.tig.as/onionbrowser/help/
[changelog]: https://raw.github.com/OnionBrowser/iOS-OnionBrowser/master/CHANGES.txt
[miketigas]: https://mike.tig.as/
[license]: https://github.com/OnionBrowser/iOS-OnionBrowser/blob/master/LICENSE
[tor]: https://www.torproject.org/
[libevent]: http://libevent.org/
[openssl]: https://www.openssl.org/

<a href="https://d2p12wh0p3fo1n.cloudfront.net/files/20120918/a.png"><img src="https://d2p12wh0p3fo1n.cloudfront.net/files/20120918/a-100.jpg" width="100"/></a>
<a href="https://d2p12wh0p3fo1n.cloudfront.net/files/20120918/b.png"><img src="https://d2p12wh0p3fo1n.cloudfront.net/files/20120918/b-100.jpg" width="100"/></a>
<a href="https://d2p12wh0p3fo1n.cloudfront.net/files/20120918/c.png"><img src="https://d2p12wh0p3fo1n.cloudfront.net/files/20120918/c-100.jpg" width="100"/></a>
<a href="https://d2p12wh0p3fo1n.cloudfront.net/files/20120918/d.png"><img src="https://d2p12wh0p3fo1n.cloudfront.net/files/20120918/d-100.jpg" width="100"/></a>
<a href="https://d2p12wh0p3fo1n.cloudfront.net/files/20120918/e.png"><img src="https://d2p12wh0p3fo1n.cloudfront.net/files/20120918/e-100.jpg" width="100"/></a>
<a href="https://d2p12wh0p3fo1n.cloudfront.net/files/20120918/f.png"><img src="https://d2p12wh0p3fo1n.cloudfront.net/files/20120918/f-150.jpg" width="150"/></a>

<i>Screenshots: iPhone 4/4S, iPhone 5, iPad 3</i>

---

#### Integration notes

Onion Browser responds to two URL schemes: `onionbrowser://` and
`onionbrowsers://`, representing HTTP and HTTPS URLs, respectively. These
work like the URI schemes [in iOS Google Chrome][crios] and other popular
third-party web browsers.

* A URL of `onionbrowser://opennews.org/` will launch Onion Browser and
  navigate the app to `http://opennews.org/`.
* A URL of `onionbrowsers://mike.tig.as/` will launch Onion Browser and
  navigate the app to `https://mike.tig.as/`.

Allowing your own app to launch Onion Browser instead of Safari works similarly
to [iOS Google Chrome][crios]:

1. Check if Onion Browser is installed by seeing if iOS can open a
   `onionbrowser://` URL.
2. If so, replace the `http://` prefix with `onionbrowser://` and replace
   the `https://` prefix with `onionbrowsers://`.
3. Then tell iOS to open the newly defined URL (`newURL`) by executing
   `[[UIApplication sharedApplication] openURL:newURL];`

See [the Google Chrome iOS instructions][crios] for more details -- just note
that you should replace their `googlechrome://` URL schemes with the proper
`onionbrowser://` ones.

[x-callback-url]: http://x-callback-url.com/
[crios]: https://developers.google.com/chrome/mobile/docs/ios-links#uri_schemes

---

#### Compilation notes

The app, when compiled, contains static library versions of [Tor][tor] and it's
dependencies, [libevent][libevent] and [openssl][openssl].

The build scripts for Tor and other dependencies are based on
[build-libssl.sh][build_libssl] from [x2on/OpenSSL-for-iPhone][openssliphone].
The scripts are configured to compile universal binaries for armv7 and
i386 (for the iOS Simulator).

[build_libssl]: https://github.com/x2on/OpenSSL-for-iPhone/blob/c637f773a99810bb101169f8e534d0d6b09f3396/build-libssl.sh
[openssliphone]: https://github.com/x2on/OpenSSL-for-iPhone

The tor `build-tor.sh` script patches one file in Tor (`src/common/compat.c`)
to remove references to `ptrace()` and `_NSGetEnviron()`. This first is only used
for the `DisableDebuggerAttachment` feature (default: True) implemented in Tor
0.2.3.9-alpha. (See [changelog][tor_changelog] and [manual][tor_manual].)
`ptrace()` and `_NSGetEnviron()` calls are not allowed in App Store apps; apps
submitted with `ptrace()` symbols are rejected on upload by Apple's
auto-validation of the uploaded binary. (The `_NSGetEnviron()` code does not
even compile when using iPhoneSDK due to that function being undefined.)
See the patch files in `build-patches/` if you are interested in the changes.

[tor_changelog]: https://gitweb.torproject.org/tor.git/blob/tor-0.2.4.18-rc:/ChangeLog
[tor_manual]: https://www.torproject.org/docs/tor-manual-dev.html.en

Tor 0.2.3.17-beta introduced compiler and linker "hardening" ([Tor ticket 5210][ticket5210]),
which is incompatible with the iOS Device build chain.  The app (when building
for iOS devices) is configured with `--disable-gcc-hardening --disable-linker-hardening`
to get around this issue. (Due to the isolation of executable code on iOS devices,
this should not cause a significant change in security.)

[ticket5210]: https://trac.torproject.org/projects/tor/ticket/5210

Because iOS applications cannot launch subprocesses or otherwise execute other
binaries, the tor client is run in-process in a `NSThread` subclass which
executes the `tor_main()` function (as an external `tor` executable would)
and attempts to safely wrap Tor within the app. (`libor.a` and
`libtor.a`, intermediate binaries created when compiling Tor, are used to
provide Tor.) Side-effects of this method have not yet been fully evaluated.
Management of most tor functionality (status checks, reloading tor on connection
changes) is handled by accessing the Tor control port in an internal, telnet-like
session from the `AppDelegate`.

The app uses a `NSURLProtocol` subclass (`ProxyURLProtocol`), registered to
handle HTTP/HTTPS requests. That protocol uses the `CKHTTPConnection` class
which nearly matches the `NSURLConnection` class, providing wrappers and access
to the underlying `CFHTTP` Core Framework connection bits. This connection
class is where SOCKS5 connectivity is enabled. (Because we are using SOCKS5,
DNS requests are sent over the Tor network, as well.)

(I had WireShark packet logs to support the claim that this app protects all
HTTP/HTTPS/DNS traffic in the browser, but seem to have misplaced them. You'll
have to take my word for it or run your own tests.)

The app uses [Automatic Reference Counting (ARC)][arc] and was developed against
iOS 5.X or greater. (It *may* work when building against iOS 4.X, since most
of the ARC behavior exists in that older SDK, with the notable exception
of weakrefs.)

[arc]: https://developer.apple.com/library/ios/releasenotes/ObjectiveC/RN-TransitioningToARC/index.html

## Building

1. Check Xcode version
2. Build dependencies via command-line
3. Build application in XCode

### Check Xcode version

Double-check that the "currently selected" Xcode Tools correspond to the version
of Xcode you have installed:

    xcode-select -print-path

For the newer Xcode 4.3+ installed via the App Store, the directory should be
`/Applications/Xcode.app/Contents/Developer`, and not the straight `/Developer`
(used by Xcode 4.2 and earlier). If you have both copies of Xcode installed
(or if you have updated to Xcode 4.3 but `/Developer` still shows), do this:

    sudo xcode-select -switch /Applications/Xcode.app/Contents/Developer

### Optional: PGP key verification for dependencies

(Currently in testing.) The build scripts
for OpenSSL, libevent, and tor, verify that the package downloaded is PGP
signed by one of the users responsible for packaging the library. You'll
need to have GnuPG installed and import their public keys to allow this to
work.

* OpenSSL: [core developers](https://www.openssl.org/about/). 1.0.1i is known
  to be signed by Matt Caswell 0x0E604491
  [0xF295C759](http://pgp.mit.edu:11371/pks/lookup?op=vindex&search=0xF295C759).
* libevent: [Nick Mathewson](http://www.wangafu.net/~nickm/)
  ([0x165733EA](http://www.wangafu.net/~nickm/public_key.asc)) or
  [Neils Provos](http://www.citi.umich.edu/u/provos/)
  ([0xC2009841](http://www.citi.umich.edu/u/provos/pgp.key)). 2.0.21 is known
  to be signed by Nick Matthewson 0x8D29319A (subkey of 0x165733EA).
* tor: [signing key info](https://www.torproject.org/docs/signing-keys.html.en).
  0.2.4.20 is known to be signed by Roger Dingledine
  ([0x19F78451](http://pgp.mit.edu/pks/lookup?op=get&search=0x19F78451).

If you don't care about PGP key verification, you'll need to run each of
the scripts with the `--noverify` option or change `VERIFYGPG` to `false`
in each of the `build-*.sh` scripts before continuing.)

### Building dependencies

`cd` to the root directory of this repository and then run these commands in
the following order to build the dependencies. (This can take anywhere between
five and thirty minutes depending on your system speed.)

    bash build-libssl.sh
    bash build-libevent.sh
    bash build-tor.sh

This should create a `dependencies` directory in the root of the repository,
containing the statically-compiled library files.

If you are inside a country or network that blocks connections to torproject.org,
you may have to use [a mirror](https://www.torproject.org/getinvolved/mirrors.html.en)
([alt](https://tor.eff.org/getinvolved/mirrors.html.en)) to successfully build
the Tor dependency. Please see the instructions in `build-tor.sh` if you require
this.

### Build OnionBrowser.xcodeproj in Xcode

Open `OnionBrowser/OnionBrowser.xcodeproj`. You should be
able to compile and run the application at this point.

The app and all dependencies are compiled to run against `arm64` and `armv7`
platforms (the default as of iOS 8).

All dependencies are further compiled for `i386` and `x86_64` targets, so
that both the 32-bit and 64-bit iOS Simulators are supported.

### Information for forks

1. If you're distributing an app that builds off of the Onion Browser code,
   you need to use your own app name and logo.

2. If you're distributing an app that builds off of the Onion Browser code,
   you need to cite Onion Browser within your app's credits as part of
   the terms of the normal MIT License.

   [See the LICENSE file][license] for information -- generally you need to
   include everything from the "ONION BROWSER LICENSE" section down through
   the rest of the file, but see the "TRADEMARK / LICENSE / FORK INFORMATION"
   section there.

3. You'll need to make sure the "Bundle identifier" (under "Info" in the
   app's Target Properties) is set to your own identifier and not
   "com.miketigas.OnionBrowser".

4. You'll need to make sure the URL handlers for your app (see *Integration
   notes* above) don't conflict with the ones for Onion Browser. Make sure
   you edit your `<app>-Info.plist` file and edit values under "URL types".

   Change "URL identifier" to your own' app's identifier from #3, change
   the URL Schemes to the URL schemes your app should open if another app
   tries to open a URL with that prefix. ("test" and "tests" will make
   your app open if another app tries to open URLs starting with "test://"
   and "tests://".)

   You'll also need to edit code in `AppDelegate.m`. Look for instances of
   `"onionbrowser:"` and `"onionbrowsers:"`, as these are the portions that
   check for your app's URL identifiers.
