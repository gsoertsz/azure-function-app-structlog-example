import azure.functions as func

from .handlerfunction import Handler
from azure import functions as func
from azure.keyvault.secrets import SecretClient
from azure.identity import ManagedIdentityCredential
from datetime import datetime
import pytz
import os
import structlog

log = structlog.get_logger("function")

def main(req: func.HttpRequest, context: func.Context) -> func.HttpResponse:

    tz = pytz.timezone('Australia/Sydney')
    ingestion_datetime = datetime.now(tz)

    vault_url = os.environ["KEY_VAULT_URL"] if "KEY_VAULT_URL" in os.environ else None
    
    if not vault_url:
        raise Exception("No Key Vault URL")

    managed_identity_credential = ManagedIdentityCredential()
    secret_client = SecretClient(
        vault_url=vault_url,
        credential=managed_identity_credential
    )
    
    try:
        handler = Handler(
            secret_client=secret_client
        )

        return handler.handle(req, context, ingestion_datetime)
    except Exception as e:
        log.error(event="Unable to execute Handler: {}".format(e), exc_info=True, error_code = 1001)
        raise e

