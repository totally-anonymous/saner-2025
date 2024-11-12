library(conflicted)  
library(dplyr)
library(ggplot2)
library(ggh4x) # devtools::install_github("teunbrand/ggh4x")
library(gridExtra)
library(patchwork)
library(scales)
library(tidyverse)
library(this.path)  

setwd(this.path::here())
source("layout.R", chdir=TRUE)

library(knitr)
library(kableExtra)
options(knitr.table.format = "latex")

library(tikzDevice)
options(tikzLatexPackages = c(getOption("tikzLatexPackages"),
                              "\\usepackage{amsmath}"))

library("optparse")

option_list = list(
  make_option(c("--network_comparison_path"), type="character", default=NULL,
              help="Path to the directory containing the network similarity table"),
  make_option(c("--plot_path"), type="character", default=NULL, 
              help="Path to the plot directory", metavar="character")
); 

opt_parser = OptionParser(option_list=option_list);
opt = parse_args(opt_parser);

create_save_locations()

#' Formats project names for aesthetics.
#'
#' @param df the data frame in which the names should be replaced.
#' @return the updated data frame
#' 
replace_project_names <- function(df) {
  df <- df %>%
    mutate(project=recode(project, "camel"="Camel", "django"="Django",
                          "gtk"="GTK", "jailhouse"="Jailhouse",
                          "openssl"="OpenSSL", "postgres"="Postgres", 
                          "qemu"="QEMU", "rstudio"="RStudio", 
                          "spark"="Spark", "wine"="Wine"))
  return(df)
}

#' Constrcuts the network similarity metrics table for all tool configurations.
#'
#' @param network_comparison_path the path to the comparison data frame.
#' @param plot_path the path to store the table.
#' 
network_comparison_table <- function(network_comparison_path, plot_path) {
  df <- data.frame(read_csv(path.join(network_comparison_path, 
                                      "network_similarity.csv")))
  df <- replace_project_names(df)
  df <- select(df, c("project", 
                     "mean_graph_edit_distance_prior",
                     "max_graph_edit_distance_prior",
                     "mean_graph_edit_distance_replication",
                     "max_graph_edit_distance_replication",
                     "mean_density_codeface",
                     "mean_density_kaiaulu_prior",
                     "mean_density_kaiaulu_replication",
                     "mean_edge_weight_codeface",
                     "max_edge_weight_codeface",
                     "mean_edge_weight_kaiaulu_prior",
                     "max_edge_weight_kaiaulu_prior",
                     "mean_edge_weight_kaiaulu_replication",
                     "max_edge_weight_kaiaulu_replication"))
  
  cap <- paste("Graph similarity for networks constructed by Codeface (C) and 
               Kaiaulu (K) with prior (P) and replication (R) configuration 
               measured by graph edit distance, network density and edge weight. 
               \\label{tab:network-similarity}", sep = "")
  
  df <- df %>% 
    mutate_if(is.numeric, round, 2)
  
  round_cols <- c("mean_graph_edit_distance_prior",
                  "mean_graph_edit_distance_replication",
                  "mean_edge_weight_codeface",
                  "max_edge_weight_codeface",
                  "mean_edge_weight_kaiaulu_prior",
                  "max_edge_weight_kaiaulu_prior",
                  "mean_edge_weight_kaiaulu_replication",
                  "max_edge_weight_kaiaulu_replication")
  for (c in round_cols) {
    df[, c] <- round(df[,c], digits = 0)
  }
  
  colnames(df) <- c("Project", 
                    "Mean", "Max",
                    "Mean", "Max",
                    "Mean", "Mean", "Mean",
                    "Mean", "Max",
                    "Mean", "Max",
                    "Mean", "Max")
  df_out <- kable(df, booktabs = TRUE, linesep = "", caption = cap, escape = FALSE) %>%
    add_header_above(c("", "C/K(P)"=2, "C/K(R)"=2, 
                       "C", "K(P)", "K(R)",
                       "C"=2, "K(P)"=2, "K(R)"=2), bold=TRUE) %>% 
    add_header_above(c("", "Graph Edit Distance"=4, 
                       "Density"=3,
                       "Edge Weight"=6), bold=TRUE) %>% 
    row_spec(0, bold=TRUE) %>%
    kable_styling(latex_options = "scale_down")
  
  # Workaround: fix minor formatting issues
  df_out <- gsub("table", "table*", df_out)
  df_out <- gsub(" ([0-9]+) ", " \\\\num{\\1} ", df_out)
  df_out <- gsub(" ([0-9]).([0-9])([0-9]) ", " \\\\num{\\1.\\2\\3} ", df_out)
  df_out <- gsub(" ([0-9]+)\\\\\\\\", " \\\\num{\\1}\\\\\\\\", df_out)
  
  dir.create(plot_path, recursive = TRUE, showWarnings = FALSE)
  plot_file_path <- path.join(plot_path, "network_comparison_table.tex")
  writeLines(df_out, plot_file_path)
}


# Network similarity table
table_path <- path.join(opt$plot_path, "table")
network_comparison_table(opt$network_comparison_path, table_path)
