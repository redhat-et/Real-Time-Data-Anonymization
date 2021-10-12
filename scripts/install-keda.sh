kubectl create namespace keda
helm install keda kedacore/keda --version 1.4.2 --namespace keda
