export XDG_DATA_HOME="${HOME}/.local/share"
export XDG_CONFIG_HOME="${HOME}/.config"
export XDG_CACHE_HOME="${HOME}/.cache"

# Show hostname in prompt if we're SSH'ing.
host=""
if [ -n "$SSH_CLIENT" ] || [ -n "$SSH_TTY" ]; then
  host="(\h) "
fi

export PS1="\[\033[33;1m\]\W\[\033[m\] $ "
if [[ -r $XDG_CONFIG_HOME/bash/git-aware-prompt/README.md ]]; then
  export GITAWAREPROMPT=$XDG_CONFIG_HOME/bash/git-aware-prompt
  source "${GITAWAREPROMPT}/main.sh"
  export PS1="${host}\[\033[33;1m\]\W\[\033[m\]\[$txtcyn\]\$git_branch\[$txtred\]\$git_dirty\[$txtrst\] $ "
fi;

[[ -r /usr/local/etc/bash_completion.d/git-completion.bash ]] && . /usr/local/etc/bash_completion.d/git-completion.bash

[ -f /usr/local/etc/profile.d/autojump.sh ] && . /usr/local/etc/profile.d/autojump.sh

[[ -r $XDG_CONFIG_HOME/bash/exports ]] && . $XDG_CONFIG_HOME/bash/exports
[[ -r $XDG_CONFIG_HOME/bash/aliases ]] && . $XDG_CONFIG_HOME/bash/aliases
[[ -r $XDG_CONFIG_HOME/bash/secrets ]] && . $XDG_CONFIG_HOME/bash/secrets
[[ -r $XDG_CONFIG_HOME/bash/path ]] && . $XDG_CONFIG_HOME/bash/path
[[ -r $HOME/.inputrc ]] && . ~/.inputrc

if hash pyenv 2>/dev/null; then eval "$(pyenv init -)"; fi
