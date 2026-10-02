pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick
import QtPositioning

import qs.modules.common

Singleton {
    id: root

    // 10 minute
    readonly property int fetchInterval: Config.options.bar.weather.fetchInterval * 60 * 1000
    readonly property string city: Config.options.bar.weather.city
    readonly property bool useUSCS: Config.options.bar.weather.useUSCS
    property bool gpsActive: Config.options.bar.weather.enableGPS

    onUseUSCSChanged: root.getData()
    onCityChanged: root.getData()

    property var location: ({
        valid: false,
        lat: 0,
        lon: 0
    })

    property var data: ({
        uv: 0,
        humidity: 0,
        sunrise: 0,
        sunset: 0,
        windDir: 0,
        wCode: 0,
        city: "",
        wind: "",
        precip: "",
        visib: "",
        press: "",
        temp: "",
        tempFeelsLike: "",
        lastRefresh: ""
    })

    function refineData(data) {
        let temp = {}
        const rainMm = data?.rain?.["1h"] || data?.rain?.["3h"] || 0
        const snowMm = data?.snow?.["1h"] || data?.snow?.["3h"] || 0

        temp.description = data?.weather?.[0]?.description || ""
        temp.cr = data?.clouds?.all !== undefined
            ? Math.round(data.clouds.all * 0.8) + "%"
            : "0%"
        temp.humidity = (data?.main?.humidity || 0) + "%"

        const fmt = (unix) => new Date(unix * 1000).toLocaleTimeString("en-US", {
            hour: "numeric",
            minute: "2-digit",
            second: "2-digit",
            hour12: true
        })

        temp.sunrise = data?.sys?.sunrise ? fmt(data.sys.sunrise) : "0"
        temp.sunset  = data?.sys?.sunset  ? fmt(data.sys.sunset)  : "0"

        temp.windDir = data?.wind?.deg || 0
        temp.wCode = data?.weather?.[0]?.id || 0
        temp.city = data?.name || "City"

        if (root.useUSCS) {
            temp.wind = (data?.wind?.speed || 0) + " mph"
            temp.precip = ((rainMm + snowMm) * 0.0394).toFixed(2) + " in"
            temp.visib = ((data?.visibility || 0) / 1609).toFixed(1) + " mi"
            temp.press = (data?.main?.pressure || 0) + " hPa"
            temp.temp = Math.round(data?.main?.temp || 0) + "°F"
            temp.tempFeelsLike = Math.round(data?.main?.feels_like || 0) + "°F"
        } else {
            temp.wind = (data?.wind?.speed || 0) + " m/s"
            temp.precip = (rainMm + snowMm).toFixed(1) + " mm"
            temp.visib = ((data?.visibility || 0) / 1000).toFixed(1) + " km"
            temp.press = (data?.main?.pressure || 0) + " hPa"
            let roundedTemp = Math.round(data?.main?.temp || 0)
            let roundedFeels = Math.round(data?.main?.feels_like || 0)

            temp.temp = roundedTemp + "°C"
            temp.tempFeelsLike = roundedFeels + "°C"
        }

        temp.lastRefresh = DateTime.time + " • " + DateTime.date
        temp.description = temp.description.charAt(0).toUpperCase() + temp.description.slice(1)
        temp.tempMin = Math.round(data?.main?.temp_min ?? 0) + "°"
        temp.tempMax = Math.round(data?.main?.temp_max ?? 0) + "°"

        root.data = temp
        if (data?.coord) root.getForecast(data.coord.lat, data.coord.lon)
    }

    // ---- taloshell: hourly + 7 day forecast from Open-Meteo (no API key) ----
    property list<var> hourly: [] // {time: Date, temp, code, precip}
    property list<var> daily: []  // {date: Date, min, max, code, precip, sunrise, sunset}

    function getForecast(lat, lon) {
        const unit = root.useUSCS ? "&temperature_unit=fahrenheit" : ""
        const url = `https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lon}`
            + `&hourly=temperature_2m,weather_code,precipitation_probability,is_day`
            + `&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,sunrise,sunset`
            + `&timezone=auto&forecast_days=7${unit}`
        forecastFetcher.command = ["curl", "-s", "--max-time", "15", url]
        forecastFetcher.running = true
    }

    Process {
        id: forecastFetcher
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text)
                    const now = Date.now()
                    const hours = []
                    for (let i = 0; i < (d.hourly?.time?.length ?? 0); i++) {
                        const t = new Date(d.hourly.time[i])
                        if (t.getTime() < now - 3600000) continue
                        hours.push({ time: t, temp: Math.round(d.hourly.temperature_2m[i]), code: d.hourly.weather_code[i],
                                     precip: d.hourly.precipitation_probability?.[i] ?? 0, night: d.hourly.is_day?.[i] === 0 })
                        if (hours.length >= 24) break
                    }
                    root.hourly = hours
                    const days = []
                    for (let i = 0; i < (d.daily?.time?.length ?? 0); i++) {
                        days.push({ date: new Date(d.daily.time[i] + "T12:00"), min: Math.round(d.daily.temperature_2m_min[i]),
                                    max: Math.round(d.daily.temperature_2m_max[i]), code: d.daily.weather_code[i],
                                    precip: d.daily.precipitation_probability_max?.[i] ?? 0,
                                    sunrise: d.daily.sunrise?.[i] ?? "", sunset: d.daily.sunset?.[i] ?? "" })
                    }
                    root.daily = days
                } catch (e) {
                    console.warn("[WeatherService] Forecast parse error:", e.message)
                }
            }
        }
    }

    function refresh() { root.getData() }

    function getData() {
        const defaultApiKey = "8b05d62206f459e1d298cbe5844d7d87"
        let apiKey = KeyringStorage.keyringData?.apiKeys?.openweather || defaultApiKey

        if (!apiKey || apiKey === "") {
            console.error("[WeatherService] Missing OpenWeather API key.")
            return
        }

        let units = root.useUSCS ? "imperial" : "metric"
        let url = "https://api.openweathermap.org/data/2.5/weather?"

        if (root.gpsActive && root.location.valid) {
            url += `lat=${root.location.lat}&lon=${root.location.lon}`
        } else {
            url += `q=${formatCityName(root.city)}`
        }

        url += `&units=${units}`
        url += `&appid=${apiKey}`

        let command = `curl -s "${url}"`

        fetcher.command[2] = command
        fetcher.running = true
    }

    function formatCityName(cityName) {
        return cityName.trim().split(/\s+/).join('+')
    }

    Component.onCompleted: {
        if (!root.gpsActive) return
        console.info("[WeatherService] Starting GPS service.")
        positionSource.start()
    }

    Process {
        id: fetcher
        command: ["bash", "-c", ""]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.length === 0)
                    return

                try {
                    const parsedData = JSON.parse(text)

                    if (parsedData.cod && parsedData.cod !== 200) {
                        console.error("[WeatherService] API error:", parsedData.message)
                        return
                    }

                    root.refineData(parsedData)
                } catch (e) {
                    console.error("[WeatherService] JSON parse error:", e.message)
                }
            }
        }
    }

    PositionSource {
        id: positionSource
        updateInterval: root.fetchInterval

        onPositionChanged: {
            if (position.latitudeValid && position.longitudeValid) {
                root.location.lat = position.coordinate.latitude
                root.location.lon = position.coordinate.longitude
                root.location.valid = true
                root.getData()
            } else {
                root.gpsActive = root.location.valid ? true : false
                console.error("[WeatherService] Failed to get GPS location.")
            }
        }

        onValidityChanged: {
            if (!positionSource.valid) {
                positionSource.stop()
                root.location.valid = false
                root.gpsActive = false
                console.error("[WeatherService] Could not acquire valid GPS backend.")
            }
        }
    }

    Timer {
        running: !root.gpsActive
        repeat: true
        interval: root.fetchInterval
        triggeredOnStart: !root.gpsActive
        onTriggered: root.getData()
    }
}