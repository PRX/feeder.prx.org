const MAPPING = {
  "Africa/Abidjan": "Monrovia",
  "Africa/Accra": "Monrovia",
  "Africa/Addis_Ababa": "Nairobi",
  "Africa/Algiers": "West Central Africa",
  "Africa/Asmera": "Nairobi",
  "Africa/Bamako": "Monrovia",
  "Africa/Bangui": "West Central Africa",
  "Africa/Banjul": "Monrovia",
  "Africa/Bissau": "Monrovia",
  "Africa/Blantyre": "Harare",
  "Africa/Brazzaville": "West Central Africa",
  "Africa/Bujumbura": "Harare",
  "Africa/Cairo": "Cairo",
  "Africa/Casablanca": "Casablanca",
  "Africa/Ceuta": "Brussels",
  "Africa/Conakry": "Monrovia",
  "Africa/Dakar": "Monrovia",
  "Africa/Dar_es_Salaam": "Nairobi",
  "Africa/Djibouti": "Nairobi",
  "Africa/Douala": "West Central Africa",
  "Africa/El_Aaiun": "Casablanca",
  "Africa/Freetown": "Monrovia",
  "Africa/Gaborone": "Harare",
  "Africa/Harare": "Harare",
  "Africa/Johannesburg": "Pretoria",
  "Africa/Juba": "Nairobi",
  "Africa/Kampala": "Nairobi",
  "Africa/Khartoum": "Nairobi",
  "Africa/Kigali": "Harare",
  "Africa/Kinshasa": "West Central Africa",
  "Africa/Lagos": "West Central Africa",
  "Africa/Libreville": "West Central Africa",
  "Africa/Lome": "Monrovia",
  "Africa/Luanda": "West Central Africa",
  "Africa/Lubumbashi": "Harare",
  "Africa/Lusaka": "Harare",
  "Africa/Malabo": "West Central Africa",
  "Africa/Maputo": "Harare",
  "Africa/Maseru": "Harare",
  "Africa/Mbabane": "Harare",
  "Africa/Mogadishu": "Nairobi",
  "Africa/Monrovia": "Monrovia",
  "Africa/Nairobi": "Nairobi",
  "Africa/Ndjamena": "West Central Africa",
  "Africa/Niamey": "West Central Africa",
  "Africa/Nouakchott": "Monrovia",
  "Africa/Ouagadougou": "Monrovia",
  "Africa/Porto-Novo": "West Central Africa",
  "Africa/Sao_Tome": "Monrovia",
  "Africa/Tunis": "West Central Africa",
  "America/Anchorage": "Alaska",
  "America/Anguilla": "Georgetown",
  "America/Antigua": "Georgetown",
  "America/Argentina/Buenos_Aires": "Buenos Aires",
  "America/Argentina/La_Rioja": "Buenos Aires",
  "America/Argentina/Rio_Gallegos": "Buenos Aires",
  "America/Argentina/Salta": "Buenos Aires",
  "America/Argentina/San_Juan": "Buenos Aires",
  "America/Argentina/San_Luis": "Buenos Aires",
  "America/Argentina/Tucuman": "Buenos Aires",
  "America/Argentina/Ushuaia": "Buenos Aires",
  "America/Aruba": "Georgetown",
  "America/Bahia_Banderas": "Guadalajara",
  "America/Barbados": "Georgetown",
  "America/Belize": "Central America",
  "America/Blanc-Sablon": "Georgetown",
  "America/Boa_Vista": "Georgetown",
  "America/Bogota": "Bogota",
  "America/Boise": "Mountain Time (US & Canada)",
  "America/Buenos_Aires": "Buenos Aires",
  "America/Cambridge_Bay": "Mountain Time (US & Canada)",
  "America/Caracas": "Caracas",
  "America/Catamarca": "Buenos Aires",
  "America/Cayman": "Bogota",
  "America/Chicago": "Central Time (US & Canada)",
  "America/Chihuahua": "Chihuahua",
  "America/Coral_Harbour": "Bogota",
  "America/Cordoba": "Buenos Aires",
  "America/Costa_Rica": "Central America",
  "America/Creston": "Arizona",
  "America/Curacao": "Georgetown",
  "America/Danmarkshavn": "UTC",
  "America/Dawson": "Pacific Time (US & Canada)",
  "America/Dawson_Creek": "Arizona",
  "America/Denver": "Mountain Time (US & Canada)",
  "America/Detroit": "Eastern Time (US & Canada)",
  "America/Dominica": "Georgetown",
  "America/Edmonton": "Mountain Time (US & Canada)",
  "America/Eirunepe": "Bogota",
  "America/El_Salvador": "Central America",
  "America/Glace_Bay": "Atlantic Time (Canada)",
  "America/Godthab": "Greenland",
  "America/Goose_Bay": "Atlantic Time (Canada)",
  "America/Grand_Turk": "Georgetown",
  "America/Grenada": "Georgetown",
  "America/Guadeloupe": "Georgetown",
  "America/Guatemala": "Central America",
  "America/Guayaquil": "Bogota",
  "America/Guyana": "Georgetown",
  "America/Halifax": "Atlantic Time (Canada)",
  "America/Havana": "Eastern Time (US & Canada)",
  "America/Hermosillo": "Arizona",
  "America/Indiana/Indianapolis": "Indiana (East)",
  "America/Indiana/Knox": "Central Time (US & Canada)",
  "America/Indiana/Marengo": "Indiana (East)",
  "America/Indiana/Petersburg": "Eastern Time (US & Canada)",
  "America/Indiana/Tell_City": "Central Time (US & Canada)",
  "America/Indiana/Vevay": "Indiana (East)",
  "America/Indiana/Vincennes": "Eastern Time (US & Canada)",
  "America/Indiana/Winamac": "Eastern Time (US & Canada)",
  "America/Indianapolis": "Indiana (East)",
  "America/Inuvik": "Mountain Time (US & Canada)",
  "America/Iqaluit": "Eastern Time (US & Canada)",
  "America/Jamaica": "Bogota",
  "America/Jujuy": "Buenos Aires",
  "America/Juneau": "Alaska",
  "America/Kentucky/Monticello": "Eastern Time (US & Canada)",
  "America/Kralendijk": "Georgetown",
  "America/La_Paz": "La Paz",
  "America/Lima": "Lima",
  "America/Los_Angeles": "Pacific Time (US & Canada)",
  "America/Louisville": "Eastern Time (US & Canada)",
  "America/Lower_Princes": "Georgetown",
  "America/Managua": "Central America",
  "America/Manaus": "Georgetown",
  "America/Marigot": "Georgetown",
  "America/Martinique": "Georgetown",
  "America/Matamoros": "Central Time (US & Canada)",
  "America/Mazatlan": "Mazatlan",
  "America/Mendoza": "Buenos Aires",
  "America/Menominee": "Central Time (US & Canada)",
  "America/Merida": "Guadalajara",
  "America/Mexico_City": "Mexico City",
  "America/Moncton": "Atlantic Time (Canada)",
  "America/Monterrey": "Monterrey",
  "America/Montevideo": "Montevideo",
  "America/Montreal": "Eastern Time (US & Canada)",
  "America/Montserrat": "Georgetown",
  "America/Nassau": "Eastern Time (US & Canada)",
  "America/New_York": "Eastern Time (US & Canada)",
  "America/Nipigon": "Eastern Time (US & Canada)",
  "America/Nome": "Alaska",
  "America/Noronha": "Harare",
  "America/North_Dakota/Beulah": "Central Time (US & Canada)",
  "America/North_Dakota/Center": "Central Time (US & Canada)",
  "America/North_Dakota/New_Salem": "Central Time (US & Canada)",
  "America/Ojinaga": "Mountain Time (US & Canada)",
  "America/Panama": "Bogota",
  "America/Pangnirtung": "Eastern Time (US & Canada)",
  "America/Phoenix": "Arizona",
  "America/Port-au-Prince": "Eastern Time (US & Canada)",
  "America/Port_of_Spain": "Georgetown",
  "America/Porto_Velho": "Georgetown",
  "America/Puerto_Rico": "Georgetown",
  "America/Rainy_River": "Central Time (US & Canada)",
  "America/Rankin_Inlet": "Central Time (US & Canada)",
  "America/Regina": "Saskatchewan",
  "America/Resolute": "Central Time (US & Canada)",
  "America/Rio_Branco": "Bogota",
  "America/Santiago": "Santiago",
  "America/Santo_Domingo": "Georgetown",
  "America/Sao_Paulo": "Brasilia",
  "America/Scoresbysund": "Azores",
  "America/Sitka": "Alaska",
  "America/St_Barthelemy": "Georgetown",
  "America/St_Johns": "Newfoundland",
  "America/St_Kitts": "Georgetown",
  "America/St_Lucia": "Georgetown",
  "America/St_Thomas": "Georgetown",
  "America/St_Vincent": "Georgetown",
  "America/Swift_Current": "Saskatchewan",
  "America/Tegucigalpa": "Central America",
  "America/Thule": "Atlantic Time (Canada)",
  "America/Thunder_Bay": "Eastern Time (US & Canada)",
  "America/Tijuana": "Tijuana",
  "America/Toronto": "Eastern Time (US & Canada)",
  "America/Tortola": "Georgetown",
  "America/Vancouver": "Pacific Time (US & Canada)",
  "America/Whitehorse": "Pacific Time (US & Canada)",
  "America/Winnipeg": "Central Time (US & Canada)",
  "America/Yakutat": "Alaska",
  "America/Yellowknife": "Mountain Time (US & Canada)",
  "Antarctica/Casey": "Perth",
  "Antarctica/Davis": "Bangkok",
  "Antarctica/DumontDUrville": "Guam",
  "Antarctica/Macquarie": "Solomon Is.",
  "Antarctica/McMurdo": "Auckland",
  "Antarctica/Palmer": "Santiago",
  "Antarctica/Syowa": "Nairobi",
  "Antarctica/Vostok": "Astana",
  "Arctic/Longyearbyen": "Amsterdam",
  "Asia/Aden": "Kuwait",
  "Asia/Almaty": "Almaty",
  "Asia/Baghdad": "Baghdad",
  "Asia/Bahrain": "Kuwait",
  "Asia/Baku": "Baku",
  "Asia/Bangkok": "Bangkok",
  "Asia/Bishkek": "Astana",
  "Asia/Brunei": "Kuala Lumpur",
  "Asia/Calcutta": "Chennai",
  "Asia/Choibalsan": "Ulaanbaatar",
  "Asia/Chongqing": "Chongqing",
  "Asia/Colombo": "Sri Jayawardenepura",
  "Asia/Dhaka": "Dhaka",
  "Asia/Dili": "Osaka",
  "Asia/Dubai": "Abu Dhabi",
  "Asia/Hong_Kong": "Hong Kong",
  "Asia/Hovd": "Bangkok",
  "Asia/Irkutsk": "Irkutsk",
  "Asia/Jakarta": "Jakarta",
  "Asia/Jayapura": "Osaka",
  "Asia/Jerusalem": "Jerusalem",
  "Asia/Kabul": "Kabul",
  "Asia/Kamchatka": "Kamchatka",
  "Asia/Karachi": "Karachi",
  "Asia/Kathmandu": "Kathmandu",
  "Asia/Katmandu": "Kathmandu",
  "Asia/Khandyga": "Yakutsk",
  "Asia/Kolkata": "Kolkata",
  "Asia/Krasnoyarsk": "Krasnoyarsk",
  "Asia/Kuala_Lumpur": "Kuala Lumpur",
  "Asia/Kuching": "Kuala Lumpur",
  "Asia/Kuwait": "Kuwait",
  "Asia/Macau": "Beijing",
  "Asia/Magadan": "Magadan",
  "Asia/Makassar": "Kuala Lumpur",
  "Asia/Manila": "Kuala Lumpur",
  "Asia/Muscat": "Muscat",
  "Asia/Nicosia": "Athens",
  "Asia/Novokuznetsk": "Krasnoyarsk",
  "Asia/Novosibirsk": "Novosibirsk",
  "Asia/Omsk": "Novosibirsk",
  "Asia/Phnom_Penh": "Bangkok",
  "Asia/Pontianak": "Bangkok",
  "Asia/Qatar": "Kuwait",
  "Asia/Qyzylorda": "Astana",
  "Asia/Rangoon": "Rangoon",
  "Asia/Riyadh": "Riyadh",
  "Asia/Saigon": "Bangkok",
  "Asia/Sakhalin": "Magadan",
  "Asia/Seoul": "Seoul",
  "Asia/Shanghai": "Beijing",
  "Asia/Singapore": "Singapore",
  "Asia/Srednekolymsk": "Srednekolymsk",
  "Asia/Taipei": "Taipei",
  "Asia/Tashkent": "Tashkent",
  "Asia/Tbilisi": "Tbilisi",
  "Asia/Tehran": "Tehran",
  "Asia/Thimphu": "Dhaka",
  "Asia/Tokyo": "Tokyo",
  "Asia/Ulaanbaatar": "Ulaanbaatar",
  "Asia/Urumqi": "Urumqi",
  "Asia/Ust-Nera": "Magadan",
  "Asia/Vientiane": "Bangkok",
  "Asia/Vladivostok": "Vladivostok",
  "Asia/Yakutsk": "Yakutsk",
  "Asia/Yekaterinburg": "Ekaterinburg",
  "Asia/Yerevan": "Yerevan",
  "Atlantic/Azores": "Azores",
  "Atlantic/Bermuda": "Atlantic Time (Canada)",
  "Atlantic/Canary": "Dublin",
  "Atlantic/Cape_Verde": "Cape Verde Is.",
  "Atlantic/Faeroe": "Dublin",
  "Atlantic/Madeira": "Dublin",
  "Atlantic/Reykjavik": "Monrovia",
  "Atlantic/South_Georgia": "Mid-Atlantic",
  "Atlantic/St_Helena": "Monrovia",
  "Australia/Adelaide": "Adelaide",
  "Australia/Brisbane": "Brisbane",
  "Australia/Broken_Hill": "Adelaide",
  "Australia/Currie": "Hobart",
  "Australia/Darwin": "Darwin",
  "Australia/Hobart": "Hobart",
  "Australia/Lindeman": "Brisbane",
  "Australia/Melbourne": "Melbourne",
  "Australia/Perth": "Perth",
  "Australia/Sydney": "Sydney",
  CST6CDT: "Central Time (US & Canada)",
  EST5EDT: "Eastern Time (US & Canada)",
  "Etc/GMT": "UTC",
  "Etc/GMT+0": "UTC",
  "Etc/GMT+10": "Hawaii",
  "Etc/GMT+11": "Solomon Is.",
  "Etc/GMT+12": "International Date Line West",
  "Etc/GMT+2": "Harare",
  "Etc/GMT+4": "Georgetown",
  "Etc/GMT+5": "Bogota",
  "Etc/GMT+6": "Central America",
  "Etc/GMT+7": "Arizona",
  "Etc/GMT-0": "UTC",
  "Etc/GMT-1": "West Central Africa",
  "Etc/GMT-10": "Guam",
  "Etc/GMT-11": "Solomon Is.",
  "Etc/GMT-12": "International Date Line West",
  "Etc/GMT-13": "Nuku'alofa",
  "Etc/GMT-2": "Harare",
  "Etc/GMT-3": "Nairobi",
  "Etc/GMT-4": "Abu Dhabi",
  "Etc/GMT-6": "Astana",
  "Etc/GMT-7": "Bangkok",
  "Etc/GMT-8": "Kuala Lumpur",
  "Etc/GMT-9": "Osaka",
  "Etc/GMT0": "UTC",
  "Etc/Greenwich": "UTC",
  "Etc/UCT": "UTC",
  "Etc/UTC": "UTC",
  "Etc/Universal": "UTC",
  "Etc/Zulu": "UTC",
  "Europe/Amsterdam": "Amsterdam",
  "Europe/Andorra": "Amsterdam",
  "Europe/Athens": "Athens",
  "Europe/Belfast": "London",
  "Europe/Belgrade": "Belgrade",
  "Europe/Berlin": "Berlin",
  "Europe/Bratislava": "Bratislava",
  "Europe/Brussels": "Brussels",
  "Europe/Bucharest": "Bucharest",
  "Europe/Budapest": "Budapest",
  "Europe/Busingen": "Amsterdam",
  "Europe/Chisinau": "Athens",
  "Europe/Copenhagen": "Copenhagen",
  "Europe/Dublin": "Dublin",
  "Europe/Gibraltar": "Amsterdam",
  "Europe/Guernsey": "Dublin",
  "Europe/Helsinki": "Helsinki",
  "Europe/Isle_of_Man": "Dublin",
  "Europe/Istanbul": "Istanbul",
  "Europe/Jersey": "Dublin",
  "Europe/Kaliningrad": "Kaliningrad",
  "Europe/Kiev": "Kyiv",
  "Europe/Lisbon": "Lisbon",
  "Europe/Ljubljana": "Ljubljana",
  "Europe/London": "London",
  "Europe/Luxembourg": "Amsterdam",
  "Europe/Madrid": "Madrid",
  "Europe/Malta": "Amsterdam",
  "Europe/Mariehamn": "Helsinki",
  "Europe/Minsk": "Minsk",
  "Europe/Monaco": "Amsterdam",
  "Europe/Moscow": "Moscow",
  "Europe/Oslo": "Amsterdam",
  "Europe/Paris": "Paris",
  "Europe/Podgorica": "Belgrade",
  "Europe/Prague": "Prague",
  "Europe/Riga": "Riga",
  "Europe/Rome": "Rome",
  "Europe/Samara": "Samara",
  "Europe/San_Marino": "Amsterdam",
  "Europe/Sarajevo": "Sarajevo",
  "Europe/Simferopol": "Moscow",
  "Europe/Skopje": "Skopje",
  "Europe/Sofia": "Sofia",
  "Europe/Stockholm": "Stockholm",
  "Europe/Tallinn": "Tallinn",
  "Europe/Tirane": "Belgrade",
  "Europe/Uzhgorod": "Helsinki",
  "Europe/Vaduz": "Amsterdam",
  "Europe/Vatican": "Amsterdam",
  "Europe/Vienna": "Vienna",
  "Europe/Vilnius": "Vilnius",
  "Europe/Volgograd": "Volgograd",
  "Europe/Warsaw": "Warsaw",
  "Europe/Zagreb": "Zagreb",
  "Europe/Zaporozhye": "Helsinki",
  "Europe/Zurich": "Amsterdam",
  GB: "London",
  "GB-Eire": "London",
  GMT: "UTC",
  "GMT+0": "UTC",
  "GMT-0": "UTC",
  GMT0: "UTC",
  Greenwich: "UTC",
  "Indian/Antananarivo": "Nairobi",
  "Indian/Chagos": "Astana",
  "Indian/Christmas": "Bangkok",
  "Indian/Comoro": "Nairobi",
  "Indian/Mayotte": "Nairobi",
  MST7MDT: "Mountain Time (US & Canada)",
  PST8PDT: "Pacific Time (US & Canada)",
  "Pacific/Apia": "Samoa",
  "Pacific/Auckland": "Auckland",
  "Pacific/Bougainville": "Solomon Is.",
  "Pacific/Chatham": "Chatham Is.",
  "Pacific/Efate": "Solomon Is.",
  "Pacific/Enderbury": "Nuku'alofa",
  "Pacific/Fakaofo": "Tokelau Is.",
  "Pacific/Fiji": "Fiji",
  "Pacific/Funafuti": "International Date Line West",
  "Pacific/Galapagos": "Central America",
  "Pacific/Guadalcanal": "Solomon Is.",
  "Pacific/Guam": "Guam",
  "Pacific/Honolulu": "Hawaii",
  "Pacific/Johnston": "Hawaii",
  "Pacific/Kosrae": "Solomon Is.",
  "Pacific/Kwajalein": "International Date Line West",
  "Pacific/Majuro": "Marshall Is.",
  "Pacific/Midway": "Midway Island",
  "Pacific/Nauru": "International Date Line West",
  "Pacific/Niue": "Solomon Is.",
  "Pacific/Noumea": "New Caledonia",
  "Pacific/Pago_Pago": "American Samoa",
  "Pacific/Palau": "Osaka",
  "Pacific/Ponape": "Solomon Is.",
  "Pacific/Port_Moresby": "Port Moresby",
  "Pacific/Rarotonga": "Hawaii",
  "Pacific/Saipan": "Guam",
  "Pacific/Tahiti": "Hawaii",
  "Pacific/Tarawa": "International Date Line West",
  "Pacific/Tongatapu": "Nuku'alofa",
  "Pacific/Truk": "Guam",
  "Pacific/Wake": "International Date Line West",
  "Pacific/Wallis": "International Date Line West",
  UCT: "UTC",
  "US/Alaska": "Alaska",
  "US/Aleutian": "Alaska",
  "US/Arizona": "Arizona",
  "US/Central": "Central America",
  "US/East-Indiana": "Indiana (East)",
  "US/Eastern": "Eastern Time (US & Canada)",
  "US/Hawaii": "Hawaii",
  "US/Indiana-Starke": "Indiana (East)",
  "US/Michigan": "Eastern Time (US & Canada)",
  "US/Mountain": "Mountain Time (US & Canada)",
  "US/Pacific": "Pacific Time (US & Canada)",
  "US/Pacific-New": "Pacific Time (US & Canada)",
  "US/Samoa": "Samoa",
  UTC: "UTC",
  Universal: "UTC",
  WET: "UTC",
  Zulu: "UTC",
}

/**
 * Best effort to convert IANA/other common timezone names to ActiveSupport "friendly" names
 * @param {String} zone Timezone string
 * @returns Friendly timezone string or null.
 */
export default function lookupFriendlyTimeZone(zone) {
  return MAPPING[zone] || null
}
