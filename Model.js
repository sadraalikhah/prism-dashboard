function pad2(value) {
  return (Number(value) < 10 ? "0" : "") + Number(value)
}

function dateKey(date) {
  return date.getFullYear() + "-" + pad2(date.getMonth() + 1) + "-" + pad2(date.getDate())
}

function monthCells(year, month, today) {
  var first = new Date(year, month, 1)
  var leading = (first.getDay() + 6) % 7
  var cursor = new Date(year, month, 1 - leading)
  var todayKey = dateKey(today)
  var cells = []
  for (var i = 0; i < 42; i++) {
    var weekday = cursor.getDay()
    cells.push({
      day: cursor.getDate(),
      inMonth: cursor.getMonth() === month && cursor.getFullYear() === year,
      weekend: weekday === 0 || weekday === 6,
      today: dateKey(cursor) === todayKey
    })
    cursor.setDate(cursor.getDate() + 1)
  }
  return cells
}

function stepMonth(year, month, delta) {
  var date = new Date(year, month + delta, 1)
  return { year: date.getFullYear(), month: date.getMonth() }
}
