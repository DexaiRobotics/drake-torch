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

# this always needs to be first in the path
export PYTHONPATH=/opt/ros/melodic/lib/python3/dist-packages/:$PYTHONPATH

if ! grep -q /opt/drake/lib/python3.6/site-packages <<< "$PYTHONPATH"; then
    export PYTHONPATH=$PYTHONPATH:/opt/drake/lib/python3.6/site-packages
fi

export PS1="\[\033[36m\]\u\[\033[m\]@\[\033[32m\] \[\033[33;1m\]\w\[\033[m\] (\$(git branch 2>/dev/null | grep '^*' | colrm 1 2)) \$ "
EOF
