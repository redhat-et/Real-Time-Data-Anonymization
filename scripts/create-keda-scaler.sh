username="$(kubectl get secret hello-world-default-user -o jsonpath='{.data.username}' | base64 --decode)"
password="$(kubectl get secret hello-world-default-user -o jsonpath='{.data.password}' | base64 --decode)"
service="$(kubectl get service hello-world -o jsonpath='{.spec.clusterIP}')"

amqp_url=$(echo -n "amqp://${username}:${password}@${service}:5672" | base64 | tr -d '\n')
aws_url=$(echo -n "https://"$(kubectl get service -n rook-ceph rook-ceph-rgw-my-store -o jsonpath='{.spec.clusterIP}') | base64)

cat << EOF | kubectl apply -f -
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
  name: rgw-s3-url
data:
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

