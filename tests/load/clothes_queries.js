import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  stages: [
    { duration: '1m', target: 150 },
    { duration: '3m', target: 150 },
    { duration: '1m', target: 0 },
  ],
  thresholds: {
    http_req_duration: ['p(95)<300'],
    http_req_failed: ['rate<0.01'],
  },
};

const BASE_URL = __ENV.API_BASE_URL || 'http://localhost:8000';
const USER_ID = __ENV.TEST_USER_ID || 142;

export default function () {
  const clothesRes = http.get(`${BASE_URL}/clothes/user/${USER_ID}`);
  check(clothesRes, {
    'clothes 200': (r) => r.status === 200,
  });

  const analyticsRes = http.get(
    `${BASE_URL}/wardrobe/analytics/most-worn?user_id=${USER_ID}`,
  );
  check(analyticsRes, {
    'analytics 200': (r) => r.status === 200,
  });

  sleep(1);
}
