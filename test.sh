#!/bin/sh
set -e

url=$(pg_tmp -o "-c shared_preload_libraries=$PWD/safeupdate")
echo "Using $url"
psql -a $url <<SQL > trace.out 2>&1
-- Setup
CREATE TABLE employees (name varchar(30));
INSERT INTO employees VALUES ('Eric'),('kevin'),('Bob');
-- Should fail
DELETE FROM employees;
UPDATE employees SET name='kevin';
-- Should pass
DELETE FROM employees WHERE name='Bob';
UPDATE employees SET name='Kevin' WHERE
  name='kevin';
UPDATE employees SET name='Kevin'
WHERE name='kevin';
SELECT * FROM employees;
SQL
diff {expected,trace}.out
echo "PASS"
