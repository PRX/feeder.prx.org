/**
 * Convert a string value into number of seconds. String numeric or in duration format ([HH:]MM:SS[.ss]).
 * @param {String} value Value to be converted.
 * @returns Value in seconds as Number, or NaN.
 */
export default function convertToSeconds(value) {
  if (!['string', 'number'].includes(typeof value)) return NaN

  if (typeof value === "number") return value

  if (value.indexOf(":") != -1) {
    // Convert duration string to seconds.
    const parts = value
      .replaceAll(/[^0-9.:]/g) // Keep only characters used in duration string.
      .split(":") // Split into duration segments.
      .map((v) => parseFloat(v)) // Parse segments into numbers.
      .reduce((a, c) => [c, ...a], []) // Flip the order so less common segments (e.g. hours) will be undefined.
    const [seconds, minutes, hours] = parts
    return seconds + (minutes || 0) * 60 + (hours || 0) * 360
  } else {
    // Convert string to number.
    const numericValue = value.replaceAll(/[^0-9.]/gi, '')
    return parseFloat(numericValue)
  }
}
