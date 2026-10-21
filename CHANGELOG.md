# Changelog

## Unreleased

### Fixed

- `dns-check.sh` rejects unknown record types instead of letting `dig` silently query `A`.
- `dns-check.sh` performs a reverse lookup for `PTR` checks of IP addresses.
- `dns-check.sh` rejects hostnames with spaces or empty labels with exit code `2`.
- `web-check.sh` ignores `~/.curlrc`, so certificate verification cannot be disabled there.
- `toolbox.ps1` passes quotes and empty arguments intact on Windows PowerShell 5.1.

### Changed

- Smoke checks assert exact exit codes and cover DNS, TLS, redirects, and timeouts offline.
- Added launcher checks, run in CI with standard and Windows PowerShell 5.1 argument passing.
- CI lints Bash scripts with ShellCheck.

## 1.0.0

### Added

- Ubuntu 24.04 image with DNS, TCP, HTTP, TLS, routing, packet-capture, and Python utilities.
- Trusted CA certificates and Python virtual-environment support.
- PowerShell launcher with configurable image and persistent work directory.
- DNS, TCP-port, and HTTP helper scripts with argument validation and timeouts.
- Build instructions, architecture overview, utility reference, and local troubleshooting examples.
- Offline container smoke checks and GitHub Actions build validation.
- Source-control and build-context exclusions for local reports and sensitive files.
- MIT license with image license metadata and an included license file.
