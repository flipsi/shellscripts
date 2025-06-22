#!/usr/bin/env bash

function print_in_color
{
    local text="$1"
    local color="$2"

    # Define color codes
    case "$color" in
        "black") color_code="\033[0;30m" ;;
        "red") color_code="\033[0;31m" ;;
        "green") color_code="\033[0;32m" ;;
        "yellow") color_code="\033[0;33m" ;;
        "blue") color_code="\033[0;34m" ;;
        "magenta") color_code="\033[0;35m" ;;
        "cyan") color_code="\033[0;36m" ;;
        "white") color_code="\033[0;37m" ;;
        "reset") color_code="\033[0m" ;;
        *) color_code="\033[0m" ;; # Default to reset if no valid color
    esac

    # Print the text in the chosen color
    echo -e "${color_code}${text}\033[0m"
}

function echo_success
{
    print_in_color "[SUCCESS] $1" green
}


function echo_warning
{
    print_in_color "[WARNING] $1" yellow
}


function echo_error
{
    print_in_color "[ERROR] $1" red
}


function echo_skipped
{
    print_in_color "[SKIPPING] $1" cyan
}

function has
{
    type "$1" > /dev/null 2>&1
}

function require
{
    if ! type "$1" > /dev/null; then
        echo_error "ERROR! Could not find command $1. Please install according package $2"
        exit 1
    fi
}

function get_linux_distro
{
    if [ "$(hostname)" = 'nott' ] && type pacman > /dev/null; then
        # My work Arch Linux thinks she's Ubuntu
        OS="Arch Linux"
    elif [ -f /etc/os-release ]; then
        source /etc/os-release
        OS="$NAME"
        # echo "Distribution: $NAME"
        # echo "Version: $VERSION"
    # elif [ -f /etc/issue ]; then
    #     echo "Distro: $(cat /etc/issue)"
    else
        echo_error "Unable to determine Linux distribution."
    fi
}

function backup_file_with_date
{
    local file="$1"
    local backup="${file}.$(date +%F-%H%M).bak"
    if [ -w "$file" ]; then cp_cmd="cp"; else cp_cmd="sudo cp"; fi
    for existing in "${file}".*.bak; do
        if [ -e "$existing" ] && sudo cmp -s "$file" "$existing"; then
            echo_skipped "Backup file $existing already exists and has the exact same content."
            return
        fi
    done
    echo_success "Created backup file $backup"
    $cp_cmd "$file" "$backup"
}

function append_once
{
    file="$1"
    line="$2"
    sudo touch "$file"
    sudo grep -Fxq "$line" "$file" && echo_skipped "Line $line already present in $file" && return
    sudo grep -Fxq "$line" "$file" || echo "$line" | sudo tee -a "$file" >/dev/null
    echo_success "Line $line added to $file"
}

function configure_pacman
{
    backup_file_with_date '/etc/pacman.conf'
    sudo sed -i 's/^#Color/Color/' '/etc/pacman.conf' \
        && echo_success "Pacman configured" \
        || echo_success "Pacman already configured."
}

function install_yay
{
    if has yay; then
        echo_skipped "yay already installed."
    else
        echo -e "\nInstalling yay..."
        git clone https://aur.archlinux.org/yay.git
        cd yay
        makepkg -si
        cd -
        echo_success "yay installed."
    fi
}

function install_with_yay
{
    # sudo pacman -S --needed "$@"
    # (some packages are AUR only)
    require yay
    yay -S --needed "$@"
}

function add_user_to_group_if_not_in_group
{
    local groupname=$1
    local username=${2:-$USER}
    if getent group "$groupname" &>/dev/null; then
        if id -nG "$username" | grep -qw "$groupname"; then
            echo_skipped "User '$username' is already a member of the group '$groupname'."
        else
            sudo usermod -aG "$groupname" "$username"
            echo_success "User '$username' has been added to group '$groupname'."
        fi
    else
        echo_error "Group '$groupname' does not exist."
    fi
}

function configure_dnf
{
    local file='/etc/dnf/dnf.conf'
    backup_file_with_date "$file"
    append_once "$file" 'max_parallel_downloads=10'
    append_once "$file" 'fastestmirror=true'
    # enable fusion repository
    install_with_dnf \
        https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-"$(rpm -E %fedora)".noarch.rpm \
        https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-"$(rpm -E %fedora)".noarch.rpm
}

function enable_copr_repo
{
    sudo dnf copr enable -y "$@"
}

function install_with_dnf
{
    sudo dnf install -y --skip-unavailable "$@"
}

