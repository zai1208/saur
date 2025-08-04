#!/bin/bash

# --- Constants ---
RED='\033[0;31m'
NC='\033[0m'

confirm() {
  local prompt="$1"
  local response
  read -rp "$prompt [y/N]: " response
  if [[ "$response" != [yY] ]]; then
    echo "Aborting ..."
    exit 1
  fi
}

install () {
  echo -e "${RED}Since this is an AUR package, saur will enforce viewing the PKGBUILD, it will be displayed using less, you can press Q to exit less and will be asked for confirmation before continuing${NC}\n"
  read -n 1 -s -r -p "Press any key to continue..."
  curl -fsSL "https://aur.archlinux.org/cgit/aur.git/plain/PKGBUILD?h=$1" | bat
  echo
  continue "Do you want to continue?"

  continue "Have you verified that the PKGBUILD is safe and wish to continue? [y/N]"

  cd ~/$install_dir
  git clone "https://aur.archlinux.org/$1.git"
  cd "$1"
  makepkg -si
}


# --- Main Logic ---
if [ "$1" == "-S" ]
then
  echo -e "${RED}WARNING: AUR PACKAGES ARE DANGEROUS${NC}"
  continue "Continue?"

  install $2
fi

