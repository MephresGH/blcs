#!/usr/bin/env bash

# shellcheck disable=SC2062,SC2061
IFS=$'\n'

install_kernel() {
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
	dir=$(ls -d "$SCRIPTPATH"/"$directory")

	if ! cd "$dir"; then
		printf "\nError: directory doesn't exist, exiting...\n"
		exit 1
	fi

	while :; do
		printf "%s" "What do you want to do here? \
([B]uild/Open [M]enu + [B]uild [CHOOSE MENU]/[M]enu/[D]efault Setup/[C]lear/Back to [P]revious Menu) "
		read -r bdcp conf
		case "$bdcp" in
		[Bb])
			git branch -r

			if ! make -j"$threads"; then
				make clean -j"$threads"
				make -j"$threads"
			fi

			install_kernel
			;;
		"mb" | "MB")
			git branch -r

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
		while :; do
			printf "Do you want to update your Linux kernel, only build, or exit? "
			read -rp "([U]pdate|RETURN/[B]uild/[S]how Newest Version/[E]xit) " ubse
			case "$ubse" in
			[Uu] | "")
				[[ -f "$old_dir"/.config ]] && cp -i "$old_dir"/.config .

				while :; do
					printf "Do you want to download the master, release-candidate, or stable branch, or specify a tag? "
					read -rp "(M/R/S/[INPUT]) " mrs
					case "$mrs" in
					[Mm])
						kernel_name="newest master kernel"
						branch="master"
						version="${version_array[0]/-rc/.0-rc}"
						break
						;;
					[Rr])
						kernel_name="newest release-candidate kernel"
						branch="v${version_array[0]}"
						version="${version_array[0]/-rc/.0-rc}"
						break
						;;
					[Ss])
						kernel_name="newest stable kernel"
						branch="linux-rolling-stable"
						version="${version_array[1]}"
						break
						;;
					*)
						kernel_name="$mrs kernel tag"
						printf "Checking if the tag '%s' kernel exists...\n" "$mrs"

						if curl -L https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/refs/tags 2>&1 | grep -q "linux-$mrs"; then
							branch="v$mrs"
							break
						else
							printf "\nError: tag '%s' not found\n" "$mrs"
						fi
						;;
					esac
				done

				if grep -E 'stable|tag' <<< "$kernel_name"; then
					kernel_link="https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git"
				else
					kernel_link="https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git"
				fi

				printf "Checking if newest kernel is already installed...\n"

				if [[ "$skip_check" == 1 ]]; then
					printf "Skipping check...\n"
				else
					if sudo find /boot/ -name vmlinuz* -exec file {} \; | grep -w "version $version" | sort -VC; then
						printf "Current version is up-to-date or newer, exiting...\n"
						exit 2
					else
						printf "Kernel is outdated, updating the Linux kernel...\n"
					fi

				fi

				if [[ "$second_input" == -[Ee] ]]; then
					if [[ "$branch" ]]; then
						directory="blcs_kernel-$branch"
					else
						directory="blcs_kernel-$version"
					fi
				else
					directory="blcs_kernel"
				fi

				printf "Downloading the %s (%s)...\n" "$kernel_name" "$version"

				if [[ ! -d "$directory" ]]; then
					git clone --branch "$branch" "$kernel_link" --depth=1 "$directory"
					cp "$SCRIPTPATH"/.config "$SCRIPTPATH"/"$directory"
				fi

				if ! cd "$SCRIPTPATH"/"$directory"; then
					printf "\nError: directory doesn't exist, exiting...\n"
					exit 1
				fi

				if ! git branch -r | grep "$branch"; then
					git remote add "$branch" "$kernel_link" >/dev/null
				fi

				git fetch origin --depth=1 "$branch"
				git reset --hard FETCH_HEAD
				git checkout HEAD
				break 1
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

first_input="$1"
second_input="$2"
skip_check=0

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
-[Uu]) ;;
-[Hh] | --help | "")
	printf "Usage: update <option> \
	\n\nPrimary options:\n-F, --force\t\tUpdate local kernel git regardless of status \
	\n-B, --build\t\tBuild a custom kernel if local git was found \
	\n-U, --update\t\tDo a regular update first, then build \
	\n-H, --help\t\tDisplay this help message \
	\n\nSecondary options:\n-E, --extend\t\tExtend name instead of using 'blcs_kernel' for git kernel directory\n"
	exit
	;;
*)
	printf "Error: %s is not a valid primary parameter\n" "$first_input"
	exit 1
	;;
esac

if [[ "$second_input" == -[Ee] ]]; then
	printf "%s flag has been used, adjusting git folder to include full tag name...\n" "$second_input"
elif [[ "$second_input" == "" ]]; then
	:
else
	printf "Error: %s is not a valid secondary parameter\n" "$second_input"
	exit 1
fi

SCRIPTPATH=$(readlink -f "$0" | xargs dirname)
old_dir=$(find ./blcs_kernel* -type d 2>/dev/null | head -n1)
active_ver=$(uname -r)
mapfile -t version_array < <(
	curl -s https://www.kernel.org | grep -A1 'mainline:' | grep -oPm1 '(?<=strong>).*(?=</strong.*)'
	curl -s https://www.kernel.org | grep -A1 'stable:' | grep -oPm1 '(?<=strong>).*(?=</strong.*)'
	curl -s https://www.kernel.org | grep -A1 'longterm:' | grep -oPm1 '(?<=strong>).*(?=</strong.*)'
)

if [[ "$build" ]]; then
	build_kernel
else
	startup
fi
