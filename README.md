# Real-Time-Data-Anonymization

This repo contains demo for KubeCon 2021 talk [Real-Time Data Anonymization the Serverless Way - Yuval Lifshitz & Huamin Chen, Red Hat
](https://kccncna2021.sched.com/event/lV3P/real-time-data-anonymization-the-serverless-way-yuval-lifshitz-huamin-chen-red-hat?iframe=no)


# MicroShift
Install [microshift](https://github.com/redhat-et/microshift)

## Create default storage provisioner

```bash
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolume
metadata:
  name: hostpath-provisioner
spec:
  capacity:
    storage: 8Gi
  accessModes:
  - ReadWriteOnce
  hostPath:
    path: "/var/hpvolumes"
EOF    
kubectl patch storageclass kubevirt-hostpath-provisioner -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

# Rook
> since bucket notification support is still work-in-progress, replace image in: `operator.yaml` with: `quay.io/ylifshit/rook-ceph`
> in order to workaround an issue with rabbitmq, replace the ceph image in: `cluster-test.yaml` with `quay.io/ceph-ci/ceph:wip-yuval-fix-50611`

* get the Rook code:
```
git clone https://github.com/rootfs/rook -b microshift-int
```
* enter the ceph yamls directory:
```
cd rook/cluster/examples/kubernetes/ceph
```
* install basic rook operator
```
kubectl apply -f crds.yaml -f common.yaml -f operator.yaml
```
* install the ceph cluster
```
kubectl apply -f cluster-test.yaml
```
* install the object store
```
kubectl apply -f object-test.yaml
```
and wait for the RGW to run:
```
kubectl -n rook-ceph get pod -l app=rook-ceph-rgw
```
now we can set a storage class, topics, notifications, and OBCs. Documentation is [here](https://github.com/rook/rook/blob/d0be92327830082169bfcf276239bbcfa066f4fc/Documentation/ceph-object-bucket-notifications.md)

## Logs
operator logs:
```
kubectl logs -l app=rook-ceph-operator -n rook-ceph -f 
```
RGW logs:
```
kubectl logs -l app=rook-ceph-rgw -n rook-ceph -f 
```

# Create RGW S3 bucket
```bash
cat << EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
   name: rook-ceph-delete-bucket-my-store
provisioner: rook-ceph.ceph.rook.io/bucket # driver:namespace:cluster
# set the reclaim policy to delete the bucket and all objects
# when its OBC is deleted.
reclaimPolicy: Delete
parameters:
   objectStoreName: my-store
   objectStoreNamespace: rook-ceph # namespace:cluster
   region: us-east-1
   # To accommodate brownfield cases reference the existing bucket name here instead
   # of in the ObjectBucketClaim (OBC). In this case the provisioner will grant
   # access to the bucket by creating a new user, attaching it to the bucket, and
   # providing the credentials via a Secret in the namespace of the requesting OBC.
   #bucketName:
---
apiVersion: objectbucket.io/v1alpha1
kind: ObjectBucketClaim
metadata:
  name: ceph-delete-bucket
spec:
  # To create a new bucket specify either `bucketName` or
  # `generateBucketName` here. Both cannot be used. To access
  # an existing bucket the bucket name needs to be defined in
  # the StorageClass referenced here, and both `bucketName` and
  # `generateBucketName` must be omitted in the OBC.
  bucketName: notification-demo-bucket
  generateBucketName: ceph-bkt
  storageClassName: rook-ceph-delete-bucket-my-store
  additionalConfig:
    # To set for quota for OBC
    #maxObjects: "1000"
    #maxSize: "2G"
EOF  
```
# workround plaintext password limitation
to workaround the rabbitmq issue, change the following conf parameter in the RGW:
```bash
kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- ceph config set client.rgw.my.store.a rgw_allow_secrets_in_cleartext true
kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- ceph config set  client.rgw.my.store.a debug_rgw 10
```
# set bucket notification
## get ceph bucket object user
```bash
USER=$(kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- radosgw-admin user list |grep ceph-user |cut -d '"' -f2)
export AWS_ACCESS_KEY_ID=$(kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- radosgw-admin user info --uid  $USER |grep access_key|awk '{print $2}' |cut -d '"' -f2)
export AWS_SECRET_ACCESS_KEY=$(kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- radosgw-admin user info --uid  $USER |grep secret_key|awk '{print $2}' |cut -d '"' -f2)
export AWS_DEFAULT_REGION=my-store
aws configure set default.sns.signature_version s3


```
# RabbitMQ
install the rabbitmq operator
```
kubectl apply -f https://github.com/rabbitmq/cluster-operator/releases/latest/download/cluster-operator.yml
kubectl apply -f https://raw.githubusercontent.com/rabbitmq/cluster-operator/main/docs/examples/hello-world/rabbitmq.yaml
```
 
Create exchange,queue, and routing key using the RGW bucket notification topic name
```bash
kubectl exec -ti hello-world-server-0 -- rabbitmqadmin declare exchange name=ex1 type=topic
kubectl exec -ti hello-world-server-0 -- rabbitmqadmin declare queue name=bucket-notification-queue durable=true
kubectl exec -ti hello-world-server-0 -- rabbitmqadmin declare binding source=ex1 destination_type=queue destination=bucket-notification-queue routing_key=demo #routing_key is the topic name
```

## get AMQP username/password/service
```bash
username="$(kubectl get secret hello-world-default-user -o jsonpath='{.data.username}' | base64 --decode)"
password="$(kubectl get secret hello-world-default-user -o jsonpath='{.data.password}' | base64 --decode)"
service="$(kubectl get service hello-world -o jsonpath='{.spec.clusterIP}')" 
```



# create ampq notification endpoint
```bash
RGW_MY_STORE=$(kubectl get service -n rook-ceph rook-ceph-rgw-my-store -o jsonpath='{.spec.clusterIP}')
aws --endpoint-url http://$RGW_MY_STORE:80 sns create-topic --name=demo --attributes='{"push-endpoint": "amqp://$username:$password@$service:5672", "amqp-exchange": "ex1", "amqp-ack-level": "broker"}'
aws --endpoint-url http://$RGW_MY_STORE:80 s3api put-bucket-notification-configuration --bucket notification-demo-bucket --notification-configuration='{"TopicConfigurations": [{"Id": "notif1", "TopicArn": "arn:aws:sns:my-store::demo", "Events": ["s3:ObjectCreated:*"]}]}'
```

# Create KEDA scale object
```bash
kubectl apply -f keda/rabbitmq.yaml
```
# Test
## Push to bucket
```bash
echo "test" > test.txt
aws --endpoint-url http://$RGW_MY_STORE:80 s3 cp test.txt s3://notification-demo-bucket/foo
```

