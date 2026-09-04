import SwiftUI

struct ContentView: View {

    private let initialURL = SWVContext.shared.initialURL

    @State private var showSplash = true

    var body: some View {
        ZStack {

            if let url = initialURL {
                WebView(url: url)
                    .ignoresSafeArea()
            } else {
                Text("Erro ao carregar o atendimento.")
            }

            if showSplash {
                ZStack {
                    Color.white
                        .ignoresSafeArea()

                    Image("splash_njci")
                        .resizable()
                        .scaledToFit()
                        .ignoresSafeArea()
                }
                .zIndex(10)
                .transition(.opacity)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.easeOut(duration: 0.3)) {
                    showSplash = false
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
