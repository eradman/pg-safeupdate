Require SQL Where Clause
========================

`safeupdate` is a simple extension to PostgreSQL that requires criteria for
`UPDATE` and `DELETE`.

Installation
------------

    gmake
    gmake install

Activate per-session by running

    load 'safeupdate';

Make this manditory for all databases and connections by adding the following to
`postgresql.conf`

    shared_preload_libraries=safeupdate

Examples
--------

Set a column value for all the records in a table

    => UPDATE fan SET speed=90 WHERE 1=1;

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
[pg_tmp]: http://ephemeralpg.org
