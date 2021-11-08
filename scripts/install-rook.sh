kubectl apply -f https://raw.githubusercontent.com/rootfs/rook/microshift-int/cluster/examples/kubernetes/ceph/crds.yaml
kubectl apply -f https://raw.githubusercontent.com/rootfs/rook/microshift-int/cluster/examples/kubernetes/ceph/common.yaml
kubectl apply -f https://raw.githubusercontent.com/rootfs/rook/microshift-int/cluster/examples/kubernetes/ceph/operator-openshift.yaml
sleep 5
kubectl apply -f https://raw.githubusercontent.com/rootfs/rook/microshift-int/cluster/examples/kubernetes/ceph/cluster-test.yaml
sleep 30
kubectl apply -f https://raw.githubusercontent.com/rootfs/rook/microshift-int/cluster/examples/kubernetes/ceph/object-test.yaml
kubectl apply -f https://raw.githubusercontent.com/rootfs/rook/microshift-int/cluster/examples/kubernetes/ceph/toolbox.yaml
