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
  delta = "\e[7m#{delta}\e[27m" if (Time.now - start) > 0.1
  puts "#{delta}: #{descr}"
end

def eq(a, b)
  _a = "#{a}".gsub /^/, "\e[33m> "
  _b = "#{b}".gsub /^/, "\e[36m< "
  raise "\"#{$test_description}\"\n#{_a}\e[39m#{_b}\e[39m" unless b === a
end

# Setup
$url = `pg_tmp -o "-c shared_preload_libraries=#{Dir.pwd}/safeupdate"`
psql = "psql -At -q #{$url}"
puts "using #{$url}"
q = %{
  CREATE TABLE employees (name varchar(30));
  INSERT INTO employees VALUES ('Eric'),('kevin'),('Bob');
}
out, err, status = Open3.capture3(psql, :stdin_data=>q)
eq err.empty?, true
eq out.empty?, true
eq status.success?, true

# Tests

try "Block unqualified DELETE" do
  q = %{
    DELETE FROM employees;
  }
  out, err, status = Open3.capture3(psql, :stdin_data=>q)
  eq err, "ERROR:  DELETE requires a WHERE clause\n"
  eq status.success?, true
  eq out.empty?, true
end

try "Block unqualified UPDATE" do
  q = %{
    UPDATE employees SET name='Kevin';
  }
  out, err, status = Open3.capture3(psql, :stdin_data=>q)
  eq err, "ERROR:  UPDATE requires a WHERE clause\n"
  eq status.success?, true
  eq out.empty?, true
end

try "Allow qualified DELETE" do
  q = %{
    BEGIN;
    DELETE FROM employees WHERE name='Bob' RETURNING name;
    ROLLBACK;
  }
  out, err, status = Open3.capture3(psql, :stdin_data=>q)
  eq err.empty?, true
  eq status.success?, true
  eq out, "Bob\n"
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
  eq err.empty?, true
  eq status.success?, true
  eq out, "Kevin\n"
end

puts "\n#{$tests} tests PASSED"

