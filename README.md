## Onion Browser

[![Build Status](https://travis-ci.org/mtigas/OnionBrowser.svg?branch=2.X)](https://travis-ci.org/mtigas/OnionBrowser)  
[Official Site][official] | [Support][help] | [Release History][releases] | [Donate][donate]  
&copy; 2012-2018, Tigas Ventures, LLC ([Mike Tigas][miketigas])

*This is the Onion Browser <strong>2.X branch</strong>, based on [Endless][endless]. The old version of Onion Browser can be found [here][1.X].*

**Onion Browser** is a free web browser for iPhone and iPad that encrypts and tunnels web traffic through the [Tor network][tor]. See the [official site][official] for more details and App Store links.

Please see the [LICENSE][license] file for usage and redistribution terms. As of the 2.X (Endless-based) tree, redistribution of this software in binary form, with or without modification, is not permitted. (The previous [1.X tree][1.X] of Onion Browser was available under [a different license](https://github.com/mtigas/OnionBrowser/blob/1.X/LICENSE).)

---

* **OnionBrowser**: 2.0.3 (20180209.48) - See [official release history][releases] and [changelog][changelog].
* **[Endless][endless]** upstream: 1.6.1
* **[Tor.framework][Tor.framework]**: 31.9.2
  * **[Tor][tor]**: 0.3.1.9
  * **[libevent][libevent]**: 2.1.8
  * **[OpenSSL][openssl]**: 1.1.0g
  * **[liblzma][liblzma]**: 5.2.3

[official]: https://onionbrowser.com/
[help]: https://github.com/mtigas/OnionBrowser/wiki/Help
[releases]: https://github.com/mtigas/OnionBrowser/releases
[changelog]: https://raw.github.com/mtigas/OnionBrowser/2.X/CHANGES.txt
[donate]: https://onionbrowser.com/#support-project
[miketigas]: https://mike.tig.as/
[license]: https://github.com/mtigas/OnionBrowser/blob/2.X/LICENSE
[Tor.framework]: https://github.com/iCepa/Tor.framework
[tor]: https://www.torproject.org/
[libevent]: http://libevent.org/
[openssl]: https://www.openssl.org/
[liblzma]: https://tukaani.org/xz/
[iobfs]: https://github.com/mtigas/iObfs
[endless]: https://github.com/jcs/endless
[1.X]: https://github.com/mtigas/OnionBrowser/tree/1.X

### Notable 2.X Features

The following features are new to Onion Browser, by way of the upstream work on [Endless][endless]:

- Multiple tab support

- Search from URL bar

- Ability to configure security and privacy settings (script blocking, etc) on a per-site basis

- Per-site cookie handling

- [HTTPS Everywhere](https://www.eff.org/HTTPS-EVERYWHERE) support

- HTTP Strict Transport Security (HSTS) support, pre-loaded with the [Chromium ruleset](https://hstspreload.org/)

- Ability to view SSL certificate information, to allow manual verification of SSL certificates

- [1Password extension](https://github.com/AgileBits/onepassword-app-extension)
  support (if 1Password app is installed)