function setup_flatpak
{
    install_with_dnf flatpak flatseal
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
}

function install_with_flatpak
{
    flatpak install -y "$@"
}

function install_packages
{
    if has yay; then
        install_with_yay "$@"
    elif has dnf; then
        install_with_dnf "$@"
    else
        echo_error "Could not find package manager!"
    fi
}

function install_all_packages
{
    # (Assumes same package name in every distro I use. For others see below)
    install_packages \
        acpi \
        alacritty \
        arandr \
        atool \
        audacity \
        bluez blueman \
        bpytop \
        chromium \
        cups cups-pdf \
        docker \
        docker-compose \
        elinks \
        eza \
        fd \
        feh \
        fish \
        fzf \
        gcolor3 \
        gimp \
        git-delta \
        git-revise \
        goobook \
        highlight \
        htop \
        iproute \
        jq \
        keychain \
        kitty \
        krita \
        libnotify \
        libreoffice \
        lsof \
        lynx \
        mediainfo \
        musescore \
        ncdu \
        neovim \
        neomutt mutt-wizard msmtp isync pass notmuch notmuch-mutt \
        net-tools \
        nginx \
        notification-daemon \
        nsxiv \
        ntp \
        odt2txt \
        pass \
        pdfgrep \
        php php-cli php-common php-fpm \
        picom  \
        playerctl \
        podman \
        polybar \
        pwgen \
        python3-pip \
        prettier \
        qutebrowser \
        ranger \
        redshift \
        ripgrep \
        rofi \
        rsync \
        shellcheck \
        shellcheck-sarif \
        sshfs \
        source-highlight \
        sox \
        syncthing \
        texlive texlive-standalone latexmk \
        the_silver_searcher \
        thunar \
        tig \
        tldr \
        tmux \
        translate-shell \
        trash-cli \
        unclutter-xfixes \
        unzip \
        urlscan \
        usbutils \
        vlc \
        vlc-gui-ncurses \
        wakeonlan \
        xclip \
        xdotool \
        xfce4-screenshooter \
        xsel \
        yt-dlp \
        zathura zathura-pdf-poppler poppler \
        zip

    setup_flatpak
    install_with_flatpak  \
        com.slack.Slack \
        com.spotify.Client \
        com.vivaldi.Vivaldi \
        org.telegram.desktop \
        org.signal.Signal

    # allow vivaldi to write files to download directory
    # (note this is untested, I used flatseal to to it)
    # flatpak info --show-permissions com.vivaldi.Vivaldi
    sudo flatpak override com.vivaldi.Vivaldi --filesystem="$HOME/tmp"

    if [[ "$OS" = "Fedora Linux" ]]; then
        # Note: If the `ip` command ("iproute" package) is not found, you have to run with sudo ;)
        enable_copr_repo mamg22/nsxiv
        enable_copr_repo skidnik/clipmenu
        enable_copr_repo phrdina/cyrus-sasl-xoauth2
        install_packages \
            clipmenu \
            cyrus-sasl-xoauth2 \
            dex-autostart \
            nsxiv \
            pipx \
            python3-speedtest-cli \
            wol

    elif [[ "$OS" = "Arch Linux" ]]; then
        install_i3_desktop
        install_packages \
            bluez-utils \
            browserpass browserpass-chromium \
            cyrus-sasl-xoauth2 \
            dex \
            fuse-common fuse2 ntfs-3g \
            gnu-netcat \
            inetutils \
            mlocate \
            pydf \
            python-pipx \
            wakeonlan \
            zsa-keymapp-bin

    fi

    # pipx ensurepath
    # sudo pipx ensurepath --global # optional to allow pipx actions with --global argument
}

function update_firmware
{
    if [[ "$OS" = "Fedora Linux" ]]; then
        sudo fwupdmgr get-devices
        sudo fwupdmgr refresh --force
        sudo fwupdmgr get-updates
        # requires interactive confirmation
        # fails if no updates available
        sudo fwupdmgr update \
            && echo_success "Upgraded firmware." \
            || echo_skipped "Firmware is up to date."
    else
        echo_skipped "No firmware update command for OS $OS configured."
    fi
}

function install_i3_desktop
{
    install_packages xorg-server xorg-xinit xorg-xbacklight
    echo_warning "Make sure to install drivers for hardware acceleration!"

    install_packages \
        arandr \
        i3-wm i3lock polybar dmenu rofi rofi-pass \
        pipewire-audio pipewire-pulse wireplumber pavucontrol alsa-utils pamixer \
        python dbus-python \
        libnotify notification-daemon \
        picom redshift unclutter feh xfce4-screenshooter \
        xsel xclip clipmenu \
        cups cups-pdf \
        numlockx

    pip install i3-py
}

