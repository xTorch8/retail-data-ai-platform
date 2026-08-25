import logging
from ..models.guardrail_model import GuardrailRequest, GuardrailResponse
import sqlglot
from sqlglot import exp

class SQLGuardrail:
    def __init__(self):
        self._allowed_statement_types = (
            exp.Select,
            exp.With,
            exp.Show,
            exp.Describe,
        )

    def validate(self, request: GuardrailRequest) -> GuardrailResponse:
        logging.info(f"[INFO][sql_guardrail.py][validate] Validate SQL query safety")
        try:    
            query = request.input.strip()
            statements = sqlglot.parse(query, dialect = "snowflake")
            if not statements:
                logging.error(f"[ERROR][sql_guardrail.py][validate] No SQL statement found")
                return GuardrailResponse(
                    is_safe = False,
                    error = "No SQL statement found"
                )

            for statement in statements:
                if not isinstance(statement, self._allowed_statement_types):
                    statement_type = type(statement).__name__.upper()
                    logging.error(f"[ERROR][sql_guardrail.py][validate] Found blcoked SQL statement type: {statement_type}")
                    return GuardrailResponse(
                        is_safe = False,
                        error = f"{statement_type} is not allowed"
                    )

            return GuardrailResponse(
                is_safe = True
            )
        except Exception as e:
            logging.error(f"[INFO][sql_guardrail.py][validate] Error in validating SQL query safety: {e}")
            return GuardrailResponse(
                is_safe = False,
                error = "System error"
            )
        