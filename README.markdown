WIP.

Currently contains a build chain for creating the library dependencies for a
universal i386 (iPhoneSimulator) and armv6/armv7 (iPhone/iPad) application
containing [tor][tor] and it's dependencies [libevent][libevent] and
[openssl][openssl].

[tor]: https://www.torproject.org/
[libevent]: http://libevent.org/
[openssl]: https://www.openssl.org/

Build scripts based on [build-libssl.sh][build_libssl] from [x2on/OpenSSL-for-iPhone][opensslipone]

[build_libssl]: https://github.com/x2on/OpenSSL-for-iPhone/blob/c637f773a99810bb101169f8e534d0d6b09f3396/build-libssl.sh
[openssliphone]: https://github.com/x2on/OpenSSL-for-iPhone

---

## Building dependencies

Run the commands in the following order.

    bash build-libssl.sh
    bash build-libevent.sh
    bash build-tor.sh
