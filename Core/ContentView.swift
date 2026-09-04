import SwiftUI
import UIKit

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

                    if let splashURL = Bundle.main.url(
                        forResource: "splash_njci",
                        withExtension: "png"
                    ) {

                        print("✅ SPLASH ENCONTRADA: \(splashURL.path)")

                        if let splashImage = UIImage(
                            contentsOfFile: splashURL.path
                        ) {

                            print("✅ SPLASH CARREGADA COMO IMAGEM")

                            Image(uiImage: splashImage)
                                .resizable()
                                .scaledToFit()
                                .ignoresSafeArea()

                        } else {

                            print("❌ ARQUIVO ENCONTRADO, MAS NÃO FOI POSSÍVEL ABRIR A IMAGEM")
                        }

                    } else {

                        print("❌ SPLASH NÃO ENCONTRADA NO BUNDLE")
                    }
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
