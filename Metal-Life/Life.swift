import Cocoa
import MetalKit
import simd

struct Uniforms {
    var mvpMatrix = matrix_identity_float4x4
    var bgColor: float4 = float4(0.0)
    var fgColor: float4 = float4(1.0)
    var pointSize: Float = 9.0 // 1.0 to 14.0
    var gridDimensions: uint2 = uint2(32, 32)
}

class LifeView: MTKView {
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
    
    required init(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override var acceptsFirstResponder: Bool {
        return true
    }

    func setup(device: MTLDevice) {
        self.device = device

        let defaultLibrary = device.newDefaultLibrary()
        let fragmentProgram = defaultLibrary!.makeFunction(name: "lifeFragment")
        vertexProgram = defaultLibrary!.makeFunction(name: "lifeVertex")
        simulateProgram = defaultLibrary!.makeFunction(name: "lifeSimulate")
        
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
    
    override func viewDidEndLiveResize() {
        self.needsReset = true
    }
    
    func resetBuffers() {
        self.needsReset = false
                
        let pixelSpacing: Float = (3.0 / 128.0)
        let gridSpacing: Float = (40.0 / 3.0)
        let unitDimensions: float2 = float2(Float(self.bounds.width) * pixelSpacing, Float(self.bounds.height) * pixelSpacing) * 0.5
        
        self.uniforms.mvpMatrix = matrix_ortho(-unitDimensions.x, unitDimensions.x, -unitDimensions.y, unitDimensions.y, -1.0, 1.0)
        self.uniforms.gridDimensions.x = UInt32(unitDimensions.x * gridSpacing)
        self.uniforms.gridDimensions.y = UInt32(unitDimensions.y * gridSpacing)
        self.numCells = Int(self.uniforms.gridDimensions.x * self.uniforms.gridDimensions.y)
        
        self.cpuCellsBuffer = [UInt8](repeating: 0, count: self.numCells)
        let memSize: Int = self.numCells * MemoryLayout<UInt8>.stride
        
        if (vertexBufferB == nil || vertexBufferB!.length != memSize) {
            self.vertexBufferB = device!.makeBuffer(bytes: self.cpuCellsBuffer, length: self.numCells * MemoryLayout<UInt8>.stride, options: [.storageModeManaged])
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
            self.vertexBufferA = device!.makeBuffer(bytes: self.cpuCellsBuffer, length: self.numCells * MemoryLayout<UInt8>.stride, options: [.storageModeManaged])
        }
        else {
            memcpy(vertexBufferA!.contents(), self.cpuCellsBuffer, memSize)
            self.vertexBufferA!.didModifyRange(NSMakeRange(0, memSize))
        }
        
        self.drawingA = true
    }

    func render(drawable: CAMetalDrawable) {
        if (self.inLiveResize) {
            return
        }
        
        if (self.needsReset) {
            self.resetBuffers()
        }
        
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
        
        self.drawingA = !self.drawingA
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
}
