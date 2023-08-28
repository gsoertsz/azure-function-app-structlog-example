
from shared_code.utils import loggingutils
import structlog
import logging

log = structlog.get_logger("function")

def test_loggingcontext_annotation():
    logging_context_helper_fn1(str_arg="some string")

    assert True

@loggingutils.log_context(logger_to_use=log)
def logging_context_helper_fn1(str_arg: str) -> str:
    log.info(event="This is the first fn call")
    logging_context_helper_fn2(str_arg=f"{str_arg}, with some more data")
    log.info(event="After the nested call in the first scope")


@loggingutils.log_context(logger_to_use=log, level=logging.INFO)
def logging_context_helper_fn2(str_arg: str) -> str:
    log.info(event="This is the second function call")
    return str_arg