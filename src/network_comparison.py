import argparse
import os
import networkx as nx
import numpy as np
import yaml

from networkx.classes import get_edge_attributes
from query_codeface import *


def arguments():
    """Define command line options."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--network_path_codeface", required=True,
                        help="Path to the directory containing the networks "
                             "extracted by Codeface")
    parser.add_argument("--network_path_kaiaulu", required=True,
                        help="Path to the directory containing the networks "
                             "extracted by Kaiaulu")
    parser.add_argument("--kaiaulu_conf_path", required=True,
                        help="Path to the configuration file for Kaiaulu")
    parser.add_argument("--save_path", required=True,
                        help="Save path for the network comparison table")
    return parser.parse_args()


def create_similarity_table(network_path_codeface, network_path_kaiaulu,
                            kaiaulu_conf_path, save_path):
    """
    Creates a table measuring the similarity of networks constructed with
    Codeface and Kaiaulu.

    Args:
        network_path_codeface: Path to the Codeface network directory.
        network_path_kaiaulu: Path to the Kaiaulu network directory.
        kaiaulu_conf_path: Path to the Kaiaulu configuration directory.
        save_path: Path to save the similarity table.

    Returns:
        None.
    """
    save_path = os.path.join(save_path)
    if not os.path.exists(save_path):
        os.makedirs(save_path)

    df_similarity = pd.DataFrame()

    projects = sorted(os.listdir(os.path.join(network_path_kaiaulu, "prior")))
    for p in projects:
        print("Evaluating network similarity for project "+p+"...")
        df_project = pd.DataFrame()

        # Get number of ranges to compare.
        kaiaulu_project_conf_path = os.path.join(kaiaulu_conf_path,
                                                 p+"_prior_analysis.yml")
        with open(kaiaulu_project_conf_path) as file:
            conf = yaml.safe_load(file)
        date_list = conf["analysis"]["window"]["ranges"]
        ranges = range(1, len(date_list))
        for r in ranges:
            codeface_matrix_path = os.path.join(network_path_codeface, p,
                                                "range_"+str(r)+"_adjacency_matrix_with_names.csv")
            kaiaulu_prior_matrix_path = os.path.join(network_path_kaiaulu,
                                                     "prior", p,
                                                     "range_"+str(r)+"_adjacency_matrix.csv")
            kaiaulu_replication_matrix_path = os.path.join(network_path_kaiaulu,
                                                           "replication", p,
                                                           "range_"+str(r)+"_adjacency_matrix.csv")

            # Read adjacency matrices and construct network graphs.
            G_codeface = None
            G_kaiaulu_prior = None
            G_kaiaulu_replication = None
            try:
                adj_codeface = pd.read_csv(codeface_matrix_path, index_col=0)
                adj_codeface.index = adj_codeface.index.map(str)
                G_codeface = nx.from_pandas_adjacency(adj_codeface, nx.DiGraph())
            except:
                print("Codeface adjacency matrix for project "+p+" range "+str(r)+" not found.")

            try:
                adj_kaiaulu_prior = pd.read_csv(kaiaulu_prior_matrix_path,
                                          encoding="latin-1", index_col=0)
                G_kaiaulu_prior = nx.from_pandas_adjacency(adj_kaiaulu_prior,
                                                           nx.DiGraph())
            except:
                print("Kaiaulu (prior) adjacency matrix for project "+p+" range "+str(r)+" not found.")

            try:
                adj_kaiaulu_replication = pd.read_csv(kaiaulu_replication_matrix_path,
                                          encoding="latin-1", index_col=0)
                G_kaiaulu_replication = nx.from_pandas_adjacency(adj_kaiaulu_replication,
                                                                 nx.DiGraph())
            except:
                print("Kaiaulu (replication) adjacency matrix for project "+p+" range "+str(r)+" not found.")

            # Calculate graph edit distance.
            graph_edit_distance_prior = nx.graph_edit_distance(G_codeface,
                                                         G_kaiaulu_prior,
                                                         timeout=10)
            graph_edit_distance_replication = nx.graph_edit_distance(G_codeface,
                                                         G_kaiaulu_replication,
                                                         timeout=10)

            # Calculate network density and edge weight.
            if G_codeface is None or nx.is_empty(G_codeface):
                density_codeface = 0
                weight_median_codeface = 0
                weight_mean_codeface = 0
                weight_max_codeface = 0
            else:
                density_codeface = nx.density(G_codeface)
                weights_codeface = list(get_edge_attributes(G_codeface, "weight").values())
                weight_median_codeface = np.median(weights_codeface)
                weight_mean_codeface = np.mean(weights_codeface)
                weight_max_codeface = max(weights_codeface)

            if G_kaiaulu_prior is None or nx.is_empty(G_kaiaulu_prior):
                density_kaiaulu_prior = 0
                weight_median_kaiaulu_prior = 0
                weight_mean_kaiaulu_prior = 0
                weight_max_kaiaulu_prior = 0
            else:
                density_kaiaulu_prior = nx.density(G_kaiaulu_prior)
                weights_kaiaulu_prior = list(get_edge_attributes(G_kaiaulu_prior, "weight").values())
                weight_median_kaiaulu_prior = np.median(weights_kaiaulu_prior)
                weight_mean_kaiaulu_prior = np.mean(weights_kaiaulu_prior)
                weight_max_kaiaulu_prior = np.max(weights_kaiaulu_prior)

            if G_kaiaulu_replication is None or nx.is_empty(G_kaiaulu_replication):
                density_kaiaulu_replication = 0
                weight_median_kaiaulu_replication = 0
                weight_mean_kaiaulu_replication = 0
                weight_max_kaiaulu_replication = 0
            else:
                density_kaiaulu_replication = nx.density(G_kaiaulu_replication)
                weights_kaiaulu_replication = list(get_edge_attributes(G_kaiaulu_replication, "weight").values())
                weight_median_kaiaulu_replication = np.median(weights_kaiaulu_replication)
                weight_mean_kaiaulu_replication = np.mean(weights_kaiaulu_replication)
                weight_max_kaiaulu_replication = max(weights_kaiaulu_replication)

            # Assemble project similarity dataframe.
            entry = pd.DataFrame.from_dict({
                "project": [p],
                "range": [r],
                "graph_edit_distance_prior": [graph_edit_distance_prior],
                "graph_edit_distance_replication": [graph_edit_distance_replication],
                "density_codeface": [density_codeface],
                "density_kaiaulu_prior": [density_kaiaulu_prior],
                "density_kaiaulu_replication": [density_kaiaulu_replication],
                "edge_weight_median_codeface": [weight_median_codeface],
                "edge_weight_median_kaiaulu_prior": [weight_median_kaiaulu_prior],
                "edge_weight_median_kaiaulu_replication": [weight_median_kaiaulu_replication],
                "edge_weight_mean_codeface": [weight_mean_codeface],
                "edge_weight_mean_kaiaulu_prior": [weight_mean_kaiaulu_prior],
                "edge_weight_mean_kaiaulu_replication": [weight_mean_kaiaulu_replication],
                "edge_weight_max_codeface": [weight_max_codeface],
                "edge_weight_max_kaiaulu_prior": [weight_max_kaiaulu_prior],
                "edge_weight_max_kaiaulu_replication": [weight_max_kaiaulu_replication]
            })

            if df_project.empty:
                df_project = entry
            else:
                df_project = pd.concat([df_project, entry], ignore_index=True)

        # Save project similarity table.
        project_path = os.path.join(save_path, p+"_network_similarity.csv")
        df_project.to_csv(project_path, index=False)

        # Assemble summary similarity dataframe.
        entry = pd.DataFrame.from_dict({
            "project": [p],
            "median_graph_edit_distance_prior": [np.median(df_project["graph_edit_distance_prior"].dropna())],
            "median_graph_edit_distance_replication": [np.median(df_project["graph_edit_distance_replication"].dropna())],
            "mean_graph_edit_distance_prior": [np.mean(df_project["graph_edit_distance_prior"].dropna())],
            "mean_graph_edit_distance_replication": [np.mean(df_project["graph_edit_distance_replication"].dropna())],
            "max_graph_edit_distance_prior": [max(df_project["graph_edit_distance_prior"].dropna())],
            "max_graph_edit_distance_replication": [max(df_project["graph_edit_distance_replication"].dropna())],
            "median_density_codeface": [np.median(df_project["density_codeface"].dropna())],
            "median_density_kaiaulu_prior": [np.median(df_project["density_kaiaulu_prior"].dropna())],
            "median_density_kaiaulu_replication": [np.median(df_project["density_kaiaulu_replication"].dropna())],
            "mean_density_codeface": [np.mean(df_project["density_codeface"].dropna())],
            "mean_density_kaiaulu_prior": [np.mean(df_project["density_kaiaulu_prior"].dropna())],
            "mean_density_kaiaulu_replication": [np.mean(df_project["density_kaiaulu_replication"].dropna())],
            "median_edge_weight_codeface": [np.median(df_project["edge_weight_median_codeface"].dropna())],
            "median_edge_weight_kaiaulu_prior": [np.median(df_project["edge_weight_median_kaiaulu_prior"].dropna())],
            "median_edge_weight_kaiaulu_replication": [np.median(df_project["edge_weight_median_kaiaulu_replication"].dropna())],
            "mean_edge_weight_codeface": [np.mean(df_project["edge_weight_mean_codeface"].dropna())],
            "mean_edge_weight_kaiaulu_prior": [np.mean(df_project["edge_weight_mean_kaiaulu_prior"].dropna())],
            "mean_edge_weight_kaiaulu_replication": [np.mean(df_project["edge_weight_mean_kaiaulu_replication"].dropna())],
            "max_edge_weight_codeface": [np.max(df_project["edge_weight_max_codeface"].dropna())],
            "max_edge_weight_kaiaulu_prior": [np.max(df_project["edge_weight_max_kaiaulu_prior"].dropna())],
            "max_edge_weight_kaiaulu_replication": [np.max(df_project["edge_weight_max_kaiaulu_replication"].dropna())]
        })

        if df_similarity.empty:
            df_similarity = entry
        else:
            df_similarity = pd.concat([df_similarity, entry], ignore_index=True)

    similarity_path = os.path.join(save_path, "network_similarity.csv")
    df_similarity.to_csv(similarity_path, index=False)


def main(network_path_codeface, network_path_kaiaulu, kaiaulu_conf_path,
         save_path):
    create_similarity_table(network_path_codeface, network_path_kaiaulu,
                            kaiaulu_conf_path, save_path)


if __name__ == "__main__":
    args = arguments()
    main(args.network_path_codeface, args.network_path_kaiaulu,
         args.kaiaulu_conf_path, args.save_path)
