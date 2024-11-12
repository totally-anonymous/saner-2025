# These plots are inspired by https://doi.org/10.48550/arXiv.2405.07770.

library(conflicted)  
library(dplyr)
library(dtw)
library(ggplot2)
library(ggh4x) # devtools::install_github("teunbrand/ggh4x")
library(gridExtra)
library(scales)
library(tidyverse)
library(TSclust)
library(this.path)
library(matrixStats)

setwd(this.path::here())
source("layout.R", chdir=TRUE)

library(knitr)
library(formattable)
library(kableExtra)
options(knitr.table.format = "latex")

library(tikzDevice)
options(tikzLatexPackages = c(getOption("tikzLatexPackages"),
                              "\\usepackage{amsmath}"))

library("optparse")

option_list = list(
  make_option(c("--statistics_path_codeface"), type="character", default=NULL, 
              help="Path to the Codeface statistics directory", 
              metavar="character"),
  make_option(c("--statistics_path_kaiaulu_prior"), type="character", 
              default=NULL, help="Path to the Kaiaulu statistics directory", 
              metavar="character"),
  make_option(c("--statistics_path_kaiaulu_replication"), type="character", 
              default=NULL, help="Path to the Kaiaulu statistics directory", 
              metavar="character"),
  make_option(c("--rank_path_prior"), type="character", default=NULL, 
              help="Path to the ranking comparison directory", 
              metavar="character"),
  make_option(c("--rank_path_replication"), type="character", default=NULL, 
              help="Path to the ranking comparison directory", 
              metavar="character"),
  make_option(c("--plot_path"), type="character", default=NULL, 
              help="Path to the plot files", metavar="character")
); 

opt_parser = OptionParser(option_list=option_list);
opt = parse_args(opt_parser);

create_save_locations()

#' Determines the list of projects to plot. In case of a partial run of the
#' analysis pipeline, not all desired projects may be available.
#'
#' @param project the list of desired project names to plot.
#' @param available_projects a list of files with the project name as part of their name.
#' @return the list of available projects.
#'
check_project_availability <- function(projects, available) {
  for (p in projects) {
    found <- FALSE
    for (p_a in available) {
      if (startsWith(p_a, p)) {
        found <- TRUE
        break
      }
    }
    if (!found) {
      # Remove non-available projects from the list.
      projects <- projects[!projects == p]
    }
  }
  return(projects)
}

#' Merges the metrics calculated on the baseline data for each tool configuration.
#'
#' @param codeface_path the path to the metrics calculated on Codeface data.
#' @param kaiaulu_path_prior the path to the metrics calculated on Kaiaulu data with prior configuration.
#' @param kaiaulu_path_prior the path to the metrics calculated on Kaiaulu data with replication configuration.
#' @return the merged data set.
#' 
load_statistics_df <- function(codeface_path, kaiaulu_path_prior, 
                               kaiaulu_path_replication) {
  kaiaulu_files_prior <- list.files(kaiaulu_path_prior)
  kaiaulu_files_replication <- list.files(kaiaulu_path_replication)
  codeface_files <- list.files(codeface_path)
  
  df_all <- data.frame()
  
  for (f in codeface_files){
    f_path <- file.path(codeface_path, f)
    df <- data.frame(read_csv(f_path))
    df <- df %>%
      mutate(tool=recode(tool, "codeface"="Codeface"))
    df_all <- rbind(df_all, df)
  }
  
  for (f in kaiaulu_files_prior){
    f_path <- file.path(kaiaulu_path_prior, f)
    df <- data.frame(read_csv(f_path))
    df <- df %>%
      mutate(tool=recode(tool, "kaiaulu"="Kaiaulu (P)"))
    df_all <- rbind(df_all, df)
  }
  
  for (f in kaiaulu_files_replication){
    f_path <- file.path(kaiaulu_path_replication, f)
    df <- data.frame(read_csv(f_path))
    df <- df %>%
      mutate(tool=recode(tool, "kaiaulu"="Kaiaulu (R)"))
    df_all <- rbind(df_all, df)
  }
  
  return(df_all)
}

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

