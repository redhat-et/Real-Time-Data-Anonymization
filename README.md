# Real-Time-Data-Anonymization

This repo contains demo for KubeCon 2021 talk [Real-Time Data Anonymization the Serverless Way - Yuval Lifshitz & Huamin Chen, Red Hat
](https://kccncna2021.sched.com/event/lV3P/real-time-data-anonymization-the-serverless-way-yuval-lifshitz-huamin-chen-red-hat?iframe=no)


[![Demo](https://img.youtube.com/vi/iOQ9npYnmk8/0.jpg)](https://www.youtube.com/watch?v=iOQ9npYnmk8 "Demo")
> Note that the video refers to an older version of Rook and Ceph where more manual steps were needed

# MicroShift
Install [microshift](https://github.com/redhat-et/microshift).

> Note that Ceph needs at least one extra disk to run, and since microshift runs directly on the host, and extra physical disk is needed (e.g. attach a USB drive).
If this is not possible, we would recommend running microshift inside a VM, and attach an extra virtual disk to the VM.

## Create default storage provisioner
```bash
sh scripts/microshift-default-storageclass.sh
```
# Rook
```bash
sh scripts/install-rook.sh
```

# Create RGW S3 bucket
```bash
sh scripts/s3-bucket.sh
```

# Install RabbitMQ and declare exchange and queue
install the rabbitmq operator
```bash
sh scripts/install-rabbitmq.sh
```
 
Create exchange, queue, and routing key using the RGW bucket notification topic name
```bash
sh scripts/rabbitmq-declare-queue.sh
```

# Create RGW Bucket Notification
```bash
sh scripts/create-s3-bucket-notification.sh
```

# Start KEDA and Serverless function
Ensure `helm` v3 is [installed](https://helm.sh/docs/intro/install/) locally, then 
```bash
sh scripts/install-keda.sh
kubectl apply -f keda/anonymize-function.yaml
```

# Generate and apply Kubernetes Secrets for AWS and AMQP and the KEDA scaler
```bash
sh scripts/create-k8s-secret.sh
```

# Test
## Push images to bucket
Make sure that the `awscli` tool is [installed](https://docs.aws.amazon.com/cli/latest/userguide/install-linux.html) locally.
```bash
RGW_MY_STORE=$(kubectl get service -n rook-ceph rook-ceph-rgw-my-store -o jsonpath='{.spec.clusterIP}')
while true; do file=$(date +%Y-%m-%d-%H-%M-%S)".jpg"; aws --endpoint-url http://$RGW_MY_STORE:80 s3 cp test/image.jpg s3://notification-demo-bucket/$file;sleep 3;done
```

## Watch KEDA operator logs
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
