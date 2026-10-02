qsdir := env_var('HOME') / '.config/quickshell/taloshell'
srcdir := env_var('HOME') / '.cache/taloshell/src'

# Check dependencies (fonts, cli tools, optional backends)
doctor:
    bash scripts/taloshell/doctor.sh

# Clone (or update) and install metis, the Graph tab's backend
metis:
    #!/usr/bin/env bash
    set -euo pipefail
    mkdir -p "{{srcdir}}"
    if [ -d "{{srcdir}}/metis/.git" ]; then
        git -C "{{srcdir}}/metis" pull --ff-only
    else
        git clone git@github.com:Walker-00/metis.git "{{srcdir}}/metis"
    fi
    just -f "{{srcdir}}/metis/justfile" -d "{{srcdir}}/metis" install

# Clone (or update) and install pigeon, the mail client's backend daemon
pigeon:
    #!/usr/bin/env bash
    set -euo pipefail
    mkdir -p "{{srcdir}}"
    if [ -d "{{srcdir}}/pigeon/.git" ]; then
        git -C "{{srcdir}}/pigeon" pull --ff-only
    else
        git clone git@github.com:Walker-00/pigeon.git "{{srcdir}}/pigeon"
    fi
    just -f "{{srcdir}}/pigeon/justfile" -d "{{srcdir}}/pigeon" install

# Clone and install both backends (metis for Graph, pigeon for Mail)
deps: metis pigeon

# Sync this repo into ~/.config/quickshell/taloshell (keeps the live config
# dir in step; never touches your ~/.config/taloshell settings/state, which
# live elsewhere), then fetch and build metis and pigeon so Graph and Mail
# work out of the box. Deletes files removed from the repo too.
install: deps
    mkdir -p {{qsdir}}
    rsync -a --delete \
        --exclude '.git' \
        --exclude '.gitignore' \
        ./ {{qsdir}}/

# install, then restart the running shell so changes take effect
reload: install
    qs -c taloshell kill 2>/dev/null || true
    qs -c taloshell >/dev/null 2>&1 &

# Launch the shell directly from this repo without installing (for testing)
run:
    qs -p .

# Remove the installed copy at ~/.config/quickshell/taloshell (leaves metis
# and pigeon installed; see their own justfiles' `uninstall`)
uninstall:
    rm -rf {{qsdir}}