function setup_printer
{
    install_packages cups cups-pdf
    sudo systemctl enable --now cups.service
    if [[ "$OS" = "Arch Linux" ]]; then
        install_packages brother-hll2375dw
        echo_warning "Driver installed. Ideally that's it, but if not, you might have to install printer via CUPS web API (http://localhost:631/admin/)."
    fi

    if lpstat -t | grep -q 'no system default destination'; then
        PRINTER=$(lpstat -t | grep -E '^Brother' | head -n1 | cut -d' ' -f1)
        if [[ -n "$PRINTER" ]]; then
            lpoptions -d "$PRINTER"
            echo_success "Default printer set to $PRINTER"
        fi
    else
        echo_skipped "Default printer already set."
        lpstat -t | grep 'default'
    fi
}

function use_unfree_ffmpeg
{
    sudo dnf swap -y ffmpeg-free ffmpeg --allowerasing
    sudo dnf update -y @multimedia --setopt="install_weak_deps=False" --exclude=PackageKit-gstreamer-plugin
    install_packages --allowerasing ffmpeg-free ffmpegthumbnailer
}

function configure_sudoers
{
    # because the default behavior of having to type password after a few minutes is too short
    local filename='/etc/sudoers'
    backup_file_with_date "$filename"
    append_once "$filename" "Defaults        timestamp_timeout=60"
}

function configure_pam_faillock
{
    # because the default behavior of being locked out for 10 minutes after 3 failed login attempts is very annoying.
    local filename='/etc/security/faillock.conf'
    backup_file_with_date "$filename"
    # sudo sed -e -i 's/^(# )?deny = .*/deny = 9/' "$filename"
    # sudo sed -e -i 's/^(# )?unlock_time = .*/unlock_time = 120/' "$filename"
    append_once "$filename" "deny = 9"
    append_once "$filename" "unlock_time = 120"
}

function enable_zsa_keyboard_flashing_and_keymapp_access
{
    local FILENAME='/etc/udev/rules.d/50-zsa.rules'
    if [[ -f "$FILENAME" ]]; then
        echo_skipped "udev rules for ZSA keyboards already exist."
    else
        sudo tee "$FILENAME" > /dev/null <<EOF
KERNEL=="hidraw*", ATTRS{idVendor}=="16c0", MODE="0664", GROUP="plugdev"
KERNEL=="hidraw*", ATTRS{idVendor}=="3297", MODE="0664", GROUP="plugdev"

# Legacy rules for live training over webusb (Not needed for firmware v21+)
  # Rule for all ZSA keyboards
  SUBSYSTEM=="usb", ATTR{idVendor}=="3297", GROUP="plugdev"
  # Rule for the Moonlander
  SUBSYSTEM=="usb", ATTR{idVendor}=="3297", ATTR{idProduct}=="1969", GROUP="plugdev"
  # Rule for the Ergodox EZ
  SUBSYSTEM=="usb", ATTR{idVendor}=="feed", ATTR{idProduct}=="1307", GROUP="plugdev"
  # Rule for the Planck EZ
  SUBSYSTEM=="usb", ATTR{idVendor}=="feed", ATTR{idProduct}=="6060", GROUP="plugdev"

# Wally Flashing rules for the Ergodox EZ
ATTRS{idVendor}=="16c0", ATTRS{idProduct}=="04[789B]?", ENV{ID_MM_DEVICE_IGNORE}="1"
ATTRS{idVendor}=="16c0", ATTRS{idProduct}=="04[789A]?", ENV{MTP_NO_PROBE}="1"
SUBSYSTEMS=="usb", ATTRS{idVendor}=="16c0", ATTRS{idProduct}=="04[789ABCD]?", MODE:="0666"
KERNEL=="ttyACM*", ATTRS{idVendor}=="16c0", ATTRS{idProduct}=="04[789B]?", MODE:="0666"

# Keymapp / Wally Flashing rules for the Moonlander and Planck EZ
SUBSYSTEMS=="usb", ATTRS{idVendor}=="0483", ATTRS{idProduct}=="df11", MODE:="0666", SYMLINK+="stm32_dfu"
# Keymapp Flashing rules for the Voyager
SUBSYSTEMS=="usb", ATTRS{idVendor}=="3297", MODE:="0666", SYMLINK+="ignition_dfu"
EOF
    echo_success "Created ZSA keyboard udev rules."
    fi
}

