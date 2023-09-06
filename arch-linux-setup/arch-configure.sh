#!/bin/bash

set -e

if [[ "$SUSER" = "root" ]]; then
    echo "No no no, please execute this as non-root."
    exit 1
fi

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

function install_tools()
{
    install_packages \
        bpytop \
        elinks \
        fd \
        fish \
        ffmpegthumbnailer \
        fzf \
        git-revise \
        git-delta \
        highlight \
        htop \
        inetutils \
        lynx \
        mediainfo \
        mlocate \
        odt2txt \
        ranger \
        ripgrep \
        shellcheck \
        the_silver_searcher \
        tig \
        tldr \
        translate-shell \
        tmux
}

function setup_fonts()
{
    install_packages \
        ttf-inconsolata \
        ttf-dejavu \
        noto-fonts \
        noto-fonts-emoji \
        ttf-fira-mono \
        ttf-roboto \
        ttf-fira-sans

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
        "$HOME/dotfiles./install.sh --all"
        echo_success "dotfiles installed."
    fi
}

function set_shell()
{
    sudo chsh -s /usr/bin/fish "$USER"
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
        # git branch --set-upstream-to=github/main main
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
        ssh "$OTHER_HOST" "gpg --export --armor $GPG_KEY_ID > tmp/gpg.public.key"
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
        i3-wm i3lock polybar dmenu rofi rofi-pass \
        pipewire-audio pipewire-pulse wireplumber pavucontrol alsa-utils pamixer \
        python dbus-python \
        dex picom unclutter feh \
        redshift \
        xsel xclip clipmenu
}

function setup_vim_and_neovim()
{
    install_packages neovim nodejs npm python python-pynvim
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
    sudo systemctl start bluetooth.service
    sudo systemctl enable bluetooth.service
}


function install_desktop_apps()
{
    install_packages \
        alacritty \
        spotify playerctl \
        sxiv \
        telegram-desktop \
        vivaldi browserpass browserpass-chromium \
        chromium \
        zathura zathura-pdf-poppler poppler
}


install_tools
install_yay
configure_pacman
setup_ssh
setup_fonts
clone_and_install_dotfiles
# setup_password_store
setup_power_management
install_i3_desktop
install_bluetooth
setup_vim_and_neovim
install_desktop_apps


