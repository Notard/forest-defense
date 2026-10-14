/**
 * 숲 지키기 플레이 기록 받기 (16-4단계).
 *
 * 구글 시트 → 확장 프로그램 → Apps Script에 이 파일을 통째로 붙여 넣고 웹 앱으로 배포한다.
 * 자세한 순서는 tools/sheets/README.md.
 *
 * 게임이 사건마다 JSON 한 줄을 POST로 보낸다 (Content-Type: text/plain).
 *   open  : 앱을 켬 (first = 처음 켠 기기인지)
 *   start : 판 시작
 *   end   : 판 끝 (result = won · lost · quit-retry · quit-map)
 * 개인 정보는 없다: id는 기기마다 무작위로 만든 번호다.
 */

const PLAYS = 'plays';
const SUMMARY = 'summary';
const FIELDS = ['received', 't', 'event', 'id', 'v', 'plat', 'lang', 'diff', 'stage', 'result', 'sec', 'wave',
  'hearts', 'defeated', 'stars', 'placed', 'levelups', 'first', 'extra'];
const EVENTS = ['open', 'start', 'end'];
const MAX_BODY = 4000;

/** 게임이 보내는 기록을 받는다. */
function doPost(e) {
  try {
    const text = (e && e.postData && e.postData.contents) || '';
    if (text.length > MAX_BODY) return out_('too long');
    const row = JSON.parse(text);
    if (!row || EVENTS.indexOf(row.event) < 0) return out_('unknown event');
    const known = {};
    FIELDS.forEach(function (f) { known[f] = true; });
    const extra = {};
    Object.keys(row).forEach(function (k) { if (!known[k]) extra[k] = row[k]; });
    row.extra = Object.keys(extra).length ? JSON.stringify(extra) : '';
    const values = FIELDS.map(function (f, i) { return i === 0 ? new Date() : clip_(row[f]); });
    const lock = LockService.getScriptLock();
    lock.waitLock(5000);
    try {
      plays_().appendRow(values);
    } finally {
      lock.releaseLock();
    }
    return out_('ok');
  } catch (err) {
    return out_('error');
  }
}

/** 브라우저로 주소를 열면 "ok" (배포가 됐는지 확인용). */
function doGet() {
  return out_('ok');
}

/** 처음 한 번 실행: plays 탭 머리줄과 summary 탭 요약 수식을 만든다. 다시 실행해도 된다. */
function setup() {
  plays_();
  const book = SpreadsheetApp.getActiveSpreadsheet();
  const sheet = book.getSheetByName(SUMMARY) || book.insertSheet(SUMMARY);
  sheet.clear();
  const src = PLAYS + '!A:S';
  const blocks = [
    ['기기 수 (처음 켠 기기)', '=COUNTIFS(' + PLAYS + '!C:C,"open",' + PLAYS + '!R:R,TRUE)'],
    ['기기 수 (기록이 있는)', '=COUNTUNIQUE(' + PLAYS + '!D2:D)'],
    ['스테이지별 시작 수', '=QUERY(' + src + ',"select I, count(D) where C=\'start\' group by I label count(D) \'시작\'",1)'],
    ['스테이지별 끝 (이김·짐·나감)', '=QUERY(' + src + ',"select I, count(D) where C=\'end\' group by I pivot J",1)'],
    ['이긴 판 평균 시간(초)', '=QUERY(' + src + ',"select I, avg(K) where C=\'end\' and J=\'won\' group by I label avg(K) \'평균 초\'",1)'],
    ['난이도별 끝', '=QUERY(' + src + ',"select H, count(D) where C=\'end\' group by H pivot J",1)'],
    ['기기·브라우저별 켬', '=QUERY(' + src + ',"select F, count(D) where C=\'open\' group by F label count(D) \'켬\'",1)'],
    ['언어별 켬', '=QUERY(' + src + ',"select G, count(D) where C=\'open\' group by G label count(D) \'켬\'",1)'],
  ];
  let col = 1;
  blocks.forEach(function (b) {
    sheet.getRange(1, col).setValue(b[0]).setFontWeight('bold');
    sheet.getRange(2, col).setFormula(b[1]);
    col += 5;
  });
}

function plays_() {
  const book = SpreadsheetApp.getActiveSpreadsheet();
  let sheet = book.getSheetByName(PLAYS);
  if (!sheet) {
    sheet = book.insertSheet(PLAYS, 0);
    sheet.appendRow(FIELDS);
    sheet.setFrozenRows(1);
    sheet.getRange(1, 1, 1, FIELDS.length).setFontWeight('bold');
  }
  return sheet;
}

function clip_(v) {
  if (v === undefined || v === null) return '';
  if (typeof v === 'number' || typeof v === 'boolean') return v;
  const s = String(v);
  return s.length > 200 ? s.slice(0, 200) : s;
}

function out_(text) {
  return ContentService.createTextOutput(text).setMimeType(ContentService.MimeType.TEXT);
}
