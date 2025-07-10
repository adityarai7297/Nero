import SwiftUI
import Neumorphic

struct ExerciseChart: View {
    let data: [WorkoutSet]
    let chartType: ExerciseChartType
    let timeframe: ExerciseHistoryTimeframe
    
    private var chartData: [ChartDataPoint] {
        switch chartType {
        case .volume:
            return data.map { set in
                ChartDataPoint(
                    date: set.timestamp,
                    value: Double(set.weight * set.reps)
                )
            }
        case .weight:
            return data.map { set in
                ChartDataPoint(
                    date: set.timestamp,
                    value: Double(set.weight)
                )
            }
        }
    }
    
    private var maxValue: Double {
        chartData.map(\.value).max() ?? 100
    }
    
    private var minValue: Double {
        chartData.map(\.value).min() ?? 0
    }
    
    private var valueRange: Double {
        maxValue - minValue
    }
    
    // Only show first and last labels to avoid clutter
    private var labelsToShow: (first: ChartDataPoint?, last: ChartDataPoint?) {
        guard !chartData.isEmpty else { return (nil, nil) }
        return (chartData.first, chartData.last)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Chart area
            GeometryReader { geometry in
                ZStack {
                    // Background grid
                    ChartGrid(geometry: geometry)
                    
                    // Chart line
                    if chartData.count > 1 {
                        ChartLine(
                            data: chartData,
                            geometry: geometry,
                            maxValue: maxValue,
                            minValue: minValue
                        )
                    }
                    
                    // Data points
                    ChartPoints(
                        data: chartData,
                        geometry: geometry,
                        maxValue: maxValue,
                        minValue: minValue
                    )
                    
                    // Value labels (only first and last)
                    ChartLabels(
                        first: labelsToShow.first,
                        last: labelsToShow.last,
                        geometry: geometry,
                        maxValue: maxValue,
                        minValue: minValue
                    )
                }
            }
            .frame(height: 200)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.offWhite)
                    .softInnerShadow(
                        RoundedRectangle(cornerRadius: 12),
                        darkShadow: Color.black.opacity(0.1),
                        lightShadow: Color.white.opacity(0.9),
                        spread: 0.5,
                        radius: 2
                    )
            )
            .padding(8)
            
            // Chart info
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(chartType.unit)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if !chartData.isEmpty {
                        Text("Range: \(Int(minValue)) - \(Int(maxValue))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if !chartData.isEmpty {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(chartData.count) data points")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if let first = chartData.first, let last = chartData.last {
                            let change = last.value - first.value
                            let changeText = change >= 0 ? "+\(Int(change))" : "\(Int(change))"
                            Text("Change: \(changeText)")
                                .font(.caption2)
                                .foregroundColor(change >= 0 ? .green : .red)
                        }
                    }
                }
            }
        }
    }
}

struct ChartDataPoint {
    let date: Date
    let value: Double
}

struct ChartGrid: View {
    let geometry: GeometryProxy
    
    var body: some View {
        Path { path in
            let gridLines = 4
            let spacing = geometry.size.height / CGFloat(gridLines + 1)
            
            // Horizontal grid lines
            for i in 1...gridLines {
                let y = spacing * CGFloat(i)
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: geometry.size.width, y: y))
            }
        }
        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
    }
}

struct ChartLine: View {
    let data: [ChartDataPoint]
    let geometry: GeometryProxy
    let maxValue: Double
    let minValue: Double
    
    private var path: Path {
        var path = Path()
        
        guard data.count > 1 else { return path }
        
        let sortedData = data.sorted { $0.date < $1.date }
        let width = geometry.size.width
        let height = geometry.size.height
        let valueRange = maxValue - minValue
        
        // Calculate points
        var points: [CGPoint] = []
        for (index, point) in sortedData.enumerated() {
            let x = width * CGFloat(index) / CGFloat(sortedData.count - 1)
            let normalizedValue = valueRange > 0 ? (point.value - minValue) / valueRange : 0.5
            let y = height * (1 - normalizedValue)
            points.append(CGPoint(x: x, y: y))
        }
        
        // Create smooth curve
        if points.count > 1 {
            path.move(to: points[0])
            
            if points.count == 2 {
                // Just a straight line for 2 points
                path.addLine(to: points[1])
            } else {
                // Use quadratic curves for smoothing
                for i in 1..<points.count {
                    let current = points[i]
                    let previous = points[i-1]
                    
                    if i == 1 {
                        // First curve segment
                        let midX = (previous.x + current.x) / 2
                        let midY = (previous.y + current.y) / 2
                        path.addQuadCurve(to: CGPoint(x: midX, y: midY), control: previous)
                    }
                    
                    if i < points.count - 1 {
                        // Middle segments
                        let next = points[i+1]
                        let midX1 = (previous.x + current.x) / 2
                        let midY1 = (previous.y + current.y) / 2
                        let midX2 = (current.x + next.x) / 2
                        let midY2 = (current.y + next.y) / 2
                        path.addQuadCurve(to: CGPoint(x: midX2, y: midY2), control: current)
                    } else {
                        // Last segment
                        path.addQuadCurve(to: current, control: current)
                    }
                }
            }
        }
        
        return path
    }
    
    var body: some View {
        path
            .stroke(
                LinearGradient(
                    colors: [Color.accentBlue, Color.blue],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
            )
    }
}

struct ChartPoints: View {
    let data: [ChartDataPoint]
    let geometry: GeometryProxy
    let maxValue: Double
    let minValue: Double
    
    var body: some View {
        ForEach(Array(data.enumerated()), id: \.offset) { index, point in
            let sortedData = data.sorted { $0.date < $1.date }
            if let dataIndex = sortedData.firstIndex(where: { $0.date == point.date }) {
                let width = geometry.size.width
                let height = geometry.size.height
                let valueRange = maxValue - minValue
                
                let x = width * CGFloat(dataIndex) / CGFloat(max(sortedData.count - 1, 1))
                let normalizedValue = valueRange > 0 ? (point.value - minValue) / valueRange : 0.5
                let y = height * (1 - normalizedValue)
                
                Circle()
                    .fill(Color.accentBlue)
                    .frame(width: 6, height: 6)
                    .position(x: x, y: y)
                    .shadow(color: Color.accentBlue.opacity(0.3), radius: 2, x: 0, y: 1)
            }
        }
    }
}

struct ChartLabels: View {
    let first: ChartDataPoint?
    let last: ChartDataPoint?
    let geometry: GeometryProxy
    let maxValue: Double
    let minValue: Double
    
    var body: some View {
        Group {
            // First point label
            if let first = first {
                let valueRange = maxValue - minValue
                let normalizedValue = valueRange > 0 ? (first.value - minValue) / valueRange : 0.5
                let y = geometry.size.height * (1 - normalizedValue)
                
                VStack(spacing: 2) {
                    Text("\(Int(first.value))")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.offWhite)
                                .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
                        )
                }
                .position(x: 0, y: max(y - 20, 10))
            }
            
            // Last point label
            if let last = last, first?.date != last.date {
                let valueRange = maxValue - minValue
                let normalizedValue = valueRange > 0 ? (last.value - minValue) / valueRange : 0.5
                let y = geometry.size.height * (1 - normalizedValue)
                
                VStack(spacing: 2) {
                    Text("\(Int(last.value))")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.offWhite)
                                .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
                        )
                }
                .position(x: geometry.size.width, y: max(y - 20, 10))
            }
        }
    }
} 