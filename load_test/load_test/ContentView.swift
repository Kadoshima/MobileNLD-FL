//
//  ContentView.swift
//  load_test
//
//  Created by HAGIHARA KADOSHIMA on 2025/07/31.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var loadGenerator = CPULoadGenerator()
    @State private var selectedLoad: CPULoadGenerator.LoadLevel = .idle
    @State private var isAutomatedTestRunning = false
    @State private var testDuration: Double = 60 // 秒
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // ヘッダー
                VStack(spacing: 10) {
                    Image(systemName: "cpu")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("CPU Load Test Tool")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("for A15 Bionic Energy Measurement")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                
                // 現在の状態表示
                VStack(spacing: 15) {
                    HStack {
                        Text("Status:")
                            .fontWeight(.semibold)
                        Text(loadGenerator.isRunning ? "Running" : "Idle")
                            .foregroundColor(loadGenerator.isRunning ? .green : .gray)
                    }
                    
                    HStack {
                        Text("Target Load:")
                            .fontWeight(.semibold)
                        Text("\(loadGenerator.currentLoadPercent)%")
                    }
                    
                    HStack {
                        Text("Actual CPU:")
                            .fontWeight(.semibold)
                        Text(String(format: "%.1f%%", loadGenerator.actualCPUUsage))
                            .foregroundColor(.blue)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
                
                Divider()
                
                // 手動負荷制御
                VStack(alignment: .leading, spacing: 15) {
                    Text("Manual Load Control")
                        .font(.headline)
                    
                    ForEach(CPULoadGenerator.LoadLevel.allCases, id: \.self) { level in
                        Button(action: {
                            if loadGenerator.currentLoadPercent == level.targetPercent && loadGenerator.isRunning {
                                loadGenerator.stopLoad()
                            } else {
                                loadGenerator.startLoad(level: level)
                                selectedLoad = level
                            }
                        }) {
                            HStack {
                                Image(systemName: loadGenerator.currentLoadPercent == level.targetPercent && loadGenerator.isRunning ? "stop.circle.fill" : "play.circle.fill")
                                Text(level.description)
                                Spacer()
                            }
                            .padding()
                            .background(loadGenerator.currentLoadPercent == level.targetPercent && loadGenerator.isRunning ? Color(level.color).opacity(0.3) : Color.gray.opacity(0.1))
                            .cornerRadius(8)
                        }
                        .disabled(isAutomatedTestRunning)
                    }
                }
                .padding(.horizontal)
                
                Divider()
                
                // 自動テスト
                VStack(alignment: .leading, spacing: 15) {
                    Text("Automated Test")
                        .font(.headline)
                    
                    HStack {
                        Text("Duration per level:")
                        Slider(value: $testDuration, in: 30...300, step: 30)
                        Text("\(Int(testDuration))s")
                            .frame(width: 50)
                    }
                    
                    Button(action: runAutomatedTest) {
                        HStack {
                            Image(systemName: isAutomatedTestRunning ? "stop.circle.fill" : "play.rectangle.fill")
                            Text(isAutomatedTestRunning ? "Stop Test" : "Run All Levels")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isAutomatedTestRunning ? Color.red : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                // インストラクション
                Text("Use Instruments Energy Log while running tests")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding()
            }
            .navigationBarHidden(true)
        }
    }
    
    private func runAutomatedTest() {
        if isAutomatedTestRunning {
            loadGenerator.stopLoad()
            isAutomatedTestRunning = false
            return
        }
        
        isAutomatedTestRunning = true
        
        Task {
            for level in CPULoadGenerator.LoadLevel.allCases {
                guard isAutomatedTestRunning else { break }
                
                await MainActor.run {
                    loadGenerator.measureLoadWithSignpost(level: level, duration: testDuration)
                }
                
                try? await Task.sleep(nanoseconds: UInt64(testDuration * 1_000_000_000))
                
                // レベル間の休憩時間
                if level != CPULoadGenerator.LoadLevel.allCases.last {
                    try? await Task.sleep(nanoseconds: 5_000_000_000) // 5秒
                }
            }
            
            await MainActor.run {
                isAutomatedTestRunning = false
            }
        }
    }
}

#Preview {
    ContentView()
}
