#!/bin/bash

# print version numbers of some tools. grep output if needed.
# ordered as i like it. pipe to sort if needed.


VERSIONNUMBER_BINARY='s/.*(([[:digit:]])+\.[[:digit:]]+).*/\1/'
VERSIONNUMBER_TERNARY='s/.*(([[:digit:]])+\.[[:digit:]]+\.[[:digit:]]+).*/\1/'
# VERSIONNUMBER='s/.*(([[:digit:]])+\.[[:digit:]]+(\.[[:digit:]]+)?).*/\1/'


# SYSTEM

echo -n 'kernel       '
uname -r | sed -E "$VERSIONNUMBER_TERNARY"


# BASICS

if (command -v bash >/dev/null); then
    echo -n 'bash         '
    bash --version | head -n 1 | sed -E "$VERSIONNUMBER_TERNARY"
fi

if (command -v zsh >/dev/null); then
    echo -n 'zsh          '
    zsh --version | sed -E "$VERSIONNUMBER_TERNARY"
fi

if (command -v fish >/dev/null); then
    echo -n 'fish         '
    fish --version | sed -E "$VERSIONNUMBER_TERNARY"
fi

if (command -v vim >/dev/null); then
    echo -n 'vim          '
    version=$(vim --version | head -n 1 | sed -E "$VERSIONNUMBER_BINARY")
    patch=$(vim --version | head -n 2 | tail -n 1 | sed -E 's/.*[[:digit:]]+-([[:digit:]]+).*/\1/')
    echo "$version.$patch"
fi

if (command -v i3 >/dev/null); then
    echo -n 'i3           '
    i3 --version | sed -E "$VERSIONNUMBER_BINARY"
fi

if (command -v tmux >/dev/null); then
    echo -n 'tmux         '
    tmux -V | sed -E "$VERSIONNUMBER_BINARY"
fi

if (command -v ranger >/dev/null); then
    echo -n 'ranger       '
    ranger --version | head -n 1 | sed -E "$VERSIONNUMBER_TERNARY"
fi

if (command -v git >/dev/null); then
    echo -n 'git          '
    git --version | sed -E "$VERSIONNUMBER_TERNARY"
fi

if (command -v docker >/dev/null); then
    echo -n 'docker       '
    docker --version | sed -E "$VERSIONNUMBER_TERNARY"
fi




# COMPILER AND INTERPRETER

if (command -v gcc >/dev/null); then
    echo -n 'gcc          '
    gcc --version | head -n 1 | sed -E "$VERSIONNUMBER_TERNARY"
fi

if (command -v g++ >/dev/null); then
    echo -n 'g++          '
    g++ --version | head -n 1 | sed -E "$VERSIONNUMBER_TERNARY"
fi

if (command -v clang >/dev/null); then
    echo -n 'clang        '
    clang --version | head -n 1 | sed -E "$VERSIONNUMBER_TERNARY"
fi

if (command -v perl >/dev/null); then
    echo -n 'perl         '
    perl --version | head -n 2 | tail -n 1 | sed -E "$VERSIONNUMBER_TERNARY"
fi

if (command -v ruby >/dev/null); then
    echo -n 'ruby         '
    ruby --version | sed -E "$VERSIONNUMBER_TERNARY"
fi

if (command -v lua >/dev/null); then
    echo -n 'lua          '
    lua -v | head -n 2 | tail -n 1 | sed -E "$VERSIONNUMBER_TERNARY"
fi

if (command -v python2 >/dev/null); then
    echo -n 'python2      '
    python2 --version 2>&1 | sed -E "$VERSIONNUMBER_TERNARY"
fi
if (command -v python3 >/dev/null); then
    echo -n 'python3      '
    python3 --version | sed -E "$VERSIONNUMBER_TERNARY"
fi
if (command -v python >/dev/null); then
    echo -n 'python       '
    python --version | sed -E "$VERSIONNUMBER_TERNARY"
fi

if (command -v php >/dev/null); then
    echo -n 'php          '
    php --version | head -n 1 | sed -E "$VERSIONNUMBER_TERNARY"
fi

if (command -v node >/dev/null); then
    echo -n 'node         '
    node --version | head -n 1 | sed -E "$VERSIONNUMBER_TERNARY"
fi
if (command -v nodejs >/dev/null); then
    echo -n 'nodejs       '
    nodejs --version | head -n 1 | sed -E "$VERSIONNUMBER_TERNARY"
fi

if (command -v mongo >/dev/null); then
    echo -n 'mongo        '
    mongo --version | head -n 1 | sed -E "$VERSIONNUMBER_TERNARY"
fi

if (command -v postgres >/dev/null); then
    echo -n 'postgres     '
    postgres --version | sed -E "$VERSIONNUMBER_TERNARY"
fi

if (command -v mysql >/dev/null); then
    echo -n 'mysql        '
    mysql -V | head -n 1 | sed -E "$VERSIONNUMBER_TERNARY"
fi


if (command -v java >/dev/null); then
    echo -n 'java         '
    java -version 2>&1 | head -n 1 | sed -E "$VERSIONNUMBER_TERNARY"
fi

if (command -v scala >/dev/null); then
    echo -n 'scala        '
    scala 2>&1 -version | sed -E "$VERSIONNUMBER_TERNARY"
fi

if (command -v ghc >/dev/null); then
    echo -n 'ghc          '
    ghc --version | sed -E "$VERSIONNUMBER_TERNARY"
fi

