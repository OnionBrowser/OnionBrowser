###endless

A (Mobile)Safari-like web browser for iOS (wrapping around UIWebView, of course) with a design goal of increased security and privacy.

Basic browser functionality implemented:

- Basics of entering URLs, following redirections, back, forward, cookie storage
- Swipe left and right to go back and forward
- Shows padlock for SSL-encrypted URLs

Security and privacy-focused features implemented:

- Shows green organization name for EV SSL certs
- Integrates full [HTTPS Everywhere](https://www.eff.org/HTTPS-EVERYWHERE) ruleset (currently over 11,000 rules) to do on-the-fly URL rewriting to force requests over SSL where supported
- Sending of Do-Not-Track header on all requests

=================
Features planned but not yet implemented:

- Multiple tabs like Safari, some kind of overview navigation
- Make default only store cookies for the session (auto-destroying *n* seconds after closing last tab using those cookies) and only allow permanent storage of whitelisted cookies
- URL blacklist based on Ghostery or some other tracker-blocking plugin (just trackers, not all of Adblock)
- HTTP Strict Transport Security cache
- Bookmarks, probably a home-screen table layout like Safari

Some nice-to-haves:

- Favicon loader into search bar
- Integrated live auto-complete searching like Safari