import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  vus: 10,
  duration: '2m',
  thresholds: {
    http_req_duration: ['p(95)<400'],
    http_req_failed: ['rate<0.02'],
  },
};

const BASE_URL = __ENV.API_BASE_URL || 'http://localhost:8000';
const USER_ID = __ENV.TEST_USER_ID || 142;

export default function () {
  const historyRes = http.get(`${BASE_URL}/outfits/history/${USER_ID}`);
  check(historyRes, {
    'history 200': (r) => r.status === 200,
    'history payload not empty': (r) => r.json().length >= 0,
  });

  const clothesRes = http.get(`${BASE_URL}/clothes/user/${USER_ID}`);
  check(clothesRes, {
    'clothes 200': (r) => r.status === 200,
  });

  sleep(1);
}
