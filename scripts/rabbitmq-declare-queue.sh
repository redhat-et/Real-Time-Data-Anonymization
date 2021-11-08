kubectl exec -ti hello-world-server-0 -c rabbitmq -- rabbitmqadmin delete exchange name=ex1
kubectl exec -ti hello-world-server-0 -c rabbitmq -- rabbitmqadmin declare exchange name=ex1 type=topic
kubectl exec -ti hello-world-server-0 -c rabbitmq -- rabbitmqadmin delete queue name=bucket-notification-queue
kubectl exec -ti hello-world-server-0 -c rabbitmq -- rabbitmqadmin declare queue name=bucket-notification-queue durable=false
kubectl exec -ti hello-world-server-0 -c rabbitmq -- rabbitmqadmin declare binding source=ex1 destination_type=queue destination=bucket-notification-queue routing_key=demo #routing_key is the topic name

