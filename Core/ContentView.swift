import SwiftUI
import UIKit

struct ContentView: View {

    private let initialURL = SWVContext.shared.initialURL

    @State private var showSplash = true
    @State private var splashImage: UIImage? = nil

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
        .onAppear {

            if let splashURL = Bundle.main.url(
                forResource: "splash_njci",
                withExtension: "png"
            ) {

                print("✅ SPLASH ENCONTRADA: \(splashURL.path)")

                if let image = UIImage(
                    contentsOfFile: splashURL.path
                ) {
                    print("✅ SPLASH CARREGADA COMO IMAGEM")
                    splashImage = image
                } else {
                    print("❌ ARQUIVO ENCONTRADO, MAS A IMAGEM NÃO ABRIU")
                }

            } else {
                print("❌ SPLASH NÃO ENCONTRADA NO BUNDLE")
            }

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
