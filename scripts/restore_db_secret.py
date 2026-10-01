import json
import subprocess
from urllib.parse import quote


def output(name: str) -> str:
    return subprocess.check_output(
        ["terraform", "-chdir=infra/terraform", "output", "-raw", name],
        text=True,
    ).strip()


secret_arn = output("database_master_secret_arn")
endpoint = output("database_endpoint")
host, port = endpoint.rsplit(":", 1)

secret_string = subprocess.check_output(
    [
        "aws", "secretsmanager", "get-secret-value",
        "--region", "ap-south-1",
        "--secret-id", secret_arn,
        "--query", "SecretString",
        "--output", "text",
        "--no-cli-pager",
    ],
    text=True,
)
credentials = json.loads(secret_string)

database_url = (
    f"postgresql+psycopg://"
    f"{quote(credentials['username'], safe='')}:"
    f"{quote(credentials['password'], safe='')}"
    f"@{host}:{port}/boundarypass"
)

manifest = {
    "apiVersion": "v1",
    "kind": "Secret",
    "metadata": {"name": "boundarypass-db", "namespace": "default"},
    "type": "Opaque",
    "stringData": {"DATABASE_URL": database_url},
}

subprocess.run(
    [
        "kubectl", "apply", "--server-side",
        "--field-manager=boundarypass-restore", "-f", "-",
    ],
    input=json.dumps(manifest),
    text=True,
    check=True,
)
print("Updated Kubernetes Secret default/boundarypass-db")