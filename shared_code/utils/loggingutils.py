from typing import Any
from structlog.contextvars import bind_contextvars, unbind_contextvars, get_contextvars, reset_contextvars
import structlog

def log_context(logger_to_use: Any = None) -> Any:

    def inner_wrapped(func) -> Any:
        def wrap(*args, **kwargs):
            context_vars = get_contextvars()

            current_scope = context_vars["scope"] if "scope" in context_vars else None
            target_scope = f"{current_scope}.{func.__name__}" if current_scope else func.__name__

            param_dict = {
                "scope": target_scope,
                "args": args, 
                "function": func.__name__
            }

            tokens = bind_contextvars(**param_dict, **kwargs)

            if logger_to_use:
                logger_to_use.debug(event=f"Entering")

            result = func(*args, **kwargs)

            if logger_to_use:
                logger_to_use.debug(event=f"Exiting")

            reset_contextvars(**tokens)

            return result

        return wrap
    return inner_wrapped