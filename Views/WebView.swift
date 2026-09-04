import SwiftUI
import WebKit
import PhotosUI
import UniformTypeIdentifiers

// This class will hold our single WKWebView instance.
// This ensures it's created only once for the lifetime of the view.
class WebViewStore: ObservableObject {
    let webView: WKWebView

    init() {
        let configuration = WKWebViewConfiguration()

        // We will add the userContentController configuration
        // within the Coordinator.
        self.webView = WKWebView(
            frame: .zero,
            configuration: configuration
        )
    }
}

struct WebView: UIViewRepresentable {

    let url: URL

    // Use a StateObject to ensure the store is created
    // once per view lifecycle.
    @StateObject private var webViewStore = WebViewStore()

    func makeCoordinator() -> Coordinator {
        Coordinator(
            self,
            webView: webViewStore.webView
        )
    }

    func makeUIView(context: Context) -> WKWebView {

        let webView = webViewStore.webView

        // The coordinator is the single source of all delegates.
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator

        // Initialize all registered plugins.
        PluginManager.shared.initializePlugins(
            context: SWVContext.shared,
            webView: webView
        )

        // Pull to refresh.
        if SWVContext.shared.pullToRefreshEnabled {

            let refreshControl = UIRefreshControl()

            refreshControl.addTarget(
                context.coordinator,
                action: #selector(Coordinator.handleRefresh),
                for: .valueChanged
            )

            webView.scrollView.addSubview(refreshControl)
            webView.scrollView.bounces = true
        }

        // Load initial URL only once.
        let request = URLRequest(url: url)
        webView.load(request)

        return webView
    }

    // Keep empty to prevent unnecessary reloads.
    func updateUIView(
        _ uiView: WKWebView,
        context: Context
    ) {
    }

    // Coordinator acts as a bridge between
    // WKWebView and SwiftUI.
    class Coordinator:
        NSObject,
        WKNavigationDelegate,
        WKScriptMessageHandler,
        WKUIDelegate,
        PHPickerViewControllerDelegate,
        UIImagePickerControllerDelegate,
        UINavigationControllerDelegate,
        UIDocumentPickerDelegate {

        var parent: WebView
        var webView: WKWebView

        private var filePickerCompletionHandler: (([URL]?) -> Void)?

        init(
            _ parent: WebView,
            webView: WKWebView
        ) {

            self.parent = parent
            self.webView = webView

            super.init()

            // Add message handlers.
            let swvContext = SWVContext.shared

            let userContentController =
                self.webView.configuration.userContentController

            if swvContext.enabledPlugins.contains("Toast") {
                userContentController.add(
                    self,
                    name: "toast"
                )
            }

            if swvContext.enabledPlugins.contains("Dialog") {
                userContentController.add(
                    self,
                    name: "dialog"
                )
            }

            if swvContext.enabledPlugins.contains("Location") {
                userContentController.add(
                    self,
                    name: "location"
                )
            }
        }


        // MARK: - Navigation

        func webView(
            _ webView: WKWebView,
            didFinish navigation: WKNavigation!
        ) {

            if let refreshControl =
                webView.scrollView.subviews.first(
                    where: { $0 is UIRefreshControl }
                ) as? UIRefreshControl {

                refreshControl.endRefreshing()
            }

            // Platform detection.
            let script = """
            if (typeof setPlatform === 'function') {
                setPlatform('ios');
            }
            """

            webView.evaluateJavaScript(
                script,
                completionHandler: nil
            )

            // Notify plugins that the page loaded.
            if let url = webView.url {
                PluginManager.shared.webViewDidFinishLoad(
                    url: url
                )
            }
        }


        // MARK: - Error page

        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: Error
        ) {

            let nsError = error as NSError

            // Ignore normal cancelled navigations / redirects.
            if nsError.code == NSURLErrorCancelled {
                return
            }

            loadErrorPage(in: webView)
        }

        func webView(
            _ webView: WKWebView,
            didFail navigation: WKNavigation!,
            withError error: Error
        ) {

            let nsError = error as NSError

            if nsError.code == NSURLErrorCancelled {
                return
            }

            loadErrorPage(in: webView)
        }

