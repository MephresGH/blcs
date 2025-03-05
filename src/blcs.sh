#!/usr/bin/env bash

# shellcheck disable=SC2062,SC2061
IFS=$'\n'

install_kernel() {
	printf "%s\n" "$version"
	if dir=$(find /usr/lib/modules/"$version"+ | head -n1); then
		sudo rm -r "$dir"
	fi

	cp "$SCRIPTPATH"/"$directory"/arch/x86/boot/bzImage "$SCRIPTPATH"/"$directory"/vmlinuz-linux-custom
	sudo make modules_install
	sudo rm -f /boot/vmlinuz-linux-custom
	sudo install -m 0600 "$SCRIPTPATH"/"$directory"/vmlinuz-linux-custom /boot/
	sudo install -m 0600 System.map /boot/System.map

	while read -rp "Do you want to install custom headers? (Y/N) " yn; do
		case "$yn" in
		[Yy])
			if cd /usr/lib/modules/"$version"*; then
				sudo mv build build.bak
				sudo mkdir build
				sudo cp -r build.bak/* build/
				sudo cp "$SCRIPTPATH"/pkgbase .
				sudo install -m 644 "/boot/vmlinuz-linux-custom" ./vmlinuz
				sudo rm build.bak
			else
				printf "\nError: directory not found. exiting..."
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

	printf "The kernel has been updated, exiting.\n"
	exit 0
}

build_kernel() {
	IFS=$' \t\n'
	basic_threads=$(nproc --all)
	threads=$((basic_threads + 1))
	new_git_hash=$(git rev-parse --short HEAD)
	dir=$(ls -d "$SCRIPTPATH"/"$directory")

	if ! cd "$dir"; then
		printf "\nError: directory doesn't exist, exiting...\n"
		exit 1
	fi

	while read -rp "What do you want to do here? ([B]uild/Open [M]enu + [B]uild [CHOOSE MENU]/[M]enu/[D]efault Setup/[C]lear/Back to [P]revious Menu) " bdcp conf; do
		case "$bdcp" in
		[Bb])
			git branch -r
			[[ "$git_hash" = "$new_git_hash" ]] && git_hash=$(git rev-parse --short HEAD)

			if ! make -j"$threads"; then
				make clean -j"$threads"
				make -j"$threads"
			fi

			install_kernel
			;;
		"mb" | "MB")
			git branch -r
			[[ "$git_hash" = "$new_git_hash" ]] && git_hash=$(git rev-parse --short HEAD)

			case "$conf" in
			"")
				printf "Warning: no menu selected, continuing without build menu\n"
				;;
			*)
				make "$conf"config -j"$threads"
				;;
			esac

			if ! make -j"$threads"; then
				make clean -j"$threads"
				make -j"$threads"
				install_kernel
			fi

			printf "\nError: invalid menu selected\n"
			install_kernel
			;;
		[Dd])
			make clean -j"$threads"
			cp "$SCRIPTPATH"/.config ..
			rm "$SCRIPTPATH"/.config
			make localmodconfig -j"$threads"
			make menuconfig -j"$threads"
			install_kernel
			;;
		[Cc]) sudo make clean -j"$threads" ;;
		[Pp])
			printf "Going back to previous menu...\n"
			startup
			;;
		*) printf "\nError: input is invalid\n" ;;
		esac
	done
}

startup() {
	printf "Bash Linux Compilation Script\n\n"
	printf "Current running kernel version: %s\n" "$active_ver"
	printf "Newest mainline kernel: %s\n" "${version_array[0]/-/.0-}"
	printf "Newest stable kernel: %s\n" "${version_array[1]}"
	printf "Newest LTS kernel: %s\n\n" "${version_array[2]}"

	if [[ "$skip_update" != "1" ]]; then
		while read -rp "Do you want to update your Linux kernel, only build, or exit? ([U]pdate|RETURN/[B]uild/[S]how Newest Version/[E]xit) " ubse; do
			case "$ubse" in
			[Uu] | "")
				[[ -f "$old_dir"/.config ]] && cp -i "$old_dir"/.config .

				while read -rp "Do you want to download the master, release-candidate, or stable branch, or specify a tag? (M/R/S/[INPUT]) " mrs; do
					case "$mrs" in
					[Mm])
						kernel="newest master kernel"
						branch="master"
						kernel_link="https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git"
						version="${version_array[0]/-rc/.0-rc}"
						break
						;;
					[Rr])
						kernel="newest release-candidate kernel"
						branch="v${version_array[0]}"
						kernel_link="https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git"
						version="${version_array[0]/-rc/.0-rc}"
						break
						;;
					[Ss])
						kernel="newest stable kernel"
						branch="linux-rolling-stable"
						kernel_link="https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git"
						version="${version_array[1]}"
						break
						;;
					*)
						kernel="$mrs kernel tag"
						printf "Checking if the tag '%s' kernel exists...\n" "$mrs"

						if curl -L https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/refs/tags 2>&1 | grep -q "$mrs"; then
							kernel_link="https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git"
							tag="v$mrs"
							break
						elif curl -L https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/refs/tags 2>&1 | grep -q "$mrs"; then
							kernel_link="https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git"
							tag="v$mrs"
							break
						else
							printf "\nError: tag '%s' not found\n" "$mrs"
						fi
						;;
					esac
				done

				printf "Checking if newest kernel is already installed...\n"

				if [[ "$skip_check" == 1 ]]; then
					printf "Skipping check...\n"
				else
					if sudo find /boot/ -name vmlinuz* -exec file {} \; | grep -w "version $version" | sort -VC ||
						sudo find /boot/ -name vmlinuz* -exec file {} \; | grep -w "version $version" | sort -VC; then
						printf "Current version is up-to-date or newer, exiting...\n"
						exit 2
					else
						printf "Kernel is outdated, updating the Linux kernel...\n"
					fi

				fi

				directory="blcs_kernel-${version}"
				printf "Downloading the %s (%s)...\n" "$kernel" "$version"

				if [[ "$tag" ]]; then
					git clone "$kernel_link" -b "$tag" --depth=1 "$tag"
				elif git clone "$kernel_link" -b "$branch" --depth=1 "$directory"; then
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
				printf "Current kernel version: %s\nNewest kernel version: %s\n" "$active_ver" "${version_array[0]/-/.0-}"
				if sudo find /boot/ -name vmlinuz* -exec file {} \; | grep -w "version $version" | sort -VC ||
					sudo find /boot/ -name vmlinuz* -exec file {} \; | grep -w "version $version" | sort -VC; then
					printf "Kernel %s or newer is installed on the local computer.\n" "${version_array[0]/-/.0-}"
				else
					printf "Kernel %s is not installed on the local computer.\n" "${version_array[0]/-/.0-}"
				fi
				;;
			[Ee])
				printf "Exiting...\n"
				exit
				;;
			*) printf "\nError: input is invalid\n" ;;
			esac
		done
		build_kernel
	fi
}

SCRIPTPATH=$(readlink -f "$0" | xargs dirname)
first_input="$1"
second_input="$2"
skip_check=0
old_dir=$(find ./blcs_kernel* -type d 2>/dev/null | head -n1)
active_ver=$(uname -r)
readarray -t version_array < <(
	curl -s https://www.kernel.org | grep -A1 'mainline:' | grep -oP '(?<=strong>).*(?=</strong.*)'
	curl -s https://www.kernel.org | grep -A1 'stable:' | grep -oPm1 '(?<=strong>).*(?=</strong.*)'
	curl -s https://www.kernel.org | grep -A1 'longterm:' | grep -oPm1 '(?<=strong>).*(?=</strong.*)'
)

case "$first_input" in
-[Ff] | --force)
	printf "%s flag has been used, kernel will be updated regardless...\n" "$first_input"
	skip_check=1
	;;
-[Bb] | --build)
	printf "Skipping update process, going to build instead...\n"
	build=1
	skip_update=1
	;;
-[Hh] | --help)
	printf "Usage: update <option> \
	\nOptions:\n-F, --force\t\tUpdate local kernel git regardless of status \
	\n-B, --build\t\tBuild a custom kernel if local git was found \
	\n-U, --update, any key\tDo a regular update first, then build \
	\n-H, --help\t\tDisplay this help message\n"
	exit
	;;
-[Uu] | *) ;;
esac

if [[ "$build" ]]; then
	build_kernel
else
	startup
fi
