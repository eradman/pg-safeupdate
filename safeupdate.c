#include "postgres.h"
#include "fmgr.h"
#include "utils/guc.h"
#include "parser/analyze.h"
#include "nodes/nodeFuncs.h"

PG_MODULE_MAGIC;

void _PG_init(void);
bool safeupdate_enabled;

static post_parse_analyze_hook_type prev_post_parse_analyze_hook = NULL;

#if (PG_VERSION_NUM >= 140000)
static void
delete_needs_where_check(ParseState *pstate, Query *query, JumbleState *jstate)
{
	ListCell *l;
	Query *ctequery;

	if (!safeupdate_enabled)
		return;

	if (query->hasModifyingCTE) {
		foreach(l, query->cteList)
		{
			CommonTableExpr *cte = (CommonTableExpr *) lfirst(l);
			ctequery = castNode(Query, cte->ctequery);
			delete_needs_where_check(pstate, ctequery, jstate);
		}
	}

	switch (query->commandType)
	{
	case CMD_DELETE:
		Assert(query->jointree != NULL);
		if (query->jointree->quals == NULL)
			ereport(ERROR,
			    (errcode(ERRCODE_CARDINALITY_VIOLATION),
			     errmsg("DELETE requires a WHERE clause")));
		break;
	case CMD_UPDATE:
		Assert(query->jointree != NULL);
		if (query->jointree->quals == NULL)
			ereport(ERROR,
			    (errcode(ERRCODE_CARDINALITY_VIOLATION),
			     errmsg("UPDATE requires a WHERE clause")));
	default:
		break;
	}
	if (prev_post_parse_analyze_hook != NULL)
		(*prev_post_parse_analyze_hook) (pstate, query, jstate);
}
#else
static void
delete_needs_where_check(ParseState *pstate, Query *query)
{
	ListCell *l;
	Query *ctequery;

	if (!safeupdate_enabled)
		return;

	if (query->hasModifyingCTE) {
		foreach(l, query->cteList)
		{
			CommonTableExpr *cte = (CommonTableExpr *) lfirst(l);
			ctequery = castNode(Query, cte->ctequery);
			delete_needs_where_check(pstate, ctequery);
		}
	}

	switch (query->commandType)
	{
	case CMD_DELETE:
		Assert(query->jointree != NULL);
		if (query->jointree->quals == NULL)
			ereport(ERROR,
			    (errcode(ERRCODE_CARDINALITY_VIOLATION),
			     errmsg("DELETE requires a WHERE clause")));
		break;
	case CMD_UPDATE:
		Assert(query->jointree != NULL);
		if (query->jointree->quals == NULL)
			ereport(ERROR,
			    (errcode(ERRCODE_CARDINALITY_VIOLATION),
			     errmsg("UPDATE requires a WHERE clause")));
	default:
		break;
	}
	if (prev_post_parse_analyze_hook != NULL)
		(*prev_post_parse_analyze_hook) (pstate, query);
}
#endif

void
_PG_init(void)
{
	DefineCustomBoolVariable("safeupdate.enabled",
	    "Enforce qualified updates",
	    "Prevent DML without a WHERE clause",
	    &safeupdate_enabled, 1, PGC_SUSET, 0, NULL, NULL, NULL);
	prev_post_parse_analyze_hook = post_parse_analyze_hook;
	post_parse_analyze_hook = delete_needs_where_check;
}
