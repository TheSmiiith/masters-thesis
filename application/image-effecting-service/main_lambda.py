import boto3
import os
import json
from io import BytesIO
from PIL import Image, ImageFilter


def lambda_handler(event, context):
    # SQS and S3 clients
    sqs = boto3.client('sqs', region_name=os.environ['AWS_REGION'])
    s3 = boto3.resource('s3')

    # Environment variables
    queue_url = os.environ['QUEUE_URL']
    image_store_queue_url = os.environ['IMAGE_STORE_QUEUE_URL']
    temporary_image_store_bucket_name = os.environ['TEMPORARY_IMAGE_STORE_BUCKET_NAME']

    for record in event['Records']:
        body = json.loads(record['body'])
        attributes = record['messageAttributes']

        instanceId = attributes['InstanceId']['stringValue']
        requestId = attributes['RequestId']['stringValue']

        # Image name and extension from the message
        image_name = body['imageName']
        image_extension = body['imageExtension']

        print(f"Message received with RequestId: {requestId}")

        # Get image and it's content from the bucket
        bucket = s3.Bucket(temporary_image_store_bucket_name)
        image = bucket.Object(image_name + image_extension).get()
        image_content = image['Body'].read()

        print("Image downloaded from the Temporary Image Store bucket")

        # Open and compress image
        img = Image.open(BytesIO(image_content))

        # Blur image
        img_blur = img.filter(ImageFilter.BLUR)
        img_blur_buffer = BytesIO()
        img_blur.save(img_blur_buffer, format=img.format)

        blur_image_content = img_blur_buffer.getvalue()

        # Unsharp Mask image
        img_unsharp_mask = img.filter(ImageFilter.UnsharpMask)
        img_unsharp_mask_buffer = BytesIO()
        img_unsharp_mask.save(img_unsharp_mask_buffer, format=img.format)

        unsharp_mask_image_content = img_unsharp_mask_buffer.getvalue()

        # Gaussian Blur image
        img_gaussian_blur = img.filter(ImageFilter.GaussianBlur)
        img_gaussian_blur_buffer = BytesIO()
        img_gaussian_blur.save(img_gaussian_blur_buffer, format=img.format)

        gaussian_blur_image_content = img_gaussian_blur_buffer.getvalue()

        # Median Filter image
        img_median_filter = img.filter(ImageFilter.MedianFilter)
        img_median_filter_buffer = BytesIO()
        img_median_filter.save(img_median_filter_buffer, format=img.format)

        median_filter_image_content = img_median_filter_buffer.getvalue()

        # Edge Detection image
        img_edge_detection = img.filter(ImageFilter.FIND_EDGES)
        img_edge_detection_buffer = BytesIO()
        img_edge_detection.save(img_edge_detection_buffer, format=img.format)

        edge_detection_image_content = img_edge_detection_buffer.getvalue()

        # Upload images to bucket
        bucket.put_object(Key=image_name + '-blur' + image_extension,
                          Body=blur_image_content,
                          ContentType=image['ContentType'])

        bucket.put_object(Key=image_name + '-unsharp-mask' + image_extension,
                          Body=unsharp_mask_image_content,
                          ContentType=image['ContentType'])

        bucket.put_object(Key=image_name + '-gaussian-blur' + image_extension,
                          Body=gaussian_blur_image_content,
                          ContentType=image['ContentType'])

        bucket.put_object(Key=image_name + '-median-filter' + image_extension,
                          Body=median_filter_image_content,
                          ContentType=image['ContentType'])

        bucket.put_object(Key=image_name + '-edge-detection' + image_extension,
                          Body=edge_detection_image_content,
                          ContentType=image['ContentType'])

        print("Effected images uploaded to the Temporary Image Store bucket")

        # Response message
        response_message = {
            'images': [
                {
                    'imageName': image_name + '-blur',
                    'imageExtension': image_extension
                },
                {
                    'imageName': image_name + '-unsharp-mask',
                    'imageExtension': image_extension
                },
                {
                    'imageName': image_name + '-gaussian-blur',
                    'imageExtension': image_extension
                },
                {
                    'imageName': image_name + '-median-filter',
                    'imageExtension': image_extension
                },
                {
                    'imageName': image_name + '-edge-detection',
                    'imageExtension': image_extension
                },
            ]
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
                'StringValue': 'effecting'
            }
        }

        # Send message to the Image Store Queue
        response = sqs.send_message(
            QueueUrl=image_store_queue_url,
            MessageBody=json.dumps(response_message),
            MessageAttributes=response_attributes
        )

        print(f"Response sent for RequestId: {requestId}")

        # Delete the message
        sqs.delete_message(
            QueueUrl=queue_url,
            ReceiptHandle=record['receiptHandle']
        )
