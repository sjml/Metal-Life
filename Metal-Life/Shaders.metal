#include <metal_stdlib>
using namespace metal;


constant float gridSpacing = (1.5 / 20.0);

struct VertexOut {
    float4 position [[position]];
    float pointSize [[point_size]];
    uchar lifetime;
};

struct NeighborIndices {
    uint4 cardinals;
    uint4 diagonals;
};

struct Uniforms {
    float4x4 mvpMatrix;
    float4 bgColor;
    float4 fgColor;
    float pointSize;
    uint2 gridDimensions;
};

static NeighborIndices getNeighbors(unsigned int index, uint2 gridDimensions) {
    NeighborIndices neighbors;
    
    neighbors.cardinals.x = index - 1; // west
    neighbors.cardinals.y = index + 1; // east
    neighbors.cardinals.z = (index - gridDimensions.x) % (gridDimensions.x * gridDimensions.y); // south
    neighbors.cardinals.w = (index + gridDimensions.x) % (gridDimensions.x * gridDimensions.y); // north
    
    neighbors.diagonals.x = neighbors.cardinals.z - 1; // southwest
    neighbors.diagonals.y = neighbors.cardinals.z + 1; // southeast
    neighbors.diagonals.z = neighbors.cardinals.w - 1; // northwest
    neighbors.diagonals.w = neighbors.cardinals.w + 1; // northeast
    
    if (index % gridDimensions.x == 0) {
        // shift western up by one for wrap-around
        neighbors.cardinals.x += gridDimensions.x;
        neighbors.diagonals.x += gridDimensions.x;
        neighbors.diagonals.z += gridDimensions.x;
    }
    if (index % gridDimensions.x == gridDimensions.x - 1) {
        // shift eastern down
        neighbors.cardinals.y -= gridDimensions.x;
        neighbors.diagonals.y -= gridDimensions.x;
        neighbors.diagonals.w -= gridDimensions.x;
    }
    
    return neighbors;
}


vertex void lifeSimulate(
    const device uchar* current [[ buffer(0) ]],
    device uchar* future [[ buffer(1) ]],
    const device Uniforms& uniforms [[ buffer(2) ]],
    unsigned int vId [[ vertex_id ]]
) {

    NeighborIndices neighbors = getNeighbors(vId, uniforms.gridDimensions);
    uchar neighborCount = 0;
    
    if (current[neighbors.cardinals.x] > 0) {
        neighborCount++;
    }
    if (current[neighbors.cardinals.y] > 0) {
        neighborCount++;
    }
    if (current[neighbors.cardinals.z] > 0) {
        neighborCount++;
    }
    if (current[neighbors.cardinals.w] > 0) {
        neighborCount++;
    }
    if (current[neighbors.diagonals.x] > 0) {
        neighborCount++;
    }
    if (current[neighbors.diagonals.y] > 0) {
        neighborCount++;
    }
    if (current[neighbors.diagonals.z] > 0) {
        neighborCount++;
    }
    if (current[neighbors.diagonals.w] > 0) {
        neighborCount++;
    }
    
    future[vId] = current[vId];
    if (current[vId] > 0) {
        if (neighborCount < 2) {
            future[vId] = 0;
        }
        else if (neighborCount > 3) {
            future[vId] = 0;
        }
    }
    else {
        if (neighborCount == 3) {
            future[vId] = 255;
        }
    }
}

vertex VertexOut lifeVertex (
    const device uchar* current [[ buffer(0) ]],
    const device Uniforms& uniforms [[ buffer(2) ]],
    unsigned int vId [[ vertex_id ]]
    ) {
    
    int xIndex = vId % uniforms.gridDimensions.x;
    int yIndex = vId / uniforms.gridDimensions.x;
    
    float startX = uniforms.gridDimensions.x * -gridSpacing;
    float startY = uniforms.gridDimensions.y * -gridSpacing;
    float endX   = uniforms.gridDimensions.x *  gridSpacing;
    float endY   = uniforms.gridDimensions.y *  gridSpacing;
    
    float xCoord = startX + (((endX - startX) / (uniforms.gridDimensions.x - 1)) * xIndex);
    float yCoord = startY + (((endY - startY) / (uniforms.gridDimensions.y - 1)) * yIndex);
        
    VertexOut vOut;
    vOut.position = uniforms.mvpMatrix * float4(xCoord, yCoord, 0.0, 1.0);
    vOut.pointSize = uniforms.pointSize;
    vOut.lifetime = current[vId];
    
    return vOut;
}

fragment float4 lifeFragment(
    VertexOut interpolated [[stage_in]],
    const device Uniforms& uniforms [[ buffer(2) ]]
) {
    if (interpolated.lifetime > 128) {
        return uniforms.fgColor;
    }
    else {
        return uniforms.bgColor;
    }
}
