#!/bin/bash

set -euf -o pipefail

declare ORIGINAL=' \[ -z "$PS1" \] && return '
ORIGINAL="${ORIGINAL// /[[:space:]]*}"

# need to source bashrc in a non-interactive shell to get paths correct
declare REPLACEMENT='case $- in
    *i*) ;;
      *) return;;
esac'
REPLACEMENT="${REPLACEMENT//
/\\n}"

declare -r -a FIX_FILES=( /etc/bash.bashrc /etc/skel/.bashrc /root/.bashrc )

sed -i -e 's/^'"$ORIGINAL"'$/'"$REPLACEMENT"'/' "${FIX_FILES[@]}"

if ! grep -q rospy, /opt/ros/melodic/lib/python2.7/dist-packages/message_filters/__init__.py; then
    sed -i -e 's/import rospy/import rospy, functools/' /opt/ros/melodic/lib/python2.7/dist-packages/message_filters/__init__.py
fi

if ! grep -q functools.reduce /opt/ros/melodic/lib/python2.7/dist-packages/message_filters/__init__.py; then
    sed -i -e 's/reduce/functools.reduce/g' /opt/ros/melodic/lib/python2.7/dist-packages/message_filters/__init__.py
fi

# TODO: fix up these calls into functions
# TODO: move this code into a separate setup script which can be sourced

cat <<'EOF' >> /root/.bashrc
if [[ -f /opt/ros/$ROS_DISTRO/setup.bash ]]; then
    echo "found /opt/ros/$ROS_DISTRO/setup.bash. sourcing..."
    source /opt/ros/$ROS_DISTRO/setup.bash
fi
if [[ -f $HOME/catkin_ws/devel/setup.bash ]]; then
    echo "found $HOME/catkin_ws/devel/setup.bash. sourcing..."
    source $HOME/catkin_ws/devel/setup.bash
fi
export ROS_PYTHON_VERSION=3

# prioritise python3 imports, then python2, apt installs to python2
export PYTHONPATH=/opt/ros/melodic/lib/python3/dist-packages/:$PYTHONPATH
export PYTHONPATH=$PYTHONPATH:/opt/ros/melodic/lib/python2.7/dist-packages/

# set prompt text/color based on type of container
parse_git_branch() {
     git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/ (\1)/'
}

if [[ ! -v DEPLOYMENT_DOCKER ]]; then 
	export PS1="\[\033[32m\]\h🐳 \[\033[36m\]\u@dev\[\033[m\]:\[\033[33;1m\]\w\[\033[m\]\$(parse_git_branch) $ "
else
	export PS1="\[\e[0;49;91m\]\h🐳 \[\033[36m\]\u@deploy\[\033[m\]:\[\033[33;1m\]\w\[\033[m\]\$(parse_git_branch) $ "
fi
EOF
