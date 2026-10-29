# GCS source bucket

imgproxy reading source images from a private GCS bucket via the `gs://` URL scheme. The module grants
`roles/storage.objectViewer` to the imgproxy service account, so the bucket stays private.

Signing keys are required; see [signed](../signed/) for how to create them.

```bash
terraform init
terraform apply -var project_id=my-project

gcloud storage cp photo.jpg gs://my-project-imgproxy-images/photo.jpg

# <signature> must be generated, see https://docs.imgproxy.net/usage/signing_the_url
curl "$(terraform output -raw url)/<signature>/rs:fit:300:200/plain/gs://my-project-imgproxy-images/photo.jpg"
```

The module does not create buckets; here the example creates one itself.
