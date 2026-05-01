from tapipy.tapis import Tapis

t = Tapis(base_url="https://tacc.tapis.io", username="your_username", password="your password")
t.get_tokens()

apps = t.apps.getApps()
for app in apps:
    exec_system = getattr(getattr(app, "jobAttributes", None), "execSystemId", getattr(app, "execSystemId", "N/A"))
    print(f"ID: {app.id} | Version: {app.version} | ExecSystem: {exec_system}")

t = Tapis(base_url="https://tacc.tapis.io", username="your_username", password="your password")
t.get_tokens()

# 2. Corrected App Definition
# Note: In Tapis V3, "jobAttributes" is the container for Slurm-specific defaults
app_def = {
    "id": "stampede3-generic-runner",
    "version": "1.0.0",
    "description": "Generic runner for Slurm jobs on Stampede3",
    "containerImage": "docker://ubuntu:latest",
    "jobType": "FORK",
    "jobAttributes": {
        "execSystemId": "stampede3.exec.raiyan",
        "maxMinutes": 30,
        "nodeCount": 1,
        "coresPerNode": 1,
        "archiveOnAppError": False,
        "archiveMode": "SKIP_ON_FAIL",
        "parameterSet": {
            "appArgs": [],
            "envVariables": [],
        }
    }
}

try:
    t.apps.createAppVersion(**app_def)
    print("App registered successfully!")
except Exception as e:
    message = str(e)
    # If version already exists, update in place
    if (
        "APPAPI_APP_VERSION_EXISTS" in message
        or "APPAPI_APP_EXISTS" in message
        or "409" in message
    ):
        t.apps.putApp(appId=app_def["id"], appVersion=app_def["version"], **app_def)
        print("App version already exists, updated instead.")
    else:
        print(f"Error: {e}")