#' Formats data for the time series metrics plot.
#'
#' @param statistics_path_codeface the path to the metrics calculated on Codeface data.
#' @param statistics_path_kaiaulu_prior the path to the metrics calculated on Kaiaulu data with prior configuration.
#' @param statistics_path_kaiaulu_replication the path to the metrics calculated on Kaiaulu data with replication configuration.
#' @param plot_data_path the path to store the formatted data.
#' @param file_name the file name of the formatted data.
#' @param project_subset the subset of projects to consider.
#'
load_ts_plot_data <- function(statistics_path_codeface, 
                              statistics_path_kaiaulu_prior, 
                              statistics_path_kaiaulu_replication,
                              plot_data_path, file_name, project_subset) {
  df_all <- load_statistics_df(statistics_path_codeface, 
                               statistics_path_kaiaulu_prior,
                               statistics_path_kaiaulu_replication)
  df_all <- dplyr::filter(df_all, project %in% project_subset)
  df_all <- replace_project_names(df_all)
  
  column_map <- data.frame("old" = c("project", "tool", "range_id",
                                     "n_commits",
                                     "n_files",
                                     "n_named_entities",
                                     "n_devs"),
                           "new" = c("Project", "Tool", "Time",
                                     "\\#\\,Commits",
                                     "\\#\\,Files",
                                     "\\#\\,Entities",
                                     "\\#\\,Developers"))
  names(df_all) <- column_map$new[match(names(df_all), column_map$old)]

  # Convert data frame to long format
  df <- pivot_longer(df_all, cols=c("\\#\\,Commits",
                                    "\\#\\,Files",
                                    "\\#\\,Entities",
                                    "\\#\\,Developers"),
                     names_to="Feature", values_to="Count")  
  
  dir.create(plot_data_path, recursive = TRUE, showWarnings = FALSE)
  plot_data_path <- path.join(plot_data_path, file_name)
  write_csv(df, plot_data_path)
}

#' Plots the time series metrics for all tool configurations.
#'
#' @param plot_data_path the path to the formatted data.
#' @param plot_save_file_name the file name of the plot.
#' 
git_ts_plot <- function(plot_data_path, plot_save_file_name) {
  df <- data.frame(read_csv(plot_data_path))

  p <- ggplot(df, aes(x = Time, y = Count, color = Tool)) +
    labs(x = "Time in 3 month intervals") +
    geom_line(linewidth = LINE.SIZE-0.1, linetype="solid", alpha=0.6,
              position=position_dodge(width=1.5)) +
    geom_point(shape = 18, size = POINT.SIZE*1.2, alpha=0.6, 
               position=position_dodge(width=1.5)) +
    scale_colour_manual(values=COLOURS.LIST[c(2,6,8)], name="Tool") +
    facet_grid2(Feature ~ Project,
                scales = "free", independent = "y") +
    scale_x_continuous(breaks = pretty(df$Time, n = 5)) +
    theme_paper_base() +
    theme(axis.text = element_text(size = TINY.SIZE),
          axis.text.x = element_text(size = TINY.SIZE),
          axis.text.y = element_text(size = TINY.SIZE),
          axis.title.x = element_text(size = SMALL.SIZE),
          axis.title.y = element_text(size = SMALL.SIZE), 
          legend.text = element_text(size = SMALL.SIZE),
          legend.title = element_text(size = SMALL.SIZE),
          legend.key.size = unit(SYM.SIZE, "line"), # Legend symbol width
          legend.position = "top",
          strip.text = element_text(size = SMALL.SIZE)) # Facet title size
  ggsave(str_c(OUTDIR_PDF, plot_save_file_name, ".pdf"), plot = p, 
         width = TEXTWIDTH, height = 0.6*TEXTWIDTH, units = "in")
  plot(p)

  tikz(str_c(OUTDIR_TIKZ, plot_save_file_name, ".tex"), 
       width = TEXTWIDTH, height =  0.6*TEXTWIDTH)
  print(p)
  dev.off()
}


