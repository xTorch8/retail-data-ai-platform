from ..dependencies.snowflake_dependency import get_snowflake_root_dependency
from fastapi import APIRouter, Depends
from ..models.query_model import (
    ExecuteSQLQueryRequest,
    GetSemanticViewRequest, 
    GetTableDetailRequest,
    GetTableListRequest,
    GetRelationshipListRequest
)
from ..services.query_service import QueryService
from snowflake.core import Root

router = APIRouter(
    prefix = "/api/query",
    tags = ["query"]
)

query_service = QueryService()

@router.post("/execute")
async def execute_sql_query(request: ExecuteSQLQueryRequest, root: Root = Depends(get_snowflake_root_dependency)):
    return query_service.execute_sql_query(root, request)

@router.get("/semantic-view")
async def get_semantic_view(view_name: str, root: Root = Depends(get_snowflake_root_dependency)):
    request = GetSemanticViewRequest(
        view_name = view_name
    )

    return query_service.get_semantic_view(root, request)

@router.get("/semantic-view/tables/detail")
async def get_table_detail(view_name: str, table_name: str, root: Root = Depends(get_snowflake_root_dependency)):
    request = GetTableDetailRequest(
        view_name = view_name,
        table_name = table_name
    ) 

    return query_service.get_table_detail(root, request)

@router.get("/semantic-view/tables")
async def get_table_list(view_name: str, root: Root = Depends(get_snowflake_root_dependency)):
    request = GetTableListRequest(
        view_name = view_name
    )

    return query_service.get_table_list(root, request)

@router.get("/semantic-view/relationships")
async def get_relationship_list(view_name: str, table_name: str, root: Root = Depends(get_snowflake_root_dependency)):
    request = GetRelationshipListRequest(
        view_name = view_name,
        table_name = table_name
    )

    return query_service.get_relationship_list(root, request)