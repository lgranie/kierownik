#!/usr/bin/env bash

set -euo pipefail

if getent passwd 1000 >/dev/null; then
  touch /var/lib/kier-firstboot.done
  exit 0
fi

if homectl list --json=short | jq -e '. | length > 0' >/dev/null; then
  touch /var/lib/kier-firstboot.done
  exit 0
fi

trap '/usr/libexec/kier/firstboot.sh;' EXIT
trap '/usr/libexec/kier/firstboot.sh;' SIGINT

FULLNAME="Laurent Granie"
USERNAME="lgranie"
PASSWORD="liliop"
DOTSREPO="https://codeberg.org/lgranie/mise-dots.git"
TIMEZONE="Europe/Paris"
HOSTNAME="kier-vm"
main_menu() {
  local choice=""
  while :; do
    gum style --border thick \
      "Full name: $FULLNAME" \
      "Username:  $USERNAME" \
      "dotfiles:  $DOTSREPO" \
      "Timezone:  $TIMEZONE" \
      "Hostname:  $HOSTNAME" 

    choice=$(gum choose \
      "Setup" \
      "Confirm" \
      --limit 1)
    clear

    case "$choice" in
    "Setup")
      setup_form
      ;;
    "Confirm")
      if [[ -z "$FULLNAME" || -z "$USERNAME" || -z "$PASSWORD" || -z "$TIMEZONE" ]]; then
        gum style --border thick \
          "Some fields are missing, please fill them in."
        continue
      fi
      setup
      ;;
    *)
      clear
      gum style --border thick "Invalid choice." 2>/dev/null
      ;;
    esac
  done
}

create_account() {
  local confirm_password=""

  while :; do
    FULLNAME=$(gum input --placeholder "Enter Full name")

    if [[ -z "$FULLNAME" ]]; then
      clear
      gum style --border thick "Full name cannot be empty"
      continue
    fi

    if [[ ${#FULLNAME} -lt 2 ]]; then
      clear
      gum style --border thick "Full name must be at least 2 characters long" 2>/dev/null
      continue
    fi
    clear && break
  done

  while :; do
    USERNAME=$(gum input --placeholder "Enter username")

    if [[ -z "$USERNAME" ]]; then
      clear
      gum style --border thick "Username cannot be empty"
      continue
    fi

    if [[ ${#USERNAME} -lt 2 ]]; then
      clear
      gum style --border thick "Username must be at least 2 characters long" 2>/dev/null
      continue
    fi

    if [[ ! "$USERNAME" =~ ^[a-z][a-z0-9._-]*$ ]]; then
      clear
      gum style --border thick \
        "Username must start with a lowercase letter and contain only lowercase letters, digits, '.', '_', or '-'"
      continue
    fi
    clear && break
  done

  while :; do
    while :; do
      PASSWORD=$(gum input --password --placeholder "Enter password")

      if [[ -z "$PASSWORD" ]]; then
        clear
        gum style --border thick "Password cannot be empty" 2>/dev/null
        continue
      fi

      if [[ ${#PASSWORD} -lt 6 ]]; then
        clear
        gum style --border thick "Password must be at least 6 characters long" 2>/dev/null
        continue
      fi
      clear && break
    done

    confirm_password=$(gum input --password --placeholder "Confirm password")
    [[ "$PASSWORD" == "$confirm_password" ]] && clear && break
    clear
    gum style --border thick "Password don't match" 2>/dev/null
  done
}

setup_form() {
  create_account
  select_timezone
  select_hostname
}

select_timezone() {
  mapfile -t zones < <(timedatectl list-timezones)

  while :; do
    TIMEZONE=$(printf "%s\n" "${zones[@]}" | gum filter --limit 1 --placeholder "Search")
    [[ -n "$TIMEZONE" ]] && clear && break
    clear
    gum style --border thick "Timezone selection is required" 2>/dev/null
  done
}

select_hostname() {
  while :; do
    HOSTNAME=$(gum input --placeholder "Enter host name")
    [[ -n "$HOSTNAME" ]] && clear && break
    clear
    gum style --border thick "Host name selection is required" 2>/dev/null
  done
}

setup() {
  timedatectl set-local-rtc 0
  timedatectl set-timezone "$TIMEZONE"

  hostnamectl hostname "$HOSTNAME" --transient
  
  # Prepare skel
  mkdir -p /tmp/skel/$USERNAME/.config/systemd/user/dotfiles-init.service.d
  cat << EOF > /tmp/skel/$USERNAME/.config/systemd/user/dotfiles-init.service.d/10-custom.conf
[Service]
Environment=DOTSREPO="$DOTSREPO"
EOF
  chmod -R +rwX /tmp/skel/$USERNAME/.config

  NEWPASSWORD="$PASSWORD" /usr/bin/homectl create "$USERNAME" \
    --password-change-now=false \
    --storage=directory \
    --fs-type=btrfs \
    --shell=/usr/bin/zsh \
    --member-of=wheel,users \
    --real-name="$FULLNAME"
  
  shopt -s dotglob
  runuser -u $USERNAME -- cp -R /tmp/skel/$USERNAME/* /var/home/$USERNAME.homedir/
  shopt -u dotglob

  rm -rf /tmp/skel/$USERNAME

  unset NEWPASSWORD
  unset PASSWORD

  trap '' EXIT
  trap '' SIGINT
  touch /var/lib/kier-firstboot.done
  exit 0
}

sleep 5
# flatpak install --reinstall -y io.github.kolunmi.Bazaar &
clear
main_menu