#' Formats data for the time series similarity table.
#'
#' @param statistics_path_codeface the path to the metrics calculated on Codeface data.
#' @param statistics_path_kaiaulu_prior the path to the metrics calculated on Kaiaulu data with prior configuration.
#' @param statistics_path_kaiaulu_replication the path to the metrics calculated on Kaiaulu data with replication configuration.
#' @param plot_data_path the path to store the formatted data.
#' @param file_name the file name of the formatted data.
#' 
load_similarity_data <- function(statistics_path_codeface,
                                 statistics_path_kaiaulu_prior,
                                 statistics_path_kaiaulu_replication,
                                 plot_data_path, file_name) {
  df_all <- load_statistics_df(statistics_path_codeface,
                               statistics_path_kaiaulu_prior,
                               statistics_path_kaiaulu_replication)
  df_cor <- data.frame(matrix(ncol = 15, nrow = 0))
  
  # Calculate similarity.
  tools <- c("Codeface", "Kaiaulu (P)", "Kaiaulu (R)")
  for (i in seq_along(tools)) {
    if (i < length(tools)-1) {  # -1 to skip Kaiaulu intra-tool comparison
      for (j in seq(from=i+1, to=length(tools))) {
        if (i == j) {
          next
        } else {
          df_tools <- data.frame(matrix(ncol = 15, nrow = 0))
          for (p in unique(df_all$project)) {
            row <- data.frame(tool_1=NA, tool_2=NA, project=NA,
                              commits_ncd=NA, commits_dtw=NA, commits_cor=NA,
                              files_ncd=NA, files_dtw=NA, files_cor=NA,
                              entities_ncd=NA, entities_dtw=NA, entities_cor=NA,
                              developers_ncd=NA, developers_dtw=NA, developers_cor=NA)
            row$tool_1 <- tools[i]
            row$tool_2 <- tools[j]
            row$project <- p
            
            # Measure the time series similarity for all features.
            # Commits
            x <- df_all[df_all$project==p & df_all$tool==tools[i], ]$n_commits
            y <- df_all[df_all$project==p & df_all$tool==tools[j], ]$n_commits
            res <- cor.test(x, y, method = "spearman")
            row$commits_ncd <- diss.NCD(x, y, type="min")
            row$commits_dtw <- dtw(scale(x), scale(y))$normalizedDistance
            row$commits_cor <- res$estimate
            
            # Files
            x <- df_all[df_all$project==p & df_all$tool==tools[i], ]$n_files
            y <- df_all[df_all$project==p & df_all$tool==tools[j], ]$n_files
            res <- cor.test(x, y, method = "spearman")
            row$files_ncd <- diss.NCD(x, y, type="min")
            row$files_dtw <- dtw(scale(x), scale(y))$normalizedDistance
            row$files_cor <- res$estimate
            
            # Entities
            x <- df_all[df_all$project==p & df_all$tool==tools[i], ]$n_named_entities
            y <- df_all[df_all$project==p & df_all$tool==tools[j], ]$n_named_entities
            res <- cor.test(x, y, method = "spearman")
            row$entities_ncd <- diss.NCD(x, y, type="min")
            row$entities_dtw <- dtw(scale(x), scale(y))$normalizedDistance
            row$entities_cor <- res$estimate
            
            # Developers
            x <- df_all[df_all$project==p & df_all$tool==tools[i], ]$n_devs
            y <- df_all[df_all$project==p & df_all$tool==tools[j], ]$n_devs
            row$developers_ncd <- diss.NCD(x, y, type="min")
            row$developers_dtw <- dtw(scale(x), scale(y))$normalizedDistance
            row$developers_cor <- res$estimate
            df_tools <- rbind(df_tools, row)
          }
          
          # Add column mean.
          cols <- sapply(df_tools, is.numeric)
          avg = data.frame(tool_1 = NA, tool_2 = NA, project="Mean \\mu", 
                           t(colMeans(df_tools[cols])))
          df_tools <- rbind(df_tools, avg)
          
          # Column column standard deviation.
          st = data.frame(tool_1 = NA, tool_2 = NA, project="Std. Dev. \\sigma", 
                          t(colSds(as.matrix(df_tools[cols]))))
          print(st)
          df_tools <- rbind(df_tools, st)
          
          df_cor <- rbind(df_cor, df_tools)
        }
      }
    }
  }
  
  df_cor <- replace_project_names(df_cor)
  
  dir.create(plot_data_path, recursive = TRUE, showWarnings = FALSE)
  plot_data_path <- path.join(plot_data_path, file_name)
  write_csv(df_cor, plot_data_path)
}

