# Installing and using Codeface

## Installing Codeface
### Docker
The recommended way to set up a Codeface instance is via docker.
Clone the repository and run

	docker build -t codeface .

to create the docker image and execute all provision scripts. Use

	docker run --name codeface -d -t --user codeface -v .:/home/codeface/codeface codeface

to create a docker container based on the Codeface docker image. To
log in to the docker container and get shell access, use

	docker exec -it codeface bash

If docker is not yet installed on your system, please consult the
[official installation instructions](https://docs.docker.com/engine/install/).

### Vagrant
An alternative way to set up Codeface is via vagrant. Clone
the repository and run

	vagrant up

to obtain a fully provisioned Codeface machine. Vagrant defaults to
Virtualbox as provider, which may cause large performance impacts
especially for I/O heavy tasks. You can /alternatively/ use

	vagrant up --provider=lxc

if you have the corresponding LXC provider for vagrant installed on
your system. To get shell access on the machine in each case, use

	vagrant ssh

If vagrant is not yet installed on your system, please consult
the corresponding [wiki page](https://github.com/siemens/codeface/wiki/Runnning-codeface-with-Vagrant).

## Analysing Projects
### Concept
Conceptually, work with Codeface is split in two stages:

1. Analyse projects using the batch-mode command line interface. See
  `analysis.md` for further details. Note that this process involves
  substantial amounts of git repo querying and data crunching, and can
  require several hours for large projects like the Linux kernel.
2. Inspect the results by visual analysis with the web frontend (see
  `webserver.md` for setup details), or by querying the database
  directly. See file `codeface/R/interactive.R` for exemplary instructions.

### Five Easy Steps to your First Analysis
To perform an analysis of project qemu (a machine emulation software)
and inspect the results in the interactive web frontend, run the
following steps:

1. Connect to the docker container or vagrant machine
2. In a vagrant-based installation, start the ID service with
   `/vagrant/id_service/start_id_service.sh&`
3. Run an analysis of qemu with `/vagrant/analysis_example.sh` (this process
   may take a while to complete)
4. <s>Start the webserver with `cd vagrant; ./shiny-server.sh`</s> (to be fixed)
5. <s>Point your webserver on the host at [http://localhost:8081](http://localhost:8081)</s>

## Status
- ![](https://travis-ci.org/siemens/codeface.svg?branch=master) on master
