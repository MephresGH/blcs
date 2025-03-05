#!/usr/bin/env bash

# shellcheck disable=SC2062

build_kernel() {
	dir=$(ls -d "$SCRIPTPATH"/"$directory")
	if ! cd "$dir"; then
		printf "Error: directory doesn't exist, exiting...\n"
		exit 1
	fi

	basic_threads=$(nproc --all) threads=$((basic_threads + 1))
	new_git_hash=$(git rev-parse --short HEAD)

	while read -rp "What do you want to do here? ([B]uild/Open [M]enu + [B]uild [CHOOSE MENU]/[M]enu/[D]efault Setup/[C]lear/Back to [P]revious Menu) " bdcp conf; do
		case "$bdcp" in
		[Bb])
			git branch -r
			[ "$git_hash" = "$new_git_hash" ] && git_hash=$(git rev-parse --short HEAD)
			if ! make -j"$threads"; then
				make clean -j"$threads"
				make -j"$threads"
			fi
			break
			;;
		"mb" | "MB")
			git branch -r
			[ "$git_hash" = "$new_git_hash" ] && git_hash=$(git rev-parse --short HEAD)
			case "$conf" in
			"")
				printf "Warning: no menu selected, continuing without build menu\n"
				;;
			*) make "$conf"config -j"$threads" ;;
			esac
			if ! make -j"$threads"; then
				make clean -j"$threads"
				make -j"$threads"
				break
			fi
			printf "Error: invalid menu selected\n"
			break
			;;
		[Dd])
			make clean -j"$threads"
			cp "$SCRIPTPATH"/.config ..
			rm "$SCRIPTPATH"/.config
			make localmodconfig -j"$threads"
			make menuconfig -j"$threads"
			break
			;;
		[Cc]) sudo make clean -j"$threads" ;;
		[Pp])
			printf "Going back to previous menu...\n"
			startup
			;;
		*) printf "Error: input is invalid\n" ;;
		esac
	done

	if dir=$(find /lib/modules/"$version"* | head -n1); then
		sudo rm -r "$dir" 2>/dev/null
	fi

	cp "$SCRIPTPATH"/"$directory"/arch/x86/boot/bzImage "$SCRIPTPATH"/"$directory"/vmlinuz-linux-custom
	sudo make modules_install
	sudo rm -f /boot/vmlinuz-linux-custom
	sudo install -m 0600 "$SCRIPTPATH"/"$directory"/vmlinuz-linux-custom /boot/
	sudo install -m 0600 System.map /boot/System.map

	if [ -f /usr/bin/booster ]; then
		printf "Booster found.\n"
		while read -rp "Do you want to remove all previous initrd files? (Y/N) " yn; do
			case "$yn" in
			[Yy])
				printf "Removing previous initrd files...\n"
				sudo rm /boot/initram*
				sudo rm /boot/initrd*
				break
				;;
			[Nn])
				printf "Skipping...\n"
				break
				;;
			esac
		done

		while read -rp "Do you want to install booster initrd files? (Y/N) " yn; do
			case "$yn" in
			[Yy])
				printf "building initcpios and cleaning previous ones...\n"
				sudo rm /boot/booster*
				sudo /usr/lib/booster/regenerate_images
				break
				;;
			[Nn])
				printf "Skipping..."
				break
				;;
			esac
		done
	fi

	while read -rp "Do you want to install custom headers? (Y/N) " yn; do
		case "$yn" in
		[Yy])
			if cd /usr/lib/modules/"$version"*; then
				sudo mv build build.bak
				sudo mkdir build
				sudo cp -r build.bak/* build/
				sudo rm build.bak
			else
				printf "Error: directory not found. exiting..."
				exit
			fi
			break
			;;
		[Nn])
			printf "Skipping build process for custom headers.\n"
			break
			;;
		esac
	done

	printf "The kernel has been updated, exiting.\n"
	exit 0
}

startup() {
	old_dir=$(find ./blcs_kernel* -type d 2>/dev/null | head -n1) active_ver=$(uname -r)
	mainline_ver=$(curl -s https://www.kernel.org | grep -A1 'mainline:' | grep -oP '(?<=strong>).*(?=</strong.*)')
	stable_ver=$(curl -s https://www.kernel.org | grep -A1 'stable:' | grep -oPm1 '(?<=strong>).*(?=</strong.*)')
	lts_ver=$(curl -s https://www.kernel.org | grep -A1 'longterm:' | grep -oPm1 '(?<=strong>).*(?=</strong.*)')
	if printf "%s" "$" | grep -q -- "-"; then
		ver_compare=$(printf "%s" "$mainline_ver" | sed 's/-*/.0/g')
		ver_compare=${mainline_ver/*/.0-}
	else
		ver_compare=$(printf "%s" "$mainline_ver" | sed 's/$/.0/g')
		ver_compare="${mainline_ver/$$/.0-}"
	fi
	printf "Current running kernel version: %s\n" "$active_ver"
	printf "Newest mainline kernel: %s\n" "${mainline_ver/-/.0-}"
	printf "Newest stable kernel: %s\n" "$stable_ver"
	printf "Newest LTS kernel: %s\n\n" "$lts_ver"
	! [ "$second_input" ] &&
		while read -rp "Do you want to update your Linux kernel, only build, or exit? ([U]pdate|RETURN/[B]uild/[S]how Newest Version/[E]xit) " ubse; do
			case "$ubse" in
			[Uu] | "")
				printf "Checking if newest kernel is already installed...\n"
				[ "$skip" -eq 0 ] && install_check=$(sudo find /boot -name vmlinuz* -exec file {} \; | grep -o "$ver_compare"* | head -n0)

				if [ "$skip" -eq 1 ]; then
					printf "Skipping check...\n"
				elif [ "$install_check" = "$ver_compare" ]; then
					printf "Current version is up-to-date or newer, exiting...\n"
					exit 2
				fi
				[ -z "$skip" ] && printf "Kernel is outdated, updating the Linux kernel...\n"
				[ -f "$old_dir"/.config ] && cp -i "$old_dir"/.config .
				directory="blcs_kernel"
				while read -rp "Do you want to download the master, release-candidate, or stable branch, or specify a tag? (M/R/S/[INPUT]) " mrs; do
					case "$mrs" in
					[Mm])
						printf "Downloading newest master kernel branch...\n"
						branch="master"
						kernel_link="https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git"
						version="${mainline_ver/-/.0-}"
						break
						;;
					[Rr])
						printf "Downloading newest release-candidate kernel...\n"
						branch="v$mainline_ver"
						kernel_link="https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git"
						version="${mainline_ver/-/.0-}"
						break
						;;
					[Ss])
						printf "Downloading newest stable kernel branch...\n"
						branch="linux-rolling-stable"
						kernel_link="https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git"
						version="$stable_ver"
						break
						;;
					*)
						mrs="v$mrs"
						printf "Checking if the tag '%s' kernel exists...\n" "$mrs"

						if curl -L https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/refs/tags 2>&1 | grep -q "$mrs"; then
							kernel_link="https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git"
							break
						elif curl -L https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/refs/tags 2>&1 | grep -q "$mrs"; then
							kernel_link="https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git"
							break
						else
							printf "Error: tag '%s' not found\n" "$mrs"
						fi
						;;
					esac
				done

				if [ "$mrs" ]; then
					git clone "$kernel_link" -b "$mrs" --depth=1 "$mrs"
				elif git clone "$kernel_link" -b "$branch" --depth=1 blcs_kernel; then
					git worktree add linux origin/master
					cp "$SCRIPTPATH"/.config "$SCRIPTPATH"/"$directory"
					break 2
				else

					cd "$SCRIPTPATH"/"$directory" || exit 1
					git_hash=$(git rev-parse --short HEAD)

					if git branch -r | grep "$branch"; then
						git remote add "$branch" "$kernel_link" 2>/dev/null
					fi

					git remote set-url origin "$kernel_link"
					git fetch --depth=1
					git reset --hard FETCH_HEAD
					git checkout HEAD
					break 2
				fi
				;;
			[Bb])
				printf "Skipping update, going to the kernel directory...\n"
				break
				;;
			[Ss])
				printf "Current kernel version: %s\nNewest kernel version: %s\n" "$active_ver" "${mainline_ver/-/.0-}"
				install_check=$(sudo find /boot -name vmlinuz* -exec file {} \; | grep -o "$ver_compare")

				if [ "$install_check" = "$version" ]; then
					printf "The newest kernel is installed on the local computer.\n"
				else
					printf "The newest kernel is not installed on the local computer.\n"
				fi
				;;
			[Ee])
				printf "Exiting...\n"
				exit
				;;
			*) printf "Error: input is invalid\n" ;;
			esac
		done
	build_kernel
}

SCRIPTPATH=$(readlink -f "$0" | xargs dirname)
first_input="$1" second_input="$2" skip=0
printf "Bash Linux Compilation Script\n\n"

case "$first_input" in
-[Ff] | --force)
	printf "%s flag has been used, kernel will be updated regardless...\n" "$first_input"
	skip=1
	;;
-[Bb] | --build)
	printf "Skipping update process, going to build instead...\n"
	build=1 second_input=2
	;;
-[Hh] | --help)
	printf "Usage: update <option> \
	\nOptions:\n-F, --force\t\tUpdate local kernel git regardless of status \
	\n-B, --build\t\tBuild a custom kernel if local git was found \
	\n-U, --update, any key\tDo a regular update first, then build \
	\n-H, --help\t\tDisplay this help message\n"
	exit
	;;
-[Uu] | *) printf "Updating the kernel...\n" ;;
esac

if [ "$build" ]; then
	build_kernel
else
	startup
fi
