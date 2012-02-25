## Onion Browser

Early-stage WIP. Goal is to create an iOS web browser that sends all traffic
over the [Tor network][tor] which is also *open source*.

#### Current Progress

Currently contains a build chain for creating the library dependencies for a
universal i386 (iPhoneSimulator) and armv6/armv7 (iPhone/iPad) application
containing [tor][tor] and it's dependencies [libevent][libevent] and
[openssl][openssl].

[tor]: https://www.torproject.org/
[libevent]: http://libevent.org/
[openssl]: https://www.openssl.org/

Build scripts based on [build-libssl.sh][build_libssl] from [x2on/OpenSSL-for-iPhone][openssliphone]

[build_libssl]: https://github.com/x2on/OpenSSL-for-iPhone/blob/c637f773a99810bb101169f8e534d0d6b09f3396/build-libssl.sh
[openssliphone]: https://github.com/x2on/OpenSSL-for-iPhone

---

### Building dependencies

Run the commands in the following order.

    bash build-libssl.sh
    bash build-libevent.sh
    bash build-tor.sh

---

### OpenSSL 1.0.1 ARM w/ASM-Acceleration

A patch is located at [patches/openssl-1.0.1-beta3-armv7-asm.diff][asm_patch]
which enables building a custom `BSD-asm` target that enables the `armv4_asm`
assembly files (originally written for `linux-armv4` and `android-armv7`).
The patch isn't compatible with other targets because the Apple version of
the AS assembler [is not compatible with the modern GNU implementation due
to it being based on an extremely old fork][as_compat] — the patch rewrites
some of the `*.S` files (or the perl scripts which generate them) to be
compatible with the Apple assembler:

* The `.global` pseudo-op was changed to `.globl`.
* Some pseudo-ops were entirely removed (`.type`, `.size`, `.fpu`, etc.)
* I screwed around with variable scope to allow the assembled files to
  link properly. Generally converted `.comm` pseudo-ops to `.lcomm`,
  manually added leading underscore for private symbol names, etc. (BUT SEE
  DISCLAIMER BELOW)

Initial tests are promising (see [docs/openssl-arm-asm.txt][bench_doc]): approx.
a 30% speed improvement on an iPhone 4S (armv7) on a totally contrived, simplistic,
artificial benchmark on SHA256 and SHA512. (But hey, the test also shows that
the patched library compiles and that at least some of it generates expected
values.)

To use this, build openssl with `build-libssl-arm.sh` instead
of `build-libssl.sh` in the "*Building dependencies*" instructions above.

---

**DISCLAIMER FOR THIS ARM-ASM PATCH**: I don't know assembly and this patch is
the result of me <del>Googling</del> [DuckDuckGo-ing](https://duckduckgo.com/)
and using trial-and-error based on**:

* [knowledge of the Apple assembler eccentricities][as_compat]
* [the Apple list of Assembler Directives][apple_directives]
* [a GNU assembler doc][gnu_as]
* Cockerell's [ARM Assembly Programming book][arm_assembly]

[asm_patch]: https://github.com/mtigas/iOS-OnionBrowser/blob/master/patches/openssl-1.0.1-beta3-armv7-asm.diff
[as_compat]: http://stackoverflow.com/a/3856303
[apple_directives]: https://developer.apple.com/library/mac/documentation/DeveloperTools/Reference/Assembler/040-Assembler_Directives/asm_directives.html
[gnu_as]: http://tigcc.ticalc.org/doc/gnuasm.html
[arm_assembly]: http://peter-cockerell.net/aalp/html/frames.html
