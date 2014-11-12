## Onion Browser

**Warning — In-Development Branch:** This *2.0.X-dev* branch is a work-in-progress rewrite of a vast majority of Onion Browser's code. Tor capability in this branch has been disabled and many features will probably not work. You should only browse this branch if you know what you're doing.

[Official Site][official] | [Support][help] | [Changelog][changelog]  
&copy; 2012-2014 [Mike Tigas][miketigas] ([@mtigas](https://twitter.com/mtigas))  
[MIT License][license]

A minimal, open-source web browser for iOS that tunnels web traffic through
the [Tor network][tor]. See the [official site][official] for more details
and App Store links.

---

* **OnionBrowser**: 2.0.X-dev — [See changelog][changelog]
* **[Tor][tor]**: 0.2.5.10 (Oct 24 2014)
* **[libevent][libevent]**: 2.0.21-stable (Nov 18 2012)
* **[OpenSSL][openssl]**: 1.0.1j (Oct 15 2014)

[official]: https://mike.tig.as/onionbrowser/
[help]: https://mike.tig.as/onionbrowser/help/
[changelog]: https://raw.github.com/OnionBrowser/iOS-OnionBrowser/master/CHANGES.txt
[miketigas]: https://mike.tig.as/
[license]: https://github.com/OnionBrowser/iOS-OnionBrowser/blob/master/LICENSE

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

See [the Google Chrome iOS instructions][crios] (for http & https) for more
examples -- just note that you should replace their `googlechrome://` URL
schemes with the proper `onionbrowser://` ones.

[x-callback-url]: http://x-callback-url.com/
[crios]: https://developers.google.com/chrome/mobile/docs/ios-links#uri_schemes

---

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
