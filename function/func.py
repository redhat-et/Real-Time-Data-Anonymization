import azure.functions as func

import tempfile
import os

import cv2
import boto3
import numpy as np

haar_cascade = cv2.CascadeClassifier('./haarcascade_frontalface_default.xml')
confidence_threshold = 0.5
weights = './yolov3-custom_final.weights'
config = './yolov3-custom.cfg'
license_plate_class_id = 0

net = cv2.dnn.readNetFromDarknet(config, weights)
net.setPreferableBackend(cv2.dnn.DNN_BACKEND_OPENCV)
ln = net.getLayerNames()
ln = [ln[i[0] - 1] for i in net.getUnconnectedOutLayers()]

try: 
    endpoint_url = os.environ['AWS_ENDPOINT_URL']
    aws_access_key = os.environ['AWS_ACCESS_KEY_ID']
    aws_secret_key = os.environ['AWS_SECRET_ACCESS_KEY']
    s3 = boto3.resource('s3',
        endpoint_url=endpoint_url,
        aws_access_key_id=aws_access_key,
        aws_secret_access_key=aws_secret_key)
except:
    print('fall back to default s3')
    s3 = boto3.resource('s3')

#TODO use crypto tagging
ALREADY_PROCESSED_KEY = 'anonymized'
ALREADY_PROCESSED_VALUE = 'true'

def download(bucket_name, key_name, file_name):
    global s3
    bucket = s3.Bucket(bucket_name)
    bucket.download_file(Filename=file_name, Key=key_name)

def upload(bucket_name, key_name, file_name):
    global s3
    bucket = s3.Bucket(bucket_name)
    tags = {'Tagging': ALREADY_PROCESSED_KEY+'='+ALREADY_PROCESSED_VALUE}
    bucket.upload_file(Filename=file_name,
                       Key=key_name,
                       ExtraArgs=tags)

def blur_face(file_name):
    global haar_cascade
    img = cv2.imread(file_name)
    h, w = img.shape[:2]
    # get kernel width and height, ensure they are odd
    kW = (w // 3) | 1
    kH = (h // 3) | 1
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    detect = haar_cascade.detectMultiScale(gray, 
                                scaleFactor=1.3, 
                                minNeighbors=4, 
                                minSize=(30, 30),
                                flags=cv2.CASCADE_SCALE_IMAGE)

    for (x, y, w, h) in detect:
        face = img[y:y+h, x:x+w]
        face = cv2.GaussianBlur(face, (kW, kH), 0)
        img[y:y+face.shape[0], x:x+face.shape[1]] = face

    cv2.imwrite(file_name, img)

def blur_license_plate(file_name):
    global ln, confidence_threshold
    img = cv2.imread(file_name)
    curH, curW = img.shape[:2]
    # resize to multiple of 32
    H = int(curH//32)*32
    W = int(curW//32)*32
    img = cv2.resize(img, (W, H))
    kW = (W // 3) | 1
    kH = (H // 3) | 1
    blob = cv2.dnn.blobFromImage(img, 1/255.0, (416, 416), swapRB=True, crop=False)
    net.setInput(blob)
    outputs = net.forward(ln)
    outputs = np.vstack(outputs)
    for output in outputs:
        scores = output[5:]
        classID = np.argmax(scores)
        confidence = scores[classID]
        if confidence > confidence_threshold and classID == license_plate_class_id:
            x, y, w, h = (output[:4] * np.array([W, H, W, H])).astype(int)
            img[int(y - h//2 ):int(y + h//2), int(x-w//2):int(x+w//2)] = cv2.GaussianBlur(img[int(y - h//2 ):int(y + h//2), int(x-w//2):int(x+w//2)] ,(kW,kH), 0)

    cv2.imwrite(file_name, img)

def process(bucket_name, key_name, file_name):
    print('downloading {}/{} to {}'.format(bucket_name, key_name, file_name))
    download(bucket_name, key_name, file_name)
    print('blurring face')
    blur_face(file_name)
    print('blurring license plate')
    blur_license_plate(file_name)
    print('uploading {} to {}/{}'.format(file_name, bucket_name, key_name))
    upload(bucket_name, key_name, file_name)
    os.remove(file_name)


def callback(ch, method, properties, body):
    import ast
    dict_str = body.decode("UTF-8")
    data = ast.literal_eval(dict_str)
    records = data['Records']
    for r in records:
        bucket_name = r['s3']['bucket']['name']
        key_name = r['s3']['object']['key']
        tags = r['s3']['object']['tags']
        for tag in tags:
            if tag['key'] == ALREADY_PROCESSED_KEY and tag['val'] == ALREADY_PROCESSED_VALUE:
                print('object {}/{} already processed'.format(bucket_name, key_name))
                return
        f = tempfile.NamedTemporaryFile()
        file_name = f.name + '-' + key_name
        f.close()
        process(bucket_name, key_name, file_name)    

def receive():
    import pika
    amqp_url = os.environ['AMQP_URL']
    amqp_exchange = os.environ['AMQP_EXCHANGE']
    amqp_routing = os.environ['AMQP_ROUTING_KEY']
    amqp_queue_name = os.environ['AMQP_QUEUE_NAME']

    connection = pika.BlockingConnection(pika.URLParameters(amqp_url))
    channel = connection.channel()
    channel.queue_bind(exchange=amqp_exchange, queue=amqp_queue_name, routing_key=amqp_routing)
    channel.basic_consume(queue=amqp_queue_name, on_message_callback=callback, auto_ack=True)
    print('starting listening to message queue {}/{}'.format(amqp_exchange, amqp_queue_name))
    channel.start_consuming()

if __name__ == "__main__":
    receive()
