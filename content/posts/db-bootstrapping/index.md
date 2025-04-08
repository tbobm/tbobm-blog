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

> Notes:
> - Why I love atlasgo: 
> - like alembic but with schema as code that can leverage HCL (shared format with other tools I use like terraform or packer) and without any direct language used
> - declarative approach is a must have today
> - easy to replicate, structure, review
> - I personally don't like ClickOps
> - lightweight and easy to use

Bootstrapping SQL Databases for Local and Production Setup

# Infra as Code, Schema as Code, Everything as Code

When working with databases, consistency and repeatability are key. Whether
setting up a local development database or provisioning a production-ready environment,
managing infrastructure and schema as code ensures a predictable and
maintainable setup.

Let's explore why this approach matters and how tools
like [AtlasGO][atlas-main] simplify schema management.

## Why yet another tool?

There are plenty of database migration tools out there, like Alembic that I've used in the past
but I love AtlasGO for a few reasons:

- **Schema as Code**: unlike imperative migration tools, [AtlasGO][atlas-main] takes a
declarative approach, allowing you to define your schema in a structured format.
- **Leverages HCL**: it uses HashiCorp Configuration Language ([HCL][hcl-gh]), the same format used
by (my dear) Terraform and Packer, making it easier to integrate with existing
infrastructure as code workflows.
- **No dependecy on a language dependency**: many tools require Python, Java,
or SQL-based scripting. AtlasGO avoids this, keeping the setup lightweight and easy to use.
- **Easy to replicate and review**: having a single source of truth for schema definitions
makes collaboration, code reviews, and automation seamless.

TODO: switch to a note or something ?

**No ClickOps**: I strongly dislike manual UI-based configurations (aka [ClickOps][clickops-wiki]).
They lead to inconsistencies and make infrastructure difficult to track and reproduce.

_What this means in practice?_

By adopting a declarative approach, we gain:

**Predictability**: changes are explicit and version-controlled.

**Automation**: infrastructure and schema changes can be applied programmatically.

**Scalability**: the same process can be used across local, staging, and production environments.

In the next section, we’ll get hands-on with AtlasGO, defining an initial schema and managing database migrations efficiently.

### embrace schema as code

- initial schema declaration
  - describe: you can either build it from scratch or by introspection on an existing database
    - add snippet
    - add minimal schema with 2 tables: papers (title, id) and mentions (ref to paper, id, document)
  - hint: introspection is great way to switch from an ORM based database management
- adding migrations
  - simple example on how to add something to our table
- additional: shout-out to chartdb.io for diagram viz (include todo to add viz picture)

### Embrace schema as code

**Initial schema declaration:**

When starting with schema as code, you can either:

- Build your schema from scratch
- Introspect an existing database to generate schema definitions automatically

Introspection is particularly useful if you're transitioning from an ORM-managed
database to a structured schema-as-code approach.

Here’s an example of a minimal schema with two tables using AtlasGO:

```hcl
schema "public" {
  table "papers" {
    column "id" { type: int, primary_key: true }
    column "title" { type: text }
  }

  table "mentions" {
    column "id" { type: int, primary_key: true }
    column "paper_id" { type: int, references: table.papers.id }
    column "document" { type: text }
  }
}
```

This schema defines:
- A `papers` table with an id (primary key) and title.
- A `mentions` table that references papers, linking a mention to a paper.

**Adding migrations:**

TODO: add example output

Once the schema is defined, making changes is straightforward.
Here’s an example migration adding a new column to papers:
```hcl
migration "add_author" {
  table "papers" {
    add column "author" { type: text }
  }
}
```
This keeps the database in sync with schema changes, making
modifications structured and predictable.

**Visualization:**

Visualizing with ChartDB.io

For database visualization, tools like ChartDB.io can generate schema diagrams,
making it easier to understand relationships and structures.
(TODO: Add visualization image example.)

In the next section, we’ll discuss best practices for user roles
and access control in SQL databases.

## stop using the masteruser

STARTDELETE
_rbac: creating standard roles and users_

only applies to non-local, apply to local when permissions need to be validated but I would not
dive in it except if mandatory

### why and how

- using the masteruser is a huge security risk
- applications can not be tracked properly
- credential rotation is painful to propagate if no dynamic retrieval is possible

when using users, we can leverage postgres capabilities by limiting max query duration, accesses
and have a more useful overview of how our database is use (i.e.: RDS enhanced monitoring and
postgres analytics can leverage multiple users)

### default go-to roles

- migration user for non-local (create, alter, drop) use to apply our migrations through CICD
- application user (read, write) for our apps
- analytics user (read only) for BI use, Data team, Product managers, ...

