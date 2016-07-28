#include "postgres.h"
#include "fmgr.h"
#include "parser/analyze.h"

PG_MODULE_MAGIC;

void _PG_init(void);

static post_parse_analyze_hook_type prev_post_parse_analyze_hook = NULL;

static void
delete_needs_where_check(ParseState *pstate, Query *query)
{
	switch (query->commandType)
	{
	case CMD_DELETE:
	if (query->commandType == CMD_DELETE)
	{
		Assert(query->jointree != NULL);
		if (query->jointree->quals == NULL)
			ereport(ERROR,
			    (errcode(ERRCODE_CARDINALITY_VIOLATION),
			     errmsg("DELETE requires a WHERE clause"), NULL));
	}
		break;
	case CMD_UPDATE:
		Assert(query->jointree != NULL);
		if (query->jointree->quals == NULL)
			ereport(ERROR,
			    (errcode(ERRCODE_CARDINALITY_VIOLATION),
			     errmsg("UPDATE requires a WHERE clause"), NULL));
	default:
		break;
	}
	if (prev_post_parse_analyze_hook != NULL)
		(*prev_post_parse_analyze_hook) (pstate, query);
}

void
_PG_init(void)
{
	prev_post_parse_analyze_hook = post_parse_analyze_hook;
	post_parse_analyze_hook = delete_needs_where_check;
}
