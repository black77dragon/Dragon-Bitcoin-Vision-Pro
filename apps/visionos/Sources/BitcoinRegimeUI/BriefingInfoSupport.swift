import BitcoinRegimeDomain
import SwiftUI

struct BriefingInfoContent: Identifiable {
    enum Diagram {
        case range(
            value: Double,
            accent: Color,
            lowLabel: String,
            midLabel: String,
            highLabel: String,
            caption: String
        )
        case confidence(ConfidenceBreakdown)
    }

    let id: String
    let eyebrow: String
    let title: String
    let headline: String
    let explanation: String
    let analogy: String
    let example: String
    let takeaways: [String]
    let diagram: Diagram
}

func briefingInfo(for score: ScoreCard) -> BriefingInfoContent {
    switch score.key {
    case "mempoolStress":
        return BriefingInfoContent(
            id: "score-\(score.key)",
            eyebrow: "How to read this tile",
            title: "Network Traffic",
            headline: "This measures how crowded the Bitcoin network is right now.",
            explanation: "When more people try to send transactions than the next few blocks can fit, fees rise and waits get longer. A higher score means there is more competition for limited space in upcoming blocks.",
            analogy: "Think of Bitcoin blocks like a small parking garage with only a few spaces opening every 10 minutes. When too many cars arrive at once, the people willing to pay more get in first.",
            example: "If this score moves from 35 to 75, a transaction that cleared cheaply earlier in the day may need a much higher fee to avoid sitting in line.",
            takeaways: [
                "Low means sending Bitcoin is relatively easy and cheap.",
                "Middle means traffic is building but still manageable.",
                "High means the queue is crowded and cheap transactions may wait."
            ],
            diagram: .range(
                value: score.value,
                accent: .red,
                lowLabel: "easy to send",
                midLabel: "busy",
                highLabel: "crowded",
                caption: "This marker shows where current network traffic sits on the scale from quiet to crowded."
            )
        )
    case "macroLiquidity":
        return BriefingInfoContent(
            id: "score-\(score.key)",
            eyebrow: "How to read this tile",
            title: "Broader Market Weather",
            headline: "This is a simple read on whether the outside financial world is helping or hurting Bitcoin.",
            explanation: "Bitcoin does not trade in isolation. When cash yields are high, the dollar is strong, and investors are nervous, risk assets usually have a harder time. A higher score means the broader backdrop is more supportive.",
            analogy: "Think of this like checking the weather before a flight. The plane can still move, but tailwinds help and headwinds make the trip harder.",
            example: "A supportive reading can mean investors are more willing to own volatile assets. A restrictive reading means they may prefer cash, bonds, or lower-risk trades.",
            takeaways: [
                "This is context, not a direct price predictor.",
                "Higher is generally more friendly for risk-taking.",
                "Lower means outside conditions may weigh on Bitcoin demand."
            ],
            diagram: .range(
                value: score.value,
                accent: .blue,
                lowLabel: "headwind",
                midLabel: "mixed",
                highLabel: "tailwind",
                caption: "The marker shows whether the outside market backdrop is acting more like a headwind or a tailwind."
            )
        )
    case "knownFlowPressure":
        return BriefingInfoContent(
            id: "score-\(score.key)",
            eyebrow: "How to read this tile",
            title: "Big Buyer Activity",
            headline: "This tracks whether visible large buyers are adding support to the market.",
            explanation: "The app watches public flow signals, especially spot ETF activity, to estimate whether large pools of money are buying or stepping back. A higher score means the visible flow we can track is helping demand.",
            analogy: "Think of a stadium crowd. Small fans matter, but when a few big groups walk in together, you feel the shift immediately. This tile looks for those larger groups.",
            example: "If ETF inflows are positive for several days, that can add a steady bid underneath the market. If they reverse, that support weakens.",
            takeaways: [
                "This is based on the large flows we can actually observe.",
                "It does not capture every buyer or seller in the market.",
                "Higher means visible big buyers are more supportive."
            ],
            diagram: .range(
                value: score.value,
                accent: .teal,
                lowLabel: "weak buying",
                midLabel: "balanced",
                highLabel: "strong buying",
                caption: "The marker shows whether visible large-buyer activity looks weak, balanced, or supportive."
            )
        )
    default:
        return BriefingInfoContent(
            id: "score-\(score.key)",
            eyebrow: "How to read this tile",
            title: score.label,
            headline: "This tile summarizes one part of the current Bitcoin market picture.",
            explanation: score.summary,
            analogy: "Think of it as one dashboard gauge among several, not a complete answer by itself.",
            example: "A single tile can move without changing the whole regime if the other signals disagree.",
            takeaways: ["Use this alongside the other tiles rather than in isolation."],
            diagram: .range(
                value: score.value,
                accent: .orange,
                lowLabel: "low",
                midLabel: "mixed",
                highLabel: "high",
                caption: "The marker shows the current reading on a simple low-to-high scale."
            )
        )
    }
}

