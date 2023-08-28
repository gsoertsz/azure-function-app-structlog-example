# Function app structured logging example


This repo demonstrates some cool features and uses for [structlog](https://www.structlog.org/en/stable/index.html), in the context of an Azure Function App. It contains everything needed to deploy and run the function app, along with an alert configured against the log analytics workspace as part of the function apps diagnostic setting.

This function app uses the [Open Weather API](https://openweathermap.org/) to provide weather details for a suburb/city/state input provided as a request body. 

## Deployment

Before you can deploy the function app you need the following:

1. an API key from [Open Weather](https://openweathermap.org/)
2. A resource group in an Azure subscription that you own
3. A service connection with Owner permissions on the subscription or the resource group outlined in (2).
4. The name of the secret used to store the api key (use `WEATHER-API-KEY`)

To deploy the function app, import the `azure-pipelines.yml` into Azure DevOps, and execute it with the parameters from the above steps

## Contributing

Use a python environment to manage this repo's dependencies and build activities. The `Makefile` assumes that a `python` executable is available and that all developer dependencies can be installed.

```
%> pyenv virtualenv 3.9.7 fn-app-env
%> pyenv activate fn-app-env
%> pip install -U pip
%> make install <--- installs developer dependencies 
%> make clean test build <--- build / test
```

I recommend forking this repo if you wish to contribute or use the code. This repo serves as an example for a blog regarding Azure Log Analytics Observability so it will likely not be open to contribution or modification.

## Executing the function app to generate logs

Once invoked, the function app loads the Open Weather API key from a key vault, then:

1. Resolves the location info (city/suburb/country) to lat,lng (geocode)
2. Uses the geocoded location to request current weather information
3. returns the response to the user.

The repo demonstrates using structlog to non-invasively track function entry/exit events with context, and the example uses the instrumentation to track the time it takes to interact with the Open Weather API for the purposes of acquiring the weather.

The purpose of this repo is to trigger the configured alert, so use the Azure Portal to find the Function URL. You can then put the URL in postman or use `curl` to submit a request with the body as follows:

```json
{
    "country_code": "au",
    "state": "vic",
    "city": "brunswick"
}
```

You should receive a response as per the below:

```json
{
    "coord": {
        "lon":144.9613,
        "lat":-37.7665
    },
    "weather": [
        {
            "id":801,
            "main":"Clouds",
            "description":"few clouds",
            "icon":"02d"
        }
    ],
    "base":"stations",
    "main": {
        "temp":16.6,
        "feels_like":16.2,
        "temp_min":13.3,
        "temp_max":20.08,
        "pressure":1022,
        "humidity":72
    },
    "visibility":10000,
    "wind": {
        "speed":2.57,"deg":160
    },
    "clouds": {
        "all":20
    },
    "dt":1693193040,
    "sys": {
        "type":2,
        "id":2041285,
        "country":"AU",
        "sunrise":1693169331,
        "sunset":1693209292
    },
    "timezone":36000,
    "id":2173741,
    "name":"Brunswick",
    "cod":200
}
```

Once you have submitted the request, after a short period a bunch of log entries should appear in the configured log analytics workspace for the `FunctionAppLogs` table. 

What you should see is a series of json formatted log messages. The alert should also fire as it is triggered when the average of 90% of the requests is below 500ms. 

