import boto3
import os
import json
from io import BytesIO
from PIL import Image

# SQS and S3 clients
sqs = boto3.client('sqs', region_name=os.environ['AWS_REGION'])
s3 = boto3.resource('s3')

# Environment variables
queue_url = os.environ['QUEUE_URL']
image_store_queue_url = os.environ['IMAGE_STORE_QUEUE_URL']
temporary_image_store_bucket_name = os.environ['TEMPORARY_IMAGE_STORE_BUCKET_NAME']

print("Application started.")

while True:
    messages = sqs.receive_message(
        QueueUrl=queue_url,
        MaxNumberOfMessages=1,
        WaitTimeSeconds=20,
        MessageAttributeNames=['All']
    )

    if 'Messages' in messages:
        # Get first (and only) message
        message = messages['Messages'][0]

        instanceId = message['MessageAttributes']['InstanceId']['StringValue']
        requestId = message['MessageAttributes']['RequestId']['StringValue']

        # Image name and extension from the message
        image_name = json.loads(message['Body'])['imageName']
        image_extension = json.loads(message['Body'])['imageExtension']

        print("Message received with RequestId: " + requestId)

        # Get image and it's content from the bucket
        bucket = s3.Bucket(temporary_image_store_bucket_name)
        image = bucket.Object(image_name + image_extension).get()
        image_content = image['Body'].read()

        print("Image downloaded from the Temporary Image Store bucket")

        # Open and compress image
        img = Image.open(BytesIO(image_content))

        buffer = BytesIO()

        img.save(buffer,
                 format=img.format,
                 optimize=True,
                 quality=50)

        compressed_image_content = buffer.getvalue()

        # Upload image to bucket
        bucket.put_object(Key=image_name + '-compressed' + image_extension,
                          Body=compressed_image_content,
                          ContentType=image['ContentType'])

        print("Compressed image uploaded to the Temporary Image Store bucket")

        # Response message
        response_message = {
            'imageName': image_name + '-compressed',
            'imageExtension': image_extension
        }

        # Response attributes
        response_attributes = {
            'InstanceId': {
                'DataType': 'String',
                'StringValue': instanceId
            },
            'RequestId': {
                'DataType': 'String',
                'StringValue': requestId
            },
            'Application': {
                'DataType': 'String',
                'StringValue': 'compression'
            }
        }

        # Send message to the Image Store Queue
        response = sqs.send_message(
            QueueUrl=image_store_queue_url,
            MessageBody=json.dumps(response_message),
            MessageAttributes=response_attributes
        )

        print("Response sent for RequestId: " + requestId)

        # Delete the message
        sqs.delete_message(
            QueueUrl=queue_url,
            ReceiptHandle=message['ReceiptHandle']
        )
