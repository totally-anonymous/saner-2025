# This script contains post-processing functions that are applied to the
# Kaiaulu data set after extraction and prior to comparison.
# In particular, this script matches identities and slices the
# file-based git log table extracted by Kaiaulu for subsequent analyses.
# Important: Kaiaulu matches identities in author and committer fields
# separately(!). By combining both columns, we get many duplicate identities.
# These identities cannot be filtered by simple dropping duplicates, since
# developers may be assigned different e-mail addresses and names in both
# columns.
# Also, identities are matched in the git log and the entity analysis results
# separately. This means that there is no holistic identity view on the
# project.
# To compare identities across all data subsets, we build an own identity
# table based on all available names and e-mail-addresses. Then, we replace
# identities in the data subsets according to this table.


import argparse
import pandas as pd
import os
import re
import yaml

from distutils.dir_util import copy_tree


def arguments():
    """Define command line options."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--experiment", required=True,
                        help="Name of the experiment series to analyse")
    parser.add_argument("--project", required=True,
                        help="Name of the project to analyse")
    parser.add_argument("--conf_path", required=True,
                        help="Path to the project configuration file")
    parser.add_argument("--data_path", required=True,
                        help="Path to Kaiaulu's analysis results (raw data "
                             "directory for a specific project)")
    parser.add_argument("--save_path", required=True,
                        help="Path to the project directory to store the "
                             "processed data.")
    parser.add_argument("--merge_id", required=False, action="store_true",
                        help="Merge identities across tables.")
    parser.add_argument("--time_slice", required=False, action="store_true",
                        help="Slice the holistic git log according to the "
                             "method specified in the configuration file")
    return parser.parse_args()


def read_gitlog(git_log_path):
    """
    Helper function to perform repeated pre-processing steps when loading
    a git log CSV file.

    Args:
        git_log_path: path to the git log table to read.

    Returns:
        The pre-processed data frame.
    """
    df = pd.read_csv(git_log_path, encoding="latin-1")

    # Sometimes, the columns "lines_added" and "lines_removed" contain
    # letters or other unwanted symbols, which should be replaced by NaN.
    df["lines_added"] = pd.to_numeric(df["lines_added"], errors="coerce")
    df["lines_removed"] = pd.to_numeric(df["lines_removed"], errors="coerce")

    # Unify date strings (if necessary).
    try:
        df["author_datetimetz"] = pd.to_datetime(df["author_datetimetz"],
                                                 format="%a %b %d %X %Y %z",
                                                 utc=True)
        df["author_datetimetz"] = df["author_datetimetz"].apply(
            lambda x: x.replace(tzinfo=None))

        df["committer_datetimetz"] = pd.to_datetime(df["committer_datetimetz"],
                                                    format="%a %b %d %X %Y %z",
                                                    utc=True)
        df["committer_datetimetz"] = df["committer_datetimetz"].apply(
            lambda x: x.replace(tzinfo=None))
    except:
        # If the date string does not match the format above, it is already
        # in the desired format.
        df["author_datetimetz"] = pd.to_datetime(df["author_datetimetz"],
                                                 format="%Y-%m-%d %H:%M:%S",
                                                 utc=True)
        df["author_datetimetz"] = df["author_datetimetz"].apply(
            lambda x: x.replace(tzinfo=None))

        df["committer_datetimetz"] = pd.to_datetime(df["committer_datetimetz"],
                                                    format="%Y-%m-%d %H:%M:%S",
                                                    utc=True)

        df["committer_datetimetz"] = df["committer_datetimetz"].apply(
            lambda x: x.replace(tzinfo=None))
    return df


def get_unique_ids(df):
    """
    Helper function to get unique IDs from author and committer columns in the
    same order as Codeface.

    Args:
        df: Data frame with author and committer columns.

    Returns:
        A list of unique identities.
    """
    # Get unique IDs from author and committer columns. Make sure to preserve
    # the order of commits and added identities, respectively (we do not use
    # panda's df.unique() for this reason).
    unique_ids = []
    for idx, row in df.iterrows():
        if row["author_name_email"] not in unique_ids:
            unique_ids.append(row["author_name_email"])
        if row["committer_name_email"] not in unique_ids:
            unique_ids.append(row["committer_name_email"])
    return unique_ids


def find_by_email(identity_part, df_id):
    """
    Helper function to search for a developer identity in the given identity
    table based on his e-mail address.

    Args:
        identity_part: Name and e-mail address of the developer (Name <e-maiL>).
        df_id: Identity table.

    Returns:
        The index and identity of the matching developer.
    """
    # Search for e-mail address matches.
    pattern = re.compile(r"<(.*?)>")
    for m in re.finditer(pattern, identity_part):
        id_1_email = m.group(1)

        # Replace invalid e-mail addresses and do not match these
        # identities.
        id_1_email = id_1_email.replace('(none)', '')
        if len(id_1_email) <= 1:
            continue

        # Add braces to avoid partial matches with incorrectly formatted
        # local domains.
        id_1_email = "<"+id_1_email+">"

        # Compare the given e-mail address to all other e-mail addresses.
        for idx, row in df_id.iterrows():
            id_2 = row["name_email"]
            if id_1_email in id_2:
                return idx, id_2
    return None, None


def find_by_name(name, df_id):
    """
    Helper function to search for a developer identity in the given identity
    table based on his name.

    Args:
        name: Name of the developer.
        df_id: Identity table.

    Returns:
        The index and identity of the matching developer.
    """
    for idx, row in df_id.iterrows():
        id_2 = row["name_email"]
        id_2_parts = id_2.split(" | ")
        for p_2 in id_2_parts:
            id_2_name = p_2.split("<")[0]
            # Use exact string matching to ignore partial matches
            # such as first name with different last name.
            if name == id_2_name:
                return idx, id_2
    return None, None


def add_ids(df_id, df):
    """
    Adds possibly new identities found in a given data frame column to the
    single source of truth identity table.

    Args:
        df_id: Existing identity table with unique person identities.
        df: Data frame with possibly new identities to add.

    Returns:
        The unified identity table.
    """
    unique_ids = get_unique_ids(df)

    # Get all unique IDs
    for id_1 in unique_ids:
        # IDs may be pre-merged by Kaiaulu. To get a matching close to Codeface,
        # consider each identity part separately.
        id_1_parts = id_1.split(" | ")
        for p_1 in id_1_parts:
            exact_match = False  # Matching name and e-mail address
            email_match = False  # Matching e-mail address, but different name
            name_match = False  # Matching name, but different e-mail address

            # Search for matches of both e-mail address and name.
            for idx, row in df_id.iterrows():
                id_2 = row["name_email"]
                if p_1 in id_2:
                    exact_match = True
                    break

            if not exact_match:
                # Search for e-mail address matches.
                idx, id_2 = find_by_email(p_1, df_id)
                if idx is not None and id_2 is not None:
                    # A new name - e-mail combination has to be added.
                    print("Adding "+p_1+" to "+id_2+" (based on e-mail)")
                    df_id.loc[idx, "name_email"] += " | "+p_1
                    email_match = True

            if not exact_match and not email_match:
                # Search for name matches.
                id_1_name = p_1.strip(" ").split("<")[0]
                if id_1_name.strip(" ") == "unknown":
                    # Identities named unknown should not be matched based on
                    # name because "unknown" might result from an API issue.
                    continue

                idx, id_2 = find_by_name(id_1_name, df_id)
                if idx is not None and id_2 is not None:
                    print("Adding "+p_1+" to "+id_2+" (based on name)")
                    # A new name - e-mail combination has to be added.
                    df_id.loc[idx, "name_email"] += " | "+p_1
                    name_match = True

            if not exact_match and not email_match and not name_match:
                # There is neither a matching e-mail address nor a matching name.
                # Therefore, add a new identity to the table.
                print("Adding new entry for "+p_1)
                entry = pd.DataFrame({"name_email": [p_1]})
                df_id = pd.concat([df_id, entry], ignore_index=True)
    return df_id


def create_id_table(df_gitlog, df_filtered, entities_path):
    """
    Constructs a single source of truth identity table containing all person
    identities found in the holistic git log as well as in the entity analysis
    results.

    Args:
        df_gitlog: Holistic git log extracted by Kaiaulu.
        df_filtered: Filtered git log extracted by Kaiaulu.
        entities_path: Path to the entity analysis results extracted by Kaiaulu.

    Returns:
        The merged person identities table.
    """
    # Start with an empty ID data frame.
    df_id = pd.DataFrame()

    # Merge the author and committer IDs from the git log.
    df_id = add_ids(df_id, df_gitlog)

    # Actually, we should have all persons' IDs now. But to be safe, also
    # check the filtered git log and the individual entity analysis results to
    # add anything we might have missed.
    df_id = add_ids(df_id, df_filtered)
    for range_dir in sorted(os.listdir(entities_path)):
        file_name = "entities_"+str(range_dir)+".csv"
        file_path = os.path.join(entities_path, range_dir, file_name)
        df_range = pd.read_csv(file_path, encoding="latin-1")
        # Merge the author and committer IDs from the entity log.
        df_id = add_ids(df_id, df_range)

    # Due to unfortunate order of adding identities, some matching criteria
    # may not be fulfilled even though there is a matching.
    # E.g. the developers A <a@example.com> and Anna <anna@example.com> would
    # not be matched. But knowing that A is also using address
    # <anna@example.com> would allow us to match.
    # This threat is also found in other tools (Codeface).
    return df_id


def replace_ids(df_id, df):
    """
    Replaces possibly diverging identities in a data frame column by unified
    identities given in an identity table.

    Args:
        df_id: Existing identity table with unique person identities.
        df: Data frame column with diverging identities to replace.

    Returns:
        The data frame column with cleaned identities.
    """
    unique_ids = get_unique_ids(df)

    # Get all unique IDs in the given column
    for id_1 in list(unique_ids):
        # IDs may be pre-merged by Kaiaulu. To get a matching close to Codeface,
        # consider each identity part separately.
        id_1_parts = id_1.split(" | ")
        for p_1 in id_1_parts:
            exact_match = False
            email_match = False

            # Search for matches of both e-mail address and name.
            for idx, row in df_id.iterrows():
                id_2 = row["name_email"]
                if p_1 in id_2:
                    print(
                        "Replacing "+id_1+" by "+id_2+" (based on exact match)")
                    df.loc[df["author_name_email"].str.contains(p_1,
                                                                regex=False), "author_name_email"] = id_2
                    df.loc[df["committer_name_email"].str.contains(p_1,
                                                                   regex=False), "committer_name_email"] = id_2
                    break

            if not exact_match:
                # Search for e-mail address matches.
                idx, id_2 = find_by_email(p_1, df_id)
                if idx is not None and id_2 is not None:
                    print("Replacing "+id_1+" by "+id_2+" (based on e-mail)")
                    df.loc[df["author_name_email"].str.contains(p_1,
                                                                regex=False), "author_name_email"] = id_2
                    df.loc[df["committer_name_email"].str.contains(p_1,
                                                                   regex=False), "committer_name_email"] = id_2
                    break

            if not exact_match and not email_match:
                # Search for name matches.
                id_1_name = p_1.strip(" ").split("<")[0]
                if id_1_name.strip(" ") == "unknown":
                    # Identities named unknown should not be matched because
                    # "unknown" might result from an API issue.
                    continue

                idx, id_2 = find_by_name(id_1_name, df_id)
                if idx is not None and id_2 is not None:
                    print("Replacing "+id_1+" by "+id_2+" (based on name)")
                    df.loc[df["author_name_email"].str.contains(p_1,
                                                                regex=False), "author_name_email"] = id_2
                    df.loc[df["committer_name_email"].str.contains(p_1,
                                                                   regex=False), "committer_name_email"] = id_2
                    break
    return df


def unify_ids(df_id, df_gitlog, df_filtered, entities_path, save_path):
    """
    Unifies identities in all git log tables extracted by Kaiaulu.

    Args:
        df_id: Single source of truth identity table.
        df_gitlog: Holistic git log extracted by Kaiaulu.
        df_filtered: Filtered git log extracted by Kaiaulu.
        entities_path: Path to the entity analysis results extracted by Kaiaulu.
        save_path: Path to the directory to store the processed data with
                   unified identities.

    Returns:
        None.
    """
    # Replace identities in the git log table.
    print("Unfiying IDs in gitlog...")
    df_gitlog = replace_ids(df_id, df_gitlog)
    df_filtered = replace_ids(df_id, df_filtered)

    # Save the post-processed git log.
    git_log_save_path = os.path.join(save_path, "gitlog_complete.csv")
    df_gitlog.to_csv(git_log_save_path, encoding="latin-1", index=False)
    git_log_save_path = os.path.join(save_path, "gitlog_filtered.csv")
    df_filtered.to_csv(git_log_save_path, encoding="latin-1", index=False)

    # Replace identities in the entity tables.
    for range_dir in sorted(os.listdir(entities_path)):
        print("Unifying IDs in range "+range_dir+"...")
        file_name = "entities_"+str(range_dir)+".csv"
        file_path = os.path.join(entities_path, range_dir, file_name)
        df_range = pd.read_csv(file_path, encoding="latin-1")

        # Merge the range entities author and committer IDs.
        df_range = replace_ids(df_id, df_range)

        # Save the post-processed entity analysis results.
        df_range_save_dir = os.path.join(save_path, "entities", range_dir)
        if not os.path.isdir(df_range_save_dir):
            os.makedirs(df_range_save_dir)
        df_range_save_path = os.path.join(df_range_save_dir, file_name)
        df_range.to_csv(df_range_save_path, encoding="latin-1", index=False)


def create_git_slices(date_list, experiment,
                      df_gitlog, entities_path, save_path):
    """
    Slices the holistic file git log table extracted by Kaiaulu into time
    slices replication to those of Kaiaulu's entity analysis.

    Args:
        date_list: The list of dates to split the git log for.
        experiment: The experiment series for which the slices are created.
        df_gitlog: The holistic git log extracted by Kaiaulu.
        entities_path: Path to the entity analysis results extracted by Kaiaulu.
        save_path: Path to the directory to store the processed slices.

    Returns:
        None.
    """
    # Create file-level git log tables for each time window (replication to the
    # entity analysis results).
    range_id_norm = 1

    for range_dir in sorted(os.listdir(entities_path)):
        file_name = "files_"+str(range_dir)+".csv"
        # Extract the required slice from the git log.
        start_time = date_list[range_id_norm-1]
        end_time = date_list[range_id_norm]
        if experiment == "prior":
            df_slice = df_gitlog.loc[
                (df_gitlog["author_datetimetz"] >= start_time) & (
                        df_gitlog["author_datetimetz"] < end_time)]
        else:
            df_slice = df_gitlog.loc[
                (df_gitlog["committer_datetimetz"] >= start_time) & (
                        df_gitlog["committer_datetimetz"] <= end_time)]

        # Save the time slice.
        slice_dir_path = os.path.join(save_path, range_dir)
        if not os.path.isdir(slice_dir_path):
            os.makedirs(slice_dir_path)
        file_path = os.path.join(slice_dir_path, file_name)
        df_slice.to_csv(file_path, encoding="latin-1", index=False)

        range_id_norm += 1


def main(experiment, project,
         conf_path, data_path, save_path,
         merge_id, time_slice):
    complete_git_log_path = os.path.join(data_path, "gitlog_complete.csv")
    filtered_git_log_path = os.path.join(data_path, "gitlog_filtered.csv")
    entities_path = os.path.join(data_path, "entities")

    with open(conf_path) as file:
        conf = yaml.safe_load(file)

    if merge_id:
        print("Merging identities in project "+str(project)+"...")

        # Load the git log.
        df_complete = read_gitlog(complete_git_log_path)
        df_filtered = read_gitlog(filtered_git_log_path)

        # Create an identity table as reference for identity matching.
        df_id = create_id_table(df_complete, df_filtered, entities_path)
        print("ID table created.")

        # Save the final identities table.
        if not os.path.isdir(save_path):
            os.makedirs(save_path)
        df_id = df_id.sort_values(by=["name_email"])
        identity_save_path = os.path.join(save_path, "identity.csv")
        df_id.to_csv(identity_save_path, encoding="latin-1", index=False)

        # Unify identities based on the identity table.
        unify_ids(df_id, df_complete, df_filtered, entities_path, save_path)
        print("IDs unified.")
    else:
        copy_tree(data_path, save_path)
        print("Data copied.")

    if time_slice:
        # (Re-)load the preprocessed holistic git log.
        processed_git_log_path = os.path.join(save_path, "gitlog_filtered.csv")
        df_filtered = read_gitlog(processed_git_log_path)

        date_list = conf["analysis"]["window"]["ranges"]

        file_dir_path = os.path.join(save_path, "files")
        if not os.path.isdir(file_dir_path):
            os.makedirs(file_dir_path)

        # Create time slices of the git log table.
        create_git_slices(date_list, experiment, df_filtered, entities_path,
                          file_dir_path)


if __name__ == "__main__":
    args = arguments()
    main(args.experiment, args.project,
         args.conf_path, args.data_path, args.save_path,
         args.merge_id, args.time_slice)
