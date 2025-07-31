//
//  ExperimentView.swift
//  MobileNLD-FL
//
//  実験実行用のビュー - 4つの実装を比較
//

import SwiftUI

struct ExperimentView: View {
    @StateObject private var experimentRunner = ExperimentRunner()
    @State private var selectedDataSize = 100
    @State private var showingResults = false
    
    let dataSizes = [50, 100, 200, 500, 1000, 2000, 5000]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 10) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 50))
                        .foregroundColor(.blue)
                    
                    Text("Performance Experiments")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Compare 4 implementation variants")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                
                // Configuration
                VStack(alignment: .leading, spacing: 15) {
                    Text("Data Size")
                        .font(.headline)
                    
                    Picker("Data Size", selection: $selectedDataSize) {
                        ForEach(dataSizes, id: \.self) { size in
                            Text("\(size) samples").tag(size)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    Text("Iterations: 10 per implementation")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
                
                // Run Button
                Button(action: runExperiment) {
                    HStack {
                        if experimentRunner.isRunning {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "play.fill")
                        }
                        Text(experimentRunner.isRunning ? "Running..." : "Run Experiment")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(experimentRunner.isRunning ? Color.orange : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(experimentRunner.isRunning)
                
                // Progress
                if experimentRunner.isRunning {
                    VStack(spacing: 10) {
                        ProgressView(value: experimentRunner.progress)
                            .progressViewStyle(LinearProgressViewStyle())
                        
                        Text(experimentRunner.currentStatus)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }
                
                // Results Summary
                if !experimentRunner.results.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Latest Results")
                            .font(.headline)
                        
                        ForEach(experimentRunner.results.sorted(by: { $0.avgTime < $1.avgTime }), id: \.implementation) { result in
                            HStack {
                                Text(result.implementation)
                                    .font(.system(.body, design: .monospaced))
                                Spacer()
                                Text(String(format: "%.2f ms", result.avgTime))
                                    .fontWeight(.semibold)
                            }
                            .padding(.vertical, 2)
                        }
                        
                        Button("View Detailed Results") {
                            showingResults = true
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                }
                
                Spacer()
                
                // Instructions
                VStack(spacing: 5) {
                    Text("For accurate SIMD measurements:")
                        .font(.caption)
                        .fontWeight(.semibold)
                    Text("Profile > Instruments > Time Profiler")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            }
            .padding()
            .navigationTitle("Experiments")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingResults) {
                ExperimentResultsView(results: experimentRunner.allResults)
            }
        }
    }
    
    private func runExperiment() {
        experimentRunner.runComparison(dataSize: selectedDataSize)
    }
}

// Experiment Runner
class ExperimentRunner: ObservableObject {
    @Published var isRunning = false
    @Published var progress: Double = 0
    @Published var currentStatus = ""
    @Published var results: [ImplementationResult] = []
    @Published var allResults: [ExperimentResult] = []
    
    struct ImplementationResult {
        let implementation: String
        let avgTime: Double
        let minTime: Double
        let maxTime: Double
        let stdDev: Double
    }
    
    struct ExperimentResult: Identifiable {
        let id = UUID()
        let timestamp: Date
        let dataSize: Int
        let results: [ImplementationResult]
    }
    
    func runComparison(dataSize: Int) {
        isRunning = true
        progress = 0
        results = []
        
        DispatchQueue.global(qos: .userInitiated).async {
            // Load test data
            guard let testData = self.loadTestData(size: dataSize) else {
                DispatchQueue.main.async {
                    self.currentStatus = "Failed to load test data"
                    self.isRunning = false
                }
                return
            }
            
            let implementations = [
                ("Scalar", self.runScalar),
                ("SIMD Only", self.runSIMDOnly),
                ("Adaptive Only", self.runAdaptiveOnly),
                ("Proposed", self.runProposed)
            ]
            
            var experimentResults: [ImplementationResult] = []
            
            for (index, (name, implementation)) in implementations.enumerated() {
                DispatchQueue.main.async {
                    self.currentStatus = "Testing \(name)..."
                    self.progress = Double(index) / Double(implementations.count)
                }
                
                let times = self.measureImplementation(testData, implementation: implementation)
                let result = ImplementationResult(
                    implementation: name,
                    avgTime: times.average,
                    minTime: times.min,
                    maxTime: times.max,
                    stdDev: times.stdDev
                )
                
                experimentResults.append(result)
                
                DispatchQueue.main.async {
                    self.results.append(result)
                }
            }
            
            DispatchQueue.main.async {
                self.progress = 1.0
                self.currentStatus = "Experiment completed"
                self.allResults.append(ExperimentResult(
                    timestamp: Date(),
                    dataSize: dataSize,
                    results: experimentResults
                ))
                
                // Save results
                self.saveResults(experimentResults, dataSize: dataSize)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    self.isRunning = false
                }
            }
        }
    }
    
    private func loadTestData(size: Int) -> [Q15]? {
        var loader = ExperimentDataLoader.shared
        return loader.loadRosslerData(maxSize: size)
    }
    
    private func measureImplementation(_ data: [Q15], implementation: ([Q15]) -> Float) -> (average: Double, min: Double, max: Double, stdDev: Double) {
        let iterations = 10
        var times: [Double] = []
        
        // Warmup
        for _ in 0..<3 {
            _ = implementation(data)
        }
        
        // Measure
        for _ in 0..<iterations {
            let start = CFAbsoluteTimeGetCurrent()
            _ = implementation(data)
            let time = (CFAbsoluteTimeGetCurrent() - start) * 1000
            times.append(time)
        }
        
        let average = times.isEmpty ? 0 : times.reduce(0, +) / Double(times.count)
        let min = times.min() ?? 0
        let max = times.max() ?? 0
        
        let variance = times.isEmpty ? 0 : times.map { pow($0 - average, 2) }.reduce(0, +) / Double(times.count)
        let stdDev = sqrt(variance)
        
        return (average, min, max, stdDev)
    }
    
    // Implementation wrappers
    private func runScalar(_ data: [Q15]) -> Float {
        return NonlinearDynamicsScalar.lyapunovExponentScalar(data)
    }
    
    private func runSIMDOnly(_ data: [Q15]) -> Float {
        return NonlinearDynamicsSIMDOnly.lyapunovExponentSIMDOnly(data)
    }
    
    private func runAdaptiveOnly(_ data: [Q15]) -> Float {
        return NonlinearDynamicsAdaptiveOnly.lyapunovExponentAdaptive(data)
    }
    
    private func runProposed(_ data: [Q15]) -> Float {
        return NonlinearDynamics.lyapunovExponent(data)
    }
    
    private func saveResults(_ results: [ImplementationResult], dataSize: Int) {
        // ExperimentResultSaverを使用して結果を保存
        ExperimentResultSaver.saveResults(results, dataSize: dataSize)
    }
}

// Results View
struct ExperimentResultsView: View {
    let results: [ExperimentRunner.ExperimentResult]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(results) { experiment in
                    Section(header: Text("Data Size: \(experiment.dataSize) - \(experiment.timestamp.formatted())")) {
                        ForEach(experiment.results, id: \.implementation) { result in
                            VStack(alignment: .leading, spacing: 5) {
                                Text(result.implementation)
                                    .font(.headline)
                                HStack {
                                    Text("Avg: \(String(format: "%.2f", result.avgTime))ms")
                                    Spacer()
                                    Text("Min: \(String(format: "%.2f", result.minTime))ms")
                                    Spacer()
                                    Text("Max: \(String(format: "%.2f", result.maxTime))ms")
                                }
                                .font(.caption)
                                .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 5)
                        }
                    }
                }
            }
            .navigationTitle("Experiment Results")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

extension DateFormatter {
    static let experimentTimestamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return formatter
    }()
}

#Preview {
    ExperimentView()
}