FROM rwthika/ros2-ml@sha256:1c24b67c934aeb6dff7d7eb7a81fa5a438bf3e5ec4f1433f065b644d75c190f5 AS builder-base

# S
ENV ROS_DISTRO=humble
ARG CR_PAT
ARG DEBIAN_FRONTEND=noninteractive
ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=all
ARG ISAAC_VERSION

# Ros requirements
COPY /ros/additional_ros_requirements.txt /additional_ros_requirements.txt
RUN --mount=type=cache,target=/var/cache/apt \
    apt-get update && \
    xargs apt-get install -y < /additional_ros_requirements.txt

# Pip requirements
COPY ros/additional_pip_requirements.txt tmp/additional_pip_requirements.txt
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install -r tmp/additional_pip_requirements.txt

# Deb requirements
COPY ros/additional_deb_requirements.txt /additional_deb_requirements.txt
RUN --mount=type=cache,target=/var/cache/apt \
    apt-get update && \
    xargs apt-get install -y < /additional_deb_requirements.txt && \
    rm -rf /var/lib/apt/lists/*