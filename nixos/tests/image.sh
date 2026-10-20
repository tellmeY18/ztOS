#!/bin/sh
# Structural checks for the starlte image, so CI can reject an image that
# cannot be flashed or booted before anyone touches a phone.
set -eu

dir=${1:-.}
rootfs=$dir/rootfs.img
boot=$dir/boot.img

fail() {
	echo "FAIL: $*" >&2
	exit 1
}

[ -f "$rootfs" ] || fail "missing $rootfs"
[ -f "$boot" ] || fail "missing $boot"
[ -f "$dir/flash.sh" ] || fail "missing $dir/flash.sh"
[ -f "$dir/build.json" ] || fail "missing $dir/build.json"

label=$(dumpe2fs -h "$rootfs" 2>/dev/null | sed -n 's/^Filesystem volume name: *//p')
[ "$label" = "ZR_ARCH" ] || fail "root filesystem label is '$label', expected ZR_ARCH"

# debugfs only prints the target of a fast symlink in `stat`; store paths are
# long enough to be slow symlinks, so read the link contents directly.
debugfs -R 'cat /sbin/init' "$rootfs" 2>/dev/null | grep -q 'nixos-system-ztos' ||
	fail "/sbin/init does not point at a nixos-system-ztos closure"
debugfs -R 'stat /etc' "$rootfs" 2>/dev/null | grep -q 'Type: directory' ||
	fail "/etc is not a directory"
debugfs -R 'stat /nix/store' "$rootfs" 2>/dev/null | grep -q 'Type: directory' ||
	fail "/nix/store is missing"
debugfs -R 'stat /nix-path-registration' "$rootfs" 2>/dev/null | grep -q 'Type: regular' ||
	fail "/nix-path-registration is missing"
debugfs -R 'stat /lib/firmware' "$rootfs" 2>/dev/null | grep -q 'Type: directory' ||
	fail "/lib/firmware is missing"
debugfs -R 'stat /lib/modules/7.1.0-zboot/extra/zrn-modem.ko' "$rootfs" 2>/dev/null |
	grep -q 'Type: regular' || fail "the 7.1.0-zboot modules are missing"
debugfs -R 'stat /lib/modules/7.1.0-zboot/modules.dep' "$rootfs" 2>/dev/null |
	grep -q 'Type: regular' || fail "modules.dep is missing"

[ "$(head -n 1 "$dir/flash.sh")" = "#!/bin/sh" ] || fail "flash.sh has no shebang"
sh -n "$dir/flash.sh" || fail "flash.sh is not valid shell"

jq -e '.codename == "starlte" and .rootfs_label == "ZR_ARCH" and .kernel == "7.1.0-zboot"' \
	"$dir/build.json" >/dev/null || fail "build.json does not describe the starlte image"

size=$(wc -c <"$rootfs")
[ "$size" -gt 100000000 ] || fail "rootfs.img is only $size bytes"

if [ -f "$dir/SHA256SUMS" ]; then
	(cd "$dir" && sha256sum -c SHA256SUMS)
fi

echo "OK: $rootfs ($size bytes), label $label, boot image present"
