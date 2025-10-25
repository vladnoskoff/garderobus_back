import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate } from 'k6/metrics';

export const errorRate = new Rate('http_req_failed');

export const options = {
  stages: [
    { duration: '1m', target: 25 },
    { duration: '3m', target: 50 },
    { duration: '1m', target: 10 },
  ],
  thresholds: {
    http_req_failed: ['rate<0.01'],
    http_req_duration: ['p(95)<750'],
    errorRate: ['rate<0.01'],
  },
};

const BASE_URL = __ENV.BASE_URL || 'http://localhost:8080';

export default function () {
  const responses = http.batch([
    ['GET', `${BASE_URL}/healthz`],
    ['GET', `${BASE_URL}/weather/user/1`],
  ]);

  responses.forEach((res) => {
    const ok = check(res, {
      'status is 2xx': (r) => r.status >= 200 && r.status < 300,
    });
    errorRate.add(!ok);
  });

  sleep(1);
}
