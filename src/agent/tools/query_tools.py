from langchain_core.tools import tool
from snowflake.core import Root
from ..services.query_service import QueryService
from ..models.query_model import (
    ExecuteSQLQueryRequest,
    GetRelationshipListRequest,
    GetTableDetailRequest,
    GetTableListRequest,
)

def get_query_tools(root: Root, query_service: QueryService):
    @tool
    def execute_sql_query(request: ExecuteSQLQueryRequest) -> str:
        """Executes a SQL SELECT query against the retail database and returns the result."""
        response = query_service.execute_sql_query(root, request)
        return response.model_dump_json()

    @tool
    def get_table_list(request: GetTableListRequest) -> str:
        """Retrieves the list of table names defined in the semantic view."""
        response = query_service.get_table_list(root, request)
        return response.model_dump_json()

    @tool
    def get_table_detail(request: GetTableDetailRequest) -> str:
        """Retrieves detailed definition of a specific table including its description, columns, primary keys, and list of dimensions/facts."""
        response = query_service.get_table_detail(root, request)
        return response.model_dump_json()

    @tool
    def get_relationship_list(request: GetRelationshipListRequest) -> str:
        """Retrieves relationships between the specified table and other tables in the semantic view."""
        response = query_service.get_relationship_list(root, request)
        return response.model_dump_json()

    return [
        execute_sql_query,
        get_table_list, 
        get_table_detail, 
        get_relationship_list
    ]
