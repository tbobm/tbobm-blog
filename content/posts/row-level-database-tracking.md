+++
title = 'Tracking Row Level changes in PostgreSQL'
date = 2024-11-04T17:17:00+02:00
ShowToc = true
+++

Ownerships and modification dates often have a huge role in troubleshooting or understanding
how applications work. Making last change metadata available can be a game changer in case
of bug hunting or to understand how data behaves without digging through logs for hours.

Let's dive in a way of automating this "last update" tracking at the row level in Postgresql.

> Code is available at [github.com/tbobm/postgresql-row-level-changes][gh-repo]

# Automatically Tracking Row-Level Changes in PostgreSQL

Managing changes to database records is a crucial part of maintaining data integrity and transparency in a system.
PostgreSQL exposes features that allow developers to automatically track changes at the row level,
ensuring that every update is recorded with both a timestamp and an identifier of the application making the change.

In this post, I'll walk you through a method to implement automatic tracking
of these changes using PostgreSQL [triggers][trigger-doc] and functions.

[trigger-doc]: https://www.postgresql.org/docs/current/trigger-definition.html

## Why Track Row-Level Changes?

In any application where data integrity is critical, understanding changes and who authored
them can be essential to understand unexpected situations.
Knowing when a record was last updated and by whom helps in tracking issues,
understanding user behavior or how a system (mis)behaves.

PostgreSQL offers several mechanisms to track these changes automatically,
ensuring that your application doesn't miss a beat when it comes to recording who changed what and when.

This requires very little overhead and can be progressively rolled out to multiple sub-components.

## Tracking the Last Update Author

One common requirement is to track which user or application last updated a particular row in a table.
PostgreSQL provides a neat way to do this using the [`current_setting`][psql-settings] function,
combined with a trigger that updates the `updated_by` column whenever a row is modified.

Let's see how to implement this behavior.

[psql-settings]: https://www.postgresql.org/docs/current/functions-admin.html#FUNCTIONS-ADMIN-SET

### Create the Table

We'll start by creating a table called `documents` where each record represents a document with its
content stored in JSON format. Additionally, we'll include an `updated_by` column to store the
identifier of the application or user that last modified the row.

```sql
CREATE TABLE documents (
  id INT PRIMARY KEY NOT NULL,
  content jsonb,
  updated_by text DEFAULT current_setting('application_name')
);
```

The setting `application_name` can be set directly in Postgresql connection URIs by setting
the `?application_name=my_app` attribute suffix.

```console
$ psql postgresql://user:password@localhost/example?application_name=tbobm

example=# select current_setting('application_name');
 current_setting 
-----------------
 tbobm

```

### Create a Trigger Function

Next, we'll create a trigger function that will automatically update the `updated_by` column with
the value of `current_setting('application_name')` whenever a row is updated. This function ensures
that every modification to the document is attributed to the correct user or application.

```sql
CREATE OR REPLACE FUNCTION set_last_update_author()
RETURNS TRIGGER AS $$
BEGIN
    -- Set the updated_by column to the current client's application_name
    NEW.updated_by := current_setting('application_name');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
```

### Attach the Trigger to the Table

Finally, we attach the trigger function to the `documents` table. This trigger will fire before
every update, ensuring that the `updated_by` column is always set correctly.

```sql
CREATE TRIGGER update_app_name_trigger
BEFORE UPDATE ON documents
FOR EACH ROW
EXECUTE FUNCTION set_last_update_author();
```

With this setup, every time a row in the `documents` table is updated, the `updated_by` field
will automatically reflect the name of the application or user making the change.

## Automatically Updating the Last Modified Timestamp

In addition to tracking **who** made the change, it's often necessary to track when the change was made.
To ensure the `last_updated` column is updated on each row modification, we'll use a default
timestamp combined with a trigger function. This setup will automatically update the timestamp
to the current time whenever a row is updated.

> This requires 0 setup on the client side, which makes it very easy to add in an existing setup

### Modify the Table Schema

First, we’ll add the `last_updated` column to the `documents` table with a default
value of the current timestamp ([postgresql doc][psql-timestamp]):

```sql
ALTER TABLE documents
ADD COLUMN last_updated TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP;
```

[psql-timestamp]: https://www.postgresql.org/docs/current/functions-datetime.html#FUNCTIONS-DATETIME-CURRENT

### Create a Trigger Function

Next, we create a trigger function to update the `last_updated` column to the current timestamp every time a row is modified:

```sql
CREATE OR REPLACE FUNCTION update_last_updated_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.last_updated := CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
```

### Attach the Trigger to the Table

Finally, we attach the trigger function to the `documents` table. This trigger will fire before
every update, ensuring the `last_updated` column is set to the current time whenever a row is modified.

```sql
CREATE TRIGGER set_last_updated
BEFORE UPDATE ON documents
FOR EACH ROW
EXECUTE FUNCTION update_last_updated_column();
```

With this setup the `last_updated` column will automatically reflect the precise
time (server side) of the latest change, providing a timestamp for each row modification.

## Testing our setup

Let's try out our freshly created automation on our `documents` table!

```sql
-- Given a application_name=my_app URI client

-- Insert a new document with content '{"foo": "bar"}'
INSERT INTO documents (id, content)
VALUES (1, '{"foo": "bar"}');

SELECT id, content, updated_by, last_updated from documents;
-- | id |     content     | updated_by |       last_updated         |
-- |----|-----------------|------------|----------------------------|
-- |  1 | {"foo": "bar"}  | my_app     | <current_timestamp>        |

-- Update only the value of "foo" in the JSON content from "bar" to "baz"
UPDATE documents
SET content = jsonb_set(content, '{foo}', '"baz"')
WHERE id = 1;

SELECT id, content, updated_by, last_updated from documents;
-- | id |     content     | updated_by |         last_updated        |
-- |----|-----------------|------------|-----------------------------|
-- |  1 | {"foo": "baz"}  | my_app     | <updated_current_timestamp> |
```

- After the `INSERT`, the `content` is `{"foo": "bar"}`, `updated_by` is set to the application name (e.g., `my_app`), and `last_updated` records the timestamp at the moment of insertion.
- After the `UPDATE`, only the `foo` key in `content` has changed to `"baz"`, and both `updated_by` and `last_updated` are updated to reflect the latest modification.

## Conclusion

By combining triggers, functions, and PostgreSQL's built-in [`current_setting`][psql-settings]
and [`CURRENT_TIMESTAMP`][psql-timestamp] features, you can create a simple system for
automatically tracking row-level changes in your database. This setup requires minimal maintenance
and ensures that your application can always provide accurate audit trails for data modifications.

Whether you're working on an internal tool or a production application, these techniques
can help you maintain data integrity and transparency, making your system more reliable and easy to understand.

Checkout the minimal working setup here: [postgresql-row-level-changes][gh-repo]

[gh-repo]: https://github.com/tbobm/postgresql-row-level-changes

Feel free to reach out if you have feedbacks or questions !

[Theo "Bob" Massard][linkedin]

[linkedin]: https://linkedin.com/in/tbobm/
