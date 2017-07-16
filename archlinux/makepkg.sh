#! /bin/bash

set -ex

cd "$(dirname "$0")"
. ./PKGBUILD
src="src/$pkgname"
rm -rf src pkg
mkdir -p "$src"
cp PKGBUILD PKGBUILD.tmp
(cd "$OLDPWD" && git ls-files -z | xargs -0 cp -a --no-dereference --parents --target-directory="$OLDPWD/$src")
makepkg --{sync,rm}deps --clean --force --noextract -p PKGBUILD.tmp "$@"
rm -f PKGBUILD.tmp
