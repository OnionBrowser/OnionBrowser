#!/usr/bin/ruby

require "active_support/core_ext/hash/conversions"
require "plist"
require "json"

HTTPS_E_TARGETS_PLIST = "Endless/Resources/https-everywhere_targets.plist"
HTTPS_E_GIT_COMMIT = File.read("https-everywhere/.git/refs/heads/master").
  strip[0, 12]

skip_https_e = false

if File.exists?(HTTPS_E_TARGETS_PLIST)
  if m = File.open(HTTPS_E_TARGETS_PLIST).gets.to_s.match(/Everywhere (.+) - /)
    skip_https_e = (m[1] == HTTPS_E_GIT_COMMIT)
  end
end

if !skip_https_e
  # convert all HTTPS Everywhere XML rule files into one big rules hash and
  # write it out as a plist, as well as a standalone hash of target URLs ->
  # rule names to another plist

  rules = {}
  targets = {}

  Dir.glob(File.dirname(__FILE__) +
  "/https-everywhere/src/chrome/content/rules/*.xml").each do |f|
    hash = Hash.from_xml(File.read(f))

    raise "no ruleset" if !hash["ruleset"]

    if hash["ruleset"]["default_off"]
      next # XXX: should we store these?
    end

    raise "conflict on #{f}" if rules[hash["ruleset"]["name"]]

    rules[hash["ruleset"]["name"]] = hash

    hash["ruleset"]["target"].each do |target|
      if !target.is_a?(Hash)
        # why do some of these get converted into an array?
        if target.length != 2 || target[0] != "host"
          puts f
          raise target.inspect
        end

        target = { target[0] => target[1] }
      end

      if targets[target["host"][1]]
        raise "rules already exist for #{target["host"]}"
      end

      targets[target["host"]] = hash["ruleset"]["name"]
    end
  end

  File.write(HTTPS_E_TARGETS_PLIST,
    "<!-- automatically generated from HTTPS Everywhere " +
    HTTPS_E_GIT_COMMIT +
    " - do not directly edit this file -->\n" +
    targets.to_plist)

  File.write("Endless/Resources/https-everywhere_rules.plist",
    "<!-- generated from HTTPS Everywhere " +
    HTTPS_E_GIT_COMMIT +
    " - do not directly edit this file -->\n" +
    rules.to_plist)
end

# do similar for URL blocking rules, converting JSON ruleset into a list of
# target domains and a list of rulesets with information URLs

targets = {}

JSON.parse(File.read("urlblocker.json")).each do |company,domains|
  domains.each do |dom|
    targets[dom] = company
  end
end

File.write("Endless/Resources/urlblocker_targets.plist",
  "<!-- generated from urlblocker.json - do not directly edit this file -->\n" +
  targets.to_plist)
