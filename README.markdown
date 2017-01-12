## Onion Browser

[![Build Status](https://travis-ci.org/mtigas/OnionBrowser.svg?branch=1.X)](https://travis-ci.org/mtigas/OnionBrowser)  
[Official Site][official] | [Support][help] | [Changelog][changelog] | [Donate][donate]  
&copy; 2012-2016 [Mike Tigas][miketigas] ([@mtigas](https://twitter.com/mtigas))  
[Mozilla Public License 2.0][license]

Onion Browser is a free web browser for iPhone and iPad that encrypts and tunnels web traffic through the [Tor network][tor]. See the [official site][official] for more details
and App Store links.

---

* **OnionBrowser**: 1.7.3 (20170112.3) - See [official release history][releases] and [changelog][changelog].
* **[Tor.framework][Tor.framework]**: a1b2928 (Dec 14 2016)
  * **[Tor][tor]**: 0.2.9.8 (Dec 19 2016)
  * **[libevent][libevent]**: 2.1.7-rc (Nov 11 2016)
  * **[OpenSSL][openssl]**: 1.0.2j (Sep 26 2016)
* **[iObfs][iobfs]**: 26463e2 (Jul 15 2016)
  * **obfs4proxy**: 0.0.8-dev, upstream 97a875e (Nov 15 2016)
  * **golang**: 1.7.4 (Dec 01 2016)

[official]: https://mike.tig.as/onionbrowser/
[help]: https://mike.tig.as/onionbrowser/help/
[releases]: https://github.com/mtigas/OnionBrowser/releases
[changelog]: https://raw.github.com/mtigas/OnionBrowser/1.X/CHANGES.txt
[donate]: https://mike.tig.as/onionbrowser/#support-project
[miketigas]: https://mike.tig.as/
[license]: https://github.com/mtigas/OnionBrowser/blob/1.X/LICENSE
[Tor.framework]: https://github.com/iCepa/Tor.framework
[tor]: https://www.torproject.org/
[libevent]: http://libevent.org/
[openssl]: https://www.openssl.org/
[iobfs]: https://github.com/mtigas/iObfs

---

#### Implementation notes

The app uses the [Tor.framework][Tor.framework] package to build the Tor, OpenSSL, and libevent
dependencies.

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

* Read more about Onion Browser and the challenges of implementing Tor clients on iOS
[in this post on the Tor Project blog](https://blog.torproject.org/blog/tor-heart-onion-browser-and-more-ios-tor).
