#!/bin/bash

if [[ -f $HOME/catkin_ws/devel/setup.bash ]]; then
    echo "found $HOME/catkin_ws/devel/setup.bash. sourcing..."
    # source $HOME/catkin_ws/devel/setup.bash
elif [[ -f /opt/ros/$ROS_DISTRO/setup.bash ]]; then
    echo "found /opt/ros/$ROS_DISTRO/setup.bash. sourcing..."
    # source /opt/ros/$ROS_DISTRO/setup.bash
fi 

