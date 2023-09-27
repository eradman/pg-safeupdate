RELEASE = 1.5
MODULES = safeupdate
PG_CONFIG = pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
RUBY = ruby
include $(PGXS)

all: versioncheck

test: ${MODULES}.so
	@${RUBY} ./test.rb

distclean:
	rm -f trace.out

versioncheck:
	@head -n3 NEWS | egrep -q "^= Next Release: ${RELEASE}|^== ${RELEASE}: "

