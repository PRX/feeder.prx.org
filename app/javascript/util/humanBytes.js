/**
 * Convert an integer number of bytes to a human readable string.
 * @param {Integer} value Value to be converted.
 * @returns Value the human readable String
 */
export default function humanBytes(value) {
  if (value) {
    const i = Math.floor(Math.log(value) / Math.log(1024))
    const units = ["B", "kB", "MB", "GB", "TB"][i]
    return (value / Math.pow(1024, i)).toFixed(2) * 1 + " " + units
  } else {
    return "0 B"
  }
}
