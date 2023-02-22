/**
 * Convert a number into string in duration format ([HH:]MM:SS[.ss]).
 * @param {Number} inputSeconds Number of seconds to convert to duration format.
 * @returns Seconds formatted in duration format.
 */
export default function convertSecondsToDuration(inputSeconds) {
  // Default to zero seconds representation.
  let duration = "00:00"

  // Treat unsupported types as zero seconds input.
  if (["number", "string"].indexOf(typeof inputSeconds) === -1) return duration

  // Sanitize string input to expected characters.
  const sanitizedStringInput = typeof inputSeconds === "string" && inputSeconds.replaceAll(/[^0-9:.]/g, "")

  // Convert sanitized string input to number.
  const totalSeconds = sanitizedStringInput ? parseFloat(sanitizedStringInput) : inputSeconds

  // Ensure we are working with a number greater than zero.
  if (!Number.isNaN(totalSeconds) && totalSeconds > 0) {
    const hours = Math.floor(totalSeconds / 3600)
    const minutes = Math.floor((totalSeconds % 3600) / 60)
    const seconds = (totalSeconds % 60).toFixed(2)

    duration = [
      ...(hours ? [hours] : []),
      String(minutes).padStart(2, "0"),
      seconds > 9 ? seconds : `0${seconds}`,
    ].join(":")
  }

  return duration
}
