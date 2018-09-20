# Change Log
## 1.7.0
### Added
- (maint) - Work around for [BOLT-845](https://tickets.puppetlabs.com/browse/BOLT-845), installing ffi on el5 machines).
- Bump bolt version from `0.22.0` to `0.23.0` to include fix for [BOLT-844](https://tickets.puppetlabs.com/browse/BOLT-844).

## 1.6.0
### Fixed
- Updates host from `localhost` to `127.0.0.1`.

### Added
- `BOLT_VERSION` is now dependent on Puppet version.
- `bolt_path` is now dependent on Puppet version.

## 1.5.2
### Added
- Add support for AlwaysBeScheduling hypervisor to `Beaker::TaskHelper::Inventory.hosts_to_inventory`.

## 1.5.1
### Added
- Include CHANGELOG.md entry for previous release.

## 1.5.0
### Added
- `Beaker::TaskHelper::Inventory.hosts_to_inventory` creates an inventory hash from beaker hosts.

## 1.4.5
### Fixed
- Windows path to bolt

## 1.4.4
This version is not semver.
### Added
- Ability to pass a custom path to bolt
- `setup_ssh_access` method to setup task ssh access on linux hosts.

## 1.4.3
### Fixed
- Handle default password when no host has a "default" role.

## 1.4.2
No changes.

## 1.4.1
This version is not semver.
### Changed
- Require `beaker-task_helper` instead of `beaker/task_helper` now.

### Fixed
- Use beaker's version_is_less rather than puppet's versioncmp

## v1.4.0
### Added
- `BEAKER_password` variable for remote tasks.

### Fixed
- Fix windows on bolt >=0.16.0
- Fix json output format.

## v1.3.0
### Added
- Cleaning up the README
- Making compatible with bolt versions greater than 0.15.0
- Pinning bolt install version to 0.16.1

## 1.2.0
### Added
- run_task now takes host as a parameter.
- task_summary_line provides a generic way for checking bolt or pe success.
- Tests added

## 1.1.0
### Added
- Better windows support.
- Make source for gem an argument.

## 1.0.1
### Fixed
- Fix license and point to the correct github URL.

## 1.0.0
- Initial release, helper methods to run bolt or pe tasks.
