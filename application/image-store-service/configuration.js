export const configuration = {
    region: process.env.AWS_REGION,
    queueUrl: process.env.QUEUE_URL,
    database: {
        address: process.env.IMAGE_STORE_DATABASE_ADDRESS,
        name: process.env.IMAGE_STORE_DATABASE_NAME,
        user: process.env.IMAGE_STORE_DATABASE_USER,
        password: process.env.IMAGE_STORE_DATABASE_PASSWORD,
    },
    temporaryImageStore: {
        bucketName: process.env.TEMPORARY_IMAGE_STORE_BUCKET_NAME,
    },
    imageCompression: {
        queueUrl: process.env.IMAGE_COMPRESSION_QUEUE_URL,
    },
    imageEffecting: {
        queueUrl: process.env.IMAGE_EFFECTING_QUEUE_URL,
    }
};