```swift
import SwiftUI
import UIKit

struct ContentView: View {

    private let initialURL = SWVContext.shared.initialURL

    @State private var showSplash = true
    @State private var splashImage: UIImage? = nil

    @StateObject private var networkMonitor = NetworkMonitor()

    var body: some View {
        ZStack {

            if networkMonitor.isConnected {

                if let url = initialURL {
                    WebView(url: url)
                        .ignoresSafeArea()
                } else {
                    Text("Erro ao carregar o atendimento.")
                }

            } else {

                NoInternetView()
            }

            if showSplash {
                ZStack {
                    Color.white
                        .ignoresSafeArea()

                    if let splashImage = splashImage {
                        Image(uiImage: splashImage)
                            .resizable()
                            .scaledToFit()
                            .ignoresSafeArea()
                    }
                }
                .zIndex(10)
                .transition(.opacity)
            }
        }
        ```swift
.onAppear {

    if let splashURL = Bundle.main.url(
        forResource: "splash_njci",
        withExtension: "png"
    ),
    let image = UIImage(contentsOfFile: splashURL.path) {
        splashImage = image
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
        withAnimation(.easeOut(duration: 0.3)) {
            showSplash = false
        }
    }
}
```

    }
}

struct NoInternetView: View {

    var body: some View {
        ZStack {

            Color.white
                .ignoresSafeArea()

            VStack(spacing: 20) {

                Image(systemName: "wifi.slash")
                    .font(.system(size: 70))
                    .foregroundColor(
                        Color(
                            red: 53 / 255,
                            green: 130 / 255,
                            blue: 184 / 255
                        )
                    )

                Text("Sem conexão com a internet")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)

                Text(
                    "Conecte-se a uma rede Wi-Fi ou ative os dados móveis para iniciar o atendimento."
                )
                .font(.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 35)
            }
        }
    }
}

#Preview {
    ContentView()
}
```