#' Constrcuts the time series similarity metrics table for all tool configurations.
#'
#' @param plot_data_path the path to the formatted data.
#' @param plot_path the path to store the table.
#' 
git_similarity_table <- function(plot_data_path, plot_path) {
  df <- data.frame(read_csv(plot_data_path))
  
  df <- df %>%
    mutate_if(is.numeric, round, digits=2)

  cap <- paste("Time series similarity for Codeface and Kaiaulu with prior (P)
               and replication (R) configuration measured by Normalised
               Compression Distance (Ncd), Dynamic Time Warping (Dtw) 
               and Spearman's Rank Correlation Coefficient (Cor). For Ncd and Dtw, 
               values close to zero (gray bar) are desired;
               for correlation, values close to one (orange bar) 
               indicate higher similarity. \\label{tab:git-ts}", sep = "")
  
  if (nrow(df) >= 24) {
    df[2:12, c("tool_1", "tool_2")] <- ""
    df[14:24, c("tool_1", "tool_2")] <- ""
    colnames(df) <- c("Tools", "", "Project",
                      "NCD", "DTW", "Cor",
                      "NCD", "DTW", "Cor",
                      "NCD", "DTW", "Cor",
                      "NCD", "DTW", "Cor")
    df_out <- kable(df, booktabs = TRUE, linesep = "", caption = cap, escape = FALSE) %>%
      add_header_above(c("", "", "", "Commits"=3, "Files"=3, "Entities"=3, 
                         "Developers"=3), bold=TRUE) %>% 
      row_spec(0, bold=TRUE) %>% 
      row_spec(10, hline_after = TRUE) %>%
      row_spec(12, hline_after = TRUE) %>%
      row_spec(22, hline_after = TRUE) %>%
      kable_styling(latex_options = "scale_down")
  } else {
    colnames(df) <- c("Tools", "", "Project",
                      "NCD", "DTW", "Cor",
                      "NCD", "DTW", "Cor",
                      "NCD", "DTW", "Cor",
                      "NCD", "DTW", "Cor")
    
    df_out <- kable(df, booktabs = TRUE, linesep = "", caption = cap, escape = FALSE) %>%
      add_header_above(c("", "", "", "Commits"=3, "Files"=3, "Entities"=3, 
                         "Developers"=3), bold=TRUE) %>% 
      kable_styling(latex_options = "scale_down")
  }
  
  # Add colored bars to the background of table cells according to their value
  df_out <- gsub("& ([0-9]).([0-9])([0-9])", "& \\\\databar{\\1.\\2\\3}", df_out)
  
  # Workaround: fix minor formatting issues
  df_out <- gsub("table", "table*", df_out)
  df_out <- gsub("midrule\\\\\\\\", "midrule", df_out)
  
  dir.create(plot_path, recursive = TRUE, showWarnings = FALSE)
  plot_file_path <- path.join(plot_path, "ts_cor_table.tex")
  writeLines(df_out, plot_file_path)
}


#' Formats data for the box plot of jointly identified files, entities and developers.
#'
#' @param rank_path_prior the path to the comparison results of Codeface and Kaiaulu with prior configuration.
#' @param rank_path_replication the path to the comparison results of Codeface and Kaiaulu with replication configuration.
#' @param plot_data_path the path to store the formatted data.
#' @param file_name the file name of the formatted data.
#' 
load_box_plot_data <- function(rank_path_prior, rank_path_replication, 
                               plot_data_path, file_name) {
  rank_file_prior_path <- path.join(rank_path_prior, "rankings_comparison_all.csv")
  rank_file_replication_path <- path.join(rank_path_replication, 
                                          "rankings_comparison_all.csv")
  df_prior <- read.csv(rank_file_prior_path)
  df_replication <- read.csv(rank_file_replication_path)
  
  df_prior <- df_prior %>%
    mutate(type = "Codeface and Kaiaulu (P)")
  df_replication <- df_replication %>%
    mutate(type = "Codeface and Kaiaulu (R)")
  df <- rbind(df_prior, df_replication)
  
  df_plot <- df[,c("project", "range", "dev_overlap_perc", 
                   "file_overlap_perc", "entity_overlap_perc", "type")]
  
  # Formatting and renaming
  df_plot <- replace_project_names(df_plot)
  names <- c("Project", "Time", "Developers", "Files", "Entities", "Type")
  colnames(df_plot) <- names
  
  # Convert dataframe to long format.
  df_plot <- pivot_longer(df_plot, cols=c("Developers", "Files", "Entities"),
                          names_to="Overlap", values_to="Value")
  
  dir.create(plot_data_path, recursive = TRUE, showWarnings = FALSE)
  plot_data_path <- path.join(plot_data_path, file_name)
  write_csv(df_plot, plot_data_path)
}

#' Plots the percentage of jointly identified files, entities and developers as
#' a box plot for all tool configurations.
#'
#' @param plot_data_path the path to the formatted data.
#' @param plot_save_file_name the file name of the plot.
#' 
git_box_plot <- function(plot_data_path, plot_save_file_name) {
  df <- data.frame(read_csv(plot_data_path))
  
  p <- ggplot(df, aes(x = Type, y = Value)) +
    labs(color="Intersection of ") +
    geom_jitter(shape=17, size=POINT.SIZE-0.1, alpha=0.1, width=0.45, height=0.02) +
    geom_boxplot(aes(x = Type, y = Value, color = Type), alpha = 0.6,
                 linewidth=LINE.SIZE, outlier.size = POINT.SIZE+0.2) +
    geom_hline(yintercept = 0, col = COLOURS.LIST[3], linewidth=LINE.SIZE,
               linetype = 2, alpha = 0.7) +
    geom_hline(yintercept = 0.5, col = COLOURS.LIST[3], linewidth=LINE.SIZE) +
    geom_hline(yintercept = 1, col = COLOURS.LIST[3], linewidth=LINE.SIZE,
               linetype = 2, alpha = 0.7) +
    scale_colour_manual(values=COLOURS.LIST[c(2,6,8)]) +
    scale_y_continuous(breaks = seq(0, 1, 0.2), 
                       limits = c(-0.05, 1.05),
                       labels = label_number(scale=100, suffix = " \\%")) +
    facet_grid2(Overlap ~ Project) +
    theme_paper_base() +
    theme(axis.title.x = element_blank(),
          axis.title.y = element_blank(),
          axis.ticks.x = element_blank(),
          axis.text.x = element_blank(),
          axis.text.y = element_text(size = TINY.SIZE), 
          legend.text = element_text(size = SMALL.SIZE), 
          legend.title = element_text(size = SMALL.SIZE, hjust=3),
          legend.position="top",
          strip.text = element_text(size = SMALL.SIZE) # Facet title size
          )
  
  ggsave(str_c(OUTDIR_PDF, plot_save_file_name, ".pdf"), plot = p, 
         width = TEXTWIDTH, height = 0.35*TEXTWIDTH, units = "in")
  plot(p)
  
  tikz(str_c(OUTDIR_TIKZ, plot_save_file_name, ".tex"),  
       width = TEXTWIDTH, height = 0.35*TEXTWIDTH)
  print(p)
  dev.off()
}


# Time series comparison plots (split into two subsets)
subset_1 <- c("camel", "gtk", "rstudio", "spark", "wine")
available_projects <- list.files(opt$statistics_path_codeface)
subset_1 <- check_project_availability(subset_1, available_projects)

if (length(subset_1) > 0) {
  plot_data_path <- path.join(opt$plot_path, "data")
  file_name <- str_c("git_ts_plot_data_", subset_1[1], ".csv")
  plot_data_file_path <- path.join(plot_data_path, file_name)
  
  load_ts_plot_data(opt$statistics_path_codeface,
                    opt$statistics_path_kaiaulu_prior,
                    opt$statistics_path_kaiaulu_replication,
                    plot_data_path, file_name, subset_1)
  git_ts_plot(plot_data_file_path, str_c("git_ts_plot_", subset_1[1]))
}

subset_2 <- c("django", "jailhouse", "openssl", "postgres", "qemu")
available_projects <- list.files(opt$statistics_path_codeface)
subset_2 <- check_project_availability(subset_2, available_projects)

if (length(subset_2) > 0) {
  plot_data_path <- path.join(opt$plot_path, "data")
  file_name <- str_c("git_ts_plot_data_", subset_2[1], ".csv")
  plot_data_file_path <- path.join(plot_data_path, file_name)
  
  load_ts_plot_data(opt$statistics_path_codeface,
                    opt$statistics_path_kaiaulu_prior,
                    opt$statistics_path_kaiaulu_replication,
                    plot_data_path, file_name, subset_2)
  git_ts_plot(plot_data_file_path, str_c("git_ts_plot_", subset_2[1]))
}

# Time series similarity table
plot_data_path <- path.join(opt$plot_path, "data")
file_name <- "git_cor_table_data.csv"
plot_data_file_path <- path.join(plot_data_path, file_name)
table_path <- path.join(opt$plot_path, "table")

load_similarity_data(opt$statistics_path_codeface,
                   opt$statistics_path_kaiaulu_prior,
                   opt$statistics_path_kaiaulu_replication,
                   plot_data_path, file_name)
git_similarity_table(plot_data_file_path, table_path)

# Intersection box plot
plot_data_path <- path.join(opt$plot_path, "data")
file_name <- "git_box_plot_data.csv"
plot_data_file_path <- path.join(plot_data_path, file_name)

load_box_plot_data(opt$rank_path_prior, opt$rank_path_replication, 
                   plot_data_path, file_name)
git_box_plot(plot_data_file_path, "git_box_plot")