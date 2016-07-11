MODULES = safeupdate
PG_CONFIG = pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)

test: ${MODULES}.so
	./test.sh

distclean:
	rm -f trace.out
