// This is the older version of the shaders where all the logic
//  for calculating the grid and everything also lived here.
// All the CPU would do was feed this shader a zeroed buffer of
//  unsigned chars and it did the rest. (The CPU would also
//  check on the buffer every few seconds to see if it had reached
//  an equilibrium, and restart it if needed. But otherwise,
//  everything was here.)
//
// Including this file for historical reasons, because I like it.
//

#include <metal_stdlib>
using namespace metal;


constant float2 start(-12.0, -9.0);
constant float2 end(12.0, 9.0);
constant int gridWidth = 160;
constant int gridHeight = 120;
constant float pointSize = 9.0;
constant int numCells = gridWidth * gridHeight;
constant float intervalX = (end[0] - start[0]) / (gridWidth - 1);
constant float intervalY = (end[1] - start[1]) / (gridHeight - 1);

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
};

static NeighborIndices getNeighbors(unsigned int index) {
    NeighborIndices neighbors;

    neighbors.cardinals.x = index - 1; // west
    neighbors.cardinals.y = index + 1; // east
    neighbors.cardinals.z = (index - gridWidth) % numCells; // south
    neighbors.cardinals.w = (index + gridWidth) % numCells; // north

    neighbors.diagonals.x = neighbors.cardinals.z - 1; // southwest
    neighbors.diagonals.y = neighbors.cardinals.z + 1; // southeast
    neighbors.diagonals.z = neighbors.cardinals.w - 1; // northwest
    neighbors.diagonals.w = neighbors.cardinals.w + 1; // northeast

    if (index % gridWidth == 0) {
        // shift western up by one for wrap-around
        neighbors.cardinals.x += gridWidth;
        neighbors.diagonals.x += gridWidth;
        neighbors.diagonals.z += gridWidth;
    }
    if (index % gridWidth == gridWidth - 1) {
        // shift eastern down
        neighbors.cardinals.y -= gridWidth;
        neighbors.diagonals.y -= gridWidth;
        neighbors.diagonals.w -= gridWidth;
    }

    return neighbors;
}


vertex void lifeSimulate(
    const device uchar* current [[ buffer(0) ]],
    device uchar* future [[ buffer(1) ]],
    unsigned int vId [[ vertex_id ]]
) {

    NeighborIndices neighbors = getNeighbors(vId);
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

    int xIndex = vId % gridWidth;
    int yIndex = vId / gridWidth;

    float xCoord = start.x + (intervalX * xIndex);
    float yCoord = start.y + (intervalY * yIndex);

    VertexOut vOut;
    vOut.position = uniforms.mvpMatrix * float4(xCoord, yCoord, 0.0, 1.0);
    vOut.pointSize = pointSize;
    vOut.lifetime = current[vId];

    return vOut;
}

fragment float4 lifeFragment(VertexOut interpolated [[stage_in]]) {
    float red = 0.0;
    if (interpolated.lifetime > 128) {
        red = 1.0;
    }
    else {
        red = 0.25;
    }
    return float4(red, 0.0, 0.0, 1.0);
}