function install_zsa_keymapp
{
    if has keymapp; then
        echo_skipped 'ZSA Keymapp is already installed.'
    else
        install_packages gtk3 webkit2gtk4.1 libusb
        TARBALL='/tmp/keymapp-latest.tar.gz'
        curl -o "$TARBALL" \
            https://oryx.nyc3.cdn.digitaloceanspaces.com/keymapp/keymapp-latest.tar.gz
        sudo aunpack -X '/usr/local/bin' "$TARBALL" keymapp
        echo_success 'Installed ZSA Keymapp'
    fi
}

function configure_keyboard_layout
{
    # For X11
    sudo mkdir -p "/etc/X11/xorg.conf.d"
    FILE="/etc/X11/xorg.conf.d/00-keyboard.conf"
    if test -f "$FILE"; then
        echo_skipped "X11 keyboard config already exist."
    else
        sudo tee "$FILE" <<EOF
Section "InputClass"
        Identifier "system-keyboard"
        MatchIsKeyboard "on"
        Option "XkbLayout" "de,us"
        Option "XkbModel" "pc104"
        Option "XkbVariant" "nodeadkeys"
EndSection
EOF
    echo_success "X11 keyboard layout set to 'de' (nodeadkeys variant)."
    fi

    # For Linux console
    LAYOUT="de-latin1-nodeadkeys"
    if localectl status | grep -q "VC Keymap: $LAYOUT"; then
        echo_skipped "Linux console keyboard layout already set to '$LAYOUT'."
    else
        if localectl list-keymaps | grep -q "$LAYOUT"; then
            file="/etc/vonsole.conf"
            line="KEYMAP=$LAYOUT"
            append_once "$file" "$line"
            # echo_success "Linux console layout set to '$LAYOUT'."
        else
            echo_warning "Linux console layout '$LAYOUT' not found!"
        fi
    fi
}

function setup_ssh()
{
    if test -f "$HOME/.ssh/id_rsa.pub"; then
        echo_skipped "SSH key already exist."
    else
        install_packages ssh-tools keychain
        echo "Generating SSH key..."
        ssh-keygen
        echo_success "Generated SSH key."
        echo_warning "Make sure to add key to GitHub etc."
    fi

}

function clone_and_install_dotfiles()
{
    require ssh
    require git
    DOTFILES_GIT_URL="git@github.com:flipsi/dotfiles"
    if test -d "$HOME/dotfiles"; then
        echo_skipped "dotfiles already exist."
    else
        echo "Cloning dotfiles..."
        mkdir -p "$HOME/src-projects"
        git clone --recursive "$DOTFILES_GIT_URL" "$HOME/src-projects/dotfiles"
        ln -s "$HOME/src-projects/dotfiles" "$HOME/dotfiles"
        echo_success "dotfiles cloned."
        "$HOME/dotfiles/install.sh" --all
        echo_success "dotfiles installed."
    fi
}

function setup_fonts()
{
    install_packages \
        noto-fonts \
        noto-fonts-emoji \
        ttf-dejavu \
        ttf-fira-mono \
        ttf-fira-sans \
        ttf-font-awesome \
        ttf-inconsolata \
        ttf-meslo-nerd \
        ttf-roboto \

    setup_font_pragmata_pro
}

