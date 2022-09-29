#  Onion Browser 2 Changelog

## 2.8.2
- Updated to Tor.framework 407.10.2 containing Tor 0.4.7.10.
- Updated Snowflake to version 2.3.0.
- Fixed crash when editing a bookmark URL.
- Minor translation updates.

## 2.8.1
- Updated to Tor.framework 407.8.2 containing Tor 0.4.7.8.

## 2.8.0
- Updated to Tor.framework 407.7.1 containing Tor 0.4.7.7 and OpenSSL 1.1.1o.
- Updated to Snowflake 2.2.0.
- Updated Spanish and Ukranian translation.
- Added Romanian translation.
- Fixed behaviour around Onion-Location redirects.
- Improved tab overview. Use snapshots instead of small webviews. Big thanks to Alexey Kosylo!

## 2.7.9
- Updated to Tor.framework 406.10.1 containing Tor 0.4.6.10 and OpenSSL 1.1.1m.
- Updated Ukrainian, Russian and traditional Chinese translations.
- Updated NYT onion address.
- Added DW and Twitter onion address to default bookmarks.
- Updated HSTS list for automatic rewrites to HTTPS.

## 2.7.8
- Improved app icon.
- Introduced BartyCrouch tool for localization consolidation.
- Translation updates.
- Updated to Tor.framework 406.9.2 containing Tor 0.4.6.9 and OpenSSL 1.1.1m. 
- Fixed build on Apple Silicon. 
- Moved shared proxy config code to IPtProxyUI library.
- Updated IPtProxy to 1.5.0 containing latest fixes to Snowflake and Obfs4proxy.
- Added Khmer translation.

## 2.7.7

- Finally added Greek to app translation. Not complete, yet, but mostly.
- Actively migrate v2 onion default bookmarks to v3.
- Added feedback, when bridge settings were changed during startup.

## 2.7.6

- Updated Tor to version 0.4.5.10.
- Added support for onion service v3 authentication.
- Fixed handling of received URLs. Will now work better with other apps, regardless
  of the state Onion Browser is in.
- Added feature: "Disable Bookmarks on Start Page".
- Now contains some popular User Agent strings for users to choose.
- Translation updates.

## 2.7.5

- Updated Arabic, Irish and Macedonian translations.
- Updated Tor to version 0.4.5.9.
- Updated Snowflake to version 1.1.0.
- Fixed a bug, where no tab was shown after restart and toolbar was also hidden.
- Added "Very Strict" content policy to really switch off JavaScript. Breaks context menu, but needed for some rare sites.

## 2.7.4

- Added Polish translation.
- Improved wording.
- Fixed app crashes on short pause/resume cycles.
- Fixed app start when Snowflake bridges are configured.
- Fixed issue when changing custom bridges and trying to connect immediately.
- Updated Tor to version 0.4.5.8.

## 2.7.3

- Updated translations.
- Added Korean translation.
- Updated dependencies.
- Fixed issue with iframes in conjunction with Universal Link Protection.
- Make automatic redirects to addresses advertised in `Onion-Location` headers configurable.
- Fixed issue on iOS 14, where security level badges weren't tappable anymore.
- Removed Meek Azure bridge, since Microsoft announced starting to block it.
- Updated Moat (Obfs4 bridge service) and Snowflake configuration.
- Updated Tor to 0.4.5.7 and OpenSSL to 1.1.1k.

## 2.7.2

- Fixed a problem with the meek-azure bridge and the MOAT service to fetch new bridges.
- Updated Thai translation.

## 2.7.1

- Fixed Snowflake stop and restart.
- Added Albanian translation.
- Small updates to Croatian, Hebrew, Japanese and Spanish.
- Fixed issue with Content Security Header. (Thanks DuckDuckGo team!)
- Updated Tor to 0.4.4.6.

