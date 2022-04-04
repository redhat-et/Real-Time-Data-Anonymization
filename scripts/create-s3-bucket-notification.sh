username="$(kubectl get secret hello-world-default-user -o jsonpath='{.data.username}' | base64 --decode)"
password="$(kubectl get secret hello-world-default-user -o jsonpath='{.data.password}' | base64 --decode)"
service="$(kubectl get service hello-world -o jsonpath='{.spec.clusterIP}')" 

cat << EOF | kubectl apply -f -
apiVersion: ceph.rook.io/v1
kind: CephBucketTopic
metadata:
  name: demo
spec:
  objectStoreName: my-store
  objectStoreNamespace: rook-ceph
  endpoint:
    amqp:
      uri: amqp://${username}:${password}@${service}:5672
      ackLevel: broker
      exchange: ex1
---
apiVersion: ceph.rook.io/v1
kind: CephBucketNotification
metadata:
  name: my-notification
spec:
  topic: demo
  filter:
  events:
    - s3:ObjectCreated:*
EOF
