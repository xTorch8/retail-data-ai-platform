from ..clients.openai_client import get_openai_client
from ..guardrails.prompt_guardrail import PromptGuardrail
import json
from langchain_core.messages import AIMessage, HumanMessage, SystemMessage, ToolMessage
import logging
from ..models.api_model import APIResponseModel
from ..models.chat_model import ChatMessageRole, ChatRequest, ChatResponse
from ..models.guardrail_model import GuardrailRequest
from ..models.openai_model import GetOpenAIModelRequest, OpenAIModelTier
from ..models.query_model import ExecuteSQLQueryResponse
from ..prompts.agent_prompts import COMPLEXITY_ROUTER_PROMPT, UNIFIED_RETAIL_AGENT_PROMPT
from snowflake.core import Root
from ..services.query_service import QueryService
from ..tools.query_tools import get_query_tools

class ChatService:
    def __init__(self):
        self._prompt_guardrail = PromptGuardrail()
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

            #region Model Routing
            if request.model_tier is not None:
                model_tier = request.model_tier
            else:
                model_routing_request = GetOpenAIModelRequest(tier = OpenAIModelTier.SMALL)
                model_routing_client = get_openai_client(model_routing_request)
                
                messages = [
                    SystemMessage(content = COMPLEXITY_ROUTER_PROMPT)
                ]

                if request.history:
                    for msg in request.history[-4:]:
                        if msg.role == ChatMessageRole.USER:
                            messages.append(HumanMessage(content = msg.content))
                        else:
                            messages.append(AIMessage(content = msg.content))

                messages.append(HumanMessage(content = request.message))

                response = model_routing_client.invoke(messages)
                content = response.content.strip()
                
                logging.info(f"[INFO][chat_service.py][chat] Complexity classifier response: {content}")
                
                if "3" in content:
                    model_tier = OpenAIModelTier.LARGE
                elif "2" in content:
                    model_tier = OpenAIModelTier.MEDIUM
                else:
                    model_tier = OpenAIModelTier.SMALL
            #endregion

            #region Agent Orchestration
            model_request = GetOpenAIModelRequest(tier = model_tier)
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

            agent_messages = [
                SystemMessage(content = UNIFIED_RETAIL_AGENT_PROMPT)
            ]

            if request.history:
                for msg in request.history:
                    if msg.role == ChatMessageRole.USER:
                        agent_messages.append(HumanMessage(content = msg.content))
                    else:
                        agent_messages.append(AIMessage(content = msg.content))

            agent_messages.append(HumanMessage(content = request.message))

            sql_retry_count = 0
            max_iterations = 8
            for _ in range(max_iterations):
                ai_msg = llm_with_tools.invoke(agent_messages)
                agent_messages.append(ai_msg)

                if not ai_msg.tool_calls:
                    break

                for tool_call in ai_msg.tool_calls:
                    tool_name = tool_call["name"]
                    tool_args = tool_call["args"]

                    if tool_name == "execute_sql_query":
                        sql_retry_count += 1
                        if sql_retry_count > 3:
                            result = json.dumps({
                                "error": "SQL execution retry limit (3 attempts) has been exceeded. Please stop querying and inform the user.",
                                "is_success": False
                            })
                            agent_messages.append(
                                ToolMessage(content = str(result), tool_call_id = tool_call["id"])
                            )
                            continue

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
                        ToolMessage(content = str(result), tool_call_id = tool_call["id"])
                    )

            sql_query = None
            query_result = None

            for msg in reversed(agent_messages):
                if isinstance(msg, AIMessage) and msg.tool_calls:
                    for tc in msg.tool_calls:
                        if tc["name"] == "execute_sql_query":
                            args = tc["args"]
                            if "request" in args and isinstance(args["request"], dict):
                                sql_query = args["request"].get("query")
                            elif "query" in args:
                                sql_query = args.get("query")
                            
                            tc_id = tc["id"]
                            for m in agent_messages:
                                if isinstance(m, ToolMessage) and m.tool_call_id == tc_id:
                                    try:
                                        res_dict = json.loads(m.content)
                                        if res_dict.get("is_success") and "payload" in res_dict:
                                            payload = res_dict["payload"]
                                            query_result = ExecuteSQLQueryResponse(
                                                result = payload.get("result"),
                                                column_names = payload.get("column_names"),
                                                total_rows = payload.get("total_rows")
                                            )
                                    except Exception as e:
                                        logging.error(f"[ERROR][chat_service.py] Failed to parse SQL result from ToolMessage: {e}")
                                    break
                            break
                    if sql_query:
                        break
            #endregion
            
            return APIResponseModel[ChatResponse](
                message = "Chat response generated successfully",
                payload = ChatResponse(
                    message = agent_messages[-1].content,
                    sql = sql_query,
                    query_result = query_result
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
