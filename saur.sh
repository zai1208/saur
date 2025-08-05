#!/bin/bash

# --- Constants ---
RED='\033[0;31m'
BLUE='\033[0;94m'
NC='\033[0m'

fetch_safety_card() {
  pkg="$1"
  echo -e "${RED}Fetching package metadata from AUR...${NC}"

  json=$(curl -fsSL "https://aur.archlinux.org/rpc/v5/info/$pkg")

  if [[ -z "$json" || "$json" == "null" ]]; then
    echo "Failed to fetch package info."
    return
  fi

  maintainer=$(echo "$json" | jq -r '.results[0].Maintainer')
  submitted=$(echo "$json" | jq -r '.results[0].FirstSubmitted' | xargs -I{} date -d @{} "+%Y-%m-%d")
  updated=$(echo "$json" | jq -r '.results[0].LastModified' | xargs -I{} date -d @{} "+%Y-%m-%d")
  votes=$(echo "$json" | jq -r '.results[0].NumVotes')
  popularity=$(echo "$json" | jq -r '.results[0].Popularity')

  echo -e "\n${RED}==== SAFETY CARD ====${NC}"
  echo -e "${BLUE}Package:${NC}    $pkg"
  echo -e "${BLUE}Maintainer:${NC} $maintainer"
  echo -e "${BLUE}Submitted:${NC}  $submitted"
  echo -e "${BLUE}Last Update:${NC}$updated"
  echo -e "${BLUE}Votes:${NC}      $votes"
  echo -e "${BLUE}Popularity:${NC} $popularity"
  echo -e "${RED}=====================${NC}"
}

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
  echo -e "${RED}Since this is an AUR package, saur will enforce viewing the PKGBUILD, it will be displayed using bat, you can press Q to exit less and will be asked for confirmation before continuing${NC}\n"
  read -n 1 -s -r -p "Press any key to continue..."
  curl -fsSL "https://aur.archlinux.org/cgit/aur.git/plain/PKGBUILD?h=$1" | bat --language=bash
  echo
  confirm "Do you want to continue?"

  confirm "Have you verified that the PKGBUILD is safe and wish to continue?"

  cd ~/$install_dir
  git clone "https://aur.archlinux.org/$1.git"
  cd "$1"
  makepkg -si
}


# --- Main Logic ---
if [ "$1" == "-S" ]
then
  echo -e "${RED}WARNING: AUR PACKAGES ARE DANGEROUS${NC}"
  confirm "Continue?"
  fetch_safety_card $2
  confirm "Do you trust this?"
  install $2
fi

