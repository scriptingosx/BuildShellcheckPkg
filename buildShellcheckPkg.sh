#!/bin/bash

export PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

# Build Shellcheck Package installer

# 2019 Armin Briegel - Scripting OS X

# this script will install all the required tools to build a binary for shellcheck
# https://github.com/koalaman/shellcheck
#
# after building the binary and man page it will build an installer pkg


# more variables

pkgname="shellcheck"
identifier="com.scriptingosx.pkg.shellcheck"
install_location="/usr/"

# warn the user

echo "WARNING:"
echo "This script will install several tools, including brew, so it can build a current"
echo "binary and installer package for the shellcheck tool."
echo
echo "Do NOT run this on your production machine, unless you are really sure."
echo

read -r -p "Are you sure you want to continue? (Y/n) " reply

if [[ $reply != 'Y' ]]; then
    echo "Cancelling..."
    exit 1
fi

# cancel if running as root
if [[ $EUID -eq 0 ]]; then
    echo "this script should NOT run as root."
    exit 1
fi

# requires brew
brew="/usr/local/bin/brew"
if [[ ! -x $brew ]]; then
    echo
    echo "Could not find brew."
    echo "When prompted, please enter password to install brew."
    echo
    
    # install brew, command from https://brew.sh
    ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
else
    echo
    echo "found brew at '$brew'"
    echo
fi

# installing brew will also take care of developer command line tools

# requires cabal
cabal="/usr/local/bin/cabal"
if [[ ! -x "$cabal" ]]; then
    echo
    echo "Installing ghc cabal"
    echo 
    
    "$brew" install ghc cabal-install
else
    echo
    echo "found cabal at '$cabal'"
    echo
fi

# requires pandoc
pandoc="/usr/local/bin/pandoc"
if [[ ! -x "$pandoc" ]]; then
    echo
    echo "Installing pandoc"
    echo 
    
    "$brew" install pandoc
else
    echo
    echo "found pandoc at '$pandoc'"
    echo
fi

# setup the directories
projectdir=$(dirname "$0")
# replace '.' in the path
projectdir=$(python -c "import os; print(os.path.realpath('${projectdir}'))")

downloaddir="${projectdir}/downloads"
if [[ ! -d "$downloaddir" ]]; then
    mkdir -p "$downloaddir"
fi

builddir="${projectdir}/build"
if [[ ! -d "$builddir" ]]; then
    mkdir -p "$builddir"
fi

payloaddir="${projectdir}/payload"
if [[ ! -d "$payloaddir" ]]; then
    mkdir -p "$payloaddir"
fi

# clone shellcheck repo
cd "$downloaddir" || exit 2

echo
echo "cloning shellcheck repo"
echo

shellcheckdir="$downloaddir/shellcheck"

if [[ -d "$shellcheckdir" ]]; then
    cd "$shellcheckdir" || exit 2
    git fetch
else
    git clone "https://github.com/koalaman/shellcheck.git"
fi

if [[ ! -d "$shellcheckdir" ]]; then
    echo
    echo "something went wrong cloning or updating shellcheck repo"
    
    exit 1
fi

# update cabal packages
if ! "$cabal" update; then
    echo "could not update cabal packages"
    exit 3
fi

# build shellcheck
cd "$shellcheckdir" || exit 2
"$cabal" install --bindir="$builddir"

shellcheck="$builddir/shellcheck"
if [[ ! -x $shellcheck ]]; then
    echo "could not build or find shellcheck binary"
    exit 4
fi

# get the version
version=$("$shellcheck" --version | awk '/version:/ {print $2}')

# build man page
"$pandoc" -s -f markdown-smart -t man "$shellcheckdir"/shellcheck.1.md -o "$builddir"/shellcheck.1

# assemble the payload

# base dir is /usr
mkdir -p "$payloaddir/local/bin"
cp "$shellcheck" "$payloaddir/local/bin/"
mkdir -p "$payloaddir/share/man/man1"
cp "$builddir/shellcheck.1" "$payloaddir/share/man/man1/"


# build the pkg

echo "building the package"
pkgpath="$builddir/$pkgname-$version.pkg"

pkgbuild --root "$payloaddir" \
         --install-location "$install_location" \
         --identifier "$identifier" \
         --version "$version" \
         "$pkgpath"

# reveal pkg in Finder
if [[ -e "$pkgpath" ]]; then
    open -R "$pkgpath"
fi



