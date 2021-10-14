USER=$(kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- radosgw-admin user list |grep ceph-user |cut -d '"' -f2)
export AWS_ACCESS_KEY_ID=$(kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- radosgw-admin user info --uid  $USER |grep access_key|awk '{print $2}' |cut -d '"' -f2)
export AWS_SECRET_ACCESS_KEY=$(kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- radosgw-admin user info --uid  $USER |grep secret_key|awk '{print $2}' |cut -d '"' -f2)
export AWS_DEFAULT_REGION=my-store
