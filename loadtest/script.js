import http from 'k6/http';
import {check} from 'k6';
import {FormData} from 'https://jslib.k6.io/formdata/0.0.2/index.js';
import {sleep} from 'k6';

const DNS_NAME = "LOAD_BALANCER_URL";

const img = open('./images/image-01.jpg', 'b');

/**
 * Load Test
 */
export const options = {
    stages: [
        { duration: '5m', target: 6, gracefulStop: '5m' },
        { duration: '20m', target: 6, gracefulStop: '5m' },
        { duration: '5m', target: 0, gracefulStop: '5m' },
    ],
    noConnectionReuse: true
};

/**
 * Stress Test
 */
// export const options = {
//     stages: [
//         { duration: '10m', target: 12, gracefulStop: '5m' },
//         { duration: '30m', target: 12, gracefulStop: '5m' },
//         { duration: '10m', target: 0, gracefulStop: '5m' },
//     ],
//     noConnectionReuse: true
// };

/**
 * Spike Test
 */
// export const options = {
//     stages: [
//         { duration: '1m', target: 48, gracefulStop: '5m' },
//         { duration: '5m', target: 48, gracefulStop: '5m' },
//         { duration: '1m', target: 0, gracefulStop: '5m' },
//     ],
//     noConnectionReuse: true
// };

export default function () {
    const fd = new FormData();

    fd.append('file', http.file(img, 'image.jpg', 'image/jpeg'));

    const res = http.post(`http://${DNS_NAME}/upload`, fd.body(), {
        headers: {'Content-Type': 'multipart/form-data; boundary=' + fd.boundary, timeout: '60'},
    });

    check(res, {
        'is status 200': (r) => r.status === 200,
    });

    sleep(1);
}