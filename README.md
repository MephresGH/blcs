# Bash Linux Compilation Script

### INTRODUCTION
Bash Linux Compilation Script (BLCS) is a basic script that allows you to compile a regular Linux kernel in a streamlined way.
The purpose of this project is to provide a more basic alternative to linux-tkg, not including any patches or config files.

### DEPENDENCIES
The following tools are required to run BLCS:
- booster (initramfs generator; optional)
- dracut (initramfs generator; optional)
- git
- GNU coreutils
- GNU make
- GNU findutils
- mkinitcpio (initramfs generator; optional)

Not having any of those programs will lead to errors. Ensure everything mentioned is installed.

### CONFIGURATION
The Linux kernel configuration options are given to the user via the ability to select configuration menus, such as menuconfig (ncurses),
xconfig, gconfig, nconfig and (old)config.

### SETUP
BLCS is a simple script that can be downloaded via Git's clone feature downloading the project from GitHub.
To download this project, you can run this command:

`git clone https://github.com/MephresGH/blcs blcs_kernel`, or:

`git clone https://github.com/MephresGH/blcs --depth=1 blcs_kernel`

### NOTE OF INTEREST
BLCS is a work-in-progress and not yet stable enough for a proper release. For feature requests, please make use of pull requests.
Any and all bugs, errors, or oversights should be reported through issues.
Finally, this project is licensed under the GNU GPL-3.0. Any legal and copyright-related information can be found there.
