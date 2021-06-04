#!/usr/bin/env ruby

require "open3"

# Test Utilities
$tests = 0
$test_description = 0

def try(descr)
    start = Time.now
    $tests += 1
    $test_description = descr
    yield
    delta = "%.3f" % (Time.now - start)
    # highlight slow tests
    delta = "\e[7m#{delta}\e[27m" if (Time.now - start) > 0.03
    puts "#{delta}: #{descr}"
end

def eq(a, b)
    _a = "#{a}".gsub /^/, "\e[33m> "
    _b = "#{b}".gsub /^/, "\e[36m< "
    raise "\"#{$test_description}\"\n#{_a}\e[39m#{_b}\e[39m" unless b === a
end

# Setup
$url = `pg_tmp -o "-c shared_preload_libraries=#{Dir.pwd}/safeupdate"`
psql = "psql --no-psqlrc -At -q #{$url}"
puts "using #{$url}"
q = %{
    CREATE TABLE employees (name varchar(30));
    INSERT INTO employees VALUES ('Eric'),('kevin'),('Robert');
}
out, err, status = Open3.capture3(psql, :stdin_data=>q)
eq err, ""
eq out, ""
eq status.success?, true

# Tests

try "Block unqualified DELETE" do
    q = %{
        DELETE FROM employees;
    }
    out, err, status = Open3.capture3(psql, :stdin_data=>q)
    eq err, "ERROR:  DELETE requires a WHERE clause\n"
    eq status.success?, true
    eq out, ""
end

try "Block unqualified UPDATE" do
    q = %{
        UPDATE employees SET name='Kevin';
    }
    out, err, status = Open3.capture3(psql, :stdin_data=>q)
    eq err, "ERROR:  UPDATE requires a WHERE clause\n"
    eq out, ""
    eq status.success?, true
end

try "Allow qualified DELETE" do
    q = %{
        BEGIN;
        DELETE FROM employees WHERE name='Robert' RETURNING name;
        ROLLBACK;
    }
    out, err, status = Open3.capture3(psql, :stdin_data=>q)
    eq err.empty?, true
    eq out, "Robert\n"
    eq status.success?, true
end

try "Allow qualified UPDATE" do
    q = %{
        BEGIN;
        UPDATE employees SET name='Kevin'
        WHERE name='kevin'
        RETURNING name;
        ROLLBACK;
    }
    out, err, status = Open3.capture3(psql, :stdin_data=>q)
    eq err, ""
    eq out, "Kevin\n"
    eq status.success?, true
end

try "Block modifying CTE with unqualified UPDATE" do
    q = %{
        WITH updates AS (
            UPDATE employees SET name='Kevin'
            RETURNING name
        )
        SELECT *
        FROM updates;
    }
    out, err, status = Open3.capture3(psql, :stdin_data=>q)
    eq err, "ERROR:  UPDATE requires a WHERE clause\n"
    eq out, ""
    eq status.success?, true
end

try "Allow modifying CTE with qualified UPDATE" do
    q = %{
        BEGIN;
        WITH updates AS (
            UPDATE employees SET name='Kevin'
            WHERE name='kevin'
            RETURNING name
        )
        SELECT *
        FROM updates;
        ROLLBACK;
    }
    out, err, status = Open3.capture3(psql, :stdin_data=>q)
    eq err, ""
    eq out, "Kevin\n"
    eq status.success?, true
end

try "Disable safeupdate" do
    q = %{
        SHOW safeupdate.enabled;
        SET safeupdate.enabled=0;
        BEGIN;
        DELETE FROM employees;
        ROLLBACK;
        SET safeupdate.enabled=1;
    }
    out, err, status = Open3.capture3(psql, :stdin_data=>q)
    eq err, ""
    eq out, "on\n"
    eq status.success?, true
end

puts "\n#{$tests} tests PASSED"

