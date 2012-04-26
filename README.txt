# Onion Browser

Official Site: http://onionbrowser.com/
Support: http://onionbrowser.com/help/

(c) 2012 Mike Tigas
http://mike.tig.as/
Twitter: @mtigas

MIT License (See LICENSE)

---

A minimal, open-source web browser for iOS that tunnels web traffic through
the Tor network (https://www.torproject.org/). See the official site
(http://onionbrowser.com/) for more details and App Store links.

## Technical notes

* OnionBrowser: 1.1.1 (20120426.1)
* Tor: 0.2.3.12-alpha
* libevent: 2.0.18-stable
* OpenSSL: 1.0.1

The app, when compiled, contains static library versions of Tor and it's
dependencies, libevent and openssl.

    tor: https://www.torproject.org/
    libevent: http://libevent.org/
    openssl: https://www.openssl.org/

The build scripts for Tor and these dependencies are based on
build-libssl.sh from x2on/OpenSSL-for-iPhone.
The scripts are configured to compile universal binaries for armv7 and
i386 (for the iOS Simulator).

    build-libssl.sh: https://github.com/x2on/OpenSSL-for-iPhone/blob/c637f773a99810bb101169f8e534d0d6b09f3396/build-libssl.sh
    OpenSSL-for-iPhone: https://github.com/x2on/OpenSSL-for-iPhone

The tor `build-tor.sh` script patches one file in Tor (`src/common/compat.c`)
to remove references to `ptrace()`. This code is only used for the
`DisableDebuggerAttachment` feature (default: True) implemented in Tor
0.2.3.9-alpha. `ptrace()` calls are not allowed in App Store apps; apps
submitted with `ptrace()` symbols are rejected on upload by Apple's
auto-validation of the uploaded binary. See the `build-tor-ptrace-patch.diff`
file.

    Tor 0.2.3.12 changelog: https://gitweb.torproject.org/tor.git/blob/tor-0.2.3.12-alpha:/ChangeLog
    Tor 0.2.3.X manual: https://www.torproject.org/docs/tor-manual-dev.html.en

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

The app uses Automatic Reference Counting (ARC) and was developed against
iOS 5.X. (It *may* work when building against iOS 4.X, since most of the ARC
behavior exists in that older SDK, with the notable exception of weakrefs.)

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
    bash OnionBrowser/icon/install.sh

This should create a `dependencies` directory in the root of the repository,
containing the statically-compiled library files.

### OnionBrowser.xcodeproj

Open `OnionBrowser/OnionBrowser.xcodeproj`. You should be
able to compile and run the application at this point. (The app is compatible
with armv7 and i386 targets, meaning that all iOS 5.0 devices and the
iPhone/iPad Simulators should be able to run the application.)
