import express from "express";
import {
    SQSClient,
    ReceiveMessageCommand,
    SendMessageCommand,
    DeleteMessageCommand,
} from "@aws-sdk/client-sqs";
import {S3Client, PutObjectCommand, GetObjectCommand, DeleteObjectCommand} from '@aws-sdk/client-s3';
import multer from 'multer';
import path from 'path';
import mysql from 'mysql2/promise';
import {v4 as uuidv4} from 'uuid';
import axios from 'axios';

const getInstanceId = async () => (await axios.get('http://169.254.169.254/latest/meta-data/instance-id')).data;

let instanceId;

import {configuration} from "./configuration.js";

const app = express();

app.use(express.json());

console.log(`Configuration: ${JSON.stringify(configuration)}`)

const connection = await mysql.createConnection({
    host: configuration.database.address,
    database: configuration.database.name,
    user: configuration.database.user,
    password: configuration.database.password
});

await connection.execute(`
    CREATE TABLE IF NOT EXISTS images
    (
        id
        INT
        AUTO_INCREMENT
        PRIMARY
        KEY,
        name
        VARCHAR
    (
        255
    ) NOT NULL,
        extension VARCHAR
    (
        10
    ) NOT NULL,
        data BLOB NOT NULL
        );
`);

const sqs = new SQSClient({
    region: configuration.region
});

const s3 = new S3Client({
    region: configuration.region
});

const storage = multer.memoryStorage();
const upload = multer({storage});

// Promise / Futures
const pendingCompressionRequests = new Map();
const pendingEffectingRequests = new Map();

app.post("/upload", upload.single('file'), async (req, res) => {
    try {
        // Get instance ID
        if (!instanceId) instanceId = await getInstanceId();

        // Upload image to the Temporary Image Store S3 bucket
        const {fileName, fileExtension} = await uploadFilesToTemporaryImageStore(req.file);

        const requestId = uuidv4();

        console.log("New request with RequestId: ", requestId);

        // Send message to the Image Compression Service
        await sendMessageToImageCompressionService(requestId, fileName, fileExtension);

        // Save request to pendingCompressionRequests
        pendingCompressionRequests.set(requestId, {
            request: res,
            image: {imageName: fileName, imageExtension: fileExtension}
        });
    } catch (e) {
        console.log("Error with /upload: ", e);
        res.status(500).end();
    }
});

const polling = async () => {
    const params = {
        QueueUrl: configuration.queueUrl,
        MaxNumberOfMessages: 10,
        WaitTimeSeconds: 20,
        VisibilityTimeout: 1,
        MessageAttributeNames: ["All"]
    };

    try {
        const data = await sqs.send(new ReceiveMessageCommand(params));

        if (data.Messages) {
            data.Messages.forEach((message) => {
                if (message.MessageAttributes && message.MessageAttributes.InstanceId.StringValue === instanceId) {
                    const application = message.MessageAttributes.Application.StringValue;
                    const requestId = message.MessageAttributes.RequestId.StringValue;
                    // Check where the message comes
                    if (application === 'compression') {
                        if (pendingCompressionRequests.has(requestId)) {
                            console.log("Compression of RequestId successfully finished: ", requestId);
                            let request = pendingCompressionRequests.get(requestId);
                            // Send message to effecting queue
                            sendMessageToImageEffectingService(requestId, request.image.imageName, request.image.imageExtension).then(() => {
                                // Remove from pending compression requests
                                pendingCompressionRequests.delete(request);
                                // Save request to pendingEffectingRequests
                                pendingEffectingRequests.set(requestId, {
                                    request: request.request,
                                    originalImage: {
                                        imageName: request.image.imageName,
                                        imageExtension: request.image.imageExtension
                                    },
                                    compressedImage: {
                                        imageName: JSON.parse(message.Body).imageName,
                                        imageExtension: JSON.parse(message.Body).imageExtension,
                                    }
                                });
                            }).catch((e) => {
                                console.log("Error: ", e);
                                // Remove from pending compression requests
                                pendingCompressionRequests.delete(request);
                                // Send error response
                                request.request.status(500).end();
                            })
                        }
                    } else if (application === 'effecting') {
                        if (pendingEffectingRequests.has(requestId)) {
                            console.log("Effecting of RequestId successfully finished: ", requestId);
                            let request = pendingEffectingRequests.get(requestId);
                            // Create images array (which we want to move to database)
                            const images = JSON.parse(message.Body).images;
                            images.unshift(request.compressedImage);
                            images.unshift(request.originalImage);
                            // Move images to database
                            moveImagesToDatabase(images.map((image) => image.imageName + image.imageExtension)).then(() => {
                                // Remove from pending effecting requests
                                pendingEffectingRequests.delete(request);
                                // Success
                                console.log("Request with RequestId successfully finished: ", requestId);
                                request.request.status(200).end();
                            }).catch((e) => {
                                console.log("Error: ", e);
                                // Remove from pending effecting requests
                                pendingEffectingRequests.delete(request);
                                // Try to send error response
                                request.request.status(500).end();
                            })
                        }
                    }
                    // Delete response message
                    (async () => {
                        await sqs.send(new DeleteMessageCommand({
                            QueueUrl: configuration.queueUrl,
                            ReceiptHandle: message.ReceiptHandle,
                        }));
                    })();
                }
            })
        }
    } catch (err) {
        console.log("Error with polling: ", err);
    } finally {
        await polling();
    }
}

