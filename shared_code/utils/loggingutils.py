from typing import Any
from structlog.contextvars import bind_contextvars, unbind_contextvars, get_contextvars, reset_contextvars
import structlog
import logging

def log_context(logger_to_use: Any = None, level: int = logging.DEBUG) -> Any:

    def inner_wrapped(func) -> Any:
        def wrap(*args, **kwargs):
            param_dict = {
                "args": args, 
                "function": func.__name__
            }

            tokens = bind_contextvars(**param_dict, **kwargs)

            if logger_to_use:
                logger_to_use.log(level=level, event=f"Entering")

            result = func(*args, **kwargs)

            if logger_to_use:
                logger_to_use.log(level=level, event=f"Exiting")

            reset_contextvars(**tokens)

            return result

        return wrap
    return inner_wrapped