func briefingInfo(for card: EvidenceCard) -> BriefingInfoContent {
    switch card.id {
    case "fee-floor", "mempool-floor":
        return BriefingInfoContent(
            id: "evidence-\(card.id)",
            eyebrow: "Why this evidence matters",
            title: "Base transaction cost",
            headline: "This shows the minimum fee that is still realistically getting into blocks.",
            explanation: "A high base fee means the line is still long enough that even lower-priority transactions must pay up. When that floor stays high after new blocks are mined, demand is likely persistent rather than temporary.",
            analogy: "Imagine a concert line where even the cheapest remaining ticket is still expensive. That tells you demand is strong across the whole queue, not just for VIP spots.",
            example: "If the fee floor stays near 18 sat/vB for hours, users trying to send with 2 or 3 sat/vB may keep getting skipped.",
            takeaways: [
                "A sticky fee floor is a sign of lasting pressure.",
                "A falling floor suggests the queue is actually clearing.",
                "This helps distinguish a brief spike from a sustained wave."
            ],
            diagram: .range(
                value: card.direction == .elevated ? 82 : 46,
                accent: .orange,
                lowLabel: "cheap base fee",
                midLabel: "elevated",
                highLabel: "sticky floor",
                caption: "This scale shows whether the cheapest workable fee is low, elevated, or stubbornly high."
            )
        )
    case "macro-backdrop":
        return BriefingInfoContent(
            id: "evidence-\(card.id)",
            eyebrow: "Why this evidence matters",
            title: "Broader market backdrop",
            headline: "This helps explain whether outside conditions are helping the Bitcoin story or getting in the way.",
            explanation: "The app combines a few high-level market measures into one easier read. It is trying to answer a simple question: are investors generally in a mood to take risk, or are they pulling back?",
            analogy: "It is like checking whether the tide is coming in or going out before you launch a small boat. The boat still matters, but the surrounding water matters too.",
            example: "If rates are high and the dollar is rising, some investors may prefer safer assets. If those pressures ease, Bitcoin often gets more breathing room.",
            takeaways: [
                "This is supporting context, not the main signal.",
                "It matters most when network or flow signals are unclear.",
                "Friendly outside conditions make Bitcoin demand easier to sustain."
            ],
            diagram: .range(
                value: card.direction == .supportive ? 68 : card.direction == .restrictive ? 28 : 50,
                accent: .blue,
                lowLabel: "risk-off",
                midLabel: "mixed",
                highLabel: "risk-on",
                caption: "This scale shows whether the outside market mood looks cautious, mixed, or more open to risk."
            )
        )
    case "flow-context":
        return BriefingInfoContent(
            id: "evidence-\(card.id)",
            eyebrow: "Why this evidence matters",
            title: "Large tracked buying",
            headline: "This looks for support from buyers big enough to move the market conversation.",
            explanation: "Visible ETF flows are not the whole market, but they are a useful window into whether large pools of capital are adding demand or backing away. Strong positive flow can help confirm that buying pressure is real.",
            analogy: "If you are watching a store, the number of people walking in matters, but one truck unloading a huge order matters too. This tile watches the truck-sized activity we can see.",
            example: "A day with strong positive ETF inflows does not guarantee price rises, but repeated inflows over time often point to steady institutional demand.",
            takeaways: [
                "This is helpful because large flows can matter a lot.",
                "Coverage is partial, so this should not be treated as complete.",
                "Use it as confirmation, not as the only signal."
            ],
            diagram: .range(
                value: card.direction == .supportive ? 70 : card.direction == .restrictive ? 32 : 50,
                accent: .teal,
                lowLabel: "outflows",
                midLabel: "balanced",
                highLabel: "inflows",
                caption: "This scale shows whether visible large-buyer flow is leaning negative, neutral, or positive."
            )
        )
    default:
        return BriefingInfoContent(
            id: "evidence-\(card.id)",
            eyebrow: "Why this evidence matters",
            title: card.title,
            headline: "This tile is one of the main reasons behind the current read.",
            explanation: card.interpretation,
            analogy: "Think of it as a clue that supports the overall diagnosis.",
            example: "One clue can be strong, but the app still checks whether the other clues agree.",
            takeaways: ["The more heavily weighted tiles matter more to the overall read."],
            diagram: .range(
                value: 50,
                accent: .gray,
                lowLabel: "weak",
                midLabel: "mixed",
                highLabel: "strong",
                caption: "This scale shows the strength of the signal in simplified form."
            )
        )
    }
}

