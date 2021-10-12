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
spec:
  bucketName: notification-demo-bucket
  storageClassName: rook-ceph-delete-bucket-my-store
  additionalConfig:
    # To set for quota for OBC
    #maxObjects: "1000"
    #maxSize: "2G"
EOF
