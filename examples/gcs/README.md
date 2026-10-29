# GCS source bucket

imgproxy reading source images from a private GCS bucket via the `gs://` URL scheme. The module grants
`roles/storage.objectViewer` to the imgproxy service account, so the bucket stays private.

Signing keys are required; see [signed](../signed/) for how to create them.

## Google Cloud setup

You need a Google Cloud project and the [gcloud CLI](https://cloud.google.com/sdk/docs/install), authenticated:

```bash
gcloud auth application-default login
gcloud config set project YOUR_PROJECT_ID
```

```bash
echo 'project_id = "my-project"' > terraform.tfvars

terraform init
terraform plan
terraform apply

gcloud storage cp photo.jpg gs://my-project-imgproxy-images/photo.jpg

# <signature> must be generated, see https://docs.imgproxy.net/usage/signing_the_url
curl "$(terraform output -raw url)/<signature>/rs:fit:300:200/plain/gs://my-project-imgproxy-images/photo.jpg"
```

The module does not create buckets; here the example creates one itself.

## Cleanup

```bash
terraform destroy
```

Terraform cannot delete the bucket while it contains objects; empty it first (`gcloud storage rm -r gs://my-project-imgproxy-images/**`). The secrets from the [signed](../signed/) example are not managed by Terraform.

## Next

Continue with [cdn](../cdn/).
