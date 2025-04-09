#!/bin/bash
source /opt/ros/jazzy/setup.bash
source $BUILD_WS/install/setup.bash
sudo chown -R dev:dev /home/dev
echo "alias cb='source /home/dev/ai_ws/zobot/utils/common/colcon-build'" >> ~/.bashrc
source ~/.bashrc