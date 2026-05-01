import requests
from tapipy.tapis import Tapis

# 1. Auth
TENANT_URL = "https://tacc.tapis.io"
USERNAME = "your_username"
PASSWORD = "your_password"

t = Tapis(base_url=TENANT_URL, username=USERNAME, password=PASSWORD)
t.get_tokens()
token = t.access_token.access_token

# 2. System Definition (V3 Strict Schema)
system_def = {
    "id": f"stampede3.exec.{USERNAME}",
    "description": "Stampede3 Execution System",
    "systemType": "LINUX",
    "host": "stampede3.tacc.utexas.edu",
    "port": 22,
    "defaultAuthnMethod": "PASSWORD",
    "canExec": True,
    "batchScheduler": "SLURM",
    "rootDir": "/",
    # Simplified jobRuntimes to match the Tapis V3 Enum requirements
    "jobRuntimes": [{"runtimeType": "SINGULARITY"}], 
    "jobWorkingDir": "/scratch/01234/raiyan/tapis/jobs", 
    "effectiveUserId": USERNAME
}

headers = {
    "X-Tapis-Token": token,
    "Content-Type": "application/json"
}

print(f"Registering System: {system_def['id']}...")
response = requests.post(
    f"{TENANT_URL}/v3/systems", 
    headers=headers, 
    json=system_def
)

if response.status_code in [200, 201]:
    print("Success! System 'stampede3.exec.raiyan' is now registered.")
else:
    print(f"Failed: {response.status_code}")
    print(f"Message: {response.text}")