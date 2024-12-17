RUBOCOP ?= rubocop
CLANG_FORMAT ?= clang-format
RELEASE = 1.5
MODULES = safeupdate
PG_CONFIG = pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
RUBY = ruby
include $(PGXS)

test: ${MODULES}.so
	@${RUBY} ./test.rb

distclean:
	rm -f trace.out

format:
	${RUBOCOP} -A
	${CLANG_FORMAT} -i *.c

.PHONY: distclean format test
