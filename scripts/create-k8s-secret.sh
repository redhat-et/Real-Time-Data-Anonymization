username="$(kubectl get secret hello-world-default-user -o jsonpath='{.data.username}' | base64 --decode)"
password="$(kubectl get secret hello-world-default-user -o jsonpath='{.data.password}' | base64 --decode)"
service="$(kubectl get service hello-world -o jsonpath='{.spec.clusterIP}')"

amqp_url=$(echo -n "amqp://"${username}:${password}@${service}:5672 |base64|tr -d '\n';echo)
USER=$(kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- radosgw-admin user list |grep ceph-user |cut -d '"' -f2)
aws_key_id=$(kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- radosgw-admin user info --uid  $USER |grep access_key|awk '{print $2}' |cut -d '"' -f2|tr -d '\n'|base64|tr -d '\n';echo)
aws_key=$(kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- radosgw-admin user info --uid  $USER |grep secret_key|awk '{print $2}' |cut -d '"' -f2|tr -d '\n' |base64|tr -d '\n';echo)
aws_url=$(echo -n "http://"$(kubectl get service -n rook-ceph rook-ceph-rgw-my-store -o jsonpath='{.spec.clusterIP}') |base64)

echo "aws env:" $aws_url ${aws_key} $aws_key_id
echo "amqp env:" $amqp_url

cat << EOF > secrets.yaml
apiVersion: v1
kind: Secret
metadata:
  name: rabbitmq-consumer-secret
data:
  amqp_url: ${amqp_url}
---
apiVersion: v1
kind: Secret
metadata:
  name: rgw-s3-credential
data:
  aws_access_key: ${aws_key}
  aws_key_id: ${aws_key_id}
  aws_endpoint_url: ${aws_url}
---
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: rabbitmq-consumer
  namespace: default
spec:
  scaleTargetRef:
    name: rabbitmq-consumer
  triggers:
    - type: rabbitmq
      metadata:
        queueName: "bucket-notification-queue"
        mode: "QueueLength"
        value: "5"
      authenticationRef:
        name: rabbitmq-consumer-trigger
---
apiVersion: keda.sh/v1alpha1
kind: TriggerAuthentication
metadata:
  name: rabbitmq-consumer-trigger
  namespace: default
spec:
  secretTargetRef:
  - parameter: host
    name: rabbitmq-consumer-secret
    key: amqp_url
EOF

