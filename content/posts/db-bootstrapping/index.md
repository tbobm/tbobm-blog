+++
title = 'Bootstrapping SQL databases for local and production setup'
date = 2025-03-11T11:30:20+02:00
ShowToc = true
tocopen = true
tags = ['tech', 'database', 'rbac', 'postgres', 'migration']
+++

A hands-on guide and list of things I enjoy doing when working with databases.

Intro: databases are everywhere + I love Postgres, sad to miss the pgdays

- [ ] Add catchy summary / teaser

## Intro - tools involved

- introduce tools
  - simple postgres image with compose
  - aws rds with terraform module
- schema as code using atlasgo
  - why yet another tool
  - initial schema declaration
  - adding migrations
- stop using the masteruser (rbac: creating roles and users)
  - migration user for non-local (create, alter, drop)
  - application user (read, write)
  - analytics user (read only)
- maintaining our database
  - migration with cicd deployment user using gha
  - keeping it lean: neat patterns to reduce the bill (summarizing, crunching)
  - ensuring we can recover: snapshots and DB dumps



- simple postgres image with compose
- aws rds with terraform module

## Infra as code, Schema as code, everything as code

### why yet another tool

Why I love atlasgo

like alembic but with schema as code that can leverage HCL

### embrace schema as code

- initial schema declaration
  - either from scratch or by introspection
  - great way to switch from an ORM based database management

- adding migrations
  - simple example on how to add something to our table

shout-out to chartdb.io ?

## stop using the masteruser

_rbac: creating standard roles and users_

only applies to non-local, apply to local when permissions need to be validated

### why and how

### default go-to roles

- migration user for non-local (create, alter, drop)
- application user (read, write)
- analytics user (read only)

### a step beyond: match applications with roles

link to tracking db article


## maintaining our database

_you're here for the RUN part too_

### CICD deployment with github actions

either synchronous or using ECS for private databases

build image with latest revision, push to ECR, trigger one-off task, wait, good if success rollback

consider waiter but inform can be costly on github actions
https://awscli.amazonaws.com/v2/documentation/api/latest/reference/ecs/wait/tasks-stopped.html


- migration with cicd deployment user using gha
  - merged changes lead to migration being applied
  - enable "self served" database rollback with workflow dispatch


### keeping it lean: reduce the bill
- keeping it lean: neat patterns to reduce the bill (summarizing, crunching)
  - analytics and processing should be split
  - ever-growing databases are not scalable, leads to wasted $

### ensuring we can recover: snapshots and DB dumps

- disaster recovery is important
- useful to bootstrap non-production environments
- snapshots vs database dumps: they should coexist IMHO

mention replibyte? anonymization is cool too

## Conclusion

Feel free to reach out if you have feedbacks or questions !

[Theo "Bob" Massard][linkedin]

[linkedin]: https://linkedin.com/in/tbobm/

[health-check-repo]: https://github.com/tbobm/complete-health-checks-design

[postgresql-home]: https://www.postgresql.org/

[ecs]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/Welcome.html
[alembic-gh]: https://github.com/sqlalchemy/alembic
[atlas-gh]: https://github.com/ariga/atlas
