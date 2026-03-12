import BitcoinRegimeDomain
import SwiftUI

struct MarketWeatherForecastStyle {
    let label: String
    let symbolName: String
    let tint: Color
}

func marketWeatherForecastStyle(score: Double) -> MarketWeatherForecastStyle {
    if score >= 72 {
        return MarketWeatherForecastStyle(label: "Sunny", symbolName: "sun.max.fill", tint: .yellow)
    }

    if score >= 58 {
        return MarketWeatherForecastStyle(label: "Mostly Sunny", symbolName: "cloud.sun.fill", tint: .orange)
    }

    if score >= 42 {
        return MarketWeatherForecastStyle(label: "Cloudy", symbolName: "cloud.fill", tint: .gray)
    }

    if score >= 28 {
        return MarketWeatherForecastStyle(label: "Rainy", symbolName: "cloud.rain.fill", tint: .blue)
    }

    return MarketWeatherForecastStyle(label: "Stormy", symbolName: "cloud.bolt.rain.fill", tint: .indigo)
}

func marketWeatherForecastStyle(component: MarketWeatherComponent) -> MarketWeatherForecastStyle {
    switch component.effect {
    case .supportive:
        return component.score >= 72
            ? MarketWeatherForecastStyle(label: "Sunny", symbolName: "sun.max.fill", tint: .yellow)
            : MarketWeatherForecastStyle(label: "Mostly Sunny", symbolName: "cloud.sun.fill", tint: .orange)
    case .neutral:
        return MarketWeatherForecastStyle(label: "Cloudy", symbolName: "cloud.fill", tint: .gray)
    case .restrictive:
        return component.score < 28
            ? MarketWeatherForecastStyle(label: "Stormy", symbolName: "cloud.bolt.rain.fill", tint: .indigo)
            : MarketWeatherForecastStyle(label: "Rainy", symbolName: "cloud.rain.fill", tint: .blue)
    case .elevated:
        return MarketWeatherForecastStyle(label: "Stormy", symbolName: "cloud.bolt.rain.fill", tint: .indigo)
    }
}
