## Onion Browser

[![Build Status](https://travis-ci.org/mtigas/OnionBrowser.svg?branch=master)](https://travis-ci.org/mtigas/OnionBrowser)  
[Official Site][official] | [Support][help] | [Changelog][changelog] | [Donate][donate]  
&copy; 2012-2016 [Mike Tigas][miketigas] ([@mtigas](https://twitter.com/mtigas))  
[MIT License][license]

A minimal, open-source web browser for iOS that tunnels web traffic through
the [Tor network][tor]. See the [official site][official] for more details
and App Store links.

---

* **OnionBrowser**: 1.7.0 (20161207.1) - See [official release history][releases] and [changelog][changelog].
* **[Tor.framework][Tor.framework]**: 05073f9 (Nov 30 2016)
  * **[Tor][tor]**: 0.2.9.6-rc (Dec 02 2016)
  * **[libevent][libevent]**: 2.1.7-rc (Nov 11 2016)
  * **[OpenSSL][openssl]**: 1.1.0c (Nov 10 2016)
* **[iObfs][iobfs]**: 26463e2 (Jul 15 2016)
  * **obfs4proxy**: 0.0.8-dev, upstream 97a875e (Nov 15 2016)
  * **golang**: 1.7.3 (Oct 19 2016)

[official]: https://mike.tig.as/onionbrowser/
[help]: https://mike.tig.as/onionbrowser/help/
[releases]: https://github.com/mtigas/OnionBrowser/releases
[changelog]: https://raw.github.com/mtigas/OnionBrowser/master/CHANGES.txt
[donate]: https://mike.tig.as/onionbrowser/#support-project
[miketigas]: https://mike.tig.as/
[license]: https://github.com/mtigas/OnionBrowser/blob/master/LICENSE
[Tor.framework]: https://github.com/iCepa/Tor.framework
[tor]: https://www.torproject.org/
[libevent]: http://libevent.org/
[openssl]: https://www.openssl.org/
[iobfs]: https://github.com/mtigas/iObfs

---

#### Adding Onion Browser support to other iOS apps

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

#### Implementation notes

The app, when compiled, contains static library versions of [Tor][tor] and it's
dependencies, [libevent][libevent] and [openssl][openssl].

The build scripts for Tor and other dependencies are based on
[build-libssl.sh][build_libssl] from [x2on/OpenSSL-for-iPhone][openssliphone].
The scripts are configured to compile universal binaries for armv7 and
i386 (for the iOS Simulator).

[build_libssl]: https://github.com/x2on/OpenSSL-for-iPhone/blob/c637f773a99810bb101169f8e534d0d6b09f3396/build-libssl.sh
[openssliphone]: https://github.com/x2on/OpenSSL-for-iPhone

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

### Information for forks

1. If you're distributing an app that builds off of the Onion Browser code,
   you need to use your own app name and logo.

   * Note that you also **cannot** use the official Tor Project logo and names
     (i.e. "Tor", "Tor Browser", "Tor Browser Bundle") without written
     permission from the Tor Project. Please
     [see their trademark FAQ for more information](https://www.torproject.org/docs/trademark-faq).

2. If you're distributing an app that builds off of the Onion Browser code,
   you **must** cite Onion Browser within your app's credits as part of
   the terms of the normal MIT License.

   [See the LICENSE file][license] -- generally you need to
   include everything from the "ONION BROWSER LICENSE" section down through
   the rest of the file. Read that file for more information, though.

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
