# FastApi template

================

## Description

My project description

[GCP Project](https://console.cloud.google.com/home/dashboard?authuser=0&project=<GCP_PROJECT_ID>&supportedpurview=project)

## Template Stack

- [FastApi](https://fastapi.tiangolo.com/)
- [SQLModel](https://sqlmodel.tiangolo.com/)
- [SQLAlchemy 2](https://docs.sqlalchemy.org/en/20/)
- [Firestore](https://firebase.google.com/docs/firestore)

## Project Setup

- Install [Poetry](https://python-poetry.org/docs/)

- Set config for venv in local

  ```sh
  poetry config virtualenvs.in-project true
  poetry env use 3.11
  poetry shell
  poetry install
  ```

- (Postgres only) Create and run required databases

  ```bash
  docker compose up -d
  ```

- Apply migrations

  ```sh
  alembic upgrade head
  ```

### Run locally

```sh
# WITHOUT DOCKER (Guess ADC from env)
uvicorn app.main:app --reload          # Or from VSCode launcher

# OR

# WITH DOCKER
Use the launch.json configuration to build and run the container

# (Running the launch is an equivalent to):
docker build -t <image>:<tag> -f Dockerfile .
docker run --name fastapi_template -p 8000:8000 -p 5678:5678 -v "$HOME/.config/gcloud/application_default_credentials.json":/gcp/creds.json --env GOOGLE_APPLICATION_CREDENTIALS=/gcp/creds.json --env GCLOUD_PROJECT=<GCP_PROJECT_ID> <image>:<tag>

```

## Tests

```sh
poetry run pytest --cov=app --cov-report=term     # Uses SQLALCHEMY_DATABASE_URI in pyproject.toml
```

## Deployment

:warning: Everything under this section assumes you specified a repository to push to, and choosed 'yes' to "as_container" question. Otherwise update the main.tf according yo your needs before running  :warning:

### Initialisation

To deploy the infrastructure, make sure ADC is configured correctly.

The main.tf will deploy:

- Image into the Artifact Registry used by Cloud Run
- Cloud Run service
- Secret in Secret Manager
- Cloud Build Trigger linked to the repository specified

Additionally, it will deploy a Cloud SQL and/or Firestore database according to you database choice.
You may need additional IAM roles to deploy databases

```bash

# Ensure your .env content is the deployed version before running
cd fastapi_template
terraform init
terraform apply

```

Once deployment is done:

- [Connect your repository to Cloud Build](https://console.cloud.google.com/cloud-build/repositories/1st-gen?authuser=0&project=<GCP_PROJECT_ID>&supportedpurview=project)
- [Add .env content into secret version](https://console.cloud.google.com/security/secret-manager/secret/fastapi-template/versions?authuser=0&project=<GCP_PROJECT_ID>&supportedpurview=project)

Cloud Build is now ready to deploy new Cloud Run revision after each push

### Migrations (Postgres only)

Run migrations into the instance with Cloud SQL Proxy

## CI/CD

### CI with Github Actions

Use .github/workflows/lint.yaml **by enabling Github Actions API** in your repository

This will run linting for every Pull Request on develop, uat and main branches

### CD with Cloud Build & Cloud Run

.cloudbuild/cloudbuild.yaml is used automatically to deploy to Cloud Run according to your Cloud Build trigger configuration

*Requirements*:

- From the trigger created by Terraform, give Github repository access to Cloud Build

- Copy .env into the secret 'fastapi-template' to ensure Cloud Build will have the correct environement.

- Roles:
  - Cloud Build Service Account has Cloud Run Admin role
  - Cloud Build Service Account has Secret Manager Secret Accessor role

## Api docs

- [Swagger](http://localhost:8000/api/docs)

## Maintainers

Digital Lab <fr.dgc.ops.dgtl@devoteamgcloud.com>
