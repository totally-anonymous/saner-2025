import argparse
import mysql.connector
import os

from query_codeface import *


def arguments():
    """Define command line options."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", required=True, help="Database port")
    parser.add_argument("--project", required=True,
                        help="Name of the project in Codeface database")
    parser.add_argument("--count", required=False, action="store_true",
                        help="Save basic counts of number of commits,\
                              developers, changed files and entity changes")
    parser.add_argument("--count_save_path", required=False,
                        help="Save path for the aggregated data")
    parser.add_argument("--hashes", required=False, action="store_true",
                        help="Save lists with all commit hashes per \
                              revision range")
    parser.add_argument("--hash_save_dir_path", required=False,
                        help="Save path for the aggregated commit hashes per "
                             "range")
    parser.add_argument("--rank", required=False, action="store_true",
                        help="Save highest ranked developers, files and"
                             "entities")
    parser.add_argument("--rank_save_dir_path", required=False,
                        help="Save directory for the rankings")

    # Sanity checks
    args = parser.parse_args()
    if args.count and (args.count_save_path is None):
        parser.error("--count requires --count_save_path.")
    if args.hashes and (args.hash_save_dir_path is None):
        parser.error("--hash requires --hash_save_dir_path.")
    if args.rank and (args.rank_save_dir_path is None):
        parser.error("--rank requires --rank_save_path.")
    return args


def count_statistics(cur, project, pid, range_ids, count_save_dir):
    """
    Calculates statistics on the number of commits, files, entities and
    developers found by Codeface for a quantitative comparison.

    Args:
        cur: The MySQL database connection cursor.
        project: Name of the project in the Codeface database.
        pid: Project ID in the Codeface database.
        range_ids: Revision range IDs.
        count_save_dir: Path to store the result data frame.

    Returns:
        None
    """
    df = pd.DataFrame()
    range_id_norm = 1

    for r in range_ids:
        # Number of commits
        n_commits = get_commits(cur, pid, r)

        # Number of changed files
        n_files = get_num_files(cur, pid, r)

        # Number of named entities
        entities = get_entities(cur, pid, r)
        n_named_entities = len(list(set(entities)))

        # Number of active developers that authored or committed
        # commits in a specific range
        n_devs = get_num_devs(cur, pid, r)

        # Add sample to dataset
        entry = pd.DataFrame.from_dict({
            "project": [project],
            "tool": ["codeface"],
            "range_id": [range_id_norm],
            "n_commits": [n_commits],
            "n_files": [n_files],
            "n_named_entities": [n_named_entities],
            "n_devs": [n_devs]
        })

        df = pd.concat([df, entry], ignore_index=True)
        range_id_norm += 1

    if not os.path.isdir(count_save_dir):
        os.makedirs(count_save_dir)
    count_save_path = os.path.join(count_save_dir, project+"_statistics.csv")
    df.to_csv(count_save_path, index=False)


def get_hashes(cur, pid, range_ids, hash_save_dir_path):
    """
    Gets the commit hashes found by Codeface for a qualitative comparison.

    Args:
        cur: The MySQL database connection cursor.
        pid: Project ID in Codeface database.
        range_ids: Revision range IDs.
        hash_save_dir_path: Path to store the result data frame.

    Returns:
        None.
    """
    if not os.path.isdir(hash_save_dir_path):
        os.makedirs(hash_save_dir_path)

    range_id_norm = 1
    for r in range_ids:
        hashes = get_commit_hashes(cur, pid, r)
        df = pd.DataFrame(hashes, columns=["project", "commit_hash"])
        hash_save_file = "range_"+str(range_id_norm)+".csv"
        hash_save_file_path = os.path.join(hash_save_dir_path,
                                           hash_save_file)
        df.to_csv(hash_save_file_path, index=False)
        range_id_norm += 1


def ranking(cur, pid, range_ids, rank_save_dir_path):
    """
    Gets the (top) files, entities and developers found by Codeface for a
    qualitative comparison.

    Args:
        cur: The MySQL database connection cursor.
        pid: Project ID in Codeface database.
        range_ids: Revision range IDs.
        rank_save_dir_path: Path to store the result data frame.

    Returns:
        None.
    """
    for f in ["developers", "files", "entities"]:
        subdir_path = os.path.join(rank_save_dir_path, f)
        if not os.path.isdir(subdir_path):
            os.makedirs(subdir_path)

    range_id_norm = 1
    for r in range_ids:
        # Most active developers
        df_dev = get_devs_activity(cur, pid, r)
        df_dev = df_dev.sort_values(by="n_commits", ascending=False)

        save_file = "range_"+str(range_id_norm)+".csv"
        dev_save_dir = os.path.join(rank_save_dir_path, "developers")
        dev_save_file_path = os.path.join(dev_save_dir, save_file)
        df_dev.to_csv(dev_save_file_path, index=False)

        # Most edited files
        df_file = get_files_activity(cur, pid, r)
        file_save_dir = os.path.join(rank_save_dir_path, "files")
        file_save_file_path = os.path.join(file_save_dir, save_file)
        df_file.to_csv(file_save_file_path, index=False)

        # Most edited entities
        df_entity = get_entities_activity(cur, pid, r)
        df_entity = df_entity[df_entity["entity"] != "File_Level"]
        entities_save_dir = os.path.join(rank_save_dir_path, "entities")
        entity_save_file_path = os.path.join(entities_save_dir, save_file)
        df_entity.to_csv(entity_save_file_path, index=False)

        range_id_norm += 1


def main(port, project, count, count_save_path, hashes, hash_save_dir_path,
         rank, rank_save_dir_path):
    # Establish database connection
    con = mysql.connector.connect(
        host="127.0.0.1",
        database="codeface",
        user="codeface",
        password="codeface",
        port=str(port)
    )
    cur = con.cursor(buffered=True)

    # Project information
    pid = get_project_id(cur, project)
    range_ids = get_range_ids(cur, pid)

    # Count statistics
    if count:
        print("Counting commits, developers, changed files and entity "
              "changes...")
        count_statistics(cur, project, pid, range_ids, count_save_path)

    if hashes:
        print("Summarising commit hashes per range...")
        get_hashes(cur, pid, range_ids, hash_save_dir_path)

    if rank:
        print("Calculating ranking of most active developers, most edited "
              "files and entities")
        ranking(cur, pid, range_ids, rank_save_dir_path)


if __name__ == "__main__":
    args = arguments()
    main(args.port, args.project,
         args.count, args.count_save_path,
         args.hashes, args.hash_save_dir_path,
         args.rank, args.rank_save_dir_path)
