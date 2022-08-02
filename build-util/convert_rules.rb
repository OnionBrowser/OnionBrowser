#!/usr/bin/ruby
#
# Endless
# Copyright (c) 2014-2015 joshua stein <jcs@jcs.org>
#
# See LICENSE file for redistribution terms.
#

#require "active_support/core_ext/hash/conversions"
#require "plist"
require "json"
require "net/https"
require "uri"

# in b64 for some reason
HSTS_PRELOAD_LIST = "https://chromium.googlesource.com/chromium/src/net/+/master/http/transport_security_state_static.json?format=TEXT"
HSTS_PRELOAD_HOSTS_PLIST = "Resources/hsts_preload.plist"

FORCE = (ARGV[0].to_s == "-f")

def convert_hsts_preload
  domains = {}

  json = JSON.parse(Net::HTTP.get(URI(HSTS_PRELOAD_LIST)).unpack("m0").first)
  json["entries"].each do |entry|
    domains[entry["name"]] = {
      "include_subdomains" => !!entry["include_subdomains"]
    }
  end

  File.write(HSTS_PRELOAD_HOSTS_PLIST,
    "<!-- generated from #{HSTS_PRELOAD_LIST} - do not directly edit this " +
      "file -->\n" +
    domains.to_plist)
end

convert_https_e
# convert_hsts_preload
