import test from 'node:test';
import assert from 'node:assert/strict';
import {
  parseTimeToMinutes,
  isTimeInInterval,
  getAlgiersTime,
  getWorkingHoursConfig,
  saveWorkingHoursConfig,
  getAutoClosedCourierIds,
  saveAutoClosedCourierIds,
  updateCourierSchedule,
} from './deliveryWorkingHoursService.js';

test('parseTimeToMinutes handles standard and edge-case time strings', () => {
  assert.equal(parseTimeToMinutes('11:00'), 660);
  assert.equal(parseTimeToMinutes('22:00'), 1320);
  assert.equal(parseTimeToMinutes('00:00'), 0);
  assert.equal(parseTimeToMinutes('24:00'), 1440);
  assert.equal(parseTimeToMinutes('24:00:00'), 1440);
  assert.equal(parseTimeToMinutes('01:30'), 90);
  assert.equal(parseTimeToMinutes('23:59'), 1439);
  assert.equal(parseTimeToMinutes('', 500), 500);
  assert.equal(parseTimeToMinutes(null, 500), 500);
  assert.equal(parseTimeToMinutes('invalid', 500), 500);
});

test('isTimeInInterval handles standard daytime shifts', () => {
  // 11:00 (660) to 22:00 (1320)
  assert.equal(isTimeInInterval(659, 660, 1320), false, '10:59 is closed');
  assert.equal(isTimeInInterval(660, 660, 1320), true, '11:00 is open');
  assert.equal(isTimeInInterval(800, 660, 1320), true, '13:20 is open');
  assert.equal(isTimeInInterval(1319, 660, 1320), true, '21:59 is open');
  assert.equal(isTimeInInterval(1320, 660, 1320), false, '22:00 is closed');
  assert.equal(isTimeInInterval(380, 660, 1320), false, '06:20 is closed');
  assert.equal(isTimeInInterval(0, 660, 1320), false, '00:00 is closed');
});

test('isTimeInInterval handles overnight shifts', () => {
  // 22:00 (1320) to 06:00 (360)
  assert.equal(isTimeInInterval(1319, 1320, 360), false, '21:59 is closed');
  assert.equal(isTimeInInterval(1320, 1320, 360), true, '22:00 is open');
  assert.equal(isTimeInInterval(1400, 1320, 360), true, '23:20 is open');
  assert.equal(isTimeInInterval(0, 1320, 360), true, '00:00 is open');
  assert.equal(isTimeInInterval(180, 1320, 360), true, '03:00 is open');
  assert.equal(isTimeInInterval(359, 1320, 360), true, '05:59 is open');
  assert.equal(isTimeInInterval(360, 1320, 360), false, '06:00 is closed');
  assert.equal(isTimeInInterval(660, 1320, 360), false, '11:00 is closed');
});

test('isTimeInInterval handles 24/7 schedules', () => {
  assert.equal(isTimeInInterval(0, 0, 1440), true);
  assert.equal(isTimeInInterval(720, 0, 1440), true);
  assert.equal(isTimeInInterval(1439, 0, 1440), true);
  assert.equal(isTimeInInterval(500, 500, 500), true);
});

test('getAlgiersTime returns valid Africa/Algiers wall-clock components', () => {
  const t = getAlgiersTime(new Date('2026-11-08T10:30:00Z')); // UTC 10:30 -> DZ 11:30
  assert.equal(t.hours, 11);
  assert.equal(t.minutes, 30);
  assert.equal(t.timeString, '11:30');
  assert.equal(t.totalMinutes, 690);
});
