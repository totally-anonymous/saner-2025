# Base image
FROM ubuntu:22.04

# Update base system packages
RUN apt-get update && apt-get -y install --no-install-recommends \
        software-properties-common \
        curl \
        htop \
        sudo \
        tmux \
        wget \
        vim

# Add Codeface user
RUN groupadd codeface && useradd -ms /bin/bash -d /home/codeface -g codeface codeface
RUN sudo usermod -aG sudo codeface
RUN bash -c "sudo echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers"

# Set up analysis directories
RUN mkdir /home/codeface/git-repos /home/codeface/res

# Set up requirements and install Codeface
COPY . /home/codeface/codeface
RUN bash /home/codeface/codeface/docker/setup.sh
RUN chown -R codeface:codeface /home/codeface
RUN chmod -R 755 /home/codeface/codeface

# Start up
WORKDIR /home/codeface
ENTRYPOINT bash /home/codeface/codeface/docker/entrypoint.sh
