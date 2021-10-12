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
