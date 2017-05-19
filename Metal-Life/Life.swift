import Cocoa
import Metal
import simd

struct Uniforms {
    var mvpMatrix = matrix_identity_float4x4
    var bgColor: float4 = float4(0.0)
    var fgColor: float4 = float4(1.0)
    var pointSize: Float = 9.0 // 1.0 to 14.0
    var gridDimensions: uint2 = uint2(32, 32)
}

class LifeView : NSView {
    let device: MTLDevice
    var displayLink: CVDisplayLink!
    // 0 = 60; 1 = 30; 3 = 15; 5 = 10; 11 = 5; 29 = 2; 59 = 1; 119 = 0.5
    var numSkipFrames: Int = 0
    private var frameSkipCounter: Int
    var simulationPipelineState: MTLRenderPipelineState!
    var renderingPipelineState: MTLRenderPipelineState!
    var vertexProgram: MTLFunction!
    var simulateProgram: MTLFunction!
    var commandQueue: MTLCommandQueue!
    
    var vertexBufferA: MTLBuffer? = nil
    var vertexBufferB: MTLBuffer? = nil
    var drawingA: Bool = true
    var uniforms: Uniforms = Uniforms()
    var numCells:Int = 1024
    var cpuCellsBuffer: [UInt8] = []
    var needsReset: Bool = false
    
    required init?(coder: NSCoder) {
        if let defaultDev = MTLCreateSystemDefaultDevice() {
            self.device = defaultDev
        }
        else {
            return nil
        }
        
        self.frameSkipCounter = self.numSkipFrames

        super.init(coder: coder)
        self.wantsLayer = true
    }
    
    override init(frame: NSRect) {
        let defaultDev = MTLCreateSystemDefaultDevice()
        self.device = defaultDev!
        
        self.frameSkipCounter = self.numSkipFrames

        super.init(frame: frame)
        self.wantsLayer = true
    }
    
    deinit {
        CVDisplayLinkStop(displayLink)
    }
    
    override var acceptsFirstResponder: Bool {
        return true
    }

    func setup() {
        if let window = self.superview?.window {
            let mLayer = CAMetalLayer()
            mLayer.device = self.device
            mLayer.pixelFormat = .bgra8Unorm
            mLayer.framebufferOnly = true
            mLayer.contentsScale = window.backingScaleFactor
            mLayer.frame = self.layer!.frame
            mLayer.isOpaque = true
            self.layer = mLayer
            
            self.displayLink = makeDisplayLink(window: window)
        }

        var metalLib = device.newDefaultLibrary()
        if (metalLib == nil) {
            try! metalLib = device.makeLibrary(filepath: Bundle(for: LifeView.self).path(forResource: "default", ofType: "metallib")!)
        }
        let fragmentProgram = metalLib!.makeFunction(name: "lifeFragment")
        vertexProgram = metalLib!.makeFunction(name: "lifeVertex")
        simulateProgram = metalLib!.makeFunction(name: "lifeSimulate")
        
        let renderStateDescriptor = MTLRenderPipelineDescriptor()
        renderStateDescriptor.vertexFunction = vertexProgram
        renderStateDescriptor.fragmentFunction = fragmentProgram
        renderStateDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        
        renderingPipelineState = try! device.makeRenderPipelineState(descriptor: renderStateDescriptor)
        
        let simulateStateDescriptor = MTLRenderPipelineDescriptor()
        simulateStateDescriptor.isRasterizationEnabled = false
        simulateStateDescriptor.vertexFunction = simulateProgram
        simulateStateDescriptor.fragmentFunction = nil
        simulateStateDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        
        simulationPipelineState = try! device.makeRenderPipelineState(descriptor: simulateStateDescriptor)
        
        commandQueue = device.makeCommandQueue()
        
        resetBuffers()
    }
    
    func start() {
        CVDisplayLinkStart(displayLink!)
    }
    
    func stop() {
        CVDisplayLinkStop(displayLink!)
    }
    
    func isAnimating() -> Bool {
        return CVDisplayLinkIsRunning(displayLink!)
    }
    
