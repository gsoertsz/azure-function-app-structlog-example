
import json
import azure.functions as func

def httpSuccessResponse(message: str) -> func.HttpResponse:
    body = {
        "message": message    
    }

    return func.HttpResponse(body=json.dumps(body), status_code=200)