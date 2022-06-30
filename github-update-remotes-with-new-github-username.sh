#!/usr/bin/env bash

set -e
set -o pipefail


function print_help_msg()
{
  cat <<-EOF
After changing your username on Github, you want to update remote URLs of all clones.
This script finds those clones on your local machine and updates the remote URLs for you.

USAGE: $(basename "$0") [OPTIONS] <old-username> <new-username>

OPTIONS:

    --no-dry-run        Actually execute. Without this, the script just prints what would be done.

    --dir <DIR>         Where to search for git clones. Defaults to $HOME.

    --help              Prints this help message.

EOF
}


function parse_arguments()
{
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help|-h)
                print_help_msg;
                exit 0
                ;;
            --no-dry-run)
                NO_DRY_RUN=true
                shift
                ;;
            --dir )
                ROOT_DIR="$2"
                shift; shift
                ;;

            *)
                if [[ -z "$OLD_USERNAME" ]]; then
                    OLD_USERNAME="$1"
                    shift
                elif [[ -z "$NEW_USERNAME" ]]; then
                    NEW_USERNAME="$1"
                    shift
                else
                    echo ERROR: Unknown argument!
                    exit 1
                fi
                ;;
        esac
    done
    if [[ -z "$OLD_USERNAME" ]]; then
        echo ERROR: Missing old username.
        exit 1
    fi
    if [[ -z "$NEW_USERNAME" ]]; then
        echo ERROR: Missing new username.
        exit 1
    fi
}


function find_git_clones()
{
    find "$ROOT_DIR" -type d -name '.git' -print0 2>/dev/null | xargs -0 dirname
}


function filter_for_github_username()
{
    for CLONE in "$@"; do
        if grep -q -E "github.com[:/]$OLD_USERNAME" "$CLONE/.git/config" 2>/dev/null; then
            echo "$CLONE"
        fi
    done
}


function change_git_urls()
{
    for CLONE in "$@"; do
        sed -i -r "s#(github.com[:/])$OLD_USERNAME#\1$NEW_USERNAME#" "$CLONE/.git/config"
    done
}


function main()
{
    parse_arguments "$@"
    ROOT_DIR=${ROOT_DIR:-$HOME} # fallback to home dir
    ROOT_DIR=${ROOT_DIR%/} # remove trailing slash

    echo -e "Changing username from '$OLD_USERNAME' to '$NEW_USERNAME' in the following git clones under $ROOT_DIR:\n"

    mapfile -t CLONES < <( find_git_clones )
    mapfile -t CLONES_TO_UPDATE < <( filter_for_github_username "${CLONES[@]}" )

    for CLONE in "${CLONES_TO_UPDATE[@]}"; do
        echo "$CLONE"
    done

    if [[ -n "$NO_DRY_RUN" ]]; then
        change_git_urls "${CLONES_TO_UPDATE[@]}"
        echo -e "\nDone."
    else
        echo -e "\nThis was a dry run, nothing was changed. Run with '--no-dry-run' to actually execute."
    fi

}

main "$@"
