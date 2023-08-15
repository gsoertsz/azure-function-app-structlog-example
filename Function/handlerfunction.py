from azure import functions as func
from azure.keyvault.secrets import SecretClient
from attrs import define
from datetime import datetime
from shared_code.utils import responseutils as responses
import structlog
import os
import requests
import json
from structlog.contextvars import bind_contextvars
from shared_code.utils import loggingutils

log = structlog.get_logger("function")

@define
class Handler(object):
    secret_client: SecretClient

    @loggingutils.log_context(logger_to_use=log)
    def handle(self, request: func.HttpRequest, context: func.Context, ingestion_datetime: datetime) -> func.HttpResponse:
    
        bind_contextvars(**request.headers)
        bind_contextvars(**vars(context))

        log.info(event="Handling request")

        weather_api_key_secret_name = os.environ["WEATHER_API_KEY_NAME"] if "WEATHER_API_KEY_NAME" in os.environ else None

        if not weather_api_key_secret_name:
            raise Exception("No API Key Secret Name")

        weather_api_key_secret = self.secret_client.get_secret(name=weather_api_key_secret_name)

        request_dict = json.loads(request.get_body())
        request_city = request_dict["city"]
        request_country_code = request_dict["country_code"]
        request_state_code = request_dict["state"]

        r_weather = self.city_request_to_weather(
            appid=weather_api_key_secret.value,
            city=request_city,
            state=request_state_code,
            country=request_country_code
        )

        log.info(event="Successfully processed")

        return func.HttpResponse(body=bytes(r_weather.text, "utf-8"), status_code=200)
    
    @loggingutils.log_context(logger_to_use=log)
    def city_request_to_weather(self, appid: str, city: str, state: str, country: str) -> requests.Response:
        query = f"{city},{state},{country}"
        
        geocode_param_dict = {
            "q": query,
            "limit": 1,
            "appid": appid
        }

        r_geocode = requests.get("http://api.openweathermap.org/geo/1.0/direct", params=geocode_param_dict)
        response_dict = json.loads(r_geocode.text)
        lat = response_dict[0]["lat"]
        lon = response_dict[0]["lon"]

        log.debug(event=f"Received geocoding response |{r_geocode.text}|")

        weather_req_params = {
            "lat": lat,
            "lon": lon,
            "units": "metric",
            "appid": appid
        }

        r_weather = requests.get("https://api.openweathermap.org/data/2.5/weather", params=weather_req_params)

        return r_weather
    