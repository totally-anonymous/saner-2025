import argparse
import os

import numpy as np
import sys
from query_codeface import *


def arguments():
    """Define command line options."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--hashes", required=False, action="store_true",
                        help="Compare commit hashes")
    parser.add_argument("--hash_dir_path_codeface", required=False,
                        help="Path to the directory where Codeface hashes "
                             "are stored")
    parser.add_argument("--hash_dir_path_kaiaulu", required=False,
                        help="Path to the directory where Kaiaulu hashes "
                             "are stored")
    parser.add_argument("--hash_save_dir_path", required=False,
                        help="Save directory for the commit hashes difference")
    parser.add_argument("--rank", required=False, action="store_true",
                        help="Compare highest ranked developers, files and "
                             "entities")
    parser.add_argument("--k", required=False, type=int,
                        help="Number of top developers, files and entities "
                             "to compare (-1 for all)")
    parser.add_argument("--rank_dir_path_codeface", required=False,
                        help="Path to the directory where Codeface rankings "
                             "are stored")
    parser.add_argument("--rank_dir_path_kaiaulu", required=False,
                        help="Path to the directory where Kaiaulu rankings "
                             "are stored")
    parser.add_argument("--rank_save_path", required=False,
                        help="Save path for the rankings comparison table")

    # Sanity checks
    args = parser.parse_args()
    if args.hashes and (args.hash_dir_path_codeface is None or
                        args.hash_dir_path_kaiaulu is None or
                        args.hash_save_dir_path is None):
        parser.error("--hash requires --hash_dir_path_codeface, "
                     "--hash_dir_path_kaiaulu and --hash_save_dir_path.")
    if args.rank and (args.k is None or
                      args.rank_dir_path_codeface is None or
                      args.rank_dir_path_kaiaulu is None or
                      args.rank_save_path is None):
        parser.error("--rank requires --k, --rank_dir_path_codeface, "
                     "--rank_dir_path_kaiaulu and --rank_save_path.")
    return args


def hash_comparison(hash_dir_path_codeface, hash_dir_path_kaiaulu,
                    hash_save_dir_path):
    """
    Compares the commit hashes found by Codeface and Kaiaulu for a qualitative
    inspection of discrepancies.

    Args:
        hash_dir_path_codeface: Path to the Codeface hash data frame.
        hash_dir_path_kaiaulu: Path to the Kaiaulu hash data frame.
        hash_save_dir_path: Path to store the result data frame.

    Returns:
        None
    """
    if not os.path.isdir(hash_save_dir_path):
        os.makedirs(hash_save_dir_path)

    files = sorted(os.listdir(hash_dir_path_kaiaulu))
    for i in range(1, len(files)+1):
        file_name = "range_"+str(i)+".csv"
        codeface_file_path = os.path.join(hash_dir_path_codeface, file_name)
        kaiaulu_file_path = os.path.join(hash_dir_path_kaiaulu, file_name)

        codeface_hashes = pd.read_csv(codeface_file_path)
        kaiaulu_hashes = pd.read_csv(kaiaulu_file_path)
        codeface_hashes["tool"] = "codeface"
        kaiaulu_hashes["tool"] = "kaiaulu"

        df = pd.concat([codeface_hashes, kaiaulu_hashes], ignore_index=False)
        df = df.drop_duplicates(subset=["project", "commit_hash"])

        save_file_path = os.path.join(hash_save_dir_path, file_name)
        df.to_csv(save_file_path, index=False)


def rank_comparison(k, rank_dir_path_codeface, rank_dir_path_kaiaulu, rank_save_path):
    """
    Compares the top k files, entities and developers found by Codeface and 
    Kaiaulu for a qualitative inspection of discrepancies.

    Args:
        k:
        hash_dir_path_codeface: Path to the Codeface hash data frame.
        hash_dir_path_kaiaulu: Path to the Kaiaulu hash data frame.
        hash_save_dir_path: Path to store the result data frame.

    Returns:
        None
    """
    projects = sorted(os.listdir(rank_dir_path_kaiaulu))

    df = pd.DataFrame(columns=["project", "range", "top_dev_overlap",
                               "top_file_overlap", "top_entity_overlap"])

    if k==-1:
        # Compare the overlap across *all* developers, files and entities.
        # Otherwise, only compare the specified number (k).
        k = sys.maxsize

    for i in range(0, len(projects)):
        project = projects[i]
        codeface_project_path = os.path.join(rank_dir_path_codeface, project)
        kaiaulu_project_path = os.path.join(rank_dir_path_kaiaulu, project)

        # Max. range index determined by the files in the results directory.
        r = len(os.listdir(os.path.join(codeface_project_path, "developers")))

        for range_id in range(1, r+1):
            # Calculate the intersection of the top k developers.
            codeface_file_path = os.path.join(codeface_project_path,
                                              "developers",
                                              "range_"+str(range_id)+".csv")
            kaiaulu_file_path = os.path.join(kaiaulu_project_path,
                                             "developers",
                                             "range_"+str(range_id)+".csv")
            df_codeface = pd.read_csv(codeface_file_path)
            df_kaiaulu = pd.read_csv(kaiaulu_file_path, encoding="latin-1")

            # Get the top k developers (either pre-defined k or, if less than k
            # developers exist, the lowest number of developers available).
            k_dev = min(max(len(df_codeface), len(df_kaiaulu)), k)

            if k_dev > 0:
                df_codeface = df_codeface[0:k_dev]
                df_kaiaulu = df_kaiaulu[0:k_dev]

                # Search for all e-mail addresses of a developer identified by
                # Codeface in the list of Kaiaulu's top k developers. If there
                # is no e-mail match, search for name matches.
                dev_overlap = 0
                for idx_c, row_c in df_codeface.iterrows():
                    match = False
                    for c in ["email1", "email2", "email3", "email4", "email5"]:
                        for idx_k, row_k in df_kaiaulu.iterrows():
                            if str(row_c[c]) in str(row_k["name_email"]):
                                match = True
                                break
                    if match:
                        dev_overlap += 1
                    else:
                        for idx_k, row_k in df_kaiaulu.iterrows():
                            if str(row_c["name"]) in str(row_k["name_email"]):
                                match = True
                                break
                        if match:
                            dev_overlap += 1
                dev_overlap_perc = dev_overlap/k_dev
            else:
                dev_overlap = 0
                dev_overlap_perc = np.nan

            # # Calculate the intersection of the top k files.
            codeface_file_path = os.path.join(codeface_project_path, "files",
                                              "range_"+str(range_id)+".csv")
            kaiaulu_file_path = os.path.join(kaiaulu_project_path, "files",
                                             "range_"+str(range_id)+".csv")
            df_codeface = pd.read_csv(codeface_file_path)
            df_kaiaulu = pd.read_csv(kaiaulu_file_path)

            # Get the top k files (either pre-defined k or, if less than k
            # files exist, the lowest number of files available).
            k_file = min(max(len(df_codeface), len(df_kaiaulu)), k)

            if k_file > 0:
                df_codeface = df_codeface[0:k_file]
                df_kaiaulu = df_kaiaulu[0:k_file]

                # Search for file names identified by Codeface in the list of
                # files identified by Kaiaulu.
                file_overlap = df_codeface["file"].isin(df_kaiaulu["file"]).sum()
                file_overlap_perc = file_overlap/k_file
            else:
                file_overlap = 0
                file_overlap_perc = np.nan

            # Calculate the intersection of the top k entities.
            codeface_file_path = os.path.join(codeface_project_path, "entities",
                                              "range_"+str(range_id)+".csv")
            kaiaulu_file_path = os.path.join(kaiaulu_project_path, "entities",
                                             "range_"+str(range_id)+".csv")
            df_codeface = pd.read_csv(codeface_file_path)
            df_kaiaulu = pd.read_csv(kaiaulu_file_path)

            # Get top k entities (either pre-defined k or, if less than k
            # entities exist, the lowest number of entities available)
            k_entity = min(max(len(df_codeface), len(df_kaiaulu)), k)

            if k_entity > 0:
                df_codeface = df_codeface[0:k_entity]
                df_kaiaulu = df_kaiaulu[0:k_entity]

                # Search for entity names identified by Codeface in the list of
                # entities identified by Kaiaulu.
                entity_overlap = df_codeface["entity"].isin(df_kaiaulu["entity"]).sum()
                entity_overlap_perc = entity_overlap/k_entity
            else:
                entity_overlap = 0
                entity_overlap_perc = np.nan

            # Assemble the comparison data frame.
            entry = pd.DataFrame({"project": [project],
                                  "range": [range_id],
                                  "k_dev": [k_dev],
                                  "dev_overlap": [dev_overlap],
                                  "dev_overlap_perc": [dev_overlap_perc],
                                  "k_file": [k_file],
                                  "file_overlap": [file_overlap],
                                  "file_overlap_perc": [file_overlap_perc],
                                  "k_entity": [k_entity],
                                  "entity_overlap": [entity_overlap],
                                  "entity_overlap_perc": [entity_overlap_perc]})

            if df.empty:
                df = entry.copy()
            else:
                df = pd.concat([df, entry], ignore_index=True)

    # Save the comparison data.
    df = df.sort_values(by=["project", "range"])
    rank_save_dir = os.path.join("/".join(rank_save_path.split("/")[:-1]))
    if not os.path.isdir(rank_save_dir):
        os.makedirs(rank_save_dir)
    df.to_csv(rank_save_path)


def main(hashes, hash_dir_path_codeface, hash_dir_path_kaiaulu,
         hash_save_dir_path, rank, k, rank_dir_path_codeface,
         rank_dir_path_kaiaulu, rank_save_path):
    if hashes:
        hash_comparison(hash_dir_path_codeface, hash_dir_path_kaiaulu,
                        hash_save_dir_path)
    if rank:
        rank_comparison(k, rank_dir_path_codeface, rank_dir_path_kaiaulu,
                        rank_save_path)


if __name__ == "__main__":
    args = arguments()
    main(args.hashes, args.hash_dir_path_codeface, args.hash_dir_path_kaiaulu,
         args.hash_save_dir_path, args.rank, args.k,
         args.rank_dir_path_codeface, args.rank_dir_path_kaiaulu,
         args.rank_save_path)
