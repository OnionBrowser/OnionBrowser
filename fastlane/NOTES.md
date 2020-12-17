# Notes on App Store translations

2020-04-03, berhart

## Currently allowed languages in App Store

ar-SA
ca
cs
da
de-DE
el
en-AU
en-CA
en-GB
en-US
es-ES
es-MX
fi
fr-CA
fr-FR
he
hi
hr
hu
id
it
ja
ko
ms
nl-NL
no
pl
pt-BR
pt-PT
ro
ru
sk
sv
th
tr
uk
vi
zh-Hans
zh-Hant

### Example script to extract this via Fastlane Deliver:

```shell
export PATH="/usr/local/opt/ruby@2.5/bin:/usr/local/Cellar/fastlane/2.144.0/libexec/bin:$PATH" \
GEM_HOME="/usr/local/Cellar/fastlane/2.144.0/libexec" \
GEM_PATH="/usr/local/Cellar/fastlane/2.144.0/libexec"
exec "/usr/local/opt/ruby@2.5/bin/ruby" "-e" 'require "fastlane"; puts FastlaneCore::Languages::ALL_LANGUAGES'
```
From https://github.com/fastlane/fastlane/issues/14959#issuecomment-506256862

## Transifex strings can be locked for certain languages:

(Note, strings can be selected all at once!)

https://docs.transifex.com/projects/preventing-resource-edits#locking-strings

### Currently (potentially) translated languages of Onion Browser, which are not supported by App Store:

locked_as
locked_be
locked_bn
locked_br
locked_lg
locked_gu
locked_is
locked_ga
locked_mk
locked_mr
locked_fa
locked_sl
locked_ta
locked_te
locked_th
locked_sq

### Languages we don't want, although supported because we're not in that countries App Store:
(or other political reasons)

locked_zh-Hans
locked_zh-Hant

## Languages, which can't be uploaded using Fastlane Deliver:
(due to a bug in the App Store API)