    private func makeDisplayLink(window: NSWindow) -> CVDisplayLink {
        func displayLinkOutputCallback(_ displayLink: CVDisplayLink, _ nowPtr: UnsafePointer<CVTimeStamp>, _ outputTimePtr: UnsafePointer<CVTimeStamp>, _ flagsIn: CVOptionFlags, _ flagsOut: UnsafeMutablePointer<CVOptionFlags>, _ displayLinkContext: UnsafeMutableRawPointer?) -> CVReturn {
            let me: LifeView = unsafeBitCast(displayLinkContext, to: LifeView.self)
            me.render()
            return kCVReturnSuccess
        }
        
        var link: CVDisplayLink?
        let screensID = UInt32(window.screen!.deviceDescription["NSScreenNumber"] as! Int)
        CVDisplayLinkCreateWithCGDisplay(screensID, &link)
        CVDisplayLinkSetOutputCallback(link!, displayLinkOutputCallback, UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()))
        return link!
    }
    
    override func viewDidEndLiveResize() {
        self.needsReset = true
    }
    
    func makeOrthoMatrix(left: Float, right: Float, bottom: Float, top: Float, near: Float, far: Float) -> float4x4 {
        
        var forReturn: float4x4 = float4x4();
        
        forReturn[0][0] = Float(2.0) / (right - left);
        forReturn[0][1] = Float(0.0);
        forReturn[0][2] = Float(0.0);
        forReturn[0][3] = Float(0.0);
        forReturn[1][0] = Float(0.0);
        forReturn[1][1] = Float(2.0) / (top - bottom);
        forReturn[1][2] = Float(0.0);
        forReturn[1][3] = Float(0.0);
        forReturn[2][0] = Float(0.0);
        forReturn[2][1] = Float(0.0);
        forReturn[2][2] = Float(1.0) / (far - near);
        forReturn[2][3] = Float(1.0);
        forReturn[3][0] = (left + right) / (left - right);
        forReturn[3][1] = (top + bottom) / (bottom - top);
        forReturn[3][2] = near / (near - far);
        forReturn[3][3] = Float(1.0);
        
        return forReturn;
    }
    
    
    func checkForEquilibrium() {
        let current = self.vertexBufferA!.contents()
        var currentInts = [UInt8](repeating: 0, count: self.numCells)
        var changeCount: Int = 0
        for i in 0..<self.numCells {
            let c = current.load(fromByteOffset: i * MemoryLayout<UInt8>.stride, as: UInt8.self)
            if self.cpuCellsBuffer[i] != c {
                changeCount += 1
            }
            currentInts[i] = c
        }
        self.cpuCellsBuffer = currentInts
        
        let change = Float(changeCount) / Float(self.numCells)
        //        print("\(change * 100.0)% change since last check.")
        
        if change < 0.001 {
            self.needsReset = true
        }
    }
 
    func resetBuffers() {
        self.needsReset = false
 
        let pixelSpacing: Float = (3.0 / 128.0)
        let gridSpacing: Float = (40.0 / 3.0)
        let unitDimensions: float2 = float2(Float(self.bounds.width) * pixelSpacing, Float(self.bounds.height) * pixelSpacing) * 0.5
        
        let ortho = makeOrthoMatrix(left: -unitDimensions.x, right: unitDimensions.x, bottom: -unitDimensions.y, top: unitDimensions.y, near: -1.0, far: 1.0)
        self.uniforms.mvpMatrix = ortho.cmatrix
        self.uniforms.gridDimensions.x = UInt32(unitDimensions.x * gridSpacing)
        self.uniforms.gridDimensions.y = UInt32(unitDimensions.y * gridSpacing)
        self.numCells = Int(self.uniforms.gridDimensions.x * self.uniforms.gridDimensions.y)
        
        self.cpuCellsBuffer = [UInt8](repeating: 0, count: self.numCells)
        let memSize: Int = self.numCells * MemoryLayout<UInt8>.stride
        
        if (vertexBufferB == nil || vertexBufferB!.length != memSize) {
            self.vertexBufferB = device.makeBuffer(bytes: self.cpuCellsBuffer, length: self.numCells * MemoryLayout<UInt8>.stride, options: [.storageModeManaged])
        }
        else {
            memcpy(self.vertexBufferB!.contents(), self.cpuCellsBuffer, memSize)
            self.vertexBufferB!.didModifyRange(NSMakeRange(0, memSize))
        }
        
        // random fill
        for index in 0..<self.numCells {
            let rand = Float(arc4random()) / Float(UINT32_MAX)
            if (rand < 0.35) {
                self.cpuCellsBuffer[index] = 255
            }
        }
        
        if (vertexBufferA == nil || vertexBufferA!.length != memSize) {
            self.vertexBufferA = device.makeBuffer(bytes: self.cpuCellsBuffer, length: self.numCells * MemoryLayout<UInt8>.stride, options: [.storageModeManaged])
        }
        else {
            memcpy(vertexBufferA!.contents(), self.cpuCellsBuffer, memSize)
            self.vertexBufferA!.didModifyRange(NSMakeRange(0, memSize))
        }
        
        self.drawingA = true
    }

    func render() {
        if (self.inLiveResize) {
            return
        }
        
        if (self.needsReset) {
            self.resetBuffers()
        }
        
        self.frameSkipCounter -= 1
        if (self.frameSkipCounter < 0) {
            self.frameSkipCounter = self.numSkipFrames
        }
        else {
            return
        }
        
        if let drawable = (self.layer as! CAMetalLayer).nextDrawable() {
            let renderPassDescriptor = MTLRenderPassDescriptor()
            renderPassDescriptor.colorAttachments[0].texture = drawable.texture
            renderPassDescriptor.colorAttachments[0].loadAction = .clear
            
            let commandBuffer = commandQueue.makeCommandBuffer()
            let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
            
            if (self.drawingA) {
                encoder.setVertexBuffer(self.vertexBufferA, offset: 0, at: 0)
                encoder.setVertexBuffer(self.vertexBufferB, offset: 0, at: 1)
            }
            else {
                encoder.setVertexBuffer(self.vertexBufferB, offset: 0, at: 0)
                encoder.setVertexBuffer(self.vertexBufferA, offset: 0, at: 1)
            }
            encoder.setVertexBytes(&self.uniforms, length: MemoryLayout<Uniforms>.stride, at: 2)
            encoder.setFragmentBytes(&self.uniforms, length: MemoryLayout<Uniforms>.stride, at: 2)
            
            encoder.setRenderPipelineState(simulationPipelineState)
            encoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: self.numCells)
            
            encoder.setRenderPipelineState(renderingPipelineState)
            encoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: self.numCells)
            
            encoder.endEncoding()
            
            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
        
        self.drawingA = !self.drawingA
    }
}
