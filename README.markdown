## Onion Browser

[Official Site][official] | [Support][help]<br>
&copy; 2012 [Mike Tigas][miketigas] ([@mtigas](https://twitter.com/mtigas))<br>
[MIT License][license]

A minimal, open-source web browser for iOS that tunnels web traffic through
the [Tor network][tor]. See the [official site][official] for more details
and App Store links.

[official]: http://onionbrowser.com/
[help]: http://onionbrowser.com/help/
[miketigas]: http://mike.tig.as/
[license]: https://github.com/mtigas/iOS-OnionBrowser/blob/master/LICENSE

<a href="//d2p12wh0p3fo1n.cloudfront.net/files/20120413/004.png"><img src="//d2p12wh0p3fo1n.cloudfront.net/files/20120413/004-100.jpg" width="100"/></a>
<a href="//d2p12wh0p3fo1n.cloudfront.net/files/20120413/003.png"><img src="//d2p12wh0p3fo1n.cloudfront.net/files/20120413/003-100.jpg" width="100"/></a>
<a href="//d2p12wh0p3fo1n.cloudfront.net/files/20120413/002.png"><img src="//d2p12wh0p3fo1n.cloudfront.net/files/20120413/002-100.jpg" width="100"/></a>
<a href="//d2p12wh0p3fo1n.cloudfront.net/files/20120413/005.png"><img src="//d2p12wh0p3fo1n.cloudfront.net/files/20120413/005-100.jpg" width="100"/></a>
<br>
<a href="//d2p12wh0p3fo1n.cloudfront.net/files/20120413/p003.png"><img src="//d2p12wh0p3fo1n.cloudfront.net/files/20120413/p003-150.jpg" width="150"/></a>
<a href="//d2p12wh0p3fo1n.cloudfront.net/files/20120413/p002.png"><img src="//d2p12wh0p3fo1n.cloudfront.net/files/20120413/p002-150.jpg" width="150"/></a>
<a href="//d2p12wh0p3fo1n.cloudfront.net/files/20120413/p001.png"><img src="//d2p12wh0p3fo1n.cloudfront.net/files/20120413/p001-150.jpg" width="150"/></a>

#### Technical notes

* **OnionBrowser**: 1.1.0 (20120416.1)
* **Tor**: 0.2.3.12-alpha
* **libevent**: 2.0.18-stable
* **OpenSSL**: 1.0.1

The app, when compiled, contains static library versions of [Tor][tor] and it's
dependencies, [libevent][libevent] and [openssl][openssl].

[tor]: https://www.torproject.org/
[libevent]: http://libevent.org/
[openssl]: https://www.openssl.org/

The build scripts for Tor and these dependencies are based on
[build-libssl.sh][build_libssl] from [x2on/OpenSSL-for-iPhone][openssliphone].
The scripts are configured to compile universal binaries for armv7 and
i386 (for the iOS Simulator).

[build_libssl]: https://github.com/x2on/OpenSSL-for-iPhone/blob/c637f773a99810bb101169f8e534d0d6b09f3396/build-libssl.sh
[openssliphone]: https://github.com/x2on/OpenSSL-for-iPhone

The tor `build-tor.sh` script patches one file in Tor (`src/common/compat.c`)
to remove references to `ptrace()`. This code is only used for the
`DisableDebuggerAttachment` feature (default: True) implemented in Tor
0.2.3.9-alpha. (See [changelog][tor_dev_changelog] and [manual][tor_dev_manual].)
`ptrace()` calls are not allowed in App Store apps; apps
submitted with `ptrace()` symbols are rejected on upload by Apple's
auto-validation of the uploaded binary. See the `build-tor-ptrace-patch.diff`
file.

[tor_dev_changelog]: https://gitweb.torproject.org/tor.git/blob/tor-0.2.3.12-alpha:/ChangeLog
[tor_dev_manual]: https://www.torproject.org/docs/tor-manual-dev.html.en

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
iOS 5.X. (It *may* work when building against iOS 4.X, since most of the ARC
behavior exists in that older SDK, with the notable exception of weakrefs.)

[arc]: https://developer.apple.com/library/ios/releasenotes/ObjectiveC/RN-TransitioningToARC/index.html

## Building

1. Build dependencies via command-line
2. Build application in XCode

### Building dependencies

`cd` to the root directory of this repository and then run these commands in
the following order to build the dependencies. (This can take anywhere between
five and thirty minutes depending on your system speed.)

    bash build-libssl.sh
    bash build-libevent.sh
    bash build-tor.sh

This should create a `dependencies` directory in the root of the repository,
containing the statically-compiled library files.

### OnionBrowser.xcodeproj

Open `OnionBrowser/OnionBrowser.xcodeproj`. You should be
able to compile and run the application at this point. (The app is compatible
with armv7 and i386 targets, meaning that all iOS 5.0 devices and the
iPhone/iPad Simulators should be able to run the application.)
