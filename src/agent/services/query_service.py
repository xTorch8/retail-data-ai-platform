from ..config import get_config
import logging
import yaml
from ..models.api_model import APIResponseModel
from ..models.query_model import (
    ExecuteSQLQueryRequest,
    ExecuteSQLQueryResponse,
    GetTableDetailRequest,
    GetTableDetailResponse,
    GetTableListRequest,
    GetTableListResponse,
    GetSemanticViewRequest, 
    GetSemanticViewResponse,
    GetRelationshipListRequest,
    GetRelationshipListResponse,
    SemanticViewModel,
)
from snowflake.core import Root
from typing import Any, Optional
import yaml

class QueryService:
    def __init__(self):
        self._config = get_config()
        self._semantic_view : Optional[SemanticViewModel] = None 

    def execute_sql_query(self, root: Root, request: ExecuteSQLQueryRequest) -> APIResponseModel[ExecuteSQLQueryResponse]:
        logging.info(f"[INFO][query_service.py][execute_sql_query] Executing SQL Query")
        try:
            result = root.session.sql(request.query).collect()
            column_names = []
            if result:
                column_names = list(result[0].as_dict().keys())

            return APIResponseModel[ExecuteSQLQueryResponse](
                message = "SQL Query executed successfully",
                payload = ExecuteSQLQueryResponse(
                    result = result,
                    column_names = column_names,
                    total_rows = len(result)
                )
            )        
        except Exception as e:
            logging.error(f"[ERROR][query_service.py][execute_sql_query] Error executing SQL Query: {e}")
            return APIResponseModel(
                error = str(e),
                is_success = False,
                status_code = 500,
                message = "Error executing SQL Query"
            )          

    def get_semantic_view(self, root: Root, request: GetSemanticViewRequest) -> APIResponseModel[GetSemanticViewResponse]:
        logging.info(f"[INFO][query_service.py][get_semantic_view] Retrieving semantic view: {request.view_name}")
        try:
            query = f"SELECT SYSTEM$READ_YAML_FROM_SEMANTIC_VIEW('{request.view_name}')"
            result = root.session.sql(query).collect()

            if not result or not result[0]:
                logging.warning(f"[WARN][query_service.py][get_semantic_view] No result returned for: {request.view_name}")
                return APIResponseModel(
                    error = f"Semantic view '{request.view_name}' not found",
                    is_success = False,
                    status_code = 404,
                    message = "Semantic view not found"
                )

            yaml_string = result[0][0]
            semantic_view_dict = yaml.safe_load(yaml_string)

            semantic_view = SemanticViewModel.model_validate(
                semantic_view_dict
            )

            self._semantic_view = semantic_view

            return APIResponseModel[GetSemanticViewResponse](
                message = "Semantic view retrieved successfully",
                payload = GetSemanticViewResponse(
                    view_definition = semantic_view
                )
            )
        except Exception as e:
            logging.error(f"[ERROR][query_service.py][get_semantic_view] Error retrieving semantic view: {e}")
            return APIResponseModel(
                error = str(e),
                is_success = False,
                status_code = 500,
                message = "Error retrieving semantic view"
            )

    def get_table_detail(self, root: Root, request: GetTableDetailRequest) -> APIResponseModel[GetTableDetailResponse]:
        logging.info(f"[INFO][query_service.py][get_table_detail] Retrieving table detail from semantic view.")
        try:
            if not self._semantic_view:
                semantic_view_request = GetSemanticViewRequest(
                    view_name = request.view_name
                )
                
                semantic_view_response = self.get_semantic_view(root, semantic_view_request)
                if not semantic_view_response.is_success:
                    raise semantic_view_response.error

            table_detail = [table for table in self._semantic_view.tables if table.name.lower() == request.table_name.lower()]  
            if len(table_detail) == 0:
                return APIResponseModel(
                    error = f"{request.table_name} is not found",
                    is_success = False,
                    status_code = 404,
                    message = "Error retrieving table detail from semantic view"
                )   

            table_detail = table_detail[0]
            return APIResponseModel[GetTableDetailResponse](
                message = "Table detail retrieved successfully",
                payload = GetTableDetailResponse(**table_detail.model_dump())
            )             
        except Exception as e:
            logging.error(f"[ERROR][query_service.py][get_table_detail] Error retrieving table detail from semantic view: {e}")
            return APIResponseModel(
                error = str(e),
                is_success = False,
                status_code = 500,
                message = "Error retrieving table detail from semantic view"
            )

    def get_table_list(self, root: Root, request: GetTableListRequest) -> APIResponseModel[GetTableListResponse]:
        logging.info(f"[INFO][query_service.py][get_table_list] Retrieving table list from semantic view.")
        try:
            if not self._semantic_view:
                semantic_view_request = GetSemanticViewRequest(
                    view_name = request.view_name
                )

                semantic_view_response = self.get_semantic_view(root, semantic_view_request)
                if not semantic_view_response.is_success:
                    raise semantic_view_response.error

            table_list = []
            for table in self._semantic_view.tables:
                table_list.append(table.name)

            return APIResponseModel[GetTableListResponse](
                message = "Table list retrieved successfully",
                payload = GetTableListResponse(
                    list = table_list
                )
            )
        except Exception as e:
            logging.error(f"[ERROR][query_service.py][get_table_list] Error retrieving table list from semantic view: {e}")
            return APIResponseModel(
                error = str(e),
                is_success = False,
                status_code = 500,
                message = "Error retrieving table list from semantic view"
            )

    def get_relationship_list(self, root: Root, request: GetRelationshipListRequest) -> APIResponseModel[GetRelationshipListResponse]:
        logging.info(f"[INFO][query_service.py][get_relationship_list] Retrieving relationsip list from semantic view.")
        try:
            if not self._semantic_view:
                semantic_view_request = GetSemanticViewRequest(
                    view_name = request.view_name
                )
                
                semantic_view_response = self.get_semantic_view(root, semantic_view_request)
                if not semantic_view_response.is_success:
                    raise semantic_view_response.error

            relationship_list = [
                relationship for relationship in self._semantic_view.relationships 
                    if relationship.left_table.lower() == request.table_name.lower() 
                        or relationship.right_table.lower() == request.table_name.lower()
            ]  

            return APIResponseModel[GetRelationshipListResponse](
                message = "Relationship list retrieved successfully",
                payload = GetRelationshipListResponse(
                    list = relationship_list
                )
            )             
        except Exception as e:
            logging.error(f"[ERROR][query_service.py][get_relationship_list] Error retrieving relationsip list from semantic view: {e}")
            return APIResponseModel(
                error = str(e),
                is_success = False,
                status_code = 500,
                message = "Error retrieving relationsip list from semantic view"
            )
