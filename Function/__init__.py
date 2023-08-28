import logging
import structlog
from structlog.stdlib import LoggerFactory

myLogger = logging.getLogger("function")
myLogger.addHandler(logging.StreamHandler())
myLogger.setLevel(logging.DEBUG)

structlog.configure(
    logger_factory=LoggerFactory(),
    processors=[
        structlog.contextvars.merge_contextvars,
        structlog.stdlib.filter_by_level,
        structlog.processors.StackInfoRenderer(),
        structlog.processors.format_exc_info,
        structlog.stdlib.add_log_level,
        structlog.stdlib.add_logger_name,
        structlog.processors.dict_tracebacks,
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.JSONRenderer()
    ]
)
