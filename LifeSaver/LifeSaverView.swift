import ScreenSaver
import simd


class LifeSaverView: ScreenSaverView {
    var lifeView: LifeView?
    var eqTimer: Timer?
    var prefsWindowController: LifeSaverPreferencesController?
    let defaults: ScreenSaverDefaults? = ScreenSaverDefaults(forModuleWithName: Bundle(for: LifeSaverPreferencesController.self).bundleIdentifier!)
    
    override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
                
        self.lifeView = LifeView(frame: frame)
        
        self.addSubview(lifeView!)
    }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        
        if self.window == nil {
            self.stopAnimation()
            return
        }
        
        if (lifeView == nil) {
            return
        }
        
        lifeView!.setup()
        
        let prefsFilePath = Bundle(for: LifeSaverPreferencesController.self).path(forResource: "InitialPreferences", ofType: "plist")
        let nsDefaultPrefs = NSDictionary(contentsOfFile: prefsFilePath!)
        if let defaultPrefs: Dictionary<String,Any> = nsDefaultPrefs as? Dictionary<String, Any> {
            self.defaults?.register(defaults: defaultPrefs)
        }
        
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
            let fr = self.defaults!.integer(forKey: "frameRate")
            lifeView!.numSkipFrames = (60 / fr) - 1
        }
        
        eqTimer = Timer.scheduledTimer(timeInterval: 3.0, target: self.lifeView!, selector: #selector(LifeView.checkForEquilibrium), userInfo: nil, repeats: true)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        fatalError("init(coder:) has not been implemented")
    }
    
    override class func backingStoreType() -> NSBackingStoreType {
        return NSBackingStoreType.nonretained
    }
    
    override func startAnimation() {
        if (self.lifeView != nil) {
            self.lifeView!.start()
        }
    }
    
    override func stopAnimation() {
        if (self.lifeView != nil) {
            self.lifeView!.stop()
        }
    }
    
    override func animateOneFrame() {
        if (self.lifeView != nil) {
            self.lifeView!.render()
        }
    }
    
    override var isAnimating: Bool {
        get {
            if (self.lifeView == nil) {
                return false
            }
            return self.lifeView!.isAnimating()
        }
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

