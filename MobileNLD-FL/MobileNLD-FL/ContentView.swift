//
//  ContentView.swift
//  MobileNLD-FL
//
//  Created by HAGIHARA KADOSHIMA on 2025/07/29.
//

import SwiftUI

struct ContentView: View {
    @State private var testResults: [TestResult] = []
    @State private var isRunningTests = false
    @State private var showResults = false
    @State private var errorMessage: String = ""
    @State private var showError = false
    // @StateObject private var benchmark = PerformanceBenchmark()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack {
                    Image(systemName: "waveform.path.ecg")
                        .imageScale(.large)
                        .foregroundStyle(.blue)
                        .font(.system(size: 60))
                    
                    Text("MobileNLD-FL")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Nonlinear Dynamics Analysis")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                
                // Test Controls
                VStack(spacing: 15) {
                    // Quick Performance Test
                    Button(action: runTests) {
                        HStack {
                            if isRunningTests {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "play.circle.fill")
                            }
                            Text(isRunningTests ? "Running Tests..." : "Quick Performance Test")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(isRunningTests) // || benchmark.isRunning)
                    
                    // 5-Minute Benchmark for Instruments
                    /*
                    Button(action: startBenchmark) {
                        HStack {
                            if benchmark.isRunning {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "timer")
                            }
                            Text(benchmark.isRunning ? "Benchmarking..." : "5-Min Instruments Benchmark")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(benchmark.isRunning ? Color.orange : Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(isRunningTests) // || benchmark.isRunning)
                    */
                    
                    /*
                    if benchmark.isRunning {
                        Button(action: benchmark.stopBenchmark) {
                            HStack {
                                Image(systemName: "stop.circle.fill")
                                Text("Stop Benchmark")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                    }
                    */
                    
                    // SIMD Performance Measurement Button
                    Button(action: runSIMDMeasurement) {
                        HStack {
                            Image(systemName: "speedometer")
                            Text("Measure SIMD Performance")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.purple)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(isRunningTests)
                    
                    // Experiment Comparison Button
                    NavigationLink(destination: ExperimentView()) {
                        HStack {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                            Text("Run 4-Implementation Comparison")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    
                    // Accuracy Comparison Button
                    NavigationLink(destination: AccuracyComparisonView()) {
                        HStack {
                            Image(systemName: "checkmark.seal.fill")
                            Text("Accuracy vs Speed Analysis")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    
                    if !testResults.isEmpty {
                        Button(action: { showResults.toggle() }) {
                            HStack {
                                Image(systemName: "chart.bar.doc.horizontal")
                                Text("View Test Results")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                    }
                }
                .padding(.horizontal)
                
                // Real-time Stats
                VStack(spacing: 15) {
                    // Benchmark Progress
                    /*
                    if benchmark.isRunning {
                        VStack(spacing: 10) {
                            Text("Instruments Benchmark Running")
                                .font(.headline)
                                .foregroundColor(.orange)
                            
                            ProgressView(value: Double(benchmark.currentIteration), 
                                       total: Double(benchmark.totalIterations))
                                .progressViewStyle(LinearProgressViewStyle())
                            
                            HStack(spacing: 20) {
                                StatView(title: "Progress", 
                                       value: "\(benchmark.currentIteration)/\(benchmark.totalIterations)")
                                StatView(title: "Avg Time", 
                                       value: String(format: "%.1fms", benchmark.averageProcessingTime * 1000))
                                StatView(title: "Target", 
                                       value: "< 4.0ms")
                            }
                        }
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(10)
                        .padding(.horizontal)
                    }
                    */
                    
                    // Test Results
                    if !testResults.isEmpty {
                        VStack(spacing: 10) {
                            Text("Last Test Results")
                                .font(.headline)
                            
                            HStack(spacing: 20) {
                                StatView(title: "Tests Passed", 
                                       value: "\(testResults.filter { $0.passed }.count)/\(testResults.count)")
                                
                                if let perfResult = testResults.first(where: { $0.testName == "Performance Benchmark" }) {
                                    StatView(title: "Processing Time", 
                                           value: String(format: "%.1fms", perfResult.executionTime))
                                }
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                        .padding(.horizontal)
                    }
                }
                
                Spacer()
                
                // Info
                Text("Real-time nonlinear dynamics analysis\nwith Q15 fixed-point arithmetic")
                    .multilineTextAlignment(.center)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding()
            }
            .navigationTitle("MobileNLD-FL")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showResults) {
            TestResultsView(results: testResults)
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func runTests() {
        isRunningTests = true
        errorMessage = ""
        
        // Run tests on background thread
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let results = NonlinearDynamicsTests.runAllTests()
                
                DispatchQueue.main.async {
                    self.testResults = results
                    self.isRunningTests = false
                    
                    // Check for failed tests
                    let failedTests = results.filter { !$0.passed }
                    if !failedTests.isEmpty {
                        self.errorMessage = "Failed tests:\n" + failedTests.map { $0.testName }.joined(separator: "\n")
                        self.showError = true
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Error running tests: \(error.localizedDescription)"
                    self.showError = true
                    self.isRunningTests = false
                }
            }
        }
    }
    
    private func startBenchmark() {
        // benchmark.startContinuousBenchmark()
    }
    
    private func runSIMDMeasurement() {
        // Signpostを使った測定を実行
        PerformanceMeasurement.measureNLDPerformance()
        
        // 少し待ってから特定関数の測定も実行
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            PerformanceMeasurement.measureSpecificFunctions()
        }
    }
}

struct StatView: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct TestResultsView: View {
    let results: [TestResult]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(results.indices, id: \.self) { index in
                    let result = results[index]
                    TestResultRow(result: result)
                }
            }
            .navigationTitle("Test Results")
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

struct TestResultRow: View {
    let result: TestResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(result.testName)
                    .font(.headline)
                Spacer()
                Image(systemName: result.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(result.passed ? .green : .red)
            }
            
            if result.testName == "Performance Benchmark" {
                Text("Execution Time: \(String(format: "%.1f", result.executionTime))ms")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                HStack {
                    Text("RMSE: \(String(format: "%.4f", result.rmse))")
                    Spacer()
                    Text("Time: \(String(format: "%.1f", result.executionTime))ms")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ContentView()
}
