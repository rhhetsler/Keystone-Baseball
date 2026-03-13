import SwiftUI

struct ContentView: View {
    
    @StateObject private var vm = StatGameViewModel()
    
    var body: some View {
        VStack(spacing: 20) {
            
            // BIG SCORE = MISTAKES
            HStack {
                VStack {
                    Text(vm.homeName)
                        .font(.caption)
                    Text("\(vm.totals(for: .home).mistakesTotal)")
                        .font(.largeTitle.bold())
                    Text("Mistakes")
                        .font(.caption2)
                }
                
                Spacer()
                
                VStack {
                    Text(vm.awayName)
                        .font(.caption)
                    Text("\(vm.totals(for: .away).mistakesTotal)")
                        .font(.largeTitle.bold())
                    Text("Mistakes")
                        .font(.caption2)
                }
            }
            .padding()
            
            // Runs visible below
            Text("Runs: \(vm.homeName) \(vm.totals(for: .home).runs)  •  \(vm.awayName) \(vm.totals(for: .away).runs)")
                .font(.headline)
            
            Divider()
            
            Button("Run +1") {
                vm.runPlus()
            }
            .buttonStyle(.borderedProminent)
            
            Button("Strike Out (Batting Team)") {
                vm.strikeout()
            }
            .buttonStyle(.bordered)
            
            Spacer()
        }
        .padding()
        .navigationTitle("The Game Within The Game")
    }
}

#Preview {
    ContentView()
}
