#!/bin/sh

export PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

# Build Shellcheck Package installer

# 2019 Armin Briegel - Scripting OS X

# this script will install all the required tools to build a binary for shellcheck
# https://github.com/koalaman/shellcheck
#
# after building the binary and man page it will build an installer pkg


# pkg variables

pkgname="shellcheck"
identifier="com.scriptingosx.pkg.shellcheck"
install_location="/usr/"

# cancel if running as root
if [ "$(id -u)" -eq 0 ]; then
    echo "this script should NOT run as root."
    exit 1
fi

# warn the user

echo "WARNING:"
echo "This script will install several tools, so it can build a current"
echo "binary and installer package for the shellcheck tool."
echo
echo "Do NOT run this on your production machine, unless you are really sure."
echo

echo "Are you sure you want to continue? (Y/n) "
read -r reply

if [ "$reply" != 'Y' ]; then
    echo "Cancelling..."
    exit 1
fi

echo
echo "There will be a few situations where you will be required to enter your password"
echo "for installations or hit a key to proceed."
echo
echo "Hit enter to proceed"

read -r reply

# requires Xcode or Developer Command line tools

echo "## checking for Dev Tools"
if ! xcode-select -p ; then
    echo "this script requires Xcode or the Developer CLI tools to be installed"
    echo "you can install them with "
    echo "$ xcode-select --install"
    exit 1
fi


# setup the directories
projectdir=$(dirname "$0")
# replace '.' in the path
projectdir=$(python -c "import os; print(os.path.realpath('${projectdir}'))")

downloaddir="${projectdir}/downloads"
if [ ! -d "$downloaddir" ]; then
    mkdir -p "$downloaddir"
fi

builddir="${projectdir}/build"
if [ ! -d "$builddir" ]; then
    mkdir -p "$builddir"
fi

payloaddir="${projectdir}/payload"
if [ ! -d "$payloaddir" ]; then
    mkdir -p "$payloaddir"
fi

# xz-utils installed?
if [ ! -x /usr/local/bin/xz ]; then
    echo
    echo "Installing xz"
    echo
    
    # download url is hardcoded,
    # check for latest version at
    # https://tukaani.org/xz/
    
    # download xz-utils
    xzname="xz-5.2.4"
    xzarchive="${xzname}.tar.gz"
    xzarchivepath="$downloaddir/$xzarchive"
    xzarchiveurl="https://tukaani.org/xz/${xzarchive}"

    if [ ! -f "${xzarchivepath}" ]; then
        echo "## downloading $xzarchiveurl to $xzarchivepath"

        if ! curl -L "$xzarchiveurl" -o "${xzarchivepath}"; then
            echo "could not download ${xzarchiveurl}"
            exit 1
        fi
    fi

    # extract xz-utils

    echo "## extracting ${xzarchivepath}"

    if ! tar -xzf "${xzarchivepath}" -C "${builddir}" ; then
        echo "could not extract ${xzarchivepath}"
        exit 1
    fi

    # build and install xz-utils
    if ! cd "$builddir/$xzname" ; then
        echo "something went wrong changing dir to $builddir/$xzname"
        exit 1
    fi

    ./configure --quiet

    echo
    echo "when prompted, please enter the password to install xz"
    sudo make install --quiet
else
    echo "found xz at /usr/local/bin/xz"
fi

# sanity check
if [ ! -x /usr/local/bin/xz ]; then
    echo "something went wrong installing xz-utils"
    exit 1
fi

# download and install pandoc
pandoc="/usr/local/bin/pandoc"
if [ ! -x "$pandoc" ]; then
    echo
    echo "Installing pandoc"
    echo 
    
    # download URL is hardcoded
    # check for latest version at 
    # https://pandoc.org
    # or
    # https://github.com/jgm/pandoc/releases/
    
    pandocversion="2.7.3"
    pandocname="pandoc"
    pandocpkg="${pandocname}-${pandocversion}-macos.pkg"
    pandocpkgpath="$downloaddir/$pandocpkg"
    pandocpkgurl="https://github.com/jgm/pandoc/releases/download/${pandocversion}/${pandocpkg}"
    
    # download pandoc pkg
    if [ ! -f "${pandocpkgpath}" ]; then
        echo "## downloading $pandocpkgurl to $pandocpkgpath"

        if ! curl -L "$pandocpkgurl" -o "${pandocpkgpath}"; then
            echo "could not download ${pandocpkgurl}"
            exit 1
        fi
    fi
    
    # install pandoc
    echo
    echo "when prompted, please enter the password to install pandoc"
    sudo installer -target / -pkg "${pandocpkgpath}"
else
    echo
    echo "found pandoc at '$pandoc'"
    echo
fi

# sanity check
if [ ! -x "$pandoc" ]; then
    echo "something went wrong installing pandoc"
    exit 1
fi


# requires cabal

# try generic cabal location
cabal="/usr/local/bin/cabal"
if [ ! -x "$cabal" ]; then
    # try user cabal location
    cabal="$HOME/.ghcup/bin/cabal"
    if [ ! -x "$cabal" ]; then
        echo
        echo "Installing ghc cabal"
        echo 
    
        # using instructions to install ghcup from
        # https://www.haskell.org/ghcup/
    
        curl https://get-ghcup.haskell.org -sSf | sh
    fi
fi

[ -r "$HOME/.ghcup/env" ] && . "$HOME/.ghcup/env"

# sanity check
if [ -x "$cabal" ]; then
    echo
    echo "found cabal at '$cabal'"
    echo
else
    echo "something went wrong installing cabal"
    exit 1
fi

# clone shellcheck repo
cd "$downloaddir" || exit 2

echo
echo "cloning shellcheck repo"
echo

shellcheckdir="$downloaddir/shellcheck"

if [ -d "$shellcheckdir" ]; then
    cd "$shellcheckdir" || exit 2
    git fetch
else
    git clone "https://github.com/koalaman/shellcheck.git"
fi

if [ ! -d "$shellcheckdir" ]; then
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
if [ ! -x "$shellcheck" ]; then
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
if [ -e "$pkgpath" ]; then
    open -R "$pkgpath"
fi



