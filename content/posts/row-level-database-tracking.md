+++
title = 'Tracking Row Level changes in PostgreSQL'
date = 2024-09-06T03:27:00+02:00
draft = false
+++

# Automatically Tracking Row-Level Changes in PostgreSQL

Managing changes to database records is a crucial part of maintaining data integrity and transparency in a system.
PostgreSQL exposes features that allow developers to automatically track changes at the row level, ensuring that every update is recorded with both a timestamp and an identifier of the application making the change.


In this post, I'll walk you through a method to implement automatic tracking of these changes using PostgreSQL [triggers][trigger-doc] and functions.

[trigger-doc]: https://www.postgresql.org/docs/current/trigger-definition.html

## Why Track Row-Level Changes?

In any application where data integrity is critical—such as in document management systems, financial applications, or auditing systems—keeping a detailed history of changes can be essential. Knowing when a record was last updated and by whom helps in tracking issues, understanding user behavior, and maintaining compliance with data governance policies.

PostgreSQL offers several mechanisms to track these changes automatically, ensuring that your application doesn't miss a beat when it comes to recording who changed what and when.

## Tracking the Last Update Author

One common requirement is to track which user or application last updated a particular row in a table. PostgreSQL provides a neat way to do this using the `current_setting` function, combined with a trigger that updates the `updated_by` column whenever a row is modified.

Here's how you can implement this:

### Step 1: Create the Table

We'll start by creating a table called `documents` where each record represents a document with its content stored in JSON format. Additionally, we'll include an `updated_by` column to store the identifier of the application or user that last modified the row.

```sql
CREATE TABLE documents (
  id INT PRIMARY KEY NOT NULL,
  content jsonb,
  updated_by text DEFAULT current_setting('application_name')
);
```

### Step 2: Create a Trigger Function

Next, we'll create a trigger function that will automatically update the `updated_by` column with the value of `current_setting('application_name')` whenever a row is updated. This function ensures that every modification to the document is attributed to the correct user or application.

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

### Step 3: Attach the Trigger to the Table

Finally, we attach the trigger function to the `documents` table. This trigger will fire before every update, ensuring that the `updated_by` column is always set correctly.

```sql
CREATE TRIGGER update_app_name_trigger
BEFORE UPDATE ON documents
FOR EACH ROW
EXECUTE FUNCTION set_last_update_author();
```

With this setup, every time a row in the `documents` table is updated, the `updated_by` field will automatically reflect the name of the application or user making the change.

## Automatically Updating the Last Modified Timestamp

In addition to tracking who made the change, it's often necessary to track when the change was made. PostgreSQL makes this straightforward with the `DEFAULT CURRENT_TIMESTAMP` clause, which can be combined with `ON UPDATE` to ensure the timestamp is automatically updated whenever a row is modified.

### Modify the Table Schema

We can modify our `documents` table to include a `last_updated` column that automatically records the time of the last modification.

```sql
ALTER TABLE documents
ADD COLUMN last_updated TIMESTAMPTZ
DEFAULT CURRENT_TIMESTAMP
ON UPDATE CURRENT_TIMESTAMP;
```

With this, the `last_updated` column will automatically update to the current timestamp whenever the row is updated, ensuring that you always know the precise time of the last change.

## Conclusion

By combining triggers, functions, and PostgreSQL's built-in `current_setting` and `CURRENT_TIMESTAMP` features, you can create a robust system for automatically tracking row-level changes in your database. This setup requires minimal maintenance and ensures that your application can always provide accurate audit trails for data modifications.

Whether you're working on an internal tool or a production application, these techniques can help you maintain data integrity and transparency, making your system more reliable and trustworthy.

Feel free to experiment with these concepts and adapt them to fit your specific needs. Happy coding!
