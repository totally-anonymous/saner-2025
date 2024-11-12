from process_kaiaulu import *
from query_kaiaulu import *


def arguments():
    """Define command line options."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--experiment", required=True,
                        help="Experiment series (prior or replication)")
    parser.add_argument("--project", required=True,
                        help="Name of the project")
    parser.add_argument("--data_path", required=True,
                        help="Path to kaiaulu analysis results")
    parser.add_argument("--conf_path", required=True,
                        help="Path to the analysis configuration file")
    parser.add_argument("--count", required=False, action="store_true",
                        help="Save basic counts of number of commits,\
                             developers, changed files and entity changes")
    parser.add_argument("--count_save_path", required=False,
                        help="Save path for the aggregated data")
    parser.add_argument("--hashes", required=False, action="store_true",
                        help="Save a list with all commit hashes per \
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
    if not (args.experiment == "prior" or args.experiment == "replication"):
        parser.error("--experiment must be prior or replication.")
    if args.count and (args.count_save_path is None):
        parser.error("--count requires --count_save_path.")
    if args.hashes and (args.hash_save_dir_path is None):
        parser.error("--hash requires --hash_save_dir_path.")
    if args.rank and (args.rank_save_dir_path is None):
        parser.error("--rank requires --rank_save_path.")
    return args


def count_statistics(experiment, project, conf_path, df_complete, df_filtered,
                     entities_path, save_path):
    """
    Calculates statistics on the number of commits, files, entities and
    developers found by Kaiaulu for a quantitative comparison.

    Args:
        experiment: The Kaiaulu configuration (prior or replication).
        project: The subject project.
        conf_path: Path to the Kaiaulu configuration file.
        df_complete: Unfiltered git log extracted by Kaiaulu.
        df_filtered: Filtered git log extracted by Kaiaulu.
        entities_path: Path to the entities extracted by Kaiaulu.
        save_path:  Path to store the result data frame.

    Returns:
        None
    """
    # Load the configuration file.
    with open(conf_path) as file:
        conf = yaml.safe_load(file)
    date_list = conf["analysis"]["window"]["ranges"]

    df = pd.DataFrame()
    range_id_norm = 1

    # Get the number of commits, changed files, changed entities,
    # and active developers.
    n_commits = n_files = n_named_entities = n_devs = 0

    for range_dir in sorted(os.listdir(entities_path)):
        file_name = "entities_"+str(range_dir)+".csv"
        file_path = os.path.join(entities_path, range_dir, file_name)
        df_entities = pd.read_csv(file_path, encoding="latin-1")

        # Extract the required slice from the git log.
        start_time = date_list[range_id_norm-1]
        end_time = date_list[range_id_norm]
        if experiment == "prior":
            df_filtered_slice = df_filtered.loc[
                (df_filtered["author_datetimetz"] >= start_time) & (
                        df_filtered["author_datetimetz"] < end_time)]

            if len(df_entities) > 0:
                n_commits = get_num_commits(df_filtered_slice)
                n_files = get_num_files(df_filtered_slice)
                n_named_entities = get_num_named_entities(df_entities)
                n_devs = get_num_devs_prior(df_filtered_slice, df_entities)
        else:
            df_complete_slice = df_complete.loc[
                (df_complete["committer_datetimetz"] >= start_time) & (
                        df_complete["committer_datetimetz"] <= end_time)]
            df_filtered_slice = df_filtered.loc[
                (df_filtered["committer_datetimetz"] >= start_time) & (
                        df_filtered["committer_datetimetz"] <= end_time)]

            if len(df_entities) > 0:
                n_commits = get_num_commits(df_complete_slice)
                n_files = get_num_files(df_filtered_slice)
                n_named_entities = get_num_named_entities(df_entities)
                n_devs = get_num_devs_replication(df_complete_slice)

        # Assemble the data frame.
        entry = pd.DataFrame.from_dict({
            "project": [project],
            "tool": ["kaiaulu"],
            "range_id": [range_id_norm],
            "n_commits": [n_commits],
            "n_files": [n_files],
            "n_named_entities": [n_named_entities],
            "n_devs": [n_devs]
        })
        df = pd.concat([df, entry], ignore_index=True)
        range_id_norm += 1

    if not os.path.isdir(save_path):
        os.makedirs(save_path)
    save_file_path = os.path.join(save_path, project+"_statistics.csv")
    df.to_csv(save_file_path, index=False)


def get_hashes(experiment, project, conf_path, df_git_log, entities_path,
               hash_save_dir_path):
    """
    Gets the commit hashes found by Codeface for a qualitative comparison.

    Args:
        experiment: The Kaiaulu configuration (prior or replication).
        project: The subject project.
        conf_path: Path to the Kaiaulu configuration file.
        df_git_log: (Un)filtered git log extracted by Kaiaulu.
        entities_path: Path to the entities extracted by Kaiaulu.
        hash_save_dir_path:  Path to store the result data frame.

    Returns:
        None
    """
    if not os.path.isdir(hash_save_dir_path):
        os.makedirs(hash_save_dir_path)

    # Load configuration file.
    with open(conf_path) as file:
        conf = yaml.safe_load(file)
    date_list = conf["analysis"]["window"]["ranges"]

    range_id_norm = 1
    for range_dir in sorted(os.listdir(entities_path)):
        # Filter hashes by timestamps.
        file_name = "entities_"+str(range_dir)+".csv"
        file_path = os.path.join(entities_path, range_dir, file_name)
        df_range = pd.read_csv(file_path, encoding="latin-1")

        if len(df_range) == 0:
            df = pd.DataFrame(columns=["project", "commit_hash"])
        else:
            # Use timestamps from configuration file as range boundaries.
            start_time = date_list[range_id_norm-1]
            end_time = date_list[range_id_norm]

            if experiment == "prior":
                df_git_log_slice = df_git_log.loc[
                    (df_git_log["author_datetimetz"] >= start_time) & (
                            df_git_log["author_datetimetz"] < end_time)]
            else:
                df_git_log_slice = df_git_log.loc[
                    (df_git_log["committer_datetimetz"] >= start_time) & (
                            df_git_log["committer_datetimetz"] <= end_time)]

            commit_hashes = df_git_log_slice["commit_hash"].unique()

            df = pd.DataFrame(
                {"project": pd.Series([project]).repeat(len(commit_hashes)),
                 "commit_hash": commit_hashes}
            )

        hash_save_file = "range_"+str(range_id_norm)+".csv"
        hash_save_file_path = os.path.join(hash_save_dir_path, hash_save_file)
        df.to_csv(hash_save_file_path, index=False)
        range_id_norm += 1


def ranking(experiment, conf_path, df_complete, df_filtered, entities_path,
            rank_save_dir_path):
    """
    Gets the (top) files, entities and developers found by Kaiaulu for a
    qualitative comparison.

    Args:
        experiment: The Kaiaulu configuration (prior or replication).
        conf_path: Path to the Kaiaulu configuration file.
        df_complete: Unfiltered git log extracted by Kaiaulu.
        df_filtered: Filtered git log extracted by Kaiaulu.
        entities_path: Path to the entities extracted by Kaiaulu.
        rank_save_dir_path:  Path to store the result data frame.

    Returns:
        None.
    """
    for f in ["developers", "files", "entities"]:
        subdir_path = os.path.join(rank_save_dir_path, f)
        if not os.path.isdir(subdir_path):
            os.makedirs(subdir_path)

    # Load configuration file.
    with open(conf_path) as file:
        conf = yaml.safe_load(file)
    date_list = conf["analysis"]["window"]["ranges"]

    range_id_norm = 1
    for range_dir in sorted(os.listdir(entities_path)):
        # Filter hashes by timestamps.
        file_name = "entities_"+str(range_dir)+".csv"
        file_path = os.path.join(entities_path, range_dir, file_name)
        df_range = pd.read_csv(file_path, encoding="latin-1")

        # Use timestamps from configuration file as range boundaries.
        start_time = date_list[range_id_norm-1]
        end_time = date_list[range_id_norm]

        if experiment == "prior":
            df_filtered_slice = df_filtered.loc[
                (df_filtered["author_datetimetz"] >= start_time) & (
                        df_filtered["author_datetimetz"] < end_time)]
        else:
            df_complete_slice = df_complete.loc[
                (df_complete["committer_datetimetz"] >= start_time) & (
                        df_complete["committer_datetimetz"] <= end_time)]
            df_filtered_slice = df_filtered.loc[
                (df_filtered["committer_datetimetz"] >= start_time) & (
                        df_filtered["committer_datetimetz"] <= end_time)]

        if len(df_filtered_slice) == 0:
            df_file = pd.DataFrame(columns=["file", "n_commits"])
        elif (experiment == "prior" and len(df_filtered_slice) == 0) or (
                experiment == "replication" and len(df_complete_slice) == 0):
            df_dev = pd.DataFrame(columns=["name_email", "n_commits"])

        df_slice = df_filtered_slice
        if experiment == "replication":
            df_slice = df_complete_slice
        if len(df_slice) > 0:
            # Consider authors and committers for the most active developers.
            df_author = df_slice[["author_name_email", "commit_hash"]]
            df_author = df_author.rename(
                columns={"author_name_email": "name_email"})
            df_committer = df_slice[
                ["committer_name_email", "commit_hash"]]
            df_committer = df_committer.rename(
                columns={"committer_name_email": "name_email"})
            df_dev = pd.concat([df_author, df_committer])

            # Count commits per developer while ignoring duplicate commit
            # hashes caused by developers being both author and committer.
            devs = df_dev.groupby("name_email")["commit_hash"].nunique()
            df_dev = pd.DataFrame({"name_email": devs.index,
                                   "n_commits": devs.values})
            df_dev = df_dev.sort_values(by="n_commits", ascending=False)

        if len(df_filtered_slice) > 0:
            # Get most edited files.
            df_file = df_filtered_slice[["file_pathname", "commit_hash"]]
            files = df_file.groupby("file_pathname")["commit_hash"].nunique()
            df_file = pd.DataFrame({"file": files.index,
                                    "n_commits": files.values})
            df_file = df_file.sort_values(by="n_commits", ascending=False)

        if len(df_range) == 0:
            df_entity = pd.DataFrame(columns=["entity", "n_commits"])
        else:
            # Get most edited entities.
            df_entity = df_range[["entity_definition_name", "commit_hash"]]
            entities = df_entity.groupby("entity_definition_name")[
                "commit_hash"].nunique()
            df_entity = pd.DataFrame({"entity": entities.index,
                                      "n_commits": entities.values})
            df_entity = df_entity.sort_values(by="n_commits", ascending=False)

        # Save the aggregated data sets.
        save_file = "range_"+str(range_id_norm)+".csv"
        dev_save_file_path = os.path.join(rank_save_dir_path, "developers",
                                          save_file)
        df_dev.to_csv(dev_save_file_path, index=False, encoding="latin-1")
        file_save_file_path = os.path.join(rank_save_dir_path, "files",
                                           save_file)
        df_file.to_csv(file_save_file_path, index=False)
        entity_save_file_path = os.path.join(rank_save_dir_path, "entities",
                                             save_file)
        df_entity.to_csv(entity_save_file_path, index=False)

        range_id_norm += 1


def main(experiment, project, data_path, conf_path, count, count_save_path,
         hashes, hash_save_dir_path, rank, rank_save_dir_path):
    entities_path = os.path.join(data_path, "entities")
    git_log_path = os.path.join(data_path, "gitlog_filtered.csv")
    df_filtered = read_gitlog(git_log_path)
    df_complete = None

    if experiment == "replication":
        # We only have a complete data frame with the replication setup.
        git_log_path = os.path.join(data_path, "gitlog_complete.csv")
        df_complete = read_gitlog(git_log_path)

    if count:
        print("Counting commits, developers, changed files and entity "
              "changes...")
        # Count properties for each range
        count_statistics(experiment, project, conf_path, df_complete,
                         df_filtered, entities_path, count_save_path)

    if hashes:
        print("Summarising commit hashes per range...")
        if experiment == "prior":
            get_hashes(experiment, project, conf_path, df_filtered,
                       entities_path, hash_save_dir_path)
        else:
            get_hashes(experiment, project, conf_path, df_complete,
                       entities_path, hash_save_dir_path)

    if rank:
        print("Calculating ranking of most active developers, most edited "
              "files and entities...")
        ranking(experiment, conf_path, df_complete, df_filtered, entities_path,
                rank_save_dir_path)


if __name__ == "__main__":
    args = arguments()
    main(args.experiment, args.project,
         args.data_path, args.conf_path,
         args.count, args.count_save_path,
         args.hashes, args.hash_save_dir_path,
         args.rank, args.rank_save_dir_path)