only one migration user should be used per environment and it will be used by our cicd user

### a step beyond: match applications with roles

following our default setup, we can go a step further and allow _parts_ of our database
to be used by some applications, in a "shared database" setup

TODO: link to tracking db article (my other medium article which recommends automated updates
based on the "?application" postgres query parameter)

STOPDELETE

Great! Here's your draft section on database roles and users, written in the style you prefer—clear, structured, and actionable for engineers and decision-makers.

---

## Stop using the master user

_RBAC: Creating standard roles and users_

One of the most overlooked yet impactful improvements you can make to your
database setup is role separation. In local development, you might get away
with using the `postgres` or `admin` user. But in production? That’s a ticking time bomb.

Role-based access control (RBAC) ensures that each piece of your stack interacts with
the database with only the privileges it needs—nothing more, nothing less.

### Why and how

Relying on the master user in production environments is a common anti-pattern.
Here's why it's problematic:
- **Security risk**: The master user has full access. A compromised app or
leaked secret means game over.
- **No visibility**: All traffic appears to come from a single user.
Debugging and auditing become much harder.
- **Credential management hell**: Rotating the master user's password
without breaking everything is a pain unless you're wired up
with something like AWS Secrets Manager which comes at a price.

Instead, creating specific users for different concerns allows you to:
- Set **resource limits** like max query duration or connection count.
- Leverage **monitoring tools** (e.g., RDS Enhanced Monitoring or `pg_stat_statements`)
to attribute usage and performance bottlenecks to the correct app.
- Simplify auditing and anomaly detection.

### Default go-to roles

Here’s a standard setup that works well in most projects:

| Role             | Privileges                             | Purpose                                       |
|------------------|----------------------------------------|-----------------------------------------------|
| `migration_user` | `CREATE`, `ALTER`, `DROP`              | Runs schema migrations via CI/CD              |
| `app_user`       | `SELECT`, `INSERT`, `UPDATE`, `DELETE` | Used by the main application                  |
| `analytics_user` | `SELECT` only                          | Read-only access for BI tools, analysts, etc. |

Only **one migration user per environment** should exist, and its usage should be limited to
your CI/CD pipelines (e.g., GitHub Actions, GitLab CI, etc.).

### A step beyond: match applications with roles

Once you have basic role separation, you can go even further by assigning access based on *parts* of your schema.

For example:
- App A gets read/write on the `orders` schema.
- App B can only read from the `public` schema.
- A shared database supports multiple services, each with tightly scoped permissions.

This works especially well when pairing with application names passed via the PostgreSQL
`?application_name=` connection parameter. Tools like `pg_stat_activity` and `pg_stat_statements`
can then help you trace queries back to their origin.

> 🔗 **TODO**: Link to my article on using `?application_name` for tracking
and dynamic RBAC automation.

```sql
-- Run as the master user or a superuser role

-- Create the migration user
CREATE ROLE migration_user WITH
    LOGIN
    PASSWORD 'your-secure-password'
    CREATEDB
    CREATEROLE
    NOSUPERUSER;

-- Grant schema modification privileges
GRANT CONNECT ON DATABASE your_database TO migration_user;
GRANT USAGE ON SCHEMA public TO migration_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO migration_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO migration_user;

-- Create the application user
CREATE ROLE app_user WITH
    LOGIN
    PASSWORD 'your-secure-password'
    NOSUPERUSER
    NOCREATEDB
    NOCREATEROLE;

GRANT CONNECT ON DATABASE your_database TO app_user;
GRANT USAGE ON SCHEMA public TO app_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO app_user;

-- Create the analytics user
CREATE ROLE analytics_user WITH
    LOGIN
    PASSWORD 'your-secure-password'
    NOSUPERUSER
    NOCREATEDB
    NOCREATEROLE;

GRANT CONNECT ON DATABASE your_database TO analytics_user;
GRANT USAGE ON SCHEMA public TO analytics_user;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO analytics_user;
```

> 🛠 **Pro Tip**: To ensure future tables inherit the correct permissions, add `ALTER DEFAULT PRIVILEGES` statements:
```sql
-- Future-proof privileges for app_user
ALTER DEFAULT PRIVILEGES IN SCHEMA public
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO app_user;

-- For analytics_user
ALTER DEFAULT PRIVILEGES IN SCHEMA public
GRANT SELECT ON TABLES TO analytics_user;
```

This script ensures your roles are ready for day-to-day use, while
keeping privileges scoped and secure.

NEXTARTICLE

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
[atlas-main]: https://atlasgo.io/
[clickops-wiki]: https://en.wiktionary.org/wiki/ClickOps
[hcl-gh]: https://github.com/hashicorp/hcl
