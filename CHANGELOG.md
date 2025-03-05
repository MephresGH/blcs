# What's Changed

[0.3] - 2025.02.10

## Changes

- Remove git worktree command
- Add newline for error messages
- Trim build_kernel() function; add install_kernel() function
- Add newline for every variable
- Change /lib/ to /usr/lib/ in find command
- Install custom headers before creating initramfs
- Copy vmlinuz over to /usr/lib/modules directory
- Add pkgbase to modules directory

[0.2.1-hotfix] - 2025.01.31

## Changes
- Reverted removal of "$tag" variable in 68cbd0f6
- ACTUALLY fixed the custom tag check functionality

[0.2] - 2025.01.30

## Changes
- Add a "v" in front of the "$mrs" variable to make tag checks more robust
- Remove unnecessary "tag" variable

[0.1.1-hotfix] - 2025.01.19

## Changes
- Fix wrong links in tag condition check
- Minor readme changes
- Update CHANGELOG.md

[0.1.1] - 2025.01.14

## Changes

- Minor cleanup
- Implement basic tag specification functionality

## Additions

- Basic changelog

[0.1] - 2025.01.12

## Additions

- Initial commit
