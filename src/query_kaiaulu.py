# Helper functions to aggregate data from Kaiaulu tables.

import pandas as pd


def get_num_commits(df_git_log):
    """
    Counts the number of commits.

    Args:
        df_git_log: The Kaiaulu git log (slice) from parse_gitlog.

    Returns:
        Number of commits.
    """
    return len(df_git_log["commit_hash"].unique())


def get_num_files(df_git_log):
    """
    Counts the number of edited files.

    Args:
        df_git_log: The Kaiaulu git log (slice) from parse_gitlog.

    Returns:
        Number of edited files.
    """
    return len(df_git_log["file_pathname"].unique())


def get_num_named_entities(df_git_log):
    """
    Counts the number of unique entities.

    Args:
        df_git_log: The Kaiaulu git log (slice) from parse_entity_gitlog.

    Returns:
        Number of unique entities..
    """
    named_entities = list(df_git_log["entity_definition_name"].unique())
    n_named_entities = len(named_entities)
    return n_named_entities


def get_num_devs_prior(df_git_log, df_entity):
    """
    Counts the number of developers for the prior parameter setting.

    Args:
        df_git_log: The Kaiaulu git log (slice) from parse_gitlog.
        df_entity: The Kaiaulu git log from parse_entity_gitlog.

    Returns:
        Number of developers (for the prior parameter setting).
    """
    df_author = df_git_log[["author_name_email"]]
    df_author = df_author.rename(
        columns={"author_name_email": "name_email"})
    df_committer = df_git_log[["committer_name_email"]]
    df_committer = df_committer.rename(
        columns={"committer_name_email": "name_email"})
    df_dev = pd.concat([df_author, df_committer])

    # Search for additional identities in entity logs
    df_author = df_entity[["author_name_email"]]
    df_author = df_author.rename(
        columns={"author_name_email": "name_email"})
    df_committer = df_entity[["committer_name_email"]]
    df_committer = df_committer.rename(
        columns={"committer_name_email": "name_email"})
    df_dev = pd.concat([df_dev, df_author, df_committer])

    n_devs = len(list(df_dev["name_email"].unique()))
    return n_devs


def get_num_devs_replication(df_git_log):
    """
    Counts the number of developers for the reproduction parameter setting.

    Args:
        df_git_log: The Kaiaulu git log (slice) from parse_gitlog.

    Returns:
        Number of developers (for the reproduction parameter setting).
    """
    # Number of active developers
    df_author = df_git_log[["author_name_email"]]
    df_author = df_author.rename(
        columns={"author_name_email": "name_email"})
    df_committer = df_git_log[["committer_name_email"]]
    df_committer = df_committer.rename(
        columns={"committer_name_email": "name_email"})
    df_dev = pd.concat([df_author, df_committer])
    n_devs = len(list(df_dev["name_email"].unique()))
    return n_devs
