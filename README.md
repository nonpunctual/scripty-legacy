# scripty-legacy

Helpful & unhelpful scripts.

- **[active.app.sh](active.app.sh)**: Logs macOS foreground-app switches as JSON, in real time, with an optional duration arg (defaults to running until interrupted).
- **[battery.health.sh](battery.health.sh)**: Reports Mac portable battery health, cycle count, max capacity, and hardware/firmware revisions as a Jamf-style `<result>` extension attribute. Exits early on non-portable Macs.
- **[build.component.pkg.sh](build.component.pkg.sh)**: Builds & signs a macOS component .pkg from a payload folder via `pkgbuild`, with an optional `--scripts` payload.
- **[build.distribution.pkg.sh](build.distribution.pkg.sh)**: Builds a signed, optionally notarized (and optionally .dmg-wrapped) macOS distribution installer from a payload folder via `pkgbuild`/`productbuild`, with an optional `--scripts` payload. Requires a Developer ID Application & Installer certificate in the keychain.
- **[configure.fleet.printers.sh](configure.fleet.printers.sh)**: Turns a CSV of printers (`name,location,uri,display_name`) into a per-printer `lpadmin` install script plus the corresponding Fleet GitOps `software: packages:` YAML entries, ready to paste into a Fleet repo.
- **[disk.warn.sh](disk.warn.sh)**: Installs a script + LaunchDaemon that checks free disk space every 60s and shows a warning dialog when it drops below 10%. Must be run as root.
- **[home.folder.size.sh](home.folder.size.sh)**: Reports top-level folder sizes under the console user's home directory, sorted, as a Jamf-style `<result>` extension attribute.
- **[internet.sharing.check.sh](internet.sharing.check.sh)**: Reports macOS Internet Sharing state: never enabled, disabled-but-configured, or enabled, with source/target interfaces from the NAT plist.
- **[jwt.decode.sh](jwt.decode.sh)**: Decodes any JWT (JSON web token) header/payload via `jq` (arg or prompt); shows a curated summary for [Fleet license](https://fleetdm.com/docs/configuration/fleet-server-configuration#license) JWTs (tier, devices, note, etc.), or dumps all claims with `iat`/`exp`/`nbf` as readable timestamps for anything else.
- **[macOS.block.app.sh](macOS.block.app.sh)**: Installs a LaunchDaemon that kills a named app on launch and shows a blocking dialog; configured for Migration Assistant by default. Must be run as root.
- **[macOS.update.app.sh](macOS.update.app.sh)**: Removes an installed app if its version is older than a given minimum (via zsh's `is-at-least`), with a test/dry-run mode. Must be run as root.
- **[mdm.managed.users.sh](mdm.managed.users.sh)**: Queries `mdmclient` for MDM management status/active managed users and cross-references GeneratedUID against local accounts to determine which local users are MDM-managed. Must be run as root.
- **[network.check.sh](network.check.sh)**: Reports network connectivity as a JSON object: active interfaces, primary service name, IPv4/IPv6 gateway & external IP, DNS reachability & resolution, configured DNS servers, Wi-Fi network/signal (when applicable), active VPN tunnels, HTTP/HTTPS/SOCKS/PAC proxy configuration, and captive portal detection. Must be run as root.
- **[network.device.list.sh](network.device.list.sh)**: Reports on devices/connections near this Mac: ARP table, nearby Bonjour services, active outbound connections, & DHCP leases handed out via Internet Sharing.
- **[network.quality.sh](network.quality.sh)**: Runs macOS's `networkquality` with a GUI picker (speed test vs. video conferencing) and shows the result in a dialog. Good for Self Service!
- **[network.service.delete.sh](network.service.delete.sh)**: Delete Network Services (e.g. stale Internet Sharing entries, etc.) by providing Network Service names as arguments. Must be run as root.
- **[reset.desktop.sh](reset.desktop.sh)**: Aggressively closes all Finder windows & force-quits every visible app, to reveal a clean desktop before directing a user to a specific Finder window.
- **[set.app.handler.sh](set.app.handler.sh)**: Sets permissions/ownership on an already-installed [`swda`](https://github.com/Lord-Kamina/SwiftDefaultApps/releases) (SwiftDefaultApps CLI) binary, then uses it to set Microsoft Outlook as the default handler for `.ics` UTIs, which normally default to Apple Calendar.
- **[set.autologin.sh](set.autologin.sh)**: DANGEROUS! Postinstall for an unattended Mac. Creates a random admin account, enables autologin via `sysadminctl`, reboots, then a deferred LaunchDaemon sweeps all other local accounts. Must be run as root.
- **[set.user.name.sh](set.user.name.sh)**: Derives the UID 501 user's display name from their `firstname.lastname` short name and sets RealName, ComputerName, HostName, and LocalHostName to match. Must be run as root.
- **[set.user.picture.sh](set.user.picture.sh)**: Replaces a local macOS user account's profile picture via `dscl`/`dsimport`, given a username and image path as args. Must be run as root.
- **[ubuntu.dconf.sh](ubuntu.dconf.sh)**: Locks down GNOME privacy/security settings (screen lock, idle timeout, location, recent files, trash) system-wide and machine-locked via dconf, so users can't override them with `gsettings`.
- **[ubuntu.privacy.security.sh](ubuntu.privacy.security.sh)**: Same GNOME privacy/security settings as ubuntu.dconf.sh, but applied per-user via `gsettings` (overridable), plus disables Tracker3 file indexing and Apport crash reporting.
- **[update.marketing.assets.sh](update.marketing.assets.sh)**: Pulls article metadata from the fleetdm/fleet GitHub repo and prints categorized markdown tables (articles, case studies, guides, etc.) for tracking marketing content.

## Other stuff

Some my ideas in scripts & code aren't posted here. They're in posts on [nonpunctual.org](https://www.nonpunctual.org/):

- [A Haiku On Regular Expressions](https://www.nonpunctual.org/posts/a-haiku-on-regular-expressions/)
- [A Light Unto My Xpath](https://www.nonpunctual.org/posts/a-light-unto-my-xpath/)
- [Apple CIDR](https://www.nonpunctual.org/posts/apple-cidr/)
- ["Automating" the Mac Evaluation Utility.app (MEU)](https://www.nonpunctual.org/posts/automating-the-mac-evaluation-utility.app-meu/)
- [Collect Year From Mac Marketing Model Name](https://www.nonpunctual.org/posts/collect-year-from-mac-marketing-model-name/)
- [GNU (New?) du Binary Option In macOS 12 Monterey](https://www.nonpunctual.org/posts/du-binary-option-in-macos-12-monterey/)
- [Dynamic Token Of Static Appreciation](https://www.nonpunctual.org/posts/dynamic-token-of-static-appreciation/)
- [Firefoxy](https://www.nonpunctual.org/posts/firefoxy/)
- [Googalogically Speaking](https://www.nonpunctual.org/posts/googalogically-speaking/)
- [Interactively Create Hugo Content With Frontmatter](https://www.nonpunctual.org/posts/interactively-create-hugo-content-with-frontmatter/)
- [I've Got the Power](https://www.nonpunctual.org/posts/ive-got-the-power/)
- [JSON & the Arg-nauts](https://www.nonpunctual.org/posts/json--the-arg-nauts/)
- [Migration "Assistant"](https://www.nonpunctual.org/posts/migration-assisstant/)
- [No Free Space For Complexity](https://www.nonpunctual.org/posts/no-free-space-for-complexity/)
- [Removing System Roots (is probably a bad idea)](https://www.nonpunctual.org/posts/removing-system-roots-is-probably-a-bad-idea/)
- [Remember That Time You Wanted All Of Your Self Service Display Names To Actually Match Your Policy Names?](https://www.nonpunctual.org/posts/self-service-display-names/)
- [Super Size Me](https://www.nonpunctual.org/posts/super-size-me/)
- [Surfin' Safari](https://www.nonpunctual.org/posts/surfin-safari/)
- [The Date Command Is Pretty Hard To Use](https://www.nonpunctual.org/posts/the-date-command-is-pretty-hard-to-use/)
- [The networkQuality Is Not Strained](https://www.nonpunctual.org/posts/the-networkquality-is-not-strained/)
- [Thinking About Extension Attributes](https://www.nonpunctual.org/posts/thinking-about-extension-attributes/)
- [Unify Your macOS Terminal Command History](https://www.nonpunctual.org/posts/unify-your-macos-terminal-command-history/)
- [UTI: Uncomfortable In Any Context](https://www.nonpunctual.org/posts/uti-uncomfortable-in-any-context/)
- [Yule Logging](https://www.nonpunctual.org/posts/yule-logging/)
