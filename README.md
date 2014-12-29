###Endless

A (Mobile)Safari-like web browser for iOS (wrapping around UIWebView, of
course) with a design goal of increased security and privacy.

![https://i.imgur.com/ABftci1l.png](https://i.imgur.com/ABftci1l.png) ![https://i.imgur.com/Md7CkLYl.png](https://i.imgur.com/Md7CkLYl.png)

#####Basic browser functionality implemented:

- Basics of entering URLs, following redirections, back, forward, cookie storage

- Swipe left and right to go back and forward

- Shows padlock for SSL-encrypted URLs

- Multiple tabs, support for `window.open` and `<a target="_blank">` automatically
  opening new tab windows

- Search from URL bar with Google or DDG

#####Security and privacy-focused features implemented:

- Defaults to only accepting cookies for the duration of the session with an
  editable whitelist of hosts from which non-session cookies will be saved

- Integrated full [HTTPS Everywhere](https://www.eff.org/HTTPS-EVERYWHERE)
  ruleset (currently over 11,000 rules) to do on-the-fly URL rewriting to force
  requests over SSL where supported, including setting the secure
  bit on received cookies and auto-detection of redirection loops

- Integrated URL blocker with a small included ruleset of behavior-tracking
  advertising, analytics, and social networking widgets (this list is intended
  for enhancing privacy and not to be an AdBlock-style comprehensive ad-blocking
  list)

- Blocks mixed-content requests (http elements on an https page), shows broken
  padlock

- Shows organization name in URL bar for sites with EV SSL certs

- Optional sending of Do-Not-Track header on all requests

#####Features planned but not yet implemented:

- Auto-destroy session cookies *n* seconds after closing last tab using those
  cookies

- HTTP Strict Transport Security cache

- Bookmarks, probably a home-screen table layout like Safari

#####Some nice-to-haves:

- Favicon loader into search bar

- Integrated live auto-complete searching like Safari
