## This file is part of Codeface. Codeface is free software: you can
## redistribute it and/or modify it under the terms of the GNU General Public
## License as published by the Free Software Foundation, version 2.
##
## This program is distributed in the hope that it will be useful, but WITHOUT
## ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
## FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
## details.
##
## You should have received a copy of the GNU General Public License
## along with this program; if not, write to the Free Software
## Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
##
## Copyright 2014 by Roger Meier <roger@bufferoverflow.ch>
## Copyright 2015 by Andreas Ringlstetter <andreas.ringlstetter@gmail.com>
## Copyright 2015 by Wolfgang Mauerer <wolfgang.mauerer@oth-regensburg.de>
## Copyright 2015 by Claus Hunsen <hunsen@fim.uni-passau.de>
## All Rights Reserved.

filter.installed.packages <- function(packageList)  {
    if("-f" %in% commandArgs(trailingOnly = TRUE)) {
        return(packageList)
    } else {
        return(packageList[which(packageList %in% installed.packages()[,1] == FALSE)])
    }
}

## Remove package from all libraries (i.e., .libPaths())
remove.installed.packages <- function(pack) {
    for (path in .libPaths()) {
        # try to remove package (hard stop() otherwise, if not existing)
        tryCatch({
            remove.packages(pack, path)
            print(paste("removed previously installed package", pack))
        }, error = function(e) {
            # silently ignore errors (the reason would be that a package
            # is not installed)
        })
    }
}

## (re-)install a package from github
reinstall.package.from.github <- function(package, url) {

    ## if package is installed, remove it completely from all libraries
    p <- filter.installed.packages(c(package))
    if(length(p) == 0) {
        remove.installed.packages(package)
    }

    ## Re-install packages
    devtools::install_github(url, quiet=T)
}

library(parallel)
num.cores <- detectCores(logical=TRUE)
if (is.na(num.cores)) {
    num.cores <- 1
}

## Install commonly available dependencies
## Install progress package (workaround avoiding subsequent installation errors)
install.packages("progress", dependencies=TRUE)

## Install wrapr package for dictionary sorting
install.packages("wrapr")

## Install svglite and ragg graphics device packages
## to prevent a graphics API version mismatch
install.packages("svglite")
install.packages("ragg")

## install potentially unresolvable dependencies
install.packages("devtools")
library(devtools)
devtools::install_url("https://cran.r-project.org/src/contrib/Archive/BH/BH_1.75.0-0.tar.gz")
devtools::install_url("https://cran.r-project.org/src/contrib/Archive/slam/slam_0.1-40.tar.gz")
devtools::install_url("https://cran.r-project.org/src/contrib/Archive/arules/arules_1.5-0.tar.gz")
devtools::install_url("https://cran.r-project.org/src/contrib/Archive/proxy/proxy_0.4-16.tar.gz")
#devtools::install_url("https://cran.r-project.org/src/contrib/Archive/tm/tm_0.7-1.tar.gz")
devtools::install_url("https://cran.r-project.org/src/contrib/Archive/logging/logging_0.8-104.tar.gz")
#devtools::install_url("https://cran.r-project.org/src/contrib/Archive/markovchain/markovchain_0.6.9.11.tar.gz")
devtools::install_url("https://cran.r-project.org/src/contrib/Archive/rjson/rjson_0.2.20.tar.gz")
devtools::install_github("nathan-russell/hashmap")

## install from BioConductor
p <- filter.installed.packages(c("BiRewire", "BiocGenerics", "graph"))
if(length(p) > 0) {

    #source("http://bioconductor.org/biocLite.R")
    #biocLite(p)
    install.packages("BiocManager")
    BiocManager::install(p)
}

## install from CRAN
p <- filter.installed.packages(c("statnet", "tm", "optparse", "arules", "data.table", "plyr",
                                 "igraph", "zoo", "xts", "lubridate", "xtable", "ggplot2",
                                 "reshape", "wordnet", "stringr", "yaml", "ineq",
                                 "scales", "gridExtra", "scales", "RMySQL", "svglite",
                                 "RCurl", "mgcv", "shiny", "dtw", "httpuv", "devtools",
                                 "corrgram", "logging", "png", "rjson", "lsa", "RJSONIO",
                                 "GGally", "corrplot", "psych", "markovchain", "hashmap"))
if(length(p) > 0) {
    install.packages(p, dependencies=T, verbose=F, quiet=F, Ncpus=num.cores)
}

## Install following packages from different sources
## and update existing installations, if needed
reinstall.package.from.github("tm.plugin.mail", "bockthom/tm-plugin-mail/pkg")
reinstall.package.from.github("snatm", "nicolehoess/snatm/pkg")
reinstall.package.from.github("shinyGridster", "wch/shiny-gridster")
reinstall.package.from.github("shinybootstrap2", "rstudio/shinybootstrap2")

## Bioconductor packages
#source("https://bioconductor.org/biocLite.R")
#biocLite("Rgraphviz")
BiocManager::install("Rgraphviz")
