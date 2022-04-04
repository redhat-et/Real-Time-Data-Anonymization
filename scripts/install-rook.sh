kubectl apply -f https://raw.githubusercontent.com/rook/rook/master/deploy/examples/crds.yaml
kubectl apply -f https://raw.githubusercontent.com/rook/rook/master/deploy/examples/common.yaml
kubectl apply -f https://raw.githubusercontent.com/rook/rook/master/deploy/examples/operator-openshift.yaml
sleep 5
kubectl apply -f https://raw.githubusercontent.com/rook/rook/master/deploy/examples/cluster-test.yaml
sleep 30
cat << EOF | kubectl apply -f -
apiVersion: ceph.rook.io/v1
kind: CephObjectStore
metadata:
  name: my-store
  namespace: rook-ceph # namespace:cluster
spec:
  metadataPool:
    replicated:
      size: 1
  dataPool:
    replicated:
      size: 1
  preservePoolsOnDelete: false
  gateway:
    securePort: 443
    instances: 1
    service:
      annotations:
        service.beta.openshift.io/serving-cert-secret-name: rook-ceph-rgw-my-store
EOF

