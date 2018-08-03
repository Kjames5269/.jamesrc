# af-magic.zsh-theme
# Repo: https://github.com/andyfleming/oh-my-zsh
# Direct Link: https://github.com/andyfleming/oh-my-zsh/blob/master/themes/af-magic.zsh-theme

if [ $UID -eq 0 ]; then NCOLOR="red"; else NCOLOR="green"; fi
local return_code="%(?..%{$fg[red]%}%? ↵%{$reset_color%})"

errCol=$FG[162]
errColL=$FG[168]

# primary prompt
PROMPT='$FG[237]------------------------------------------------------------%{$reset_color%}
%(?.$FG[032].$errCol)%~\
$(git_prompt_info) \
$FG[105]༼ つ ◕_◕ ༽つ%{$reset_color%} '

# http://zsh.sourceforge.net/Doc/Release/Prompt-Expansion.html

#$FG[105]%(!.#.༼ つ ◕_◕ ༽つ)%{$reset_color%} '
PROMPT2='%{$fg[red]%}\ %{$reset_color%} '
RPS1='${return_code}'

# color vars
eval my_gray='$FG[237]'
eval my_orange='$FG[214]'

# right prompt
if type "virtualenv_prompt_info" > /dev/null
then
	RPROMPT='$(virtualenv_prompt_info)$my_gray%n@%m%{$reset_color%}%'
else
	RPROMPT='$my_gray%n@%m%{$reset_color%}%'
fi

# git settings
ZSH_THEME_GIT_PROMPT_PREFIX="%(?.$FG[075].$errColL)(%(?.$FG[078].$FG[092])"
ZSH_THEME_GIT_PROMPT_CLEAN=""
ZSH_THEME_GIT_PROMPT_DIRTY="%(?.$my_orange.$FG[253])*%{$reset_color%}"
ZSH_THEME_GIT_PROMPT_SUFFIX="%(?.$FG[075].$errColL))%{$reset_color%}"
