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

## Intro

When working with databases, it’s easy to fall into the trap of “just winging it”—a
quick container here, a few clicks in the AWS console there, and before
you know it, you're running production off an unversioned schema with the master user.

This article is a hands-on guide—and a collection of things I’ve grown to
enjoy—when working with SQL databases in modern environments. It covers
setting up Postgres both locally and in the cloud, adopting schema as
code using Atlas, securing access with proper roles, and maintaining
everything through GitHub Actions.

The goal is to keep your database setup repeatable, reviewable, and resilient from day one.

## Infra as Code, Schema as Code, Everything as Code

When working with databases, consistency and repeatability are key. Whether
setting up a local development database or provisioning a production-ready environment,
managing infrastructure and schema as code ensures a predictable and
maintainable setup.

Let's explore why this approach matters and how tools
like [AtlasGO][atlas-main] simplify schema management.

### Why yet another tool?

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

In the next section, we’ll get hands-on with AtlasGO, defining an initial schema
and managing database migrations efficiently.

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

## Stop using the master user !

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


## Maintaining our database

_You're here for the **run** part too._

Setting up a schema and applying best practices around roles
is great but it’s not enough. Your database needs to **evolve** safely,
**scale** affordably, and be **recoverable** in a pinch.

This section walks through real-world practices that help you stay production-ready.

### CI/CD Deployment with GitHub Actions

Whether your database is public-facing or running inside a private subnet
(like AWS RDS in a VPC), schema changes should be handled like any
other part of your system: via CI/CD.

A typical setup might look like:

1. **Build a one-off migration container** using the latest application revision
2. **Push it to ECR**
3. **Trigger a one-off ECS task** to run the migration
4. **Wait for success or rollback** automatically if something fails

You can even use GitHub Actions to orchestrate the ECS task execution and lifecycle.

TODO: see example definition in gh repo

#### Example: Wait for ECS Task to Finish

If using ECS, consider leveraging the AWS CLI "waiter" to monitor your task:

```bash
aws ecs wait tasks-stopped \
  --cluster my-cluster \
  --tasks <task-id>
```

> ⚠️ Heads-up: this can be expensive in GitHub Actions minutes—use it with caution or optimize with shorter polling and early exits.

#### Good Practice

- Migrations should be applied by the `migration_user` created earlier.
- Use GitHub Actions triggers on `main` or `release` branches.
- Add a **manual rollback** mechanism using `workflow_dispatch` to enable safe rollbacks without reverting code.

### Keeping it lean: reducing the bill

Databases often grow silently until one day your AWS bill screams louder than your SRE.

**Some human friendly cost-saving patterns**:

- **Separate analytics from OLTP**: Don't let your app compete with long-running queries for dashboard refreshes
- **Summarize over time**: Replace large granular datasets with summary tables. For example, keep hourly event logs for a month, but store daily rollups after that
- **Crunch data**: Convert high-volume event streams into metric tables like:

```sql
CREATE TABLE metrics (
  event_type TEXT,
  period DATE,
  completed_count INT
);
```

You still get insights, with a fraction of the storage cost.

### Ensuring we can recover: snapshots & DB dumps

No setup is complete without a solid backup strategy.

- **Automated RDS snapshots**: Perfect for infrastructure-level recovery. Fast, point-in-time, but tied to AWS.
- **Database dumps** (e.g., `pg_dump`): Ideal for portability, seeding test/staging environments, and archiving.
- **Both** should coexist. Snapshots for fast infra restore, dumps for controlled imports and auditing.

#### Bonus: Use realistic data safely

Tools like [Replibyte](https://github.com/Qovery/Replibyte) let you:

- Dump production-like data into staging/dev environments.
- **Anonymize sensitive data** automatically.
- Safely run integration or load tests without risking exposure.

This improves test coverage while respecting privacy and compliance.

## Conclusion

Bootstrapping and maintaining SQL databases doesn't have to be a mystery or a manual chore.
By treating infrastructure and schema as code, defining clear roles, and integrating database
changes into your CI/CD workflows, you build a system that is reproducible, secure, and scalable
by design.

This hands-on approach not only improves developer velocity but also strengthens
operational resilience. Whether you're spinning up a new service locally,
managing production-grade RDS instances or fine-tuning query access for analytics,
these practices help you move fast without breaking your data.

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
