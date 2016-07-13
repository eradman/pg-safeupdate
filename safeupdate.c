#include "postgres.h"
#include "commands/explain.h"
#include "executor/instrument.h"
#include "utils/guc.h"

PG_MODULE_MAGIC;

/* Saved hook values in case of unload */
static ExecutorStart_hook_type prev_ExecutorStart = NULL;

void _PG_init(void);
void _PG_fini(void);

static void explain_ExecutorStart(QueryDesc *queryDesc, int eflags);

/*
 * Module load callback
 */
void
_PG_init(void)
{
	prev_ExecutorStart = ExecutorStart_hook;
	ExecutorStart_hook = explain_ExecutorStart;
}

/*
 * Module unload callback
 */
void
_PG_fini(void)
{
	ExecutorStart_hook = prev_ExecutorStart;
}

static void
explain_ExecutorStart(QueryDesc *queryDesc, int eflags)
{
	switch (queryDesc->operation)
	{
	case CMD_DELETE:
		if (strcasestr(queryDesc->sourceText, "WHERE ") == NULL)
			elog(ERROR, "DELETE requires a WHERE clause");
		break;
	case CMD_UPDATE:
		if (strcasestr(queryDesc->sourceText, "WHERE ") == NULL)
			elog(ERROR, "UPDATE requires a WHERE clause");
		break;
	default:
		break;
	}

	if (prev_ExecutorStart)
		prev_ExecutorStart(queryDesc, eflags);
	else
		standard_ExecutorStart(queryDesc, eflags);

}

