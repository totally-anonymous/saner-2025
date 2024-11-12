#! /usr/bin/env Rscript

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
## Copyright 2014 by Siemens AG, Mitchell Joblin <mitchell.joblin@siemens.com>
## All Rights Reserved.

## Experimental file to use the ideas of code ownership to find owners of functions
## during a certain revision
## Coupling between functions is based on evolutionary dependencies. The couplings
## are then used to identify collaboration challenges by identifying
## strong coupling between functions with different owners

source("../db.r", chdir=TRUE)
source("../query.r", chdir=TRUE)
source("../config.r", chdir=TRUE)
source("../dependency_analysis.r", chdir=TRUE)
library(igraph)
library(lubridate)

query.max.owner <- function(con, start.date, end.date) {
  query <- str_c('SELECT name, file, entityId, size ',
                 'FROM commit, commit_dependency d1, person ',
                 'WHERE commit.id = d1.commitId ',
                 'AND person.id = commit.author ',
                 'AND entityId !=', sq('FILE_LEVEL'), ' ',
                 'AND commit.commitDate >= ', sq(start.date), ' ',
                 'AND commit.commitDate < ', sq(end.date), ' ',
                 'AND size=(SELECT max(size) ',
                            'FROM commit_dependency d2 ',
                            'WHERE d1.file = d2.file ',
                            'AND d1.entityId= d2.entityId)')

  dat <- dbGetQuery(con, query)
  cols <- c('file', 'entityId')

  if(nrow(dat) > 0) {
    dat$entity <- apply(dat[,cols], 1, paste, collapse="/")
  }

  dat <- dat[, !names(dat) %in% cols]

  return(dat)
}


run.analysis <- function(conf, start.date, end.date) {
  project.id <- conf$pid

  ## Get ownership relationships
  owner.df <- query.max.owner(conf$con, start.date, end.date)
  owner.edgelist <- subset(owner.df, select = c(name, entity))
  owner.list <- unique(owner.df$name)
  entity.owner.dic <-split(owner.df$name, owner.df$entity)

  ## Get frequent item set relationships
  learning.span <- ddays(365)
  learning.start.date <- start.date - learning.span
  freq.items <- get.frequent.item.sets(conf$con, project.id, learning.start.date, end.date)
  freq.items.edgelist <- compute.item.sets.edgelist(freq.items)

  ## Remove edges that don't have evolutionary link
  keep.row <- owner.edgelist$entity %in% unique(unlist(freq.items))
  owner.edgelist.trimmed <- owner.edgelist[keep.row,]

  ## Add Evolutionary Links
  keep.row <- apply(freq.items.edgelist, 1,
                    function(x) {
                      all(x %in% owner.edgelist.trimmed$entity)})

  freq.items.edgelist.trimmed <- freq.items.edgelist[keep.row,]
  colnames(owner.edgelist.trimmed) <- c('X1', 'X2')
  owner.evol.edgelist <- rbind(owner.edgelist.trimmed, freq.items.edgelist.trimmed)

  ## Find problem dependencies
  problem <- apply(owner.evol.edgelist, 1,
                    function(r) {
                      if(!r[1] %in% owner.list){
                        dev1 <- entity.owner.dic[r[1]]
                        dev2 <- entity.owner.dic[r[2]]
                        length(union(dev1, dev2)) > 1
                      } else {FALSE}})

  #colnames(owner.evol.edgelist) <- c('From', 'To')
  g <- graph.data.frame(owner.evol.edgelist)
  V(g)$type <- V(g)$name %in% owner.list

  V(g)[!type]$name <- sapply(V(g)[!type]$name, function(x) {
                                   s <- unlist(strsplit(x,'/'))
                                   l <- length(s)
                                   name <- paste(s[l-1], s[l], sep='/')})
  ## Set Entity size
  V(g)[!type]$size <- 2
  ## Set Developer size
  V(g)[type]$size <- 10
  V(g)[type]$color <- 'green'
  E(g)$arrow.size <- 0.25
  E(g)[problem]$color <- 'red'
  E(g)[!problem]$color <- 'black'
  V(g)[!type]$label.cex <- 0.8
  V(g)[!type]$label.dist <- 0.15
  V(g)[type]$label.dist <- 0
  space <- 3
  #l <- layout.fruchterman.reingold(g, niter=500, area=vcount(g)^space,
  #                                 repulserad=vcount(g)^space)
  pdf("/tmp/ownership.pdf")
  plot(g, layout=layout_with_kk, niter=1000)
  dev.off()
}

config.script.run({
    conf <- config.from.args(positional.args=list("start_date", "end_date"),
                             require.project=TRUE)
    start.date <- ymd(conf$start_date)
    end.date <- ymd(conf$end_date)
    run.analysis(conf, start.date, end.date)
})
