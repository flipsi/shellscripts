#!/bin/bash

set -e

if [[ "$SUSER" = "root" ]]; then
    echo "No no no, please execute this as non-root."
    exit 1
fi

# TODO: use terminal colors!

function echo_success()
{
    echo "[SUCCESS] $1"
}


function echo_warning()
{
    echo "[WARNING] $1"
}


function echo_error()
{
    echo "[ERROR] $1"
}


function echo_skipped()
{
    echo "[SKIPPING] $1"
}

function has()
{
    type "$1" > /dev/null 2>&1
}

function require()
{
    if ! type "$1" > /dev/null; then
        echo "ERROR! Could not find command $1. Please install according package"
        exit 1
    fi
}

function install_packages()
{
    # sudo pacman -S --needed "$@"
    # (some packages are AUR only)
    require yay
    yay -S --needed "$@"
}

function install_yay()
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

function configure_pacman()
{
    sudo sed -i 's/^#Color/Color/' '/etc/pacman.conf'
}

function configure_pam_faillock()
{
    # Because the default behavior of being locked out for 10 minutes after 3 failed login attempts is very annoying.
    sudo sed -E -i 's/^(# )?deny = .*/deny = 9/' '/etc/security/faillock.conf'
    sudo sed -E -i 's/^(# )?unlock_time = .*/unlock_time = 120/' '/etc/security/faillock.conf'
}

function configure_keyboard_layout()
{
    # For Linux console
    LAYOUT="de-latin1-nodeadkeys"
    if localectl status | grep -q "VC Keymap: $LAYOUT"; then
        echo_skipped "Linux console keyboard layout already set to '$LAYOUT'."
    else
        if localectl list-keymaps | grep -q "$LAYOUT"; then
            FILE="/etc/vonsole.conf"
            if ! test -f "$FILE"; then
                sudo touch "$FILE"
            fi
            # TODO: doesn't work! fix this!
            # TODO: move this "ensure line in file" thing to a proper function
            sourcestring="KEYMAP=$LAYOUT"
            echo sourcestring $sourcestring
            echo file $FILE
            sudo grep -F "$sourcestring" "$FILE"
            sudo grep -q -F "$sourcestring" "$FILE"  || echo "$sourcestring" | sudo tee -a "$FILE"
            echo_success "Linux console layout set to '$LAYOUT'."
        else
            echo_warning "Linux console layout '$LAYOUT' not found!"
        fi
    fi

    # For X11
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
}

function install_tools()
{
    install_packages \
        atool \
        bpytop \
        elinks \
        eza \
        fd \
        ffmpegthumbnailer \
        fish \
        fzf \
        git-delta \
        git-revise \
        gnu-netcat \
        highlight \
        htop \
        inetutils \
        jq \
        lsof \
        lynx \
        mediainfo \
        mlocate \
        ncdu \
        net-tools \
        odt2txt \
        pydf \
        ripgrep \
        rsync \
        shellcheck \
        sox \
        source-highlight \
        speedtest-cli \
        the_silver_searcher \
        tig \
        tldr \
        tmux \
        translate-shell \
        trash-cli \
        unzip \
        usbutils \
        vlc \
        zip
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
        git clone --recursive "$DOTFILES_GIT_URL" "$HOME/dotfiles"
        echo_success "dotfiles cloned."
    fi
    "$HOME/dotfiles/install.sh" --all
    echo_success "dotfiles installed."
}

function set_shell()
{
    require fish
    PATH_TO_FISH=$(type -p fish)
    sudo chsh -s "$PATH_TO_FISH" "$USER"
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

function setup_power_management()
{
    install_packages acpi
}

function install_i3_desktop()
{
    install_packages xorg-server xorg-xinit xorg-xbacklight
    echo_warning "Make sure to install drivers for hardware acceleration!"

    install_packages \
        arandr \
        i3-wm i3lock polybar dmenu rofi rofi-pass \
        pipewire-audio pipewire-pulse wireplumber pavucontrol alsa-utils pamixer \
        python dbus-python \
        libnotify notification-daemon \
        dex picom redshift unclutter feh xfce4-screenshooter \
        redshift \
        xsel xclip clipmenu \
        cups cups-pdf

    sudo usermod -a -G audio "$USER"
}

function install_docker()
{
    install_packages docker docker-compose
    sudo usermod -a -G docker "$USER"
}

function setup_printer()
{
    install_packages cups cups-pdf brother-hll2375dw
    echo_warning "Driver installed. Now please install printer via CUPS web API (http://localhost:631/admin/)."
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

function install_bluetooth()
{
    install_packages \
        bluez bluez-utils blueman
    sudo systemctl enable --now bluetooth.service
}


function install_desktop_apps()
{
    install_packages \
        alacritty \
        thunar \
        spotify playerctl \
        nsxiv \
        gcolor3 \
        zsa-keymapp-bin \
        telegram-desktop \
        vivaldi browserpass browserpass-chromium \
        chromium \
        qutebrowser \
        zathura zathura-pdf-poppler poppler
}

function install_misc()
{
    install_packages \
        fuse-common fuse2 ntfs-3g
}


#install_tools
#install_yay
#configure_pacman
#configure_pam_faillock
#configure_keyboard_layout
#setup_ssh
setup_fonts
#clone_and_install_dotfiles
# # setup_password_store
#setup_power_management
#install_i3_desktop
#install_docker
# # setup_printer
#install_bluetooth
#setup_vim_and_neovim
#install_desktop_apps
#install_misc

