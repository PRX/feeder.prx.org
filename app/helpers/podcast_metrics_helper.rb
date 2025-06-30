module PodcastMetricsHelper
  AGENT_TAGS = {
    "0": "Unknown",
    "1": "HermesPod",
    "2": "Acast",
    "3": "Alexa",
    "4": "AllYouCanBooks",
    "5": "AntennaPod",
    "6": "Breaker",
    "7": "Castaway",
    "8": "CastBox",
    "9": "Castro",
    "10": "Clementine",
    "11": "Downcast",
    "12": "iTunes",
    "13": "NPR One",
    "14": "Overcast",
    "15": "Player FM",
    "16": "Pocket Casts",
    "17": "Podbean",
    "18": "PodcastAddict",
    "19": "The Podcast App",
    "20": "Podkicker",
    "21": "RadioPublic",
    "22": "Sonos",
    "23": "Stitcher",
    "24": "Zune",
    "25": "Apple Podcasts",
    "26": "Internet Explorer",
    "27": "Safari",
    "28": "Firefox",
    "29": "Chrome",
    "30": "Facebook",
    "31": "Twitter",
    "32": "Apple News",
    "33": "BeyondPod",
    "34": "NetCast",
    "35": "Desktop App",
    "36": "Mobile App",
    "37": "Smart Home",
    "38": "Smart TV",
    "39": "Desktop Browser",
    "40": "Mobile Browser",
    "41": "Windows",
    "42": "Android",
    "43": "iOS",
    "44": "Amazon OS",
    "45": "macOS",
    "46": "BlackBerryOS",
    "47": "Windows Phone",
    "48": "ChromeOS",
    "49": "Linux",
    "50": "webOS",
    "51": "gPodder",
    "52": "iHeartRadio",
    "53": "Juice Receiver",
    "54": "Laughable",
    "55": "Windows Media Player",
    "56": "PodCruncher",
    "57": "PodTrapper",
    "58": "PodcastRepublic",
    "59": "TED",
    "60": "TuneIn",
    "61": "Winamp",
    "62": "Google Podcasts",
    "63": "RSSRadio",
    "64": "Roku",
    "65": "ServeStream",
    "66": "uTorrent",
    "67": "Google Home",
    "68": "Smart Watch",
    "69": "WatchOS",
    "70": "Himalaya",
    "71": "MediaMonkey",
    "72": "iCatcher",
    "73": "KPCC App",
    "74": "Sonos OS",
    "75": "Podbbang",
    "76": "HardCast",
    "77": "Spotify",
    "78": "AhaRadio",
    "79": "Bullhorn",
    "80": "CloudPlayer",
    "81": "English Radio IELTS TOEFL",
    "82": "Pandora",
    "83": "Procast",
    "84": "Treble.fm",
    "85": "WNYC App",
    "86": "Bose",
    "87": "myTuner",
    "88": "sodes",
    "89": "WBEZ App",
    "90": "Wilson FM",
    "91": "Luminary",
    "92": "Edge",
    "93": "DoggCatcher",
    "94": "Chromecast",
    "95": "Squeezebox",
    "96": "Spreaker",
    "97": "VictorReader",
    "98": "Podcoin",
    "99": "Castamatic",
    "100": "Deezer",
    "101": "Audiobooks",
    "102": "Hamro Patro",
    "103": "HondaLink",
    "104": "Hubhopper",
    "105": "Instacast",
    "106": "KERA App",
    "107": "Kids Listen",
    "108": "Kodi",
    "109": "MusicBee",
    "110": "Orange Radio",
    "111": "Outcast",
    "112": "Playapod",
    "113": "Plex",
    "114": "PRI App",
    "115": "WBUR App",
    "116": "Opera",
    "117": "This American Life",
    "118": "Podimo",
    "119": "BashPodder",
    "120": "Outlook",
    "121": "Amazon Fire TV",
    "122": "Podcast Guru",
    "123": "Xiaoyuzhou",
    "124": "Nvidia Shield",
    "125": "Sony Bravia",
    "126": "Amazon Music",
    "127": "TikTok",
    "128": "SiriusXM",
    "129": "iVoox",
    "130": "Audible",
    "131": "Airr",
    "132": "Podhero",
    "133": "MixerBox",
    "134": "Xbox",
    "135": "Samsung Free",
    "136": "Snipd",
    "137": "Telmate",
    "138": "castget",
    "139": "Newsboat",
    "140": "Anghami",
    "141": "VLC",
    "142": "PRX Play",
    "143": "mowPod"
  }

  def chart_options(type:, height: "", width: "")
    {
      chart: {
        type: type,
        height: height,
        width: width,
        zoom: {enabled: false},
        animations: {
          speed: 1000,
          animateGradually: {
            delay: 50
          }
        }
      }
    }
  end

  def series_options(series)
    {
      series: series
    }
  end

  def line_options
    {
      tooltip: {
        followCursor: true,
        fixed: {
          enabled: true,
          position: "topRight",
          offsetX: 250
        }
      },
      xaxis: {type: "datetime"},
      yaxis: {
        title: {text: "Downloads"}
      },
      stroke: {
        curve: "smooth",
        width: 2
      }
    }
  end

  def bar_options
    {
      plotOptions: {
        bar: {
          horizontal: true
        }
      },
      yaxis: {
        title: {text: "Downloads"}
      }
    }
  end

  def parse_episode_downloads(data, date_start, date_end)
    data.map do |d|
      {
        name: d[:ep].title,
        data: parse_datetime_data(d[:rollups], date_start, date_end)
      }
    end.first(10)
  end

  def parse_datetime_data(data, date_start, date_end)
    date_range = (date_start.to_date..date_end.to_date).to_a

    date_range.map do |date|
      point = data.select { |d| d["hour"].to_date == date }
      if point.present?
        {
          x: date,
          y: point.first["count"]
        }
      else
        {
          x: date,
          y: 0
        }
      end
    end
  end

  def parse_agent_data(data)
    [
      {
        data: data.map do |d|
          {
            x: AGENT_TAGS[d[:code].to_s.to_sym],
            y: d[:count]
          }
        end
      }
    ]
  end

  def sum_rollups(rollups)
    rollups.map { |r| r[:count] }.reduce(:+)
  end
end