func briefingInfoForConfidence(_ confidence: ConfidenceBreakdown) -> BriefingInfoContent {
    BriefingInfoContent(
        id: "confidence",
        eyebrow: "How to read this tile",
        title: "Confidence",
        headline: "This is a reliability meter for the dashboard, not a market call by itself.",
        explanation: "The app combines three things here: how fresh the data is, how much of the picture we can see, and how much the signals agree with one another. Higher confidence means the summary is built on better and more consistent inputs.",
        analogy: "Think of a weather forecast. It is more trustworthy when the radar is current, the coverage is broad, and several models point in the same direction.",
        example: "A reading of 0.74 means the app has a usable view, but some of the inputs are still partial, simulated, or not perfectly aligned.",
        takeaways: [
            "Fresh data raises confidence.",
            "Partial coverage lowers confidence.",
            "Disagreement between signals lowers confidence."
        ],
        diagram: .confidence(confidence)
    )
}

func summaryStripTitle(for key: String) -> String {
    switch key {
    case "macroLiquidity":
        return "Broader Market"
    case "knownFlowPressure":
        return "Big Buyer Watch"
    default:
        return "Summary"
    }
}

func scoreContextLine(for score: ScoreCard) -> String {
    switch score.key {
    case "mempoolStress":
        return "Uses current fees and queue depth to show how hard it is to get into the next blocks."
    case "macroLiquidity":
        return "Summarizes whether the outside market backdrop is helping or hurting risk appetite."
    case "knownFlowPressure":
        return "Tracks the large-buyer flows we can see, mainly via public ETF data."
    default:
        return "Use this with the other tiles for a fuller picture."
    }
}

struct BriefingInfoSheet: View {
    @Environment(\.dismiss) private var dismiss
    let content: BriefingInfoContent

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(content.eyebrow)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(content.title)
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                        Text(content.headline)
                            .font(.title3.weight(.semibold))
                    }

                    Spacer(minLength: 0)

                    Button {
                        dismiss()
                    } label: {
                        Label("Close", systemImage: "xmark.circle.fill")
                            .labelStyle(.titleAndIcon)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityLabel("Close information window")
                }

                BriefingDiagramView(diagram: content.diagram)

                BriefingInfoSection(title: "What this means", text: content.explanation)
                BriefingInfoSection(title: "Analogy", text: content.analogy)
                BriefingInfoSection(title: "Example", text: content.example)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Quick takeaways")
                        .font(.headline)
                    ForEach(Array(content.takeaways.enumerated()), id: \.offset) { index, takeaway in
                        Label(takeaway, systemImage: "checkmark.circle.fill")
                            .font(.body)
                            .foregroundStyle(index == 0 ? .primary : .secondary)
                    }
                }
            }
            .padding(28)
        }
        .frame(minWidth: 560, minHeight: 540)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

private struct BriefingInfoSection: View {
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(text)
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }
}

private struct BriefingDiagramView: View {
    let diagram: BriefingInfoContent.Diagram

    var body: some View {
        switch diagram {
        case let .range(value, accent, lowLabel, midLabel, highLabel, caption):
            RangeDiagramView(
                value: value,
                accent: accent,
                lowLabel: lowLabel,
                midLabel: midLabel,
                highLabel: highLabel,
                caption: caption
            )
        case let .confidence(confidence):
            ConfidenceDiagramView(confidence: confidence)
        }
    }
}

private struct RangeDiagramView: View {
    let value: Double
    let accent: Color
    let lowLabel: String
    let midLabel: String
    let highLabel: String
    let caption: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Simple visual guide")
                .font(.headline)

            GeometryReader { geometry in
                let width = max(geometry.size.width, 1)
                let markerOffset = max(0, min(width - 20, width * value / 100 - 10))

                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [.green.opacity(0.9), accent.opacity(0.75), .red.opacity(0.85)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 18)

                    Capsule()
                        .fill(.white)
                        .frame(width: 20, height: 34)
                        .overlay {
                            Capsule()
                                .stroke(Color.black.opacity(0.18), lineWidth: 1)
                        }
                        .offset(x: markerOffset, y: -8)
                }
            }
            .frame(height: 34)

            HStack {
                Text(lowLabel)
                Spacer()
                Text(midLabel)
                Spacer()
                Text(highLabel)
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Text(caption)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.black.opacity(0.06))
        )
    }
}

private struct ConfidenceDiagramView: View {
    let confidence: ConfidenceBreakdown

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Why confidence moves")
                .font(.headline)

            ConfidenceBar(title: "Freshness", value: confidence.timeliness, color: .blue)
            ConfidenceBar(title: "Coverage", value: confidence.coverage, color: .teal)
            ConfidenceBar(title: "Agreement", value: confidence.agreement, color: .orange)

            Text("The overall confidence combines fresh data, enough coverage, and signals that broadly agree with each other.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.black.opacity(0.06))
        )
    }
}

private struct ConfidenceBar: View {
    let title: String
    let value: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                Spacer()
                Text(value.formatted(.percent.precision(.fractionLength(0))))
                    .foregroundStyle(.secondary)
            }
            .font(.caption.weight(.semibold))

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.black.opacity(0.08))
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(color.gradient)
                        .frame(width: max(22, geometry.size.width * value))
                }
            }
            .frame(height: 12)
        }
    }
}
