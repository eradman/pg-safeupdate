#!/usr/bin/env ruby

require 'open3'

# Test Utilities
@tests = 0
@test_description = 0

def try(descr)
  start = Time.now
  @tests += 1
  @test_description = descr
  yield
  delta = format('%.3f', Time.now - start)
  # highlight slow tests
  delta = "\e[7m#{delta}\e[27m" if (Time.now - start) > 0.03
  puts "#{delta}: #{descr}"
end

def eq(result, expected)
  a = result.to_s.gsub(/^/, '> ')
  b = expected.to_s.gsub(/^/, '< ')
  raise "\"#{@test_description}\"\n#{a}\n#{b}" unless result == expected
end

# Setup
@url = `pg_tmp -o "-c shared_preload_libraries=pg_stat_statements,#{Dir.pwd}/safeupdate"`
psql = "psql --no-psqlrc -At -q #{@url}"
puts "using #{@url}"
q = %{
    CREATE EXTENSION pg_stat_statements;
    CREATE TABLE employees (name varchar(30));
    INSERT INTO employees VALUES ('Eric'),('kevin'),('Robert');
}
out, err, status = Open3.capture3(psql, :stdin_data => q)
eq err, ''
eq out, ''
eq status.success?, true

# Tests

try 'Block unqualified DELETE' do
  q = %(
        DELETE FROM employees;
    )
  out, err, status = Open3.capture3(psql, :stdin_data => q)
  eq err, "ERROR:  DELETE requires a WHERE clause\n"
  eq status.success?, true
  eq out, ''
end

try 'Block unqualified UPDATE' do
  q = %(
        UPDATE employees SET name='Kevin';
    )
  out, err, status = Open3.capture3(psql, :stdin_data => q)
  eq err, "ERROR:  UPDATE requires a WHERE clause\n"
  eq out, ''
  eq status.success?, true
end

try 'Allow qualified DELETE' do
  q = %(
        BEGIN;
        DELETE FROM employees WHERE name='Robert' RETURNING name;
        ROLLBACK;
    )
  out, err, status = Open3.capture3(psql, :stdin_data => q)
  eq err.empty?, true
  eq out, "Robert\n"
  eq status.success?, true
end

try 'Allow qualified UPDATE' do
  q = %(
        BEGIN;
        UPDATE employees SET name='Kevin'
        WHERE name='kevin'
        RETURNING name;
        ROLLBACK;
    )
  out, err, status = Open3.capture3(psql, :stdin_data => q)
  eq err, ''
  eq out, "Kevin\n"
  eq status.success?, true
end

try 'Block modifying CTE with unqualified UPDATE' do
  q = %{
        WITH updates AS (
            UPDATE employees SET name='Kevin'
            RETURNING name
        )
        SELECT *
        FROM updates;
    }
  out, err, status = Open3.capture3(psql, :stdin_data => q)
  eq err, "ERROR:  UPDATE requires a WHERE clause\n"
  eq out, ''
  eq status.success?, true
end

try 'Allow modifying CTE with qualified UPDATE' do
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
  out, err, status = Open3.capture3(psql, :stdin_data => q)
  eq err, ''
  eq out, "Kevin\n"
  eq status.success?, true
end

try 'Disable safeupdate' do
  q = %(
        SHOW safeupdate.enabled;
        SET safeupdate.enabled=0;
        BEGIN;
        DELETE FROM employees;
        ROLLBACK;
        SET safeupdate.enabled=1;
    )
  out, err, status = Open3.capture3(psql, :stdin_data => q)
  eq err, ''
  eq out, "on\n"
  eq status.success?, true
end

try 'Call previous hook when disabled' do
  # Even when disabled, safeupdate must call the previous
  # post_parse_analyze_hook. Witness: pg_stat_statements (loaded first)
  # normalizes constants in that hook -- if the chain is dropped while
  # disabled, the statement is recorded un-normalized (no '$n' params).
  q = %(
        SELECT 1 FROM pg_stat_statements_reset() WHERE false;
        SET safeupdate.enabled=0;
        SELECT 1 AS safeupdate_chain_probe WHERE false;
        SET safeupdate.enabled=1;
        SELECT CASE
                 WHEN count(*) = 0 THEN 'no pg_stat_statements entry'
                 WHEN bool_or(query LIKE '%$%') THEN 'ok'
                 ELSE 'un-normalized: previous hook was not called'
               END
        FROM pg_stat_statements
        WHERE query LIKE '%safeupdate_chain_probe%';
    )
  out, err, status = Open3.capture3(psql, :stdin_data => q)
  eq err, ''
  eq out, "ok\n"
  eq status.success?, true
end

puts "\n#{@tests} tests PASSED"
