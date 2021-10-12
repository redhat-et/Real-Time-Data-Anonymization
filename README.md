# Real-Time-Data-Anonymization

This repo contains demo for KubeCon 2021 talk [Real-Time Data Anonymization the Serverless Way - Yuval Lifshitz & Huamin Chen, Red Hat
](https://kccncna2021.sched.com/event/lV3P/real-time-data-anonymization-the-serverless-way-yuval-lifshitz-huamin-chen-red-hat?iframe=no)


# MicroShift
Install [microshift](https://github.com/redhat-et/microshift)

## Create default storage provisioner
```bash
sh scripts/microshift-default-storageclass.sh
```
# Rook
> since bucket notification support is still work-in-progress, replace image in: `operator.yaml` with: `quay.io/ylifshit/rook-ceph`
> in order to workaround an issue with rabbitmq, replace the ceph image in: `cluster-test.yaml` with `quay.io/ceph-ci/ceph:wip-yuval-fix-50611`
```bash
sh scripts/install-rook.sh
```

# Create RGW S3 bucket
```bash
sh scripts/s3-bucket.sh
```
## workround plaintext password limitation
to workaround the rabbitmq issue, change the following conf parameter in the RGW:
```bash
kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- ceph config set client.rgw.my.store.a rgw_allow_secrets_in_cleartext true
kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- ceph config set  client.rgw.my.store.a debug_rgw 10
```

# Apply RGW S3 Environment Variables
```bash
source scripts/s3-env.sh
```

# Install RabbitMQ and declare exchange and queue
install the rabbitmq operator
```bash
sh scripts/install-rabbitmq.sh
```
 
Create exchange,queue, and routing key using the RGW bucket notification topic name
```bash
sh scripts/rabbitmq-declare-queue.sh
```

# Create RGW Bucket Notification
```bash
sh scripts/create-s3-bucket-notification.sh
```

# Generate and apply Kubernetes Secrets for AWS and AMQP credentials 
```bash
sh scripts/create-k8s-secret.sh
```
Now apply the secrets file `secrets.yaml`
```bash
kubectl apply -f scripts/secrets.yaml
```

# Start Keda and Serverless function
Ensure `helm` v3 is installed locally, then 
```bash
sh scripts/install-keda.sh
kubectl apply -f keda/anonymize-function.yaml
```
# Test
## Push images to bucket
```bash
RGW_MY_STORE=$(kubectl get service -n rook-ceph rook-ceph-rgw-my-store -o jsonpath='{.spec.clusterIP}')
while true; do file=$(date +%Y-%m-%d-%H-%M-%S)".jpg"; aws --endpoint-url http://$RGW_MY_STORE:80 s3 cp test.jpg s3://notification-demo-bucket/$file;sleep 3;done
```

## Watch Keda operator logs
```bash
kubectl logs -n keda  -l app=keda-operator -f
```
The logs will show Serverless functions scaling up and down.

## Watch Serverless function logs
```bash
kubectl logs -l app=rabbitmq-consumer -f
```
A sample output is as the following:
```console
# kubectl logs -l app=rabbitmq-consumer -f
downloading notification-demo-bucket/2021-10-12-17-21-31.jpg to /tmp/tmp0geekb_2-2021-10-12-17-21-31.jpg
blurring face
blurring license plate
uploading /tmp/tmp0geekb_2-2021-10-12-17-21-31.jpg to notification-demo-bucket/2021-10-12-17-21-31.jpg
object notification-demo-bucket/2021-10-12-17-21-31.jpg already processed
downloading notification-demo-bucket/2021-10-12-17-21-35.jpg to /tmp/tmpxczuj32m-2021-10-12-17-21-35.jpg
blurring face
blurring license plate
```
