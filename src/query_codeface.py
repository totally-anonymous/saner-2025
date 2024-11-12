# Helper functions to query data from the Codeface database.

import pandas as pd


def get_project_id(cur, project):
    """
    Gets the project IDs for a given project name.

    Args:
        cur: The MySQL database connection cursor.
        project: Project name in Codeface database.

    Returns:
        The project ID.
    """
    query = "select id from project where name like '"+project+"'"
    cur.execute(query)
    pid = cur.fetchone()[0]
    return pid


def get_range_ids(cur, pid):
    """
    Gets all range IDs for a given project.

    Args:
        cur: The MySQL database connection cursor.
        pid: Project ID in Codeface database.

    Returns:
        The list of all revision ranges.
    """
    query = "select releaseRangeID \
            from revisions_view \
            where projectId="+str(pid)
    cur.execute(query)
    res = cur.fetchall()
    range_ids = [r[0] for r in res]
    return range_ids


def get_devs_activity(cur, pid, range_id):
    """
    Gets all active developers (authors) with their number of authored commits
    in a specific revision range of a project.

    Args:
        cur: The MySQL database connection cursor.
        pid: Project ID in Codeface database.
        range_id: Revision range ID.

    Returns:
        Data frame with active developers (authors) and their number of commits.
    """
    query = "select personId, any_value(name) as name, \
             any_value(email1) as email1, any_value(email2) as email2, \
             any_value(email3) as email3, any_value(email4) as email4, \
             any_value(email5) as email5, count(distinct dev.commitId) as n_commits \
             from (select p.id as personId, name, email1, email2, email3, \
                   email4, email5, c.id as commitId \
                   from person p inner join commit c on p.id=c.author \
                   where c.releaseRangeId="+str(range_id)+" and \
                   c.projectId="+str(pid)+") as dev\
             group by personId"
    cur.execute(query)
    res = cur.fetchall()
    df = pd.DataFrame(res, columns=["personId", "name", "email1", "email2",
                                    "email3", "email4", "email5", "n_commits"])
    return df


def get_num_devs(cur, pid, range_id):
    """
    Gets the number of active developers (authors and committers) in a specific
    revision range of a project.

    Args:
        cur: The MySQL database connection cursor.
        pid: Project ID in Codeface database.
        range_id: Revision range ID.

    Returns:
        The number of active developers in the respective range.
    """
    query = "select count(*) \
             from (select distinct author \
                   from commit c \
                   inner join revisions_view r on c.releaseRangeId=r.releaseRangeId \
                   where c.projectId="+str(pid)+" and \
                   c.releaseRangeId="+str(range_id)+"\
                   union \
                   select distinct committer \
                   from commit c \
                   where c.projectId="+str(pid)+" and \
                   c.releaseRangeId="+str(range_id)+") as person"
    cur.execute(query)
    res = cur.fetchone()
    return res[0]


def get_commits(cur, pid, range_id):
    """
    Gets the number of commits in the given revision range.

    Args:
        cur: The MySQL database connection cursor.
        pid: Project ID in Codeface database.
        range_id: Revision range ID.

    Returns:
        The number of commits
    """
    query = "select count(*) \
             from commit \
             where projectId="+str(pid)+" and \
             releaseRangeId="+str(range_id)
    cur.execute(query)
    res = cur.fetchone()
    return res[0]


def get_commit_hashes(cur, pid, range_id):
    """
    Gets the list of all commit hashes for the given revision range.

    Args:
        cur: The MySQL database connection cursor.
        pid: Project ID in Codeface database.
        range_id: Revision range ID.

    Returns:
        The list of commit hashes
    """
    query = ("select name as project, commitHash \
             from commit c inner join project p \
             on c.projectId=p.id \
             where p.id="+str(pid)+" and c.releaseRangeId="+str(range_id))
    cur.execute(query)
    res = cur.fetchall()

    hashes = [r for r in res]
    return hashes


def get_num_files(cur, pid, range_id):
    """
    Gets the number of changed files in the given revision range.

    Args:
        cur: The MySQL database connection cursor.
        pid: Project ID in Codeface database.
        range_id: Revision range ID.

    Returns:
        The number of changed files.
    """
    query = "select count(distinct file) \
             from commit_dependency d \
             inner join commit c on d.commitId=c.id \
             where c.projectId="+str(pid)+" and \
             c.releaseRangeId="+str(range_id)
    cur.execute(query)
    res = cur.fetchone()
    return res[0]


def get_files_activity(cur, pid, range_id):
    """
    Gets the names of all changed files with their number of changing commits
    in the given revision range of the project.

    Args:
        cur: The MySQL database connection cursor.
        pid: Project ID in Codeface database.
        range_id: Revision range ID.

    Returns:
        Data frame with files and their number of commits.
    """
    query = "select file, count(distinct commitId) as n_commits \
             from commit_dependency d inner join commit c on d.commitId=c.id \
             where c.projectId="+str(pid)+" \
             and c.releaseRangeId="+str(range_id)+" \
             group by file order by n_commits desc"
    cur.execute(query)
    res = cur.fetchall()
    df = pd.DataFrame(res, columns=["file", "n_commits"])
    return df


def get_entities(cur, pid, range_id):
    """
    Gets the unique names of changed entities (functions) in the given
    revision range.

    Args:
        cur: The MySQL database connection cursor.
        pid: Project ID in Codeface database.
        range_id: Revision range ID.

    Returns:
        The changed entities.
    """
    query = "select entityId \
             from (select id, projectId, releaseRangeId from commit) as c \
             inner join commit_dependency d on c.id=d.commitId \
             where c.projectId="+str(pid)+" and \
             c.releaseRangeId="+str(range_id)
    cur.execute(query)
    res = cur.fetchall()

    if res is not None:
        return [str(r[0]) for r in res]
    else:
        return None


def get_entities_activity(cur, pid, range_id):
    """
    Gets the names of all changed entities with their number of changing
    commits in the given revision range of the project.

    Args:
        cur: The MySQL database connection cursor.
        pid: Project ID in Codeface database.
        range_id: Revision range ID.

    Returns:
        Data frame with entities and their number of commits.
    """
    query = "select entityId, count(distinct commitId) as n_commits \
             from commit_dependency d inner join commit c on d.commitId=c.id \
             where c.projectId="+str(pid)+" \
             and c.releaseRangeId="+str(range_id)+" group by entityId \
             order by n_commits desc"
    cur.execute(query)
    res = cur.fetchall()
    df = pd.DataFrame(res, columns=["entity", "n_commits"])
    return df
