set -x
username="$(kubectl get secret hello-world-default-user -o jsonpath='{.data.username}' | base64 --decode)"
password="$(kubectl get secret hello-world-default-user -o jsonpath='{.data.password}' | base64 --decode)"
service="$(kubectl get service hello-world -o jsonpath='{.spec.clusterIP}')" 

RGW_MY_STORE=$(kubectl get service -n rook-ceph rook-ceph-rgw-my-store -o jsonpath='{.spec.clusterIP}')
aws --endpoint-url http://$RGW_MY_STORE:80 sns create-topic --name=demo --attributes='{"push-endpoint": "amqp://'${username}:${password}@${service}':5672", "amqp-exchange": "ex1", "amqp-ack-level": "broker"}'
aws --endpoint-url http://$RGW_MY_STORE:80 s3api put-bucket-notification-configuration --bucket notification-demo-bucket --notification-configuration='{"TopicConfigurations": [{"Id": "notif1", "TopicArn": "arn:aws:sns:my-store::demo", "Events": ["s3:ObjectCreated:*"]}]}'

