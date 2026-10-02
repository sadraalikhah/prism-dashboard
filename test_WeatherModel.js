const assert = require('node:assert/strict');
const m = require('./WeatherModel.js');
assert.equal(m.locationKey(m.location('{"name":"Only a name"}')), '');
assert.equal(m.locationKey(m.location('{"name":"Zero","latitude":0,"longitude":0}')), '0,0');
assert.equal(m.locationKey(m.location('{"latitude":91,"longitude":0}')), '');
assert.equal(m.locationKey(m.location('{"latitude":null,"longitude":null}')), '');
const matches = m.searchResults(JSON.stringify({features:[
 {properties:{name:'Paris',state:'Île-de-France',country:'France'},geometry:{type:'Point',coordinates:[2.35,48.85]}},
 {properties:{name:'Paris',state:'Texas',country:'United States'},geometry:{type:'Point',coordinates:[-95.55,33.66]}},
 {properties:{name:'Invalid'},geometry:{type:'Point',coordinates:[0,null]}}
]}));
assert.equal(matches.length,2);
assert.equal(matches[0].label,'Paris, Île-de-France, France');
assert.equal(matches[1].description,'Texas, United States');
assert.deepEqual(m.searchResults('{"features":[]}'),[]);
assert.throws(()=>m.searchResults('{"results":{}}'));
assert.throws(()=>m.parseForecast('{"current":{"temperature_2m":null}}'));
assert.equal(m.temperature(null),'—');
assert.equal(m.conditions(999).text,'Unknown conditions');
assert.notEqual(m.conditions(0,true).icon,m.conditions(0,false).icon);
const report={current:{temperature_2m:0,weather_code:0},utc_offset_seconds:12600,
 hourly:{time:['2026-10-01T23:00','2026-10-02T00:00','2026-10-02T01:00','2026-10-02T02:00','2026-10-02T03:00','2026-10-02T04:00'],temperature_2m:[1,2,3,4,5,6],weather_code:[0,1,2,3,45,61]},
 daily:{time:['2026-10-01','2026-10-02'],temperature_2m_max:[24,22],temperature_2m_min:[10,8]}};
const now=Date.parse('2026-10-01T20:00:00Z'); // 23:30 in the location, next day at 20:30 UTC.
assert.equal(m.localTime(now,12600),'2026-10-01T23:30');
assert.deepEqual(m.hours(m.parseForecast(JSON.stringify(report)),now).map(x=>x.time),['00:00','03:00']);
assert.deepEqual(m.range(report,now),{high:24,low:10});
assert.deepEqual(m.range(report,now+3600000),{high:22,low:8});
assert.deepEqual(m.range(report,now+3*86400000),{high:null,low:null});
if (process.argv[2]) {
 const live=m.parseForecast(require('node:fs').readFileSync(process.argv[2],'utf8'));
 assert.ok(m.hours(live,Date.now()).length);
}
console.log('Weather model checks passed, including live response, ambiguous cities, zero coordinates and midnight in a half-hour timezone.');