        private func loadErrorPage(
            in webView: WKWebView
        ) {

            guard let errorURL = Bundle.main.url(
                forResource: "error",
                withExtension: "html",
                subdirectory: "web"
            ) else {
                return
            }

            webView.loadFileURL(
                errorURL,
                allowingReadAccessTo:
                    errorURL.deletingLastPathComponent()
            )
        }


        // MARK: - Navigation policy

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler:
                @escaping (WKNavigationActionPolicy) -> Void
        ) {

            if let url = navigationAction.request.url,
               URLHandler.handle(
                    url: url,
                    webView: webView
               ) {

                decisionHandler(.cancel)
                return
            }

            decisionHandler(.allow)
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationResponse: WKNavigationResponse,
            decisionHandler:
                @escaping (WKNavigationResponsePolicy) -> Void
        ) {

            if !navigationResponse.canShowMIMEType {
                decisionHandler(.download)
            } else {
                decisionHandler(.allow)
            }
        }


        // MARK: - Downloads

        func webView(
            _ webView: WKWebView,
            navigationResponse: WKNavigationResponse,
            didBecome download: WKDownload
        ) {
            download.delegate = self
        }


        // MARK: - JavaScript messages

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {

            PluginManager.shared.handleScriptMessage(
                message: message
            )
        }


        // MARK: - Pull to refresh

        @objc func handleRefresh() {
            webView.reload()
        }


        // MARK: - File upload

        func webView(
            _ webView: WKWebView,
            runOpenPanelWith parameters: WKOpenPanelParameters,
            initiatedByFrame frame: WKFrameInfo,
            completionHandler:
                @escaping ([URL]?) -> Void
        ) {

            guard SWVContext.shared.fileUploadsEnabled else {
                completionHandler(nil)
                return
            }

            self.filePickerCompletionHandler =
                completionHandler

            let alert = UIAlertController(
                title: "Select Source",
                message: nil,
                preferredStyle: .actionSheet
            )


            // Camera

            if UIImagePickerController.isSourceTypeAvailable(
                .camera
            ) {

                alert.addAction(
                    UIAlertAction(
                        title: "Camera",
                        style: .default
                    ) { _ in

                        self.showImagePicker(
                            sourceType: .camera
                        )
                    }
                )
            }


            // Photo Library

            alert.addAction(
                UIAlertAction(
                    title: "Photo Library",
                    style: .default
                ) { _ in

                    var config =
                        PHPickerConfiguration(
                            photoLibrary: .shared()
                        )

                    config.selectionLimit =
                        SWVContext.shared.multipleUploadsEnabled &&
                        parameters.allowsMultipleSelection
                        ? 0
                        : 1

                    config.filter =
                        .any(
                            of: [
                                .images,
                                .videos
                            ]
                        )

                    let picker =
                        PHPickerViewController(
                            configuration: config
                        )

                    picker.delegate = self

                    self.present(picker)
                }
            )


            // Files

            alert.addAction(
                UIAlertAction(
                    title: "Browse Files",
                    style: .default
                ) { _ in

                    let documentPicker =
                        UIDocumentPickerViewController(
                            forOpeningContentTypes: [.item],
                            asCopy: true
                        )

                    documentPicker.delegate = self

                    documentPicker.allowsMultipleSelection =
                        SWVContext.shared.multipleUploadsEnabled &&
                        parameters.allowsMultipleSelection

                    self.present(documentPicker)
                }
            )


            // Cancel

            alert.addAction(
                UIAlertAction(
                    title: "Cancel",
                    style: .cancel
                ) { _ in

                    self.filePickerCompletionHandler?(nil)
                }
            )


            // iPad support

            if let popoverController =
                alert.popoverPresentationController {

                popoverController.sourceView = webView

                popoverController.sourceRect =
                    CGRect(
                        x: webView.bounds.midX,
                        y: webView.bounds.midY,
                        width: 0,
                        height: 0
                    )

                popoverController.permittedArrowDirections = []
            }

            self.present(alert)
        }


        // MARK: - Present ViewController

        private func present(
            _ viewController: UIViewController
        ) {

            if let rootVC =
                (UIApplication.shared.connectedScenes.first
                    as? UIWindowScene)?
                    .windows
                    .first(where: \.isKeyWindow)?
                    .rootViewController {

                rootVC.present(
                    viewController,
                    animated: true
                )
            }
        }


        // MARK: - Image Picker

        private func showImagePicker(
            sourceType:
                UIImagePickerController.SourceType
        ) {

            let picker =
                UIImagePickerController()

            picker.sourceType = sourceType
            picker.delegate = self

            picker.mediaTypes = [
                UTType.image.identifier,
                UTType.movie.identifier
            ]

            self.present(picker)
        }


        // MARK: - PHPicker

        func picker(
            _ picker: PHPickerViewController,
            didFinishPicking results: [PHPickerResult]
        ) {

            picker.dismiss(animated: true)

            guard !results.isEmpty else {
                filePickerCompletionHandler?(nil)
                return
            }

            var urls: [URL] = []
            let group = DispatchGroup()

            for result in results {

                group.enter()

                result.itemProvider
                    .loadFileRepresentation(
                        forTypeIdentifier:
                            UTType.item.identifier
                    ) { url, error in

                        defer {
                            group.leave()
                        }

                        guard let url = url,
                              error == nil else {
                            return
                        }

                        let tempDirectory =
                            FileManager.default
                                .temporaryDirectory

                        let destinationURL =
                            tempDirectory
                                .appendingPathComponent(
                                    UUID().uuidString
                                    + "."
                                    + url.pathExtension
                                )

                        do {

                            try FileManager.default.copyItem(
                                at: url,
                                to: destinationURL
                            )

                            urls.append(
                                destinationURL
                            )

                        } catch {

                            print(
                                "Error copying file: \(error)"
                            )
                        }
                    }
            }

            group.notify(queue: .main) {

                self.filePickerCompletionHandler?(
                    urls.isEmpty
                    ? nil
                    : urls
                )
            }
        }


        // MARK: - UIImagePicker

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info:
                [UIImagePickerController.InfoKey : Any]
        ) {

            picker.dismiss(animated: true)

            var fileURL: URL?

            let tempDir =
                FileManager.default
                    .temporaryDirectory


            if let image =
                info[.originalImage] as? UIImage,
               let data =
                image.jpegData(
                    compressionQuality: 0.5
                ) {

                let tempURL =
                    tempDir
                        .appendingPathComponent(
                            UUID().uuidString
                        )
                        .appendingPathExtension("jpg")

                try? data.write(
                    to: tempURL
                )

                fileURL = tempURL


            } else if let videoURL =
                        info[.mediaURL] as? URL {

                let tempURL =
                    tempDir
                        .appendingPathComponent(
                            UUID().uuidString
                        )
                        .appendingPathExtension(
                            videoURL.pathExtension
                        )

                try? FileManager.default.copyItem(
                    at: videoURL,
                    to: tempURL
                )

                fileURL = tempURL
            }


            if let url = fileURL {

                self.filePickerCompletionHandler?(
                    [url]
                )

            } else {

                self.filePickerCompletionHandler?(
                    nil
                )
            }
        }


        func imagePickerControllerDidCancel(
            _ picker: UIImagePickerController
        ) {

            picker.dismiss(animated: true)

            self.filePickerCompletionHandler?(nil)
        }


        // MARK: - Document Picker

        func documentPicker(
            _ controller:
                UIDocumentPickerViewController,
            didPickDocumentsAt urls: [URL]
        ) {

            self.filePickerCompletionHandler?(
                urls
            )
        }

        func documentPickerWasCancelled(
            _ controller:
                UIDocumentPickerViewController
        ) {

            self.filePickerCompletionHandler?(
                nil
            )
        }
    }
}


// MARK: - WKDownloadDelegate

extension WebView.Coordinator: WKDownloadDelegate {

    func download(
        _ download: WKDownload,
        decideDestinationUsing response: URLResponse,
        suggestedFilename: String,
        completionHandler:
            @escaping (URL?) -> Void
    ) {

        let docsURL =
            FileManager.default.urls(
                for: .documentDirectory,
                in: .userDomainMask
            )[0]

        let fileURL =
            docsURL.appendingPathComponent(
                suggestedFilename
            )

        completionHandler(fileURL)
    }

    func downloadDidFinish(
        _ download: WKDownload
    ) {
        print("Download finished.")
    }
}
