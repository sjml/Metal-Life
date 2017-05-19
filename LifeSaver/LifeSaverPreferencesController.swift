import Cocoa
import ScreenSaver
import simd

class LifeSaverPreferencesController: NSWindowController {
    let defaults: ScreenSaverDefaults? = ScreenSaverDefaults(forModuleWithName: Bundle(for: LifeSaverPreferencesController.self).bundleIdentifier!)
    
    @IBOutlet weak var bgColorWell: NSColorWell!
    @IBOutlet weak var fgColorWell: NSColorWell!
    @IBOutlet weak var pointSizeSlider: NSSlider! {
        didSet {
            pointSizeSlider.minValue = 1.0
            pointSizeSlider.maxValue = 13.0
            pointSizeSlider.doubleValue = 9.0
        }
    }
    @IBOutlet weak var pointSizeLabel: NSTextField!
    
    @IBOutlet weak var fpsMenu: NSPopUpButton!
    
    @IBAction func okButtonAction(_ sender: Any) {
        self.defaults?.set(pointSizeSlider.doubleValue,      forKey: "pointSize")
        self.defaults?.set(bgColorWell.color.redComponent,   forKey: "bgRed")
        self.defaults?.set(bgColorWell.color.greenComponent, forKey: "bgGreen")
        self.defaults?.set(bgColorWell.color.blueComponent,  forKey: "bgBlue")
        self.defaults?.set(fgColorWell.color.redComponent,   forKey: "fgRed")
        self.defaults?.set(fgColorWell.color.greenComponent, forKey: "fgGreen")
        self.defaults?.set(fgColorWell.color.blueComponent,  forKey: "fgBlue")
        
        let req = fpsMenu.selectedItem?.title
        let reqInt = Int(req!)!
        self.defaults?.set(reqInt, forKey: "frameRate")
        
        self.defaults?.synchronize()
        NSApp.mainWindow?.endSheet(self.window!)
    }
    @IBAction func restoreButtonAction(_ sender: Any) {
        self.defaults?.set(9.0,  forKey: "pointSize")
        self.defaults?.set(0.25, forKey: "bgRed")
        self.defaults?.set(0.0,  forKey: "bgGreen")
        self.defaults?.set(0.0,  forKey: "bgBlue")
        self.defaults?.set(1.0,  forKey: "fgRed")
        self.defaults?.set(0.0,  forKey: "fgGreen")
        self.defaults?.set(0.0,  forKey: "fgBlue")
        self.defaults?.set(60,   forKey: "frameRate")
        
        self.syncUI()
    }
    @IBAction func sliderValueChanged(_ sender: Any) {
        self.pointSizeLabel.stringValue = String(format: "%.1f", arguments: [self.pointSizeSlider.doubleValue])
    }
    
    required init?(coder decoder: NSCoder) {
        super.init(coder: decoder)
    }
    override init(window: NSWindow?) {
        super.init(window: window)
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
        
        let prefsFilePath = Bundle(for: LifeSaverPreferencesController.self).path(forResource: "InitialPreferences", ofType: "plist")
        let nsDefaultPrefs = NSDictionary(contentsOfFile: prefsFilePath!)
        if let defaultPrefs: Dictionary<String,Any> = nsDefaultPrefs as? Dictionary<String, Any> {
            self.defaults?.register(defaults: defaultPrefs)
        }
        
        self.syncUI()
    }
    
    func syncUI() {
        self.pointSizeSlider.doubleValue = self.defaults!.double(forKey: "pointSize")
        self.pointSizeLabel.stringValue = String(format: "%.1f", arguments: [self.pointSizeSlider.doubleValue])
        self.bgColorWell.color = NSColor(
            red: CGFloat(self.defaults!.double(forKey: "bgRed")),
            green: CGFloat(self.defaults!.double(forKey: "bgGreen")),
            blue: CGFloat(self.defaults!.double(forKey: "bgBlue")),
            alpha: 1.0
        )
        self.fgColorWell.color = NSColor(
            red: CGFloat(self.defaults!.double(forKey: "fgRed")),
            green: CGFloat(self.defaults!.double(forKey: "fgGreen")),
            blue: CGFloat(self.defaults!.double(forKey: "fgBlue")),
            alpha: 1.0
        )
        
        let frameRate = self.defaults!.integer(forKey: "frameRate")
        NSLog("got framerate: %d", frameRate)
        NSLog(String(frameRate))
        let menuItem = self.fpsMenu.item(withTitle: String(frameRate))
        NSLog("got menu item")
        self.fpsMenu.select(menuItem)
    }
}
