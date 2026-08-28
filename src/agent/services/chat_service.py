from ..clients.openai_client import get_openai_client
from ..guardrails.prompt_guardrail import PromptGuardrail
from ..guardrails.sql_guardrail import SQLGuardrail
import json
from langchain_core.messages import SystemMessage, HumanMessage, ToolMessage
import logging
from ..models.api_model import APIResponseModel
from ..models.chat_model import ChatRequest, ChatResponse
from ..models.guardrail_model import GuardrailRequest
from ..models.openai_model import GetOpenAIModelRequest, OpenAIModelTier
from ..models.query_model import ExecuteSQLQueryRequest
from ..services.query_service import QueryService
from ..prompts.agent_prompts import TEXT_TO_SQL_PROMPT, ANALYTICAL_AGENT_PROMPT
from snowflake.core import Root
from ..tools.query_tools import get_query_tools

class ChatService:
    def __init__(self):
        self._prompt_guardrail = PromptGuardrail()
        self._sql_guardrail = SQLGuardrail()
        self._query_service = QueryService()

    def chat(self, root: Root, request: ChatRequest) -> APIResponseModel[ChatResponse]:
        logging.info(f"[INFO][chat_service.py][chat] Responding to chat")
        try:
            validate_prompt_request = GuardrailRequest(
                input = request.message
            )

            guardrail_result = self._prompt_guardrail.validate(validate_prompt_request)
            if not guardrail_result.is_safe:
                logging.warning(f"[WARNING][chat_service.py][chat] Prompt rejected by guardrail: {guardrail_result.error}")
                return APIResponseModel(
                    error = f"Prompt rejected by guardrail: {guardrail_result.error}",
                    is_success = False,
                    status_code = 400,
                    message = "Input validation failed"
                )

            model_request = GetOpenAIModelRequest(tier = OpenAIModelTier.SMALL)
            client = get_openai_client(model_request)
            if not client:
                logging.error("[ERROR][chat_service.py][chat] Failed to create OpenAI client")
                return APIResponseModel(
                    error = "OpenAI client initialization failed",
                    is_success = False,
                    status_code = 500,
                    message = "Error responding to chat"
                )
            
            tools = get_query_tools(root, self._query_service)
            llm_with_tools = client.bind_tools(tools)

            retry_count = 0
            max_retries = 3
            sql_query = None
            execution_result = None

            agent_messages = [
                SystemMessage(content = TEXT_TO_SQL_PROMPT),
                HumanMessage(content = request.message)
            ]

            while retry_count < max_retries:
                for _ in range(5):
                    ai_msg = llm_with_tools.invoke(agent_messages)
                    agent_messages.append(ai_msg)

                    if not ai_msg.tool_calls:
                        break

                    for tool_call in ai_msg.tool_calls:
                        tool_name = tool_call["name"]
                        tool_args = tool_call["args"]

                        tool_to_run = next((t for t in tools if t.name == tool_name), None)
                        if tool_to_run:
                            try:
                                result = tool_to_run.invoke(tool_args)
                            except Exception as e:
                                result = json.dumps({
                                    "error": f"Error running tool {tool_name}: {str(e)}",
                                    "is_success": False
                                })
                        else:
                            result = json.dumps({
                                "error": f"Tool {tool_name} not found.",
                                "is_success": False
                            })

                        agent_messages.append(
                            ToolMessage(content = str(result), tool_call_id  =tool_call["id"])
                        )

                generated_sql = agent_messages[-1].content.strip()
                if generated_sql.startswith("```"):
                    lines = generated_sql.splitlines()
                    if lines[0].startswith("```"):
                        lines = lines[1:]
                    if lines and lines[-1].startswith("```"):
                        lines = lines[:-1]
                    generated_sql = "\n".join(lines).strip()

                sql_guardrail_req = GuardrailRequest(input = generated_sql)
                sql_guardrail_res = self._sql_guardrail.validate(sql_guardrail_req)

                if not sql_guardrail_res.is_safe:
                    logging.warning(f"[WARNING][chat_service.py][chat] SQL Guardrail rejected query: {sql_guardrail_res.error}")
                    agent_messages.append(
                        HumanMessage(content=(
                            f"Your previous attempt generated an UNSAFE SQL query:\n"
                            f"Query: {generated_sql}\n"
                            f"Reason: {sql_guardrail_res.error}\n"
                            f"Please generate a safe, read-only SELECT query instead."
                        ))
                    )
                    retry_count += 1
                    continue

                exec_req = ExecuteSQLQueryRequest(query = generated_sql)
                exec_res = self._query_service.execute_sql_query(root, exec_req)

                if not exec_res.is_success:
                    logging.warning(f"[WARNING][chat_service.py][chat] SQL Query execution failed: {exec_res.error}")
                    agent_messages.append(
                        HumanMessage(content=(
                            f"Your previous attempt generated a SQL query that failed to execute:\n"
                            f"Query: {generated_sql}\n"
                            f"Error: {exec_res.error}\n"
                            f"Please correct the query and output the updated version."
                        ))
                    )
                    retry_count += 1
                    continue

                sql_query = generated_sql
                execution_result = exec_res.payload
                break

            if not sql_query or not execution_result:
                logging.error("[ERROR][chat_service.py][chat] Failed to generate a valid/safe SQL query within retries")
                return APIResponseModel(
                    error = "Failed to generate a valid and safe SQL query within maximum retries.",
                    is_success = False,
                    status_code = 500,
                    message = "Error responding to chat"
                )

            analytical_messages = [
                SystemMessage(content = ANALYTICAL_AGENT_PROMPT),
                HumanMessage(
                    content=(
                        f"User Question: {request.message}\n\n"
                        f"Executed SQL Query:\n{sql_query}\n\n"
                        f"SQL Execution Results:\n{execution_result.model_dump_json()}"
                    )
                )
            ]
            
            analytical_response = client.invoke(analytical_messages)

            return APIResponseModel[ChatResponse](
                message = "Chat response generated successfully",
                payload = ChatResponse(
                    message = analytical_response.content,
                    sql = sql_query,
                    query_result = execution_result.result
                )
            )

        except Exception as e:
            logging.error(f"[ERROR][chat_service.py][chat] Error responding to chat: {e}")
            return APIResponseModel(
                error = str(e),
                is_success = False,
                status_code = 500,
                message = "Error responding to chat"
            )