## 2.7.0
- Use the dedicated Meek bridge of the MOAT service directly without Tor as originally intended.
- Added Snowflake bridge support.
- Added support for the "Onion-Location" HTTP header. (See https://community.torproject.org/onion-services/advanced/onion-location/)
- Small bugfixes.
- Small translation updates to French, Japanese, Dutch, Thai, Catalan and Gaelic.
- Replaced link to https://onionbrowser.com/donate on start page with display of In-App-Purchase scene.
- Fixed issue on iOS 14, where users couldn't store documents to "Files" app anymore.
- Updated Tor to 0.4.4.5.

## 2.6.2
- Added Italian translation.
- Updated Arabic translation.
- Updated Tor to 0.4.3.6.

## 2.6.1

- Updated Tor to 0.4.3.5.
- Updated translations.
- Fixed DuckDuckGo behaviour (and probably other sites'!) in gold security level.
- Fixed app lock when no biometry available.

## 2.6.0

- Rephrased security levels and improved their description.
- Added Nextcloud Bookmarks support.
- Added optional biometric/device passcode app lock.
- Added MOAT implementation: Automatic retrieval of OBFS4 bridges via Meek.
- Fixed memory leaks, where RAM usage would increase over time, because tabs were never 
  really removed from memory.
- Empty all background tabs on memory warning signal from iOS.
- Fixed race condition with accidentally deleted start page.
- Fixed links to onionbrowser.com.
- Updated translations.
- Small bug fixes.
- Tor updated to 0.4.1.6.

## 2.5.0

- Updated translations.
- Fixed issues with persistent cookies.
- Fixed issues on iPad where scene was scrolling away when keyboard showed.
- Refurbished app start UI. Don't show error page, instead prompt user to configure bridges.
- Improved bridge configuration UI.
- Improved popups on iPad.
- Add bookmark from share sheet.
- Increased X button on tab overview for easier close.
- Added swipe up to close tabs in tab overview.
- Fixed hidden toolbar when viewing PDFs, images and other files.
- Fixed share sheet options.
- Added advanced Tor configuration option.
- Added explanation about security levels.
- Improved dark mode support.
- Fixed crash when showing Tor circuits.
- Fixed app shortcuts. (On long tap on app icon.)
- Updated OBFS4 bridge list.
- Fixed bug when changing bridge settings.
- Fixed problems with injected JavaScript.

## 2.4.0

- New browsing chrome
- Improved iPad support
- New landing page
- Bookmarks with favicons
- New Tor circuit display
- Security level presets
- New tab overview
- Tor updated to 0.4.0.6
- Updated OBFS4 server list
- Fixed issue with Content-Security-Header nonce and hash values which broke a lot of sites.
- Localization updates

## 2.3.0

- Tor updated to 0.4.0.5
- Localization updates.
- FIXED OCSP leak by adapting code from Psiphon's Endless fork and their OCSPCache. (#178)
- Now able to share downloaded PDFs and other binary files with other apps.
- Completely overhauled bookmark management UI.
- Completely overhauled settings UI.
- Replaced own dark mode with iOS 13 dark mode support.
- Onion Browser now registers for http and https URL schemes, so is able to be the default browser
  on the device.
- Dropped special 1Password support in favor of system-wide password manager support.
- Load bridges from a stored QR code photo.
- Licensing change of Endless, the upstream browser chrome project.
- Fixed context menu in "Content Policy: strict" mode.

## 2.2.1

- New "start up in last state" feature, which remembers open tabs. (#134)
- New "open in background tab" feature (#154, #158)
- FIXED: Fixed behavior of content blocking; "strict" should now properly allow static images. (#123)
- FIXED: Corrected display issues on iPad. (#169)
- FIXED: The documented in-app purchase has been missing for a few versions.
- Updated localizations for many languages. Updated some App Store localizations and screenshots. (#163, #189, #197)

## 2.2.0

- Tor updated to 0.3.5.8.
- When the app goes to background, the preview in the app switcher is now obscured. (Issue #138)
- Improved tor stop / restart behavior when going to background. Tor now completely shuts down on
  background and a fresh Tor launched when the app is resumed.
- FIXED: Websites with self-signed certificates may be accessed again, after warning the user of
  the security implications. (#111)
- FIXED: Editing bridges after first launch works again. (#121, #140)
- FIXED: Using camera to import bridges from QR code works again. (#142)
- Localizations now available in Turkish. Updated localizations for most languages.

## 2.1.0

## 2.0.3

## 2.0.2

- fixes DNS leak (#112)
- fixes bootstrap on ipv6-only networks (#114, #108, old #73)
- updates built-in bridges to match latest tor browser, including an ipv6 bridge.
- adds partial persian, icelandic, and chinese (simplified) translations

## 2.0.1

- Bugfixes to get it through the App Store inspection.

## 2.0.0

First release of the brand-new Onion Browser 2
