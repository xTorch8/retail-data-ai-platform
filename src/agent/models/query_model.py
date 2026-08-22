from pydantic import BaseModel
from typing import Any, List, Optional


class ExecuteSQLQueryRequest(BaseModel):
    query: str

class ExecuteSQLQueryResponse(BaseModel):
    result: List[Any]
    column_names: Optional[List[str]]
    total_rows: int

#region Semantic View
#region Tables
class SemanticView_BaseTable(BaseModel):
    database: str
    schema: str
    table: str

class SemanticView_PrimaryKey(BaseModel):
    columns: List[str]

class SemanticView_UniqueKeys(BaseModel):
    columns: List[str]

class SemanticView_Dimensions(BaseModel):
    name: str
    description: Optional[str] = None
    expr: Optional[str] = None
    data_type: Optional[str] = None
    access_modifier: Optional[str] = None
    sample_values: Optional[List[Any]] = None

class SemanticView_TimeDimensions(SemanticView_Dimensions):
    pass

class SemanticView_Facts(BaseModel):
    name: str
    description: Optional[str] = None
    expr: Optional[str] = None
    data_type: Optional[str] = None
    access_modifier: Optional[str] = None
    sample_values: Optional[List[Any]] = None

class SemanticView_Table(BaseModel):
    name: str
    description: Optional[str] = None
    base_table: SemanticView_BaseTable
    primary_key: Optional[SemanticView_PrimaryKey] = None
    unique_keys: Optional[List[SemanticView_UniqueKeys]] = None
    dimensions: Optional[List[SemanticView_Dimensions]] = None
    time_dimensions: Optional[List[SemanticView_TimeDimensions]] = None
    facts: Optional[List[SemanticView_Facts]] = None
#endregion

#region Relationships
class SemanticView_RelationshipColumns(BaseModel):
    left_column: str
    right_column: str

class SemanticView_Relationships(BaseModel):
    name: str
    left_table: str
    right_table: str
    relationship_columns: List[SemanticView_RelationshipColumns]
    join_type: str
#endregion

class SemanticViewModel(BaseModel):
    name: str
    tables: List[SemanticView_Table]
    relationships: Optional[List[SemanticView_Relationships]] = None

class GetSemanticViewRequest(BaseModel):
    view_name: Optional[str] = "RETAIL_ANALYTICS.GOLD.SV_RETAIL_ANALYTICS"

class GetSemanticViewResponse(BaseModel):
    view_definition: SemanticViewModel
#endregion

class GetTableDetailRequest(GetSemanticViewRequest):
    table_name: str

class GetTableDetailResponse(SemanticView_Table):
    pass

class GetTableListRequest(GetSemanticViewRequest):
    pass

class GetTableListResponse(BaseModel):
    list: List[str]

class GetRelationshipListRequest(GetTableDetailRequest):
    table_name: str

class GetRelationshipListResponse(BaseModel):
    list: List[SemanticView_Relationships]
