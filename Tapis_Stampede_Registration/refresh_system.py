import requests
from tapipy.tapis import Tapis

# 1. Configuration
TENANT_URL = "https://tacc.tapis.io"
USERNAME = "your_username"
PASSWORD = "your_password"
t = Tapis(base_url=TENANT_URL, username=USERNAME, password=PASSWORD)
t.get_tokens()
token = t.access_token.access_token

system_def = {
    "id": "stampede3.exec.raiyan",
    "description": "Stampede3 Execution System",
    "systemType": "LINUX",
    "host": "stampede3.tacc.utexas.edu",
    "port": 22,
    "defaultAuthnMethod": "PASSWORD",
    "canExec": True,
    "batchScheduler": "SLURM",
    "rootDir": "/",
    "jobRuntimes": [{"runtimeType": "SINGULARITY"}],
    "jobWorkingDir": "/scratch/11412/araiyan/tapis/jobs", 
    "effectiveUserId": USERNAME,
    "batchLogicalQueues": [
        {
            "name": "development",
            "hpcQueueName": "development",
            "maxJobs": 5,
            "maxJobsPerUser": 2,
            "maxNodeCount": 1,
            "maxCoresPerNode": 1,
            "maxMinutes": 30
        }
    ],
    # Adding this to see if the App service picks up the hint
    "notes": {
        "canBatch": True,
        "isBatch": True
    }
}

headers = {"X-Tapis-Token": token, "Content-Type": "application/json"}

print(f"Refreshing system with 'notes' metadata...")
response = requests.put(f"{TENANT_URL}/v3/systems/{system_def['id']}", headers=headers, json=system_def)

if response.status_code in [200, 201, 204]:
    print("Success! System refreshed.")
else:
    print(f"Failed: {response.text}")