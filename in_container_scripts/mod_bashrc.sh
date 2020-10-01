cat <<'EOF' >> /root/.bashrc
# set prompt text/color based on type of container
parse_git_branch() {
     git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/ (\1)/'
}
if [[ ! -v DEPLOYMENT_DOCKER ]]; then 
	export PS1="\[\033[32m\]\h🐳 \[\033[36m\]\u@dev\[\033[m\]:\[\033[33;1m\]\w\[\033[m\]\$(parse_git_branch) $ "
else
	export PS1="\[\e[0;49;91m\]\h🐳 \[\033[36m\]\u@\e[0;49;91m\]deploy\[\033[m\]:\[\033[33;1m\]\w\[\033[m\] $ "
fi
EOF