function setup_font_pragmata_pro()
{
    require aunpack atool
    FONT_PATH_USER="$HOME/.local/share/fonts"
    FONT_PATH_INSTALLED="$FONT_PATH_USER/PragmataPro_Mono_R_0826.ttf"
    FONT_ZIP="PragmataPro0.826.zip"
    FONT_ZIP_PATH="$HOME/misc/fonts/PragmataPro"
    FONT_ZIP_UNPACKED="/tmp/PragmataPro"
    if test -f "$FONT_PATH_INSTALLED"; then
        echo_skipped "Pragmata Pro font already installed."
    else
        if ! test -f "$FONT_ZIP_PATH/$FONT_ZIP"; then
            echo_error "Please copy $FONT_ZIP to $FONT_ZIP_PATH to continue."
            exit 1
        else
            echo -e "\nInstalling Pragmata Pro font..."
            aunpack "$FONT_ZIP_PATH/$FONT_ZIP" --extract-to "$FONT_ZIP_UNPACKED"
            cp $FONT_ZIP_UNPACKED/PragmataPro0.826/Fonts\ without\ ligatures/* "$FONT_PATH_USER"
            fc-cache
            echo_success "Pragmata Pro font installed."
        fi
    fi
}

function set_shell()
{
    require fish
    PATH_TO_FISH=$(type -p fish)
    sudo chsh -s "$PATH_TO_FISH" "$USER"
}

function setup_vim_and_neovim()
{
    install_packages neovim nodejs npm python python-pynvim ctags tree-sitter tree-sitter-cli
    echo "${XDG_DATA_HOME:-$HOME/.local/share}"/nvim/site/autoload/plug.vim
    if test -f "${XDG_DATA_HOME:-$HOME/.local/share}"/nvim/site/autoload/plug.vim; then
        echo_skipped "vim-plug already installed."
    else
        echo "Installing vim-plug..."
        # neovim
        sh -c 'curl -fLo "${XDG_DATA_HOME:-$HOME/.local/share}"/nvim/site/autoload/plug.vim --create-dirs \
            https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'
        # vim
        curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
            https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
        vim '+PlugInstall' '+quit'
        nvim '+PlugInstall' '+quit'
        echo_success "vim-plug installed."
    fi
}

function setup_password_store()
{
    require gpg
    require ssh
    install_packages pass
    if test -d "$HOME/.password-store"; then
        echo_skipped "password store already exists."
    else
        echo "Setting up password store..."
        mkdir "$HOME/.password-store"
        pass git init
        pass git remote add github git@github.com:flipsi/password-store.git
        git branch --set-upstream-to=github/main main
        pass git pull
        echo_success "password store pulled."
    fi
    GPG_KEY_ID=CA1DD30B080E5D7FADCE04ECFC218BA7F39AC976
    OTHER_HOST=falbala
    if gpg --list-secret-keys | grep -q "$GPG_KEY_ID"; then
        echo_skipped "GPG key already imported."
    else
        echo "Getting GPG key from $OTHER_HOST..."
        ping -c 1 "$OTHER_HOST"
        ssh "$OTHER_HOST" "gpg --list-secret-keys"
        # shellcheck disable=SC2029
        ssh "$OTHER_HOST" "gpg --export --armor $GPG_KEY_ID > tmp/gpg.public.key"
        # shellcheck disable=SC2029
        ssh "$OTHER_HOST" "gpg --export-secret-keys --armor $GPG_KEY_ID > tmp/gpg.secret.key" # FIXME requires interactive passphrase. Do this manually
        scp "$OTHER_HOST:tmp/gpg.public.key" "tmp/gpg.public.key"
        scp "$OTHER_HOST:tmp/gpg.secret.key" "tmp/gpg.secret.key"
        ssh "$OTHER_HOST" "rm tmp/gpg.public.key"
        ssh "$OTHER_HOST" "rm tmp/gpg.secret.key"
        gpg --import "tmp/gpg.secret.key" # if this hangs, see https://unix.stackexchange.com/a/432468/119362
        gpg --list-secret-keys
        echo_success "GPG key imported."
        echo "Now trust your own key!"
        gpg --edit-key "$GPG_KEY_ID" # trust the key ultimately!
    fi
}

function main
{
    install_all_packages
    # update_firmware # not necessarily want that
    configure_sudoers
    configure_pam_faillock
    enable_zsa_keyboard_flashing_and_keymapp_access
    install_zsa_keymapp
    configure_keyboard_layout
    setup_ssh
    setup_fonts
    clone_and_install_dotfiles
    setup_vim_and_neovim
    setup_password_store
    add_user_to_group_if_not_in_group docker
    add_user_to_group_if_not_in_group audio
    add_user_to_group_if_not_in_group video
    setup_printer
    sudo systemctl enable --now bluetooth.service
    sudo systemctl enable --now ntpd.service

    if [[ "$OS" = "Fedora Linux" ]]; then
        configure_dnf
        use_unfree_ffmpeg
    elif [[ "$OS" = "Arch Linux" ]]; then
        configure_pacman
        install_yay
        install_i3_desktop
    fi
}

set -e

mkdir -p "$HOME/os/"
LOGFILE="$HOME/os/linux-setup-$(date +%Y-%m-%d-%H-%M).log"
exec > >(tee -a "$LOGFILE") 2>&1

if [[ "$USER" = "root" ]]; then
    echo_error "Please execute this as non-root."
    exit 1
else
    get_linux_distro
    if [[ "$1" = "init" ]]; then
        main
    elif [[ -n "$1" ]]; then
        eval "$1"
    else
        # the majority of changes of this script are new packages, so this is convenient:
        install_all_packages
    fi
fi
