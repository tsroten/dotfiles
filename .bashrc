[ -f ~/.config/shell/profile ] && source ~/.config/shell/profile

if [ -f $XDG_CONFIG_HOME/bash/git-aware-prompt/README.md ]; then
  export GITAWAREPROMPT=$XDG_CONFIG_HOME/bash/git-aware-prompt
  source "${GITAWAREPROMPT}/main.sh"
  export PS1="${host}\[\033[33;1m\]\W\[\033[m\]\[$txtcyn\]\$git_branch\[$txtred\]\$git_dirty\[$txtrst\] $ "
fi;

# shell/profile has run brew shellenv by now, so HOMEBREW_PREFIX is set.
[ -f "$HOMEBREW_PREFIX/etc/bash_completion.d/git-completion.bash" ] && source "$HOMEBREW_PREFIX/etc/bash_completion.d/git-completion.bash"

[ -f $XDG_CONFIG_HOME/bash/exports ] && source $XDG_CONFIG_HOME/bash/exports

if hash pyenv 2>/dev/null; then eval "$(pyenv init -)"; fi
