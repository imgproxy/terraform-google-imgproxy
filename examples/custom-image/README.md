# Custom image

Use an imgproxy image from your own registry: a custom build, a private fork, or a mirror for image scanning
and air-gapped setups.

When `repo` is set, the module skips creating Artifact Registry remote repositories. `tag` accepts regular
tags and `sha256:...` digests.

## Google Cloud setup

You need a Google Cloud project and the [gcloud CLI](https://cloud.google.com/sdk/docs/install), authenticated:

```bash
gcloud auth application-default login
gcloud config set project YOUR_PROJECT_ID
```

## Mirror imgproxy into Artifact Registry

```bash
gcloud artifacts repositories create imgproxy-mirror \
  --repository-format=docker \
  --location=us-central1 \
  --description="imgproxy mirror"

docker pull darthsim/imgproxy:v4
docker tag darthsim/imgproxy:v4 \
  us-central1-docker.pkg.dev/my-project/imgproxy-mirror/imgproxy:v4
docker push us-central1-docker.pkg.dev/my-project/imgproxy-mirror/imgproxy:v4
```

## Deploy

```bash
echo 'project_id = "my-project"' > terraform.tfvars

terraform init
terraform plan
terraform apply
```

Signing keys are required; see [signed](../signed/).

## Cleanup

```bash
terraform destroy
```

The `imgproxy-mirror` Artifact Registry repository was created with `gcloud`, not Terraform; delete it with `gcloud artifacts repositories delete imgproxy-mirror --location=us-central1`.

## Next

Continue with [complete](../complete/).
