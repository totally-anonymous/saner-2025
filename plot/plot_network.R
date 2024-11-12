library(conflicted)  
library(cowplot)
library(dplyr)
library(ggplot2)
library(ggh4x) # devtools::install_github("teunbrand/ggh4x")
library(ggnetwork)
library(ggrepel)
options(ggrepel.max.overlaps = Inf)

library(gridExtra)
library(igraph)
library(network)
library(patchwork)
library(qgraph)
library(scales)
library(sna)
library(tidyverse)
library(this.path)

setwd(this.path::here())
source("layout.R", chdir=TRUE)

library(tikzDevice)
options(tikzLatexPackages = c(getOption("tikzLatexPackages"),
                              "\\usepackage{amsmath}"))

library("optparse")

Sys.setlocale('LC_ALL','C')

option_list = list(
  make_option(c("--experiment"), type="character", default=NULL,
              help="Experiment series (prior or replication)",
              metavar="character"),
  make_option(c("--project"), type="character", default=NULL, 
              help="Project to compare", metavar="character"),
  make_option(c("--range"), type="character", default=NULL, 
              help="Temporal range to compare", metavar="character"),
  make_option(c("--adj_path_codeface"), type="character", default=NULL, 
              help="Path to the directory containing Codeface's adjacency 
              matrices", metavar="character"),
  make_option(c("--adj_path_kaiaulu"), type="character", default=NULL, 
              help="Path to the directory containing Kaiaulu's adjacency 
              matrices", metavar="character"),
  make_option(c("--plot_path"), type="character", default=NULL, 
              help="Path to the plot files", metavar="character"),
  make_option(c("--names"), type="logical", default=FALSE, action="store_true",
              help="Store names"),
  make_option(c("--tikz"), type="logical", default=FALSE, action="store_true",
              help="Plot the tikz graph")
); 

opt_parser = OptionParser(option_list=option_list);
opt = parse_args(opt_parser);

create_save_locations()


#' Shortens a given developer identity to first and last name.
#'
#' @param plot_data_path the full developer identity including e-mail addresses.
#' @return the shortened name.
#' 
shorten_name <- function(s) {
  l <- strsplit(s, split="<")
  name <- trimws(l[[1]][1])
  name <- str_replace_all(name, "[^[:alnum:][:space:].']", "")
  return(name)
}

#' Replaces all developer identities by their short form (first and last name)
#'
#' @param df the data frame with full developer identities including e-mail addresses.
#' @return the updated data frame with short names.
#' 
replace_names <- function(df) {
  names_old <- colnames(df)
  names_new <- lapply(names_old, shorten_name)
  colnames(df) <- names_new
  df[,1] <- colnames(df[2:length(colnames(df))])
  return(df)
}

#' Formats a given adjacency matrix to an edge list.
#'
#' @param df the data frame in adjacency matrix format.
#' @return the data frame in edge list format.
#' 
format_df <- function(df){
  df <- replace_names(df)
  colnames(df)[1] <- "Var1"
  df <- pivot_longer(df, cols=-Var1,
                       names_to="Var2", values_to="Weight")
  return(df)
}

#' Plots an edge list as an adjacency matrix heatmap.
#'
#' @param df the data frame in edge list format.
#' @param tool the name of the tool used to construct the network.
#' @param axis_text the settings for the x- and y-axis aesthetics.
#' @param axis_text_angle the settings for the x-axis text angle.
#' @return the heatmap plot.
#' 
plot_heatmap <- function(df, tool, axis_text, axis_text_angle) {
  p <- ggplot(df, aes(x = Var1, y = Var2, fill = Weight)) +
    geom_tile(color = "black") +
    xlab(tool) + 
    scale_fill_gradientn(colours=c("#FFFFFF", COLOURS.LIST[2], COLOURS.LIST[5]),
                         values=rescale(c(-1, 0, 1))) +
    coord_fixed(ratio = 1) +
    theme_paper_base() +
    theme(axis.title.x=element_text(size = SMALL.SIZE),
          axis.title.y=element_blank(),
          axis.text = axis_text, 
          axis.text.x = axis_text_angle,
          axis.text.y = axis_text,
          legend.text = element_blank(),
          legend.title = element_blank(),
          legend.position = "none")
  return(p)
}

#' Plots the developer networks of Codeface and Kaiaulu as heatmaps next to each 
#' other.
#'
#' @param experiment the Kaiaulu configuration (prior or replication)
#' @param project the name of the project the networks were constructed for.
#' @param adj_path_codeface the path to the Codeface adjacency matrix.
#' @param adj_path_kaiaulu the path to the Kaiaulu adjacency matrix.
#' @param plot_save_path the path to store the network heatmap plot.
#' @param plot_save_file_name the file name of the network heatmap plot.
#' @param names indicator to include developer names in the plot.
#' @param tikz indicator to generate a TikZ plot.
#' 
adj_heat_map_plot <- function(experiment, project, 
                              adj_path_codeface, adj_path_kaiaulu, 
                              plot_save_path, plot_save_file_name, 
                              names = FALSE, tikz = FALSE) {
  df_c <- read.csv(adj_path_codeface, header=TRUE, check.names=FALSE, 
                   encoding = "latin-1")
  df_k <- read.csv(adj_path_kaiaulu, header=TRUE, check.names=FALSE, 
                   encoding = "latin-1")
  
  if (nrow(df_c) == 0) {
    print("No entries in the adjancency matrices. Skipping...")
  } else {
    df_c_long <- format_df(df_c)
    df_k_long <- format_df(df_k)
    scale <- ncol(df_c)/ncol(df_k)
    
    if (names) {
      axis_text = element_text(size = TINY.SIZE)
      axis_text_angle = element_text(size = TINY.SIZE, angle=60, 
                                     hjust=1, vjust=1)
    } else {
      axis_text = element_blank()
      axis_text_angle = element_blank()
    }
    
    # Create heatmap subplots.
    p_c <- plot_heatmap(df_c_long, "Codeface", axis_text, axis_text_angle)
    p_k <- plot_heatmap(df_k_long, "Kaiaulu", axis_text, axis_text_angle)
    p <- p_c + p_k
    
    # Save the plot.
    if (names) {
      plot_save_file_name <- str_c(plot_save_file_name, "_names")
    }
    adj_path <- path.join(OUTDIR_PDF, "networks", experiment, project)
    dir.create(file.path(adj_path), recursive = TRUE, showWarnings = FALSE)
    plot_save_path <- path.join(adj_path, str_c(plot_save_file_name, ".pdf"))
    
    ggsave(plot_save_path, plot = p,
           width = 2*TEXTWIDTH, height = 1*TEXTWIDTH, units = "in")
    plot(p)
    
    if (tikz) {
      tikz(str_c(OUTDIR_TIKZ, plot_save_file_name, ".tex"),
           width = 0.88*TEXTWIDTH, height = 0.5*TEXTWIDTH)
      print(p)
      dev.off()
    }
  }
}


#' Converts an adjacency matrix data frame into a data matrix.
#'
#' @param df the data frame in adjacency matrix format.
#' @return the data matrix.
#' 
format_matrix <- function(df) {
  rownames(df) <- df[,1]
  df[,1] <- NULL
  matrix <- data.matrix(df)
  return(matrix)
}

#' Plots an adjacency matrix as a developer network graph.
#'
#' @param matrix the adjacency matrix.
#' @param tool the analysis tool used to construct the network.
#' @param matrix_path the file path to the original data frame.
#' @return the developer network graph.
#' 
plot_network <- function(matrix, tool, matrix_path) {
  # Tool-specific node coloring
  if (tool == "Kaiaulu") {
    main_color <- COLOURS.LIST[6]
    m <- margin(c(0,0,0,0))
    r <- c(1,5)
  } else {
    main_color <- COLOURS.LIST[2]
    m <- margin(c(0,0,140,0))
    r <- c(1,8)
  }
  
  # Convert adjacency matrix to igraph.
  g <- igraph::graph_from_adjacency_matrix(matrix, mode = "directed", weighted = TRUE)
  g <- igraph::simplify(g, remove.multiple = FALSE, remove.loops = TRUE,
                        edge.attr.comb=list(weight="sum"))
  
  # Add additional attributes for plotting.
  if (grepl("spark", matrix_path) & grepl("range_13", matrix_path)) {
    V(g)$color <- ifelse(V(g)$name ==  "Mridul Muralidharan" | V(g)$name == "Matei Zaharia", TRUE, FALSE)
    V(g)$label_color <- ifelse(V(g)$name ==  "Mridul Muralidharan" | V(g)$name == "Matei Zaharia", TRUE, FALSE)
  } else {
    V(g)$color <- FALSE
    V(g)$label_color <- FALSE
  }
  
  V(g)$size <- igraph::degree(g)
  E(g)$weight_unscaled <- E(g)$weight
  E(g)$weight <- E(g)$weight / max(E(g)$weight)

  # Adjust the graph layout.
  lo <- igraph::layout_in_circle(g)
  lo <- norm_coords(lo, ymin=-1, ymax=1, xmin=-1, xmax=1)
  
  # Conver igraph to ggnetwork plot.
  gnet <- ggnetwork(g, layout=lo)
  
  if (gsize(g) > 0) {
    p <- ggplot(gnet, aes(x, y, xend = xend, yend = yend)) +
      geom_edges(color = COLOURS.LIST[10], linewidth=0.25, 
                 arrow = arrow(length = unit(4, "pt"), type = "closed")) +
      geom_edgetext(aes(label = weight_unscaled), color = COLOURS.LIST[3], size=1.6) +
      ylab(tool) +
      geom_nodes(aes(color = color, size=size)) +
      scale_color_manual(values = c(main_color, COLOURS.LIST[5])) +
      scale_size_continuous(range = r) +
      geom_nodelabel_repel(aes(label = name), color=COLOURS.LIST[3],
                           box.padding = unit(0.7, "lines"), size=2) +
      theme_paper_base() +
      theme(axis.line=element_blank(),
            axis.text.x=element_blank(),
            axis.text.y=element_blank(),
            axis.ticks=element_blank(),
            axis.title.x=element_blank(),
            axis.title.y=element_text(size=SMALL.SIZE),
            panel.background = element_rect(fill="white"),
            panel.grid = element_blank(),
            panel.border = element_blank(),
            legend.text = element_blank(),
            legend.title = element_blank(),
            legend.position = "none",
            plot.margin = m)
  } else {
    p <- ggplot(gnet, aes(x, y, xend = xend, yend = yend)) +
      ylab(tool) +
      geom_nodes(aes(color = color, size=size)) +
      scale_color_manual(values = c(main_color, COLOURS.LIST[5])) +
      scale_size_continuous(range = r) +
      geom_nodelabel_repel(aes(label = name), color=COLOURS.LIST[3],
                           box.padding = unit(0.7, "lines"), size=2) +
      theme_paper_base() +
      theme(axis.line=element_blank(),
            axis.text.x=element_blank(),
            axis.text.y=element_blank(),
            axis.ticks=element_blank(),
            axis.title.x=element_blank(),
            axis.title.y=element_text(size=SMALL.SIZE),
            panel.background = element_rect(fill="white"),
            panel.grid = element_blank(),
            panel.border = element_blank(),
            legend.text = element_blank(),
            legend.title = element_blank(),
            legend.position = "none",
            plot.margin = m)
  }
  return(p)
}

#' Plots the developer network graphs of Codeface and Kaiaulu next to each other.
#'
#' @param experiment the Kaiaulu configuration (prior or replication)
#' @param project the name of the project the networks were constructed for.
#' @param adj_path_codeface the path to the Codeface adjacency matrix.
#' @param adj_path_kaiaulu the path to the Kaiaulu adjacency matrix.
#' @param plot_save_path the path to store the network graph plot.
#' @param plot_save_file_name the file name of the network graph plot.
#' @param names indicator to include developer names in the plot.
#' @param tikz indicator to generate a TikZ plot.
#' 
network_graph_plot <- function(experiment, project, 
                               adj_path_codeface, adj_path_kaiaulu, 
                               plot_save_path, plot_save_file_name, 
                               names = FALSE, tikz = FALSE) {
  df_c <- read.csv(adj_path_codeface, header=TRUE, check.names=FALSE, 
                   encoding = "latin-1")
  df_k <- read.csv(adj_path_kaiaulu, header=TRUE, check.names=FALSE, 
                   encoding = "latin-1")
  
  df_c <- replace_names(df_c)
  df_k <- replace_names(df_k)
  
  # Format data frames into a square matrix.
  matrix_c <- format_matrix(df_c)
  matrix_k <- format_matrix(df_k)

  # Plot the network.
  p_c <- plot_network(matrix_c, "Codeface", adj_path_codeface)
  p_k <- plot_network(matrix_k, "Kaiaulu", adj_path_kaiaulu)
  p <- ggdraw() + draw_plot(p_c) + draw_plot(p_k, x=0.38, y=0.01, 
                                             width=0.57, height=0.37)
  
  plot_save_path <- path.join(OUTDIR_PDF, "networks", experiment, project, 
                              str_c(plot_save_file_name, ".pdf"))
  ggsave(plot_save_path, plot = p, width=0.48*TEXTWIDTH, height = 0.7*TEXTWIDTH, 
         units = "in")
  plot(p)
  
  if (tikz) {
    tikz(str_c(OUTDIR_TIKZ, plot_save_file_name, ".tex"),
         width = 0.48*TEXTWIDTH, height = 0.7*TEXTWIDTH)
    print(p)
    dev.off()
  }
}


adj_path_codeface <- path.join(opt$adj_path_codeface, opt$project, 
                               str_c("range_", opt$range, "_adjacency_matrix_with_names.csv"))
adj_path_kaiaulu <- path.join(opt$adj_path_kaiaulu, opt$project, 
                              str_c("range_", opt$range, "_adjacency_matrix.csv"))

# Network heatmap plot
plot_save_file_name <- str_c("adj_heatmap_", opt$experiment, "_", opt$project, 
                             "_", opt$range)
adj_heat_map_plot(opt$experiment, opt$project,
                  adj_path_codeface, adj_path_kaiaulu, opt$plot_path,
                  plot_save_file_name, opt$names, opt$tikz)

# Network graph plot
plot_save_file_name <- str_c("networks_", opt$experiment, "_", opt$project, 
                             "_", opt$range)
network_graph_plot(opt$experiment, opt$project,
                   adj_path_codeface, adj_path_kaiaulu, opt$plot_path, 
                   plot_save_file_name, opt$names, opt$tikz)