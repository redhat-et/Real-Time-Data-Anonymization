# RabbitMQ triggered Keda Function
This directory structure and Dockerfile are generated via [func](https://docs.microsoft.com/en-us/azure/azure-functions/functions-kubernetes-keda). 

# Model files
[haarcascade_frontalface_default.xml](./haarcascade_frontalface_default.xml) is from [OpenCV](https://github.com/opencv/opencv/blob/master/data/haarcascades/haarcascade_frontalface_default.xml)

The model for license plate detection is over Github object size, it is available in the [container image](quay.io/rootfs/kubecon21-demo:latest). The model is trained via [darknet](https://github.com/AlexeyAB/darknet) using [Vehicle Registration Plate class at Open Images Dataset](https://storage.googleapis.com/openimages/web/visualizer/index.html?set=train&type=segmentation&r=false&c=%2Fm%2F01jfm_)