app.get("/health-check", async (req, res) => {
    res.status(200).end();
})

const sendMessageToImageCompressionService = async (requestId, fileName, fileExtension) => {
    // Message body
    const messageBody = {
        imageName: fileName,
        imageExtension: fileExtension
    }

    // Send message command
    const command = new SendMessageCommand({
        MessageBody: JSON.stringify(messageBody),
        MessageAttributes: {
            "InstanceId": {
                DataType: "String",
                StringValue: instanceId
            },
            "RequestId": {
                DataType: "String",
                StringValue: requestId
            }
        },
        QueueUrl: configuration.imageCompression.queueUrl,
    });

    // Send message
    const sentMessage = await sqs.send(command);
    console.log('Message with RequestId sent to the image compression queue: ', requestId);

    return sentMessage;
};

const sendMessageToImageEffectingService = async (requestId, fileName, fileExtension) => {
    // Message body
    const messageBody = {
        imageName: fileName,
        imageExtension: fileExtension
    }

    // Send message command
    const command = new SendMessageCommand({
        MessageBody: JSON.stringify(messageBody),
        MessageAttributes: {
            "InstanceId": {
                DataType: "String",
                StringValue: instanceId
            },
            "RequestId": {
                DataType: "String",
                StringValue: requestId
            }
        },
        QueueUrl: configuration.imageEffecting.queueUrl,
    });

    // Send message
    const sentMessage = await sqs.send(command);
    console.log('Message with RequestId sent to the image effecting queue: ', requestId);

    return sentMessage;
};

const moveImagesToDatabase = async (images) => {
    // Get all images from the temporary image store bucket
    const files = await downloadFilesFromTemporaryImageStore(images);

    for (const key in files) {
        const {fileName, fileExtension, data} = files[key];

        // Save image to database
        await connection.query('INSERT INTO images (name, extension, data) VALUES (?, ?, ?)', [
            fileName,
            fileExtension,
            data
        ]);
    }

    // Delete all images from the temporary image store bucket
    await deleteFilesFromTemporaryImageStore(images);
}

const uploadFilesToTemporaryImageStore = async (file) => {
    // Get file extension
    const fileExtension = path.extname(file.originalname);

    // Check if file type is supported
    if (!(fileExtension === '.png' || fileExtension === '.jpg' || fileExtension === '.jpeg')) {
        throw Error("Invalid file - only png, jpg and jpeg is accepted.");
    }

    // Create random file name
    const fileName = new Date().toISOString() + Math.random().toString(36).substring(2, 6);

    // Upload params
    const params = {
        Bucket: configuration.temporaryImageStore.bucketName,
        Key: fileName + fileExtension,
        Body: file.buffer,
        ContentType: file.mimetype
    };

    const s3Command = new PutObjectCommand(params);

    // Upload image to the Temporary Image Store  S3 bucket
    await s3.send(s3Command);

    return {fileName, fileExtension};
};

const downloadFilesFromTemporaryImageStore = async (fileNames) => {
    const files = [];

    for (const fileName of fileNames) {
        const getObjectCommand = new GetObjectCommand({
            Bucket: configuration.temporaryImageStore.bucketName,
            Key: fileName
        });

        const {Body} = await s3.send(getObjectCommand);
        const fileBuffer = await new Promise((resolve, reject) => {
            const chunks = [];
            Body.on('data', (chunk) => chunks.push(chunk));
            Body.on('end', () => resolve(Buffer.concat(chunks)));
            Body.on('error', reject);
        });

        const [name, extension] = fileName.split('.');

        files.push({fileName: name, fileExtension: extension, data: fileBuffer});
    }

    return files;
}

const deleteFilesFromTemporaryImageStore = async (fileNames) => {
    for (const fileName of fileNames) {
        const deleteObjectCommand = new DeleteObjectCommand({
            Bucket: configuration.temporaryImageStore.bucketName,
            Key: fileName
        });
        await s3.send(deleteObjectCommand);
    }
}

app.listen(3000, () => {
    console.log("Server is running on port 3000");
    polling();
});
