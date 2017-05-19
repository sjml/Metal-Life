import ScreenSaver
import MetalKit


class LifeSaverView: ScreenSaverView {
    var lifeView: LifeView?
    var eqTimer: Timer?
    var prefsWindowController: LifeSaverPreferencesController?
    let defaults: ScreenSaverDefaults? = ScreenSaverDefaults(forModuleWithName: Bundle(for: LifeSaverPreferencesController.self).bundleIdentifier!)
    
    override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
        
        if let device = MTLCreateSystemDefaultDevice() {
            self.lifeView = LifeView(frame: frame, device: device)
        }
        if (self.lifeView == nil) {
            return nil
        }

        self.lifeView!.delegate = self
        self.lifeView!.preferredFramesPerSecond = 60
        self.lifeView!.clearColor = MTLClearColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        
        self.addSubview(lifeView!)
    }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        
        if self.window == nil {
            return
        }
        
        if let device = MTLCreateSystemDefaultDevice() {
            lifeView!.setup(device: device)
            
            if (self.defaults != nil) {
                lifeView!.uniforms.pointSize = self.defaults!.float(forKey: "pointSize")
                lifeView!.uniforms.bgColor = float4(
                    self.defaults!.float(forKey: "bgRed"),
                    self.defaults!.float(forKey: "bgGreen"),
                    self.defaults!.float(forKey: "bgBlue"),
                    1.0
                )
                lifeView!.uniforms.fgColor = float4(
                    self.defaults!.float(forKey: "fgRed"),
                    self.defaults!.float(forKey: "fgGreen"),
                    self.defaults!.float(forKey: "fgBlue"),
                    1.0
                )
            }
            
            eqTimer = Timer.scheduledTimer(timeInterval: 3.0, target: self.lifeView!, selector: #selector(LifeView.checkForEquilibrium), userInfo: nil, repeats: true)
        }
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        fatalError("init(coder:) has not been implemented")
    }
    
    override func hasConfigureSheet() -> Bool {
        return true
    }
    
    override func configureSheet() -> NSWindow? {
        if let controller = self.prefsWindowController {
            return controller.window
        }
        
        self.prefsWindowController = LifeSaverPreferencesController(windowNibName: "LifeSaverPreferences")
        return self.prefsWindowController!.window
    }
}

extension LifeSaverView: MTKViewDelegate {
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        
    }
    
    func draw(in view: MTKView) {
        if let cDraw = view.currentDrawable {
            if (self.lifeView != nil) {
                self.lifeView!.render(drawable: cDraw)
            }
        }
    }
}
