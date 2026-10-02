qsdir := env_var('HOME') / '.config/quickshell/taloshell'

# Check dependencies (fonts, cli tools, optional backends)
doctor:
    bash scripts/taloshell/doctor.sh

# Sync this repo into ~/.config/quickshell/taloshell (keeps the live config
# dir in step; never touches your ~/.config/taloshell settings/state, which
# live elsewhere). Deletes files removed from the repo too.
install:
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

# Remove the installed copy at ~/.config/quickshell/taloshell
uninstall:
    rm -rf {{qsdir}}
