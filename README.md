Require SQL Where Clause
========================

`safeupdate` is a simple extension to PostgreSQL that raises an error if
`UPDATE` and `DELETE` are executed without specifying conditions.  This
extension was initially designed to protect data from accidental obliteration of
data that is writable by [PostgREST][PostgREST].

Installation
------------

    gmake
    gmake install

Activate per-session by running

    load 'safeupdate';

Make this mandatory for all databases and connections by adding the following to
`postgresql.conf`

    shared_preload_libraries=safeupdate

Examples
--------

Try to update records without `WHERE` clause

    => UPDATE FROM rack SET fan_spee=70;
    ERROR:  UPDATE requires a WHERE clause

Set a column value for a range of records

    => UPDATE rack SET fan_speed=90 WHERE fan_speed=70;
    UPDATE 20

Set a column value for all the records in a table

    => UPDATE rack SET fan_speed=90 WHERE 1=1;
    UPDATE 300


Requirements
------------

* PostgreSQL 8.4+

News
----

A release history as well as features in the upcoming release are covered in the
[NEWS][NEWS] file.

License
-------

Source is under and ISC-style license. See the [LICENSE][LICENSE] file for more
detailed information on the license used for compatibility libraries.

[NEWS]: http://www.bitbucket.org/eradman/pg-safeupdate/src/default/NEWS
[LICENSE]: http://www.bitbucket.org/eradman/pg-safeupdate/src/default/LICENSE
[PostgREST]: http://postgrest.com
