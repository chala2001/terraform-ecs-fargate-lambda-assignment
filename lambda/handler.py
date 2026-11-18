# Health checker: calls the API's /health endpoint and logs the result
import json
import os
import urllib.error
import urllib.request

TARGET_URL = os.environ["TARGET_URL"]  # Set by Terraform


def lambda_handler(event, context):
    try:
        with urllib.request.urlopen(TARGET_URL, timeout=5) as resp:
            body = resp.read().decode()
            print(json.dumps({"url": TARGET_URL, "healthy": True, "status": resp.status, "body": body}))
            return {"healthy": True, "status": resp.status}
    except (urllib.error.URLError, TimeoutError) as err:
        print(json.dumps({"url": TARGET_URL, "healthy": False, "error": str(err)}))
        raise  # Mark the run as FAILED, so it shows in Lambda's Errors metric