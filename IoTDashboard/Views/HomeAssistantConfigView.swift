import SwiftUI
import AVFoundation

struct HomeAssistantConfigView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var homeAssistantService: HomeAssistantService
    
    @State private var serverURL = ""
    @State private var accessToken = ""
    @State private var isTesting = false
    @State private var testResult: (success: Bool, message: String)?
    @State private var showQRScanner = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Servidor")) {
                    TextField("URL", text: $serverURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                    
                    Text("Exemplo: http://192.168.1.100:8123")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section(header: Text("Autenticação")) {
                    HStack(spacing: 12) {
                        SecureField("Long-Lived Access Token", text: $accessToken)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        
                        Button {
                            showQRScanner = true
                        } label: {
                            Image(systemName: "qrcode.viewfinder")
                                .font(.system(size: 20))
                                .foregroundColor(.blue)
                        }
                    }
                    
                    Link("Como obter o token?", destination: URL(string: "https://www.home-assistant.io/docs/authentication/")!)
                        .font(.caption)
                }
                
                Section {
                    Button(action: testConnection) {
                        HStack {
                            if isTesting {
                                ProgressView()
                            } else {
                                Image(systemName: "wifi")
                            }
                            Text("Testar Ligação")
                        }
                    }
                    .disabled(serverURL.isEmpty || accessToken.isEmpty || isTesting)
                    
                    if let result = testResult {
                        HStack {
                            Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(result.success ? .green : .red)
                            Text(result.message)
                                .foregroundColor(result.success ? .green : .red)
                        }
                    }
                }
            }
            .navigationTitle("Configurar Home Assistant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Guardar") {
                        saveConfig()
                    }
                    .disabled(serverURL.isEmpty || accessToken.isEmpty)
                }
            }
            .onAppear {
                if let config = homeAssistantService.config {
                    serverURL = config.serverURL
                    accessToken = config.accessToken
                }
            }
            // ✅ CORRIGIDO: fullScreenCover em vez de sheet (não fecha automaticamente)
            .fullScreenCover(isPresented: $showQRScanner) {
                QRScannerView { scannedCode in
                    handleQRCode(scannedCode)
                    showQRScanner = false  // ✅ Fecha o scanner
                    // NÃO fecha a view de config - só atualiza o campo
                }
            }
        }
    }
    
    private func handleQRCode(_ code: String) {
        print("📷 QR Code lido: \(code.prefix(50))...")
        
        // Se o QR tiver URL + Token (formato Home Assistant Companion)
        if code.contains("homeassistant://auth-callback") {
            if let url = URL(string: code),
               let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let token = components.queryItems?.first(where: { $0.name == "token" })?.value {
                accessToken = token
                print("✅ Token extraído do callback")
            }
        }
        // Se for apenas o token
        else if code.hasPrefix("eyJ") || code.count > 100 {
            accessToken = code
            print("✅ Token direto aplicado")
        }
        // Se for URL + Token em JSON
        else if let data = code.data(using: .utf8),
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let url = json["url"] as? String {
                serverURL = url
            }
            if let token = json["token"] as? String {
                accessToken = token
            }
            print("✅ Config JSON extraída")
        }
        else {
            print("⚠️ QR Code não reconhecido")
        }
    }
    
    private func testConnection() {
        isTesting = true
        testResult = nil
        
        let tempConfig = HomeAssistantConfig(
            serverURL: serverURL,
            accessToken: accessToken,
            isEnabled: true
        )
        
        homeAssistantService.config = tempConfig
        homeAssistantService.testConnection { success, message in
            isTesting = false
            testResult = (success, message ?? (success ? "Conectado!" : "Erro desconhecido"))
        }
    }
    
    private func saveConfig() {
        let config = HomeAssistantConfig(
            serverURL: serverURL,
            accessToken: accessToken,
            isEnabled: true
        )
        homeAssistantService.saveConfig(config)
        dismiss()
    }
}

// MARK: - QR Scanner View com botão fechar
struct QRScannerView: View {
    @Environment(\.dismiss) var dismiss
    var onCodeScanned: (String) -> Void
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            QRScannerRepresentable(onCodeScanned: onCodeScanned)
                .edgesIgnoringSafeArea(.all)
            
            // ✅ Botão fechar no topo
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.white)
                    .background(
                        Circle()
                            .fill(Color.black.opacity(0.5))
                            .frame(width: 44, height: 44)
                    )
            }
            .padding(.top, 50)
            .padding(.trailing, 20)
        }
    }
}

struct QRScannerRepresentable: UIViewControllerRepresentable {
    var onCodeScanned: (String) -> Void
    
    func makeUIViewController(context: Context) -> QRScannerViewController {
        let controller = QRScannerViewController()
        controller.delegate = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ uiViewController: QRScannerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onCodeScanned: onCodeScanned)
    }
    
    class Coordinator: NSObject, QRScannerDelegate {
        var onCodeScanned: (String) -> Void
        
        init(onCodeScanned: @escaping (String) -> Void) {
            self.onCodeScanned = onCodeScanned
        }
        
        func didScanCode(_ code: String) {
            onCodeScanned(code)
        }
    }
}

// MARK: - QR Scanner UIViewController
protocol QRScannerDelegate: AnyObject {
    func didScanCode(_ code: String)
}

class QRScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    weak var delegate: QRScannerDelegate?
    
    private var captureSession: AVCaptureSession!
    private var previewLayer: AVCaptureVideoPreviewLayer!
    private var scanAreaView: UIView!
    private var hasScanned = false  // ✅ Evita múltiplos scans
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .black
        captureSession = AVCaptureSession()
        
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            showAlert("Câmera não disponível")
            return
        }
        
        let videoInput: AVCaptureDeviceInput
        
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            showAlert("Erro ao aceder à câmera")
            return
        }
        
        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        } else {
            showAlert("Não foi possível adicionar input")
            return
        }
        
        let metadataOutput = AVCaptureMetadataOutput()
        
        if captureSession.canAddOutput(metadataOutput) {
            captureSession.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr]
        } else {
            showAlert("Não foi possível adicionar output")
            return
        }
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        setupScanArea()
        setupInstructionLabel()
        
        DispatchQueue.global(qos: .userInitiated).async {
            self.captureSession.startRunning()
        }
    }
    
    private func setupScanArea() {
        let scanSize: CGFloat = 250
        scanAreaView = UIView(frame: CGRect(
            x: (view.bounds.width - scanSize) / 2,
            y: (view.bounds.height - scanSize) / 2 - 50,
            width: scanSize,
            height: scanSize
        ))
        scanAreaView.layer.borderColor = UIColor.systemBlue.cgColor
        scanAreaView.layer.borderWidth = 3
        scanAreaView.layer.cornerRadius = 12
        scanAreaView.backgroundColor = .clear
        view.addSubview(scanAreaView)
        
        addCornerLines(to: scanAreaView)
    }
    
    private func addCornerLines(to view: UIView) {
        let length: CGFloat = 30
        let thickness: CGFloat = 4
        let color = UIColor.systemBlue.cgColor
        
        // Top-left
        let topLeft1 = CALayer()
        topLeft1.frame = CGRect(x: 0, y: 0, width: length, height: thickness)
        topLeft1.backgroundColor = color
        view.layer.addSublayer(topLeft1)
        
        let topLeft2 = CALayer()
        topLeft2.frame = CGRect(x: 0, y: 0, width: thickness, height: length)
        topLeft2.backgroundColor = color
        view.layer.addSublayer(topLeft2)
        
        // Top-right
        let topRight1 = CALayer()
        topRight1.frame = CGRect(x: view.bounds.width - length, y: 0, width: length, height: thickness)
        topRight1.backgroundColor = color
        view.layer.addSublayer(topRight1)
        
        let topRight2 = CALayer()
        topRight2.frame = CGRect(x: view.bounds.width - thickness, y: 0, width: thickness, height: length)
        topRight2.backgroundColor = color
        view.layer.addSublayer(topRight2)
        
        // Bottom-left
        let bottomLeft1 = CALayer()
        bottomLeft1.frame = CGRect(x: 0, y: view.bounds.height - thickness, width: length, height: thickness)
        bottomLeft1.backgroundColor = color
        view.layer.addSublayer(bottomLeft1)
        
        let bottomLeft2 = CALayer()
        bottomLeft2.frame = CGRect(x: 0, y: view.bounds.height - length, width: thickness, height: length)
        bottomLeft2.backgroundColor = color
        view.layer.addSublayer(bottomLeft2)
        
        // Bottom-right
        let bottomRight1 = CALayer()
        bottomRight1.frame = CGRect(x: view.bounds.width - length, y: view.bounds.height - thickness, width: length, height: thickness)
        bottomRight1.backgroundColor = color
        view.layer.addSublayer(bottomRight1)
        
        let bottomRight2 = CALayer()
        bottomRight2.frame = CGRect(x: view.bounds.width - thickness, y: view.bounds.height - length, width: thickness, height: length)
        bottomRight2.backgroundColor = color
        view.layer.addSublayer(bottomRight2)
    }
    
    private func setupInstructionLabel() {
        let label = UILabel()
        label.text = "Aponta para o QR Code do Token"
        label.textColor = .white
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.textAlignment = .center
        label.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        label.layer.cornerRadius = 8
        label.clipsToBounds = true
        label.frame = CGRect(
            x: 40,
            y: scanAreaView.frame.maxY + 30,
            width: view.bounds.width - 80,
            height: 40
        )
        view.addSubview(label)
    }
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        // ✅ Evita múltiplos scans
        guard !hasScanned else { return }
        hasScanned = true
        
        captureSession.stopRunning()
        
        if let metadataObject = metadataObjects.first {
            guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
            guard let stringValue = readableObject.stringValue else { return }
            
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            
            // ✅ Chama delegate mas NÃO fecha a view aqui
            delegate?.didScanCode(stringValue)
            
            // ✅ Feedback visual de sucesso
            showSuccessAnimation()
        }
    }
    
    private func showSuccessAnimation() {
        let checkmark = UIImageView(image: UIImage(systemName: "checkmark.circle.fill"))
        checkmark.tintColor = .systemGreen
        checkmark.frame = CGRect(x: 0, y: 0, width: 80, height: 80)
        checkmark.center = view.center
        checkmark.alpha = 0
        view.addSubview(checkmark)
        
        UIView.animate(withDuration: 0.3, animations: {
            checkmark.alpha = 1
            checkmark.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
        }) { _ in
            UIView.animate(withDuration: 0.2, delay: 0.3, animations: {
                checkmark.alpha = 0
            })
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        if captureSession?.isRunning == true {
            captureSession.stopRunning()
        }
    }
    
    private func showAlert(_ message: String) {
        let alert = UIAlertController(title: "Erro", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
