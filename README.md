###Endless

A (Mobile)Safari-like web browser for iOS (wrapping around UIWebView, of
course) with a design goal of increased security and privacy.  Current builds
are available for free in the
[App Store](https://itunes.apple.com/us/app/endless-browser/id974745755?mt=8).

![https://i.imgur.com/ABftci1l.png](https://i.imgur.com/ABftci1l.png) ![https://i.imgur.com/6HsCQn3l.png](https://i.imgur.com/6HsCQn3l.png)

#####Basic browser functionality implemented:

- Basics of entering URLs, following redirections, back, forward, cookie storage

- Swipe left and right to go back and forward

- Shows padlock for SSL-encrypted URLs

- Multiple tabs with support for `window.open()` and `<a target="_blank">`
  automatically opening new tab windows, but blocks calls not made via user
  interaction events (similar to most desktop browser popup blockers)

- Search from URL bar with DDG, Google, or Startpage

#####Security and privacy-focused features implemented:

- Defaults to only accepting cookies and local storage for the duration of the
  session (until the last tab accessing that data closes) with an editable
  whitelist of hosts from which non-session data will be saved

- Auto-destroys non-whitelisted cookies and local storage (even within the same
  tab) that has not been accessed by any other tab within a configurable amount
  of time (defaults to 30 minutes) to improve privacy after browsing within a
  long-running tab

- Cookie and localStorage database listing and deletion per-host

- Integrated full [HTTPS Everywhere](https://www.eff.org/HTTPS-EVERYWHERE)
  ruleset to do on-the-fly URL rewriting to force requests over SSL where
  supported, including setting the secure bit on received cookies and
  auto-detection of redirection loops

- HTTP Strict Transport Security (RFC6797) implementation (in addition to
  WebKit's mystery built-in one) with Chromium's large preload list

- Integrated URL blocker with a small included ruleset of behavior-tracking
  advertising, analytics, and social networking widgets (this list is intended
  for enhancing privacy and not to be an AdBlock-style comprehensive ad-blocking
  list)

- Blocks mixed-content requests (http elements on an https page), shows broken
  padlock

- Blocks pages loaded from non-local networks (i.e., the internet) from trying
  to load sub-requests (e.g., images, iframes, ajax) from hosts that are on
  local RFC3330 networks such as routers and other insecure devices

- Shows organization name in URL bar for sites with EV SSL certs

- Optional sending of Do-Not-Track header on all requests

#####Features planned but not yet implemented:

- Bookmarks, probably a home-screen table layout like Safari

#####Some nice-to-haves:

- Favicon loader into search bar

- Integrated live auto-complete searching like Safari
