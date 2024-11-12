-- With project and range specified
select entityId, entityType, size commitHash, name, email1, commitDate, authorDate, authorTimeOffset, authorTimezones,
        ChangedFiles, AddedLines, DeletedLines, DiffSize, CmtMsgLines, CmtMsgBytes, NumSignedOffs, NumTags,
        general, TotalSubsys, Subsys, inRC, AuthorSubsysSimilarity, AuthorTaggersSimilarity, TaggersSubsysSimilarity, releaseRangeId, description, 
        corrective
          from (select * from (select entityId, entityType, size, impl, commitId
                              from codeface.commit_dependency
                              where commitId in (select id AS cid
                                                    from codeface.commit
                                                    where projectId=(select id from project where name like "kaiaulu") and releaseRangeId=713)) as cd 
                inner join (select * from codeface.commit) as c 
                on cd.commitId=c.id) as res
                inner join (select id AS pid, name, email1 from codeface.person) as p on res.author=p.pid;
                

--
mysql -u codeface -p -e "select entityId, entityType, size, commitHash, name, email1, commitDate, authorDate, authorTimeOffset, authorTimezones,
        ChangedFiles, AddedLines, DeletedLines, DiffSize, CmtMsgLines, CmtMsgBytes, NumSignedOffs, NumTags,
        general, TotalSubsys, Subsys, inRC, AuthorSubsysSimilarity, AuthorTaggersSimilarity, TaggersSubsysSimilarity, releaseRangeId, description, 
        corrective
          from (select * from (select entityId, entityType, size, impl, commitId
                              from codeface.commit_dependency
                              where commitId in (select id AS cid
                                                    from codeface.commit
                                                    where projectId=(select id from codeface.project where name like \"kaiaulu\") and releaseRangeId=713)) as cd 
                inner join (select * from codeface.commit) as c 
                on cd.commitId=c.id) as res
                inner join (select id AS pid, name, email1 from codeface.person) as p on res.author=p.pid;" > git.tsv