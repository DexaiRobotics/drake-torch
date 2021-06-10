#!/bin/bash
set -eufo pipefail

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

cat <<'EOF' >> /root/.bashrc

# this adds py3 to $PYTHONPATH
if [[ -f /opt/ros/${ROS_DISTRO}/setup.bash ]]; then
  echo "found /opt/ros/${ROS_DISTRO}/setup.bash. sourcing..."
  source /opt/ros/${ROS_DISTRO}/setup.bash
fi

# this script is only present after catkin workspace has been built
# with catkin_make and does not exist before catkin_make
# on melodic this sets $PYTHONPATH to two py27 locations and then py3
# but we want py3 first
if [[ -f $HOME/catkin_ws/devel/setup.bash ]]; then
  echo "found $HOME/catkin_ws/devel/setup.bash. sourcing..."
  source $HOME/catkin_ws/devel/setup.bash
fi

if [[ $ROS_DISTRO == "melodic" ]]; then
  # reorder $PYTHONPATH by moving py3 to the front (remove + prepend)
  py3path="/opt/ros/melodic/lib/python3/dist-packages"
  export PYTHONPATH=`echo $PYTHONPATH | tr ":" "\n" | grep -v $py3path | tr "\n" ":"`
  export PYTHONPATH=$py3path:$PYTHONPATH
  # finally append py27 path if not present (useful before catkin_make is run)
  if ! grep -q /opt/ros/melodic/lib/python2.7/dist-packages <<< "$PYTHONPATH"; then
    export PYTHONPATH=$PYTHONPATH:/opt/ros/melodic/lib/python2.7/dist-packages/
  fi
fi

if [[ $(lsb_release -sc) == "focal" ]]; then
  alias python=python3
fi

# set prompt text/color based on type of container
parse_git_branch() {
     git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/ (\1)/'
}
if [[ ! -v DEPLOYMENT_DOCKER ]]; then 
  export PS1="\[\033[32m\]\h🐳 \[\033[36m\]\u@dev\[\033[m\]:\[\033[33;1m\]\w\[\033[m\]\$(parse_git_branch) $ "
else
  if [[ -f /src/deploy_version.txt ]]; then
    export DEPLOY_VERSION=`cat /src/deploy_version.txt`
  fi
  export PS1="\[\e[0;49;91m\]\h🐳 \e[0;49;91m\]deploy\e[1;40;36m${DEPLOY_VERSION:-}\[\033[m\]:\[\033[33;1m\]\w\[\033[m\] $ "
fi

EOF
