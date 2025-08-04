#!/bin/bash

# --- Constants ---
RED='\033[0;31m'
NC='\033[0m'

install () {
  cd ~/$install_dir
  git clone "https://aur.archlinux.org/$1.git"
  cd "$1"
  curl -fsSL "https://aur.archlinux.org/cgit/aur.git/plain/PKGBUILD?h=$1"
}


# --- Main Logic ---
if ["$1" == "-S"]
then
  echo -e "${RED}WARNING: AUR PACKAGES ARE DANGEROUS${NC}"
  read -rp "Continue? [y/N]: " CONT
  
  if [ "$CONT" == "" || "$CONT" == "N"]
  then 
    echo "Aborting ..."
    exit;
  fi
    
fi

