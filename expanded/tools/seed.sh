#!/bin/sh
# ensure_seed — put a pinned bootstrap seed binary in place, or fail loudly.
#
# Sourced, not run:  . "$EXP/tools/seed.sh"  then  ensure_seed v1c  and use the
# path it leaves in $SEED.  Callers are test/run2.sh, test/selfcheck.sh,
# test/gtools.sh and tools/golfc.
#
# The seed is NOT in the repository.  ../SEEDS pins a release tag, an asset name
# and a sha256 for each; a missing seed is downloaded from that release and
# checked against the pin.  This is the only thing the expanded tree takes from
# the frozen v1 language — the templates and the seed's own source are in-tree
# data (data/v1.hex, self/seed.golfv1), so nothing else here needs a network.
#
# Overrides, both deliberate and both announced on stderr:
#
#   GOLF_V1C=/path/to/v1c   use that binary instead, no download, no hash check.
#                           For working offline, or for testing a v1c you built
#                           yourself from the `minimal` branch.
#   ./v1c already present    used as-is; a hash that differs from the pin is a
#                           note, not an error (you put it there on purpose).
#
# A pin that has not been filled in yet — all zeros, before the first release —
# is a hard error naming what to do about it, not a silent skip.

seed_sha256() {
	if command -v sha256sum >/dev/null 2>&1; then
		sha256sum "$1" | cut -d' ' -f1
	else
		shasum -a 256 "$1" | cut -d' ' -f1
	fi
}

# ensure_seed <name> — resolve <name> per ../SEEDS; leaves the path in $SEED.
ensure_seed() {
	seed_name="$1"
	# SEED_ROOT is the repository root — where ./SEEDS and the seed binaries
	# live.  A sourced file cannot portably find its own path, so the caller
	# sets it; every caller already knows where it is.
	if [ -z "${SEED_ROOT:-}" ]; then
		echo "seed.sh: SEED_ROOT is not set (the caller must point it at the repo root)" >&2
		return 1
	fi
	seed_root=$SEED_ROOT
	seed_file="$seed_root/$seed_name"

	# An explicit override wins outright, and says so.
	eval "seed_override=\${GOLF_$(printf '%s' "$seed_name" | tr '[:lower:]' '[:upper:]'):-}"
	if [ -n "$seed_override" ]; then
		if [ ! -x "$seed_override" ]; then
			echo "seed.sh: GOLF_${seed_name} is set to '$seed_override', which is not executable" >&2
			return 1
		fi
		echo "seed.sh: using $seed_name from the environment: $seed_override" >&2
		SEED=$seed_override
		return 0
	fi

	set -- $(awk -v f="$seed_name" '$1 == f { print $2, $3, $4 }' "$seed_root/SEEDS")
	if [ -z "${3:-}" ]; then
		echo "seed.sh: no SEEDS entry for '$seed_name'" >&2
		return 1
	fi
	seed_tag=$1 seed_asset=$2 seed_want=$3

	case "$seed_want" in
	0000000000000000000000000000000000000000000000000000000000000000)
		cat >&2 <<EOF
seed.sh: SEEDS has no sha256 for '$seed_name' yet.

  The pin is filled in once the '$seed_tag' release exists.  Cut it from the
  \`minimal\` branch (git tag $seed_tag && git push origin $seed_tag), copy the
  hash out of the release's SHA256SUMS, and put it in ./SEEDS.

  To work before then, build v1c from the minimal branch and point at it:
      GOLF_V1C=/path/to/v1c bash expanded/test/run2.sh
EOF
		return 1
		;;
	esac

	if [ ! -f "$seed_file" ]; then
		echo "seed.sh: downloading $seed_name from release $seed_tag" >&2
		seed_url="https://github.com/reardan/golf/releases/download/$seed_tag/$seed_asset"
		if command -v curl >/dev/null 2>&1; then
			curl -fsSL -o "$seed_file.download" "$seed_url" || {
				rm -f "$seed_file.download"
				echo "seed.sh: could not download $seed_url" >&2
				return 1
			}
		else
			wget -qO "$seed_file.download" "$seed_url" || {
				rm -f "$seed_file.download"
				echo "seed.sh: could not download $seed_url" >&2
				return 1
			}
		fi
		seed_got=$(seed_sha256 "$seed_file.download")
		if [ "$seed_got" != "$seed_want" ]; then
			rm -f "$seed_file.download"
			echo "seed.sh: $seed_name does not match the sha256 pinned in SEEDS; refusing to run it" >&2
			echo "seed.sh:   want $seed_want" >&2
			echo "seed.sh:   got  $seed_got" >&2
			return 1
		fi
		chmod +x "$seed_file.download"
		mv -f "$seed_file.download" "$seed_file"
	elif [ "$(seed_sha256 "$seed_file")" != "$seed_want" ]; then
		echo "seed.sh: note: $seed_name differs from its SEEDS pin (rm $seed_file to re-download)" >&2
	fi

	[ -x "$seed_file" ] || chmod +x "$seed_file"
	SEED=$seed_file
}
