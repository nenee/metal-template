import PlaygroundSupport
import MetalKit

guard let device = MTLCreateSystemDefaultDevice() else {
    fatalError("GPU ain't supported")
}

// view setup
// configures a view for metal renderer
let frame = CGRect(x: 0, y: 0, width: 600, height: 600);
let view = MTKView(frame: frame, device: device);
view.clearColor = MTLClearColor(red: 1, green: 1, blue: 0.8, alpha: 1);
view.device = device;

// to keep command buffers organized
guard let commandQueue = device.makeCommandQueue() else {
    fatalError("Couldn't create a command queue")
}

// manages memory for the mesh data
let allocator = MTKMeshBufferAllocator(device: device);

// model io creates a sphere & returns a mesh with all vertex info in buffers
let mdlMesh = MDLMesh(sphereWithExtent: [0.75, 0.75, 0.75],
                      segments: [100, 100],
                      inwardNormals: false,
                      geometryType: .triangles,
                      allocator: allocator);
// convert mesh from model io to metalkit mesh
let mesh = try MTKMesh(mesh: mdlMesh, device: device);

// shader function
let shader = """
#include <metal_stdlib> \n
using namespace metal;

struct VertexIn {
float4 position [[ attribute(0) ]];
};

vertex float4 vertex_main(const VertexIn vertex_in [[ stage_in ]]) {
return vertex_in.position;
}

fragment float4 fragment_main() {
return float4(1, 0, 0, 1);
}
"""

// compliler will check if these functions exist and make them available to a pipeline descriptor
let library = try device.makeLibrary(source: shader, options: nil);
let vertexFunction = library.makeFunction(name: "vertex_main");
let fragmentFunction = library.makeFunction(name: "fragment_main");

// set up descriptor
// ...with correct shader funcs + vertex descriptor (describes how vertices are laid out in a metla buffer)
let descriptor = MTLRenderPipelineDescriptor();
descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm;
descriptor.vertexFunction = vertexFunction;
descriptor.fragmentFunction = fragmentFunction;
descriptor.vertexDescriptor = MTKMetalVertexDescriptorFromModelIO(mesh.vertexDescriptor);

// create pipeline state from the descriptor ^
let pipelineState = try device.makeRenderPipelineState(descriptor: descriptor);

// create command buffer which stores all commands the gpu is asked to run
guard let commandBuffer = commandQueue.makeCommandBuffer(),
    
// obtain a reference to the view's render pass descriptor.
// ... it holds data for several render destinations, inc "attachments"
// ... each attachment will need info (ie texture to store to, keep texture throughout render pass?)
// ... render pass descriptor is used to create the render command encoder
let descriptor = view.currentRenderPassDescriptor,
    // render command encoder; holds all info required to send to the gpu so that the gpu can draw vertices
let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor)
    else {
        fatalError()
    }

// pass pipeline state to render encoder
renderEncoder.setRenderPipelineState(pipelineState);

// pass the buffer to the render encoder
//... offset = pos in buffer where vertex info starts, index = how the gpu vertex shader func will locate the buffer
renderEncoder.setVertexBuffer(mesh.vertexBuffers[0].buffer, offset: 0, index: 0);

guard let submesh = mesh.submeshes.first else {
    fatalError()
}

// instructs the gpu to render a vertex buffer made up of triangles w/vertices placed in the correct order by the submesh index info.
renderEncoder.drawIndexedPrimitives(type: .triangle,
                                    indexCount: submesh.indexCount,
                                    indexType: submesh.indexType,
                                    indexBuffer: submesh.indexBuffer.buffer,
                                    indexBufferOffset: 0);


// tell render encoder there are no more draw calls
renderEncoder.endEncoding();
guard let drawable = view.currentDrawable else {
    fatalError()
}

// ask command buffer to present mktview's drawable and commit to the GPU
commandBuffer.present(drawable);
commandBuffer.commit();

// display the metal view
PlaygroundPage.current.liveView = view;

