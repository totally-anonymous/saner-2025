# Base image
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Update base system packages
RUN apt-get update && apt-get -y install --no-install-recommends \
        software-properties-common build-essential gcc gfortran g++ \
        curl htop sudo tmux wget vim git python3-dev python3-pip r-base \
        libfontconfig1-dev libssl-dev libxml2-dev \
        libcurl4-openssl-dev libharfbuzz-dev libfribidi-dev \
        libfreetype6-dev libpng-dev libtiff5-dev libjpeg-dev \
        libopenmpi-dev libpq-dev libblas-dev liblapack-dev \
        libatlas-base-dev texlive-full

# Add user
RUN groupadd saner && useradd -ms /bin/bash -d /home/saner -g saner saner
RUN sudo usermod -aG sudo saner
RUN bash -c "sudo echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers"

# Set up requirements and install Codeface
COPY ./tools/codeface /home/saner/tools/codeface
RUN bash /home/saner/tools/codeface/docker/setup.sh

# Add Kaiaulu
COPY ./tools/kaiaulu /home/saner/tools/kaiaulu

# Add directories for comparative analysis
COPY ./analysis /home/saner/analysis
COPY ./src /home/saner/src
COPY ./docker /home/saner/docker
COPY ./data /home/saner/data
COPY ./plot /home/saner/plot
COPY ./log /home/saner/log
COPY ./results /home/saner/results

# Change permissions for the SANER user
RUN sudo chown -R saner:saner /home/saner
RUN sudo chmod -R 755 /home/saner

# Run the remaining setup as user
USER saner

# Install Kaiaulu dependencies
RUN bash /home/saner/tools/kaiaulu/setup/dependencies.sh

# Install dependencies for the comparative analysis
RUN bash /home/saner/analysis/setup.sh

# Start up
WORKDIR /home/saner
ENTRYPOINT ["/home/saner/docker/entrypoint.sh"]
