#!/bin/bash

# --- Constants ---
RED='\033[0;31m'
BLUE='\033[0;94m'
NC='\033[0m'
SAUR_DIR="$HOME/.config/saur"
INSTALLED_LIST="$SAUR_DIR/installed.list"
CACHE_DIR="$HOME/.cache/saur/pkgb"

mkdir -p "$SAUR_DIR" "$CACHE_DIR"

# --- Helper Functions ---
confirm() {
  local prompt="$1"
  local response
  read -rp "$prompt [y/N]: " response
  if [[ "$response" != [yY] ]]; then
    echo "Aborting ..."
    exit 1
  fi
}

fetch_safety_card() {
  pkg="$1"
  echo -e "${RED}Fetching package metadata from AUR...${NC}"

  json=$(curl -fsSL "https://aur.archlinux.org/rpc/v5/info/$pkg")

  if [[ -z "$json" || "$json" == "null" ]]; then
    echo "Failed to fetch package info."
    return
  fi

  maintainer=$(echo "$json" | jq -r '.results[0].Maintainer')
  submitted=$(echo "$json" | jq -r '.results[0].FirstSubmitted' | xargs -I{} date -d @{} "+%Y-%m-%d" 2>/dev/null || date -r {} "+%Y-%m-%d")
  updated=$(echo "$json" | jq -r '.results[0].LastModified' | xargs -I{} date -d @{} "+%Y-%m-%d" 2>/dev/null || date -r {} "+%Y-%m-%d")
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

show_pkgbuild_diff() {
  local pkg="$1"
  local latest_pkgbuild_file="$2"
  local cached_pkgbuild="$CACHE_DIR/$pkg.PKGBUILD"

  if [[ ! -f "$cached_pkgbuild" ]]; then
    echo "No cached PKGBUILD found for $pkg, treating as new install."
    return 0
  fi

  diff -u "$cached_pkgbuild" "$latest_pkgbuild_file" | less
}

cache_current_pkgbuild() {
  cp "$2" "$CACHE_DIR/$1.PKGBUILD"
}

fetch_aur_deps() {
  local missing_aur_deps=()
  mapfile -t missing_aur_deps < <(makepkg -o --syncdeps --nobuild 2>&1 | grep "not found in the repositories" | awk -F"'" '{print $2}')

  if [[ ${#missing_aur_deps[@]} -gt 0 ]]; then
    printf "\n${RED}==== AUR Dependency Summary ====${NC}\n"
    printf "%-20s | %-15s | %-10s | %-6s | %-10s | %-10s\n" "Package" "Maintainer" "Updated" "Votes" "Popularity" "Submitted"
    printf -- "---------------------------------------------------------------\n"

    for dep in "${missing_aur_deps[@]}"; do
      json=$(curl -fsSL "https://aur.archlinux.org/rpc/v5/info/$dep")
      maintainer=$(echo "$json" | jq -r '.results[0].Maintainer')
      submitted_epoch=$(echo "$json" | jq -r '.results[0].FirstSubmitted')
      submitted=$(date -d "@$submitted_epoch" +"%Y-%m-%d" 2>/dev/null || date -r "$submitted_epoch" +"%Y-%m-%d")
      last_update_epoch=$(echo "$json" | jq -r '.results[0].LastModified')
      last_update_date=$(date -d "@$last_update_epoch" +"%Y-%m-%d" 2>/dev/null || date -r "$last_update_epoch" +"%Y-%m-%d")
      votes=$(echo "$json" | jq -r '.results[0].NumVotes')
      popularity=$(echo "$json" | jq -r '.results[0].Popularity')
      printf "%-20s | %-15s | %-10s | %-6s | %-10s | %-10s\n" "$dep" "$maintainer" "$last_update_date" "$votes" "$popularity" "$submitted"
    done

    printf "${RED}=================================${NC}\n"

    confirm "Do you wish to review and install these AUR dependencies?"

    read -rp "Do you want to skip viewing PKGBUILDs for dependencies? [y/N]: " skip_view

    for dep in "${missing_aur_deps[@]}"; do
      echo
      echo -e "${RED}Handling AUR dependency: $dep${NC}"

      if [[ "$skip_view" != [yY] ]]; then
        echo -e "${RED}Viewing PKGBUILD for $dep${NC}\n"
        read -n 1 -s -r -p "Press any key to continue..."
        curl -fsSL "https://aur.archlinux.org/cgit/aur.git/plain/PKGBUILD?h=$dep" | bat --language=bash
        echo
        confirm "Have you verified that the PKGBUILD is safe and wish to continue?"
      fi

      tmpdir=$(mktemp -d)
      git clone "https://aur.archlinux.org/$dep.git" "$tmpdir/$dep"
      cd "$tmpdir/$dep"
      makepkg -si

      sed -i "/^$dep /d" "$INSTALLED_LIST"
      version=$(pacman -Q "$dep" | awk '{print $2}')
      echo "$dep $version" >> "$INSTALLED_LIST"
      cp PKGBUILD "$CACHE_DIR/$dep.PKGBUILD"

      cd - >/dev/null
      rm -rf "$tmpdir"
    done
  fi
}

update() {
  echo -e "${RED}Checking for AUR updates...${NC}"

  while read -r pkg current_version; do
    echo "Checking $pkg..."
    pkginfo=$(curl -fsSL "https://aur.archlinux.org/rpc/v5/info/$pkg")

    upstream_version=$(echo "$pkginfo" | jq -r '.results[0].Version')
    maintainer=$(echo "$pkginfo" | jq -r '.results[0].Maintainer')
    last_update_epoch=$(echo "$pkginfo" | jq -r '.results[0].LastModified')
    last_update_date=$(date -d "@$last_update_epoch" +"%Y-%m-%d" 2>/dev/null || date -r "$last_update_epoch" +"%Y-%m-%d")

    if [[ "$upstream_version" != "$current_version" ]]; then
      echo
      echo -e "Update available for $pkg: $current_version -> $upstream_version"
      echo "Maintainer: $maintainer"
      echo "Last Updated: $last_update_date"

      tmpdir=$(mktemp -d)
      git clone --depth=1 "https://aur.archlinux.org/$pkg.git" "$tmpdir/$pkg"

      echo "Showing PKGBUILD diff..."
      show_pkgbuild_diff "$pkg" "$tmpdir/$pkg/PKGBUILD"

      confirm "Do you wish to build and install $pkg $upstream_version after reviewing the diff?"

      cd "$tmpdir/$pkg" || continue
      makepkg -si || { echo "Failed to build $pkg"; continue; }

      sed -i "/^$pkg /d" "$INSTALLED_LIST"
      echo "$pkg $upstream_version" >> "$INSTALLED_LIST"

      cache_current_pkgbuild "$pkg" "$tmpdir/$pkg/PKGBUILD"

      rm -rf "$tmpdir"
    fi

  done < "$INSTALLED_LIST"

  echo "Update check complete."
}

# --- Main Logic ---
if [[ "$1" == "-S" ]]; then
  echo -e "${RED}WARNING: AUR PACKAGES ARE DANGEROUS${NC}"
  confirm "Continue?"
  fetch_safety_card "$2"
  confirm "Do you trust this?"

  echo -e "${RED}Since this is an AUR package, saur will enforce viewing the PKGBUILD, it will be displayed using bat, you can press Q to exit bat and will be asked for confirmation before continuing.${NC}\n"
  read -n 1 -s -r -p "Press any key to continue..."
  curl -fsSL "https://aur.archlinux.org/cgit/aur.git/plain/PKGBUILD?h=$2" | bat --language=bash
  echo
  confirm "Have you verified that the PKGBUILD is safe and wish to continue?"

  cd ~/$install_dir
  git clone "https://aur.archlinux.org/$2.git"
  cd "$2"

  fetch_aur_deps

  makepkg -si

  sed -i "/^$2 /d" "$INSTALLED_LIST"
  version=$(pacman -Q "$2" | awk '{print $2}')
  echo "$2 $version" >> "$INSTALLED_LIST"
  cp PKGBUILD "$CACHE_DIR/$2.PKGBUILD"

elif [[ "$1" == "-Su" ]]; then
  update
else
  echo "Usage: $0 -S <package> | -Su"
fi
