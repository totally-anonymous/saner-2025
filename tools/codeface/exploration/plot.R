#' Exports a graph to PDF.
#'
#' @param graph a graph returned by \code{igraph::graph_from_data_frame}
#' @param pdf_path path to save the PDF.
#' @param pdf_name name of the PDF file.
#' @param is_directed whether the graph is directed. If false, cells will be doubled.
#'  with src/dest switched to represent an undirected graph as a directed graph.
#' @export
#'
graph_to_pdf <- function(g, pdf_path, pdf_name, is_directed) {
  # TODO refactor: scale parameters more reasonably

  # Configure plot file
  pdf(file.path(pdf_path, pdf_name), height = 600, width = 800)

  # Scale vertices and font size according to the number of nodes and their degree
  deg <- igraph::degree(g, mode="all")
  
  if (length(igraph::V(g)) < 15) {
    vertex_size <- 5 + deg/5
    vertex_label_cex <- 50
    vertex_label_dist <- 1.5
    edge_arrow_size <- 20
    margin <- 0.3
  } else if (length(igraph::V(g)) < 70) {
    vertex_size <- 3 + deg/5
    vertex_label_cex <- 20 + deg/5
    vertex_label_dist <- 0.7
    edge_arrow_size <- 10
    margin <- 0
  } else {
    vertex_size <- 2 + deg/18
    vertex_label_cex <- 3 + deg/5
    vertex_label_dist <- 0.7
    edge_arrow_size <- 6
    margin <- 0
  }
  
  if (!(is_directed)) {
    edge_arrow_size <- 0
  }
  
  # Color nodes according to their eigenvector centrality
  # Eigenvector centrality: node's centrality depending on the centrality of its neighbors
  V(g)$ec <- eigen_centrality(g, directed=T, weights=NA)$vector
  normalize <- function(x){(x-min(x))/(max(x)-min(x))}
  (V(g)$ec_index <- round(normalize(V(g)$ec) * 19) + 1)
  
  V(g)$color <- colorRampPalette(c("turquoise", "yellow", "red"))(20)[V(g)$ec_index]
  
  # Scale the edge width according to the edge weight
  if (max(igraph::E(g)$weight) == 1) {
    igraph::E(g)$weight <- 0.8
  } else {
    igraph::E(g)$weight <- 0.8 + (100 * igraph::E(g)$weight/max(igraph::E(g)$weight))
  }
  
  # Adjust the graph layout to make better use of the available space
  lo <- layout_with_kk(g)
  lo <- norm_coords(lo, ymin=-1, ymax=1, xmin=-1, xmax=1)
  
  # Plot and save the customized graph
  plot(g,
       vertex.size = vertex_size,
       vertex.label.cex = vertex_label_cex,
       vertex_label_dist = vertex_label_dist,
       vertex.label = igraph::V(g)$names,
       vertex.label.family = "sans",
       vertex.label.color = "#000000",
       vertex.frame.width = 0.02,
       vertex.frame.color = "#AAAAAA",
       edge.color = "#AAAAAA",
       edge.arrow.size = edge_arrow_size,
       edge.width = igraph::E(g)$weight,
       margin = margin,
       rescale = FALSE,
       layout=lo*0.97)
  dev.off()
}

#' Exports an adjacency matrix visualized as a heatmap to PDF.
#'
#' @param matrix an adjacency matrix in the form of a dataframe or matrix
#' @param pdf_path path to save the PDF.
#' @param pdf_name name of the PDF file.
#' @export
#'
heatmap_to_pdf <- function(matrix, pdf_path, pdf_name) {
  # TODO refactor: scale parameters more reasonably
  
  # Configure plot file
  pdf(file.path(pdf_path, pdf_name), height = 500, width = 500)
  
  # Adjust the color palette depending on the number of nodes to improve 
  # readability in heatmaps of large, sparse matrices
  if (nrow(matrix) < 15) {
    col_pal <- colorRampPalette(c("lavender", "darkblue", "black"))(50)
  } else {
    col_pal <- colorRampPalette(c("slateblue", "darkblue", "black"))(50)
  }
  
  # Rotate the matrix to ensure that the authors are in the same order as in
  # the original dataframe
  rotate <- function(x) t(apply(x, 2, rev))
  
  # Plot the heatmap as a color image using R graphics image function
  image(
    rotate(matrix),
    axes = FALSE,
    col = col_pal,
    useRaster=TRUE,
    breaks = c(seq(1, 50, length.out = 50), 5000),
  )
  
  # Plot and save the customized heatmap
  box()
  dev.off()
}
