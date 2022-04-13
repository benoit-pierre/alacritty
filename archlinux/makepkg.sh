#!/bin/bash

set -exo pipefail

opt_args=()
opt_install=0
while [[ $# -ne 0 ]]
do
  case "$1" in
    -i*|-[^-]*i*) opt_install=1 opt_args+=("${1/i}");;
    --install) opt_install=1;;
    *) opt_args+=("$1");;
  esac
  shift
done

cargo_pkgver()
{(
  cd "$1"
  read line version <<<"$(awk -f - Cargo.lock <<\EOF
BEGIN {
  code=1
  state=""
}
/^\[\[package\]\]$/ {
  state = "package"
}
/^$/ {
  if (pkg["name"] == "alacritty") {
    gsub(/-/, ".", pkg["version"])
    print pkg["line"], pkg["version"]
    code=0
    exit
  }
  state=""
  pkg["name"]=""
}
state == "package" && match($0, "^(name|version) = \"([^\"]+)\"$", m) {
  pkg[m[1]] = m[2]
  if (m[1] == "version") pkg["line"] = FNR
}
END {
  exit code
}
EOF
  )"
  read commit _ <<<"$(git blame -p -L "$line,$line" Cargo.lock)"
  revcount="$(git rev-list --count "$commit..")"
  commit="$(git rev-parse --short @)"
  echo "$version.$revcount.g$commit"
)}

cd "$(dirname "$0")"
. ./PKGBUILD
pkgver="$(cargo_pkgver ..)"
srcdir="$pkgname"
rm -rf src pkg
{ sed "s/^pkgver=.*\$/pkgver=$pkgver/" PKGBUILD; echo "source[0]=src.tar"; } >PKGBUILD.tmp
pkgs=($(makepkg --packagelist -p PKGBUILD.tmp | grep -v -- "$pkgname-debug-[0-9]"))
git -C .. ls-files --recurse-submodules -z | tar -C .. --null --exclude="${PWD##*/}" -T - --transform="s,^,$srcdir/,rHS" -cf src.tar
makepkg --clean --force --syncdeps --rmdeps -p PKGBUILD.tmp "${opt_args[@]}"
rm -f PKGBUILD.tmp src.tar
if [[ $opt_install -ne 0 ]]
then
  sudo pacman --color=auto --upgrade -- "${pkgs[@]}"
fi
