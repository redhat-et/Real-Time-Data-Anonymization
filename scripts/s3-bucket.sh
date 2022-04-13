cat << EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: rook-ceph-delete-bucket-my-store
provisioner: rook-ceph.ceph.rook.io/bucket # driver:namespace:cluster
reclaimPolicy: Delete
parameters:
  objectStoreName: my-store
  objectStoreNamespace: rook-ceph # namespace:cluster
  region: us-east-1
---
apiVersion: objectbucket.io/v1alpha1
kind: ObjectBucketClaim
metadata:
  name: ceph-delete-bucket
  labels:
    bucket-notification-my-notification: my-notification
spec:
  bucketName: notification-demo-bucket
  storageClassName: rook-ceph-delete-bucket-my-store
EOF
