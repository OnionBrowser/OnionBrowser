###endless

A (Mobile)Safari-like web browser for iOS (wrapping around UIWebView, of
course) with a design goal of increased security and privacy.

![https://i.imgur.com/xZu2xBel.png](https://i.imgur.com/xZu2xBel.png) ![https://i.imgur.com/L8La0eZl.png](https://i.imgur.com/L8La0eZl.png)

Basic browser functionality implemented:

- Basics of entering URLs, following redirections, back, forward, cookie storage

- Swipe left and right to go back and forward

- Shows padlock for SSL-encrypted URLs

- Multiple tabs

- Search from URL bar with Google or DDG

Security and privacy-focused features implemented:

- Shows green organization name for EV SSL certs

- Integrated full [HTTPS Everywhere](https://www.eff.org/HTTPS-EVERYWHERE)
  ruleset (currently over 11,000 rules) to do on-the-fly URL rewriting to force
  requests over SSL where supported, including setting the secure
  bit on received cookies

- Optional sending of Do-Not-Track header on all requests

- Integrated URL blocker with a small included ruleset of behavior-tracking
  advertising, analytics, and social networking widgets (this list is intended
  for enhancing privacy and not to be an AdBlock-style comprehensive ad-blocking
  list)

- Default to only accepting cookies for the duration of the session with an
  editable whitelist of hosts from which permanent cookies will be saved

=================

Features planned but not yet implemented:

- Auto-destroy session cookies *n* seconds after closing last tab using those
  cookies

- HTTP Strict Transport Security cache

- Bookmarks, probably a home-screen table layout like Safari

Some nice-to-haves:

- Favicon loader into search bar

- Integrated live auto-complete searching like Safari
