import os
import sys
import tarfile
import tempfile
from pathlib import Path
from tapipy.tapis import Tapis


def required_env(name: str) -> str:
    value = os.environ.get(name, "").strip()
    if not value:
        raise ValueError(f"Missing required environment variable: {name}")
    return value


def main() -> int:
    tenant_url = os.environ.get("TAPIS_BASE_URL", "https://tacc.tapis.io")
    username = required_env("TAPIS_USERNAME")
    password = required_env("TAPIS_PASSWORD")

    app_id = os.environ.get("TAPIS_APP_ID", "fibonacci-fork-app")
    app_version = os.environ.get("TAPIS_APP_VERSION", "1.0.1")
    exec_system_id = os.environ.get("TAPIS_EXEC_SYSTEM_ID", "stampede3.exec.raiyan")
    app_description = os.environ.get(
        "TAPIS_APP_DESCRIPTION",
        "Fibonacci calculation via Fork on Stampede3 using uploaded ZIP bundle",
    )

    script_dir = Path(__file__).resolve().parent
    runner_script_env = os.environ.get("TAPIS_RUNNER_SCRIPT", "tapis_run_fib.sh")
    runner_script = Path(runner_script_env)
    
    # If it's a relative path, resolve it relative to script directory
    if not runner_script.is_absolute():
        runner_script = script_dir / runner_script
    
    runner_script = runner_script.resolve()
    
    if not runner_script.exists():
        raise FileNotFoundError(f"Runner script not found: {runner_script}")

    remote_bundle_dir = os.environ.get(
        "TAPIS_APP_BUNDLE_DIR",
        "scratch/11412/araiyan/tapis/apps",
    )
    remote_bundle_name = f"{app_id}-{app_version}.tar"
    remote_bundle_path = f"{remote_bundle_dir.rstrip('/')}/{remote_bundle_name}"
    # For FORK jobs with ZIP runtime, just use the script name, not a full container image path
    remote_container_image = "tapisjob_app.sh"

    t = Tapis(base_url=tenant_url, username=username, password=password)
    t.get_tokens()

    # Build a ZIP-runtime tar bundle containing a single executable runner script.
    with tempfile.TemporaryDirectory() as tmp_dir:
        tmp_path = Path(tmp_dir)
        bundled_runner = tmp_path / "tapisjob_app.sh"
        runner_text = runner_script.read_text(encoding="utf-8")
        runner_text = runner_text.replace("\r\n", "\n").replace("\r", "\n")
        bundled_runner.write_text(runner_text, encoding="utf-8", newline="\n")
        bundled_runner.chmod(0o755)

        bundle_tar = tmp_path / remote_bundle_name
        with tarfile.open(bundle_tar, mode="w") as tf:
            tf.add(bundled_runner, arcname="tapisjob_app.sh")
            tf.add(bundled_runner, arcname="./tapisjob_app.sh")

        try:
            t.files.mkdir(systemId=exec_system_id, path=remote_bundle_dir)
        except Exception:
            # Directory may already exist.
            pass

        with bundle_tar.open("rb") as fh:
            t.files.insert(systemId=exec_system_id, path=remote_bundle_path, file=fh)
        print(f"Uploaded ZIP runtime bundle to {remote_container_image}")

    app_def = {
        "id": app_id,
        "version": app_version,
        "description": app_description,
        "containerImage": remote_container_image,
        "runtime": "ZIP",
        "jobType": "FORK",
        "jobAttributes": {
            "execSystemId": exec_system_id,
            "maxMinutes": 10,
            "nodeCount": 1,
            "coresPerNode": 1,
            "archiveOnAppError": False,
            "archiveMode": "SKIP_ON_FAIL",
            "parameterSet": {
                "appArgs": [],
                "envVariables": [],
            },
        },
    }

    try:
        t.apps.createAppVersion(**app_def)
        print(f"Success! Created app version {app_id}:{app_version}")
    except Exception as exc:
        # If version already exists, update in place for repeatable workflows.
        message = str(exc)
        if (
            "APPAPI_APP_VERSION_EXISTS" in message
            or "APPAPI_APP_EXISTS" in message
            or "409" in message
        ):
            t.apps.putApp(appId=app_id, appVersion=app_version, **app_def)
            print(f"Success! Updated existing app version {app_id}:{app_version}")
        else:
            raise

    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as e:
        print(f"Failed: {e}")
        raise SystemExit(1)