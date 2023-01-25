[ -f ~/.config/shell/profile ] && source ~/.config/shell/profile

if [ -f $XDG_CONFIG_HOME/bash/git-aware-prompt/README.md ]; then
  export GITAWAREPROMPT=$XDG_CONFIG_HOME/bash/git-aware-prompt
  source "${GITAWAREPROMPT}/main.sh"
  export PS1="${host}\[\033[33;1m\]\W\[\033[m\]\[$txtcyn\]\$git_branch\[$txtred\]\$git_dirty\[$txtrst\] $ "
fi;

[ -f /usr/local/etc/bash_completion.d/git-completion.bash ] && source /usr/local/etc/bash_completion.d/git-completion.bash

[ -f /usr/local/etc/profile.d/autojump.sh ] && source /usr/local/etc/profile.d/autojump.sh

[ -f $XDG_CONFIG_HOME/bash/exports ] && source $XDG_CONFIG_HOME/bash/exports
[ -f $XDG_CONFIG_HOME/bash/aliases ] && source $XDG_CONFIG_HOME/bash/aliases
[ -f $XDG_CONFIG_HOME/bash/secrets ] && source $XDG_CONFIG_HOME/bash/secrets
[ -f $XDG_CONFIG_HOME/bash/path ] && source $XDG_CONFIG_HOME/bash/path

if hash pyenv 2>/dev/null; then eval "$(pyenv init -)"; fi
