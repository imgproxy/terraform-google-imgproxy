# Custom image

Use an imgproxy image from your own registry: a custom build, a private fork, or a mirror for image scanning
and air-gapped setups.

When `repo` is set, the module skips creating Artifact Registry remote repositories. `tag` accepts regular
tags and `sha256:...` digests.

## Mirror imgproxy into Artifact Registry

```bash
gcloud artifacts repositories create imgproxy-mirror \
  --repository-format=docker \
  --location=us-central1 \
  --description="imgproxy mirror"

docker pull darthsim/imgproxy:v3.0
docker tag darthsim/imgproxy:v3.0 \
  us-central1-docker.pkg.dev/my-project/imgproxy-mirror/imgproxy:v3.0
docker push us-central1-docker.pkg.dev/my-project/imgproxy-mirror/imgproxy:v3.0
```

Signing keys are required; see [signed](../signed/).
