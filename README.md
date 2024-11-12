# Reproduction Package for "Does the Tool Matter? Exploring Some Causes of Threats to Validity in Mining Software Repositories"

The study uses two mining software repositories (MSR) tools to extract and analyse ten large software projects, 
quantitatively and qualitatively comparing results and derived data to better understand the causes and impact of 
uncertainties in MSR tools and analysis pipelines.

## Repository Contents

- `analysis/`: This directory contains all necessary bash scripts to reproduce our analysis pipeline as presented in the 
paper.
- `data/`: This directory contains the git repositories and the data extracted by the MSR tools Codeface and Kaiaulu.
- `docker/`: This directory contains the entrypoint script for the docker container.
- `log/`: This directory contains log files of the comparative analysis scripts.
- `plot/`: This directory contains the plots from the paper and the source code to generate them in R.
- `results/`: This directory contains all results of the comparative analysis as CSV files.
- `src/`: This directory contains our comparative analysis scripts in Python.
- `tools/`: This directory contains the MSR tools Codeface and Kaiaulu with the configurations and adjustments described 
in the paper.

## Setup 

### 1. Docker 

Our docker image contains all dependencies including libraries, third-party tools and scripts to reproduce our study.
If docker is not yet installed on your system, please consult the
[official installation instructions](https://docs.docker.com/engine/install/).

1. Build the docker image using:
```
docker build -t saner . [2>&1 | tee build.log]
```

2. Run a docker container from the image:
```
docker run --name saner -d -t --user saner saner
```

3. You can then log in to the docker container once and run all following analyses from within the container:
```
docker exec -it saner bash
```
Alternatively, you can prefix the following commands with `docker exec -it saner`.

### 2. Analysis

We provide a single script to run all analysis steps from cloning git repositories, analysis with Codeface and Kaiaulu to 
baseline data and developer network comparisons. 

Executing all analysis steps sequentially can be very time-consuming (up to several weeks) and risky due to sporadic
parallelisation or database errors.

For quickly evaluating our replication package, you can exclude subject projects from the `project_list` 
in the `/home/saner/analysis/analysis.conf` in your docker container. The above script will then only consider the defined
subset of projects. However, be aware that our visualisations are not optimised for this scenario.

If you prefer to analyse the *entire* set of subject projects with more control, or if you experience any errors, please 
refer to the "Important Notes" 
section below.

1. Start the study analysis pipeline in your docker container:

```
bash /home/saner/analysis/analysis.sh
```

2. To inspect the results and visualisations after analysis on localhost, copy the data from the docker container using:
``` 
docker cp saner:/home/saner/data .
docker cp saner:/home/saner/log .
docker cp saner:/home/saner/plot .
docker cp saner:/home/saner/results .
```

## Important Notes

For more flexibility and to debug possible errors, we also provide scripts for individual analysis steps. 
As the holistic pipeline script, they refer to the `project_list` in `/home/saner/analysis/analysis.conf` to select the 
subject projects for analysis.

1. Clone the git repositories of all subject projects:
```
bash /home/saner/analysis/01_git_repos.sh
``` 

2. Analyse all subject projects with Codeface:
```
bash /home/saner/analysis/02_codeface_analysis.sh [number_of_cores]
``` 

3. Analyse all subject projects with Kaiaulu:
```
bash /home/saner/analysis/03_kaiaulu_analysis.sh 
```

4. Data preparation (e.g. identity matching) for the comparative analyses:
```
bash /home/saner/analysis/04_data_preparation.sh  
```

5. Baseline statistics calculation and comparison:
```
bash /home/saner/analysis/05_baseline_comparison.sh  
```

6. Developer network preparation and comparison:
```
bash /home/saner/analysis/06_network_comparison.sh
```

### Troubleshooting

From time to time, it may happen that Codeface's ID service gets unreachable. In this case, please execute:
```
ps aux | grep "node" 
kill [node_process_id]
tmux new -s id
bash start_id_service.sh&
```

Possibly, the analysis run of the affected subject project has to be restarted.

In the event that the analysis fails with one of the MSR tools, we also provide scripts to analyse individual subject projects separately.

Codeface:
```
bash /home/saner/tools/codeface/analysis.sh [project] [number_of_cores]
```

Kaiaulu:
```
bash /home/saner/tools/kaiaulu/analysis.sh [project]
